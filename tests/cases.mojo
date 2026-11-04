# The Mojo side of tools/oracle.py: `cases SCENARIO DIR` prints the same lines.
from std.sys import argv
from std.time import perf_counter_ns
from subprocess import run, check_output, CompletedProcess


def hexs(b: Span[UInt8, _]) -> String:
    comptime H = "0123456789abcdef"
    var s = String()
    for v in b:
        s += H[byte=Int(v >> 4)]
        s += H[byte=Int(v & 15)]
    return s


def d(b: Span[UInt8, _], w: String = "") -> String:
    var x = List[UInt8](b)
    if w:
        var t = String(from_utf8_lossy=b).replace(w, "<W>")
        x = List[UInt8](t.as_bytes())
    var t: UInt64 = 0
    for v in x:
        t += UInt64(v)
    var n = len(x)
    return String(n, " ", t & 0xFFFFFFFF, " ", hexs(Span(x)[: min(24, n)]), " ", hexs(Span(x)[max(0, n - 24) :]))


def show(tag: String, r: CompletedProcess, w: String = ""):
    print(tag, r.returncode, d(r.stdout, w), d(r.stderr, w))


def main() raises:
    var c = argv()[1]
    var w = String(argv()[2])
    var SH = "/bin/sh"
    if c == "basic":
        show("hello", run([SH, "-c", "printf 'hello\\n'; printf 'err' >&2"]))
        for cmd in ["exit 0", "exit 3", "exit 255", "kill -9 $$", "kill -TERM $$", "kill -INT $$"]:
            show("code " + cmd, run([SH, "-c", cmd]))
        show("empty", run(["true"]))
    elif c == "big":
        show("flood", run([SH, "-c", "yes x | head -c 3000000; yes yy | head -c 3000000 >&2; yes z | head -c 1000"]))
        var data = List[UInt8](capacity=5_000_000)
        for i in range(5_000_000):
            data.append(UInt8((i * 7 + 3) & 255))
        show("echo", run(["cat"], input=data))
        show("noread", run([SH, "-c", "exit 4"], input=data))
        show("headin", run(["head", "-c", "10"], input=data))
    elif c == "where":
        show("cwd", run([SH, "-c", "pwd; echo $FOO; echo ${HOME:-nohome}"], cwd=w, env=["FOO=bar", "PATH=/usr/bin:/bin"]), w)
        show("argv", run(["printf", "%s|", "a b", "", "ü", "$X", "'q'"]))
    elif c == "errors":
        var t0 = perf_counter_ns()
        try:
            _ = run(["sleep", "5"], timeout=0.3)
            print("timeout none")
        except e:
            print("timeout raised" if "timed out" in String(e) else "timeout other", "fast" if perf_counter_ns() - t0 < 2_000_000_000 else "slow")
        try:
            _ = run(["no-such-binary-xyz"])
            print("notfound none")
        except:
            print("notfound raised")
        try:
            _ = run([SH, "-c", "exit 7"], check=True)
            print("check none")
        except e:
            var s = String(e)
            print("check raised", String(s[byte = s.find("status ") + 7 : s.byte_length() - 1]))
        print("check_output", d(check_output([SH, "-c", "echo ok"])))
        print("check_output_err", d(check_output([SH, "-c", "echo out; echo to-stderr >&2"])))
        try:
            _ = run(List[String]())
            print("emptyargv none")
        except:
            print("emptyargv raised")
        show("emptyinput", run(["cat"], timeout=5.0, close_stdin=True))
