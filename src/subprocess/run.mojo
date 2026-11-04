"""subprocess.run: spawn with pipes, feed input and drain stdout/stderr together (no deadlock on large
output), timeout kills the child, return codes as Python (minus the signal number)."""
from std.ffi import external_call
from std.time import perf_counter_ns
from posix import reap, kill, SIGKILL, PollSet, POLLIN, POLLOUT
from posix.proc import _CStrings, _environ
from posix._sys import errno, error_code

comptime _CLOEXEC = 0o2000000
comptime _NONBLOCK = 0o4000
comptime _CHUNK = 65536


struct CompletedProcess(Movable):
    var args: List[String]
    var returncode: Int
    var stdout: List[UInt8]
    var stderr: List[UInt8]

    def __init__(out self, var args: List[String], code: Int, var out: List[UInt8], var err: List[UInt8]):
        self.args = args^
        self.returncode = code
        self.stdout = out^
        self.stderr = err^

    def text(self) -> String:
        """stdout decoded as UTF-8 (invalid bytes replaced)."""
        return String(from_utf8_lossy=self.stdout)


def _pipe() raises -> Tuple[Int32, Int32]:
    var fds = SIMD[DType.int32, 2](0)
    if external_call["pipe2", Int32](Pointer(to=fds), Int32(_CLOEXEC)) != 0:
        raise Error("subprocess: pipe failed")
    return (fds[0], fds[1])


def _close(fd: Int32):
    if fd >= 0:
        _ = external_call["close", Int32](fd)


def _spawn(argv: List[String], env: List[String], cwd: String, i: Int32, o: Int32, e: Int32) raises -> Int:
    """posix_spawnp with stdin/stdout/stderr dup2'd from the given fds (-1 inherits)."""
    var st = List[UInt8](length=80 + 336 + 128, fill=0)  # file_actions, spawnattr, sigset (glibc sizes)
    var fa = Int(st.unsafe_ptr())
    var at = fa + 80
    var sg = at + 336
    _ = external_call["posix_spawn_file_actions_init", Int32](fa)
    for t in [(i, 0), (o, 1), (e, 2)]:
        if t[0] >= 0:
            var rc = external_call["posix_spawn_file_actions_adddup2", Int32](fa, t[0], Int32(t[1]))
            if rc != 0:
                _ = external_call["posix_spawn_file_actions_destroy", Int32](fa)
                raise error_code("subprocess: spawn setup (dup2)", Int(rc))
    var d = cwd.copy()
    if cwd.byte_length() > 0:
        var rc = external_call["posix_spawn_file_actions_addchdir_np", Int32](fa, d.as_c_string_span().ptr())
        if rc != 0:
            _ = external_call["posix_spawn_file_actions_destroy", Int32](fa)
            raise error_code("subprocess: spawn setup (chdir)", Int(rc))
    _ = external_call["posix_spawnattr_init", Int32](at)
    _ = external_call["sigemptyset", Int32](sg)
    _ = external_call["posix_spawnattr_setsigmask", Int32](at, sg)
    _ = external_call["sigfillset", Int32](sg)
    _ = external_call["posix_spawnattr_setsigdefault", Int32](at, sg)
    _ = external_call["posix_spawnattr_setflags", Int32](at, Int16(0x8 | 0x4))
    var av = _CStrings(argv)
    var ev = _CStrings(env)
    var envp = Int(ev.ptrs.unsafe_ptr()) if len(env) > 0 else _environ()
    var pid = Int32(0)
    var prog = av.ptrs[0]
    var rc = external_call["posix_spawnp", Int32](Pointer(to=pid), prog, fa, at, Int(av.ptrs.unsafe_ptr()), envp)
    _ = external_call["posix_spawn_file_actions_destroy", Int32](fa)
    _ = external_call["posix_spawnattr_destroy", Int32](at)
    _ = (st[0], av.data[0], ev.ptrs[0], d)
    if rc != 0:
        raise error_code("subprocess: cannot run '" + argv[0] + "'", Int(rc))
    return Int(pid)


def _drain(fd: Int32, mut buf: List[UInt8], mut tmp: List[UInt8]) -> Bool:
    """Read what is there; False at EOF."""
    var n = external_call["read", Int](fd, tmp.unsafe_ptr(), _CHUNK)
    if n > 0:
        buf.extend(Span(tmp)[:n])
        return True
    return n < 0 and (errno() == 4 or errno() == 11)


def run(
    argv: List[String],
    input: Span[UInt8, _] = Span[UInt8, ImmUntrackedOrigin](),
    capture_output: Bool = True,
    timeout: Float64 = -1.0,
    cwd: String = "",
    env: List[String] = [],
    check: Bool = False,
    close_stdin: Bool = False,
    capture_stderr: Bool = True,
) raises -> CompletedProcess:
    """Python subprocess.run(argv, input=..., capture_output=..., timeout=..., cwd=..., env=..., check=...).
    Raises "timed out after S seconds" (child killed) and "returned non-zero exit status N" (check=True).
    close_stdin=True gives the child an empty stdin (EOF) when there is no input: Python's input=b"".
    capture_stderr=False leaves stderr on this process's stderr while stdout is captured."""
    if len(argv) == 0:
        raise Error("subprocess: empty argv")
    _ = external_call["signal", Int](Int32(13), Int(1))  # SIGPIPE ignored, as in Python
    var feed = len(input) > 0 or close_stdin
    var pi = (Int32(-1), Int32(-1))
    var po = (Int32(-1), Int32(-1))
    var pe = (Int32(-1), Int32(-1))
    var pid: Int
    try:
        if feed:
            pi = _pipe()
        if capture_output:
            po = _pipe()
        if capture_output and capture_stderr:
            pe = _pipe()
        pid = _spawn(argv, env, cwd, pi[0], po[1], pe[1])
    except e:
        for fd in [pi[0], pi[1], po[0], po[1], pe[0], pe[1]]:
            _close(fd)
        raise e^
    _close(pi[0])
    _close(po[1])
    _close(pe[1])
    if feed:
        var fl = external_call["fcntl", Int32](pi[1], Int32(3), Int32(0))
        _ = external_call["fcntl", Int32](pi[1], Int32(4), fl | Int32(_NONBLOCK))
    var out = List[UInt8]()
    var err = List[UInt8]()
    var tmp = List[UInt8](length=_CHUNK, fill=0)
    var deadline = Int(perf_counter_ns()) + Int(timeout * 1e9) if timeout >= 0 else Int.MAX
    var sent = 0
    var o_open = po[0] >= 0
    var e_open = pe[0] >= 0
    var i_open = feed
    var pidfd = Int32(external_call["syscall", Int](434, pid, 0))  # pidfd_open: readable when the child exits
    var alive = True
    var timed_out = False
    var code = Optional[Int](None)
    var ps = PollSet()  # reused: one allocation for the whole run
    while o_open or e_open or i_open or alive:
        var now = Int(perf_counter_ns())
        if now >= deadline:
            timed_out = True
            break
        ps.clear()
        var io = ps.add(po[0], POLLIN) if o_open else -1
        var ie = ps.add(pe[0], POLLIN) if e_open else -1
        var ii = ps.add(pi[1], POLLOUT) if i_open else -1
        var ip = ps.add(pidfd, POLLIN) if alive and pidfd >= 0 else -1
        var wait_ms = -1 if deadline == Int.MAX else Int((deadline - now) // 1_000_000) + 1
        if alive and pidfd < 0:
            wait_ms = 1 if wait_ms < 0 else min(wait_ms, 1)  # no pidfd (old kernel): poll waitpid
        var ready = ps.wait(wait_ms)
        if io >= 0 and ready > 0 and ps.revents(io) != 0 and not _drain(po[0], out, tmp):
            o_open = False
        if ie >= 0 and ready > 0 and ps.revents(ie) != 0 and not _drain(pe[0], err, tmp):
            e_open = False
        if ii >= 0 and ready > 0 and ps.revents(ii) != 0:
            var n = external_call["write", Int](pi[1], input.unsafe_ptr() + sent, min(len(input) - sent, _CHUNK))
            if n > 0:
                sent += n
            if (n < 0 and errno() != 11 and errno() != 4) or sent >= len(input):
                _close(pi[1])
                i_open = False
        if alive and ((ip >= 0 and ready > 0 and ps.revents(ip) != 0) or pidfd < 0):
            code = reap(pid, False)
            alive = not code
    _close(pidfd)
    for fd in [po[0], pe[0]]:
        _close(fd)
    if i_open:
        _close(pi[1])
    if timed_out:
        _ = kill(pid, SIGKILL)
        _ = reap(pid, True)
        raise Error("Command '", argv[0], "' timed out after ", timeout, " seconds")
    var rc = code.value()
    if check and rc != 0:
        raise Error("Command '", argv[0], "' returned non-zero exit status ", rc, ".")
    return CompletedProcess(argv.copy(), rc, out^, err^)


def check_output(argv: List[String], timeout: Float64 = -1.0, cwd: String = "", env: List[String] = []) raises -> List[UInt8]:
    """run(..., check=True).stdout"""
    return run(argv, timeout=timeout, cwd=cwd, env=env, check=True, capture_stderr=False).stdout.copy()
