"""Oracle: Python subprocess.run. `oracle.py --list`; `oracle.py NAME DIR` prints its lines.
Outputs print as length, byte sum and the first/last 24 bytes, with DIR replaced by <W>."""
import os, subprocess, sys, time
sys.stdout.reconfigure(line_buffering=True)
def d(b, w=""):
    b = b.replace(w.encode(), b"<W>") if w else b
    return f"{len(b)} {sum(b) & 0xFFFFFFFF} {b[:24].hex()} {b[-24:].hex()}"
def show(tag, r, w=""): print(tag, r.returncode, d(r.stdout, w), d(r.stderr, w))
SH = "/bin/sh"
def basic(w):
    show("hello", subprocess.run([SH, "-c", "printf 'hello\\n'; printf 'err' >&2"], capture_output=True))
    for c in ("exit 0", "exit 3", "exit 255", "kill -9 $$", "kill -TERM $$", "kill -INT $$"):
        show("code " + c, subprocess.run([SH, "-c", c], capture_output=True))
    show("empty", subprocess.run(["true"], capture_output=True))
def big(w):
    show("flood", subprocess.run([SH, "-c", "yes x | head -c 3000000; yes yy | head -c 3000000 >&2; yes z | head -c 1000"], capture_output=True))
    data = bytes((i * 7 + 3) & 255 for i in range(5_000_000))
    show("echo", subprocess.run(["cat"], input=data, capture_output=True))
    show("noread", subprocess.run([SH, "-c", "exit 4"], input=data, capture_output=True))
    show("headin", subprocess.run(["head", "-c", "10"], input=data, capture_output=True))
def where(w):
    show("cwd", subprocess.run([SH, "-c", "pwd; echo $FOO; echo ${HOME:-nohome}"], cwd=w, env={"FOO": "bar", "PATH": "/usr/bin:/bin"}, capture_output=True), w)
    show("argv", subprocess.run(["printf", "%s|", "a b", "", "ü", "$X", "'q'"], capture_output=True))
def errors(w):
    t = time.monotonic()
    try: subprocess.run(["sleep", "5"], timeout=0.3, capture_output=True); print("timeout none")
    except subprocess.TimeoutExpired: print("timeout raised", "fast" if time.monotonic() - t < 2 else "slow")
    try: subprocess.run(["no-such-binary-xyz"], capture_output=True); print("notfound none")
    except FileNotFoundError: print("notfound raised")
    try: subprocess.run([SH, "-c", "exit 7"], check=True, capture_output=True); print("check none")
    except subprocess.CalledProcessError as e: print("check raised", e.returncode)
    print("check_output", d(subprocess.check_output([SH, "-c", "echo ok"])))
    print("check_output_err", d(subprocess.check_output([SH, "-c", "echo out; echo to-stderr >&2"], stderr=None)))
    try: subprocess.run([], capture_output=True); print("emptyargv none")
    except (IndexError, ValueError): print("emptyargv raised")
    show("emptyinput", subprocess.run(["cat"], input=b"", capture_output=True, timeout=5))
S = {"basic": basic, "big": big, "where": where, "errors": errors}
if sys.argv[1] == "--list": print("\n".join(S))
else: S[sys.argv[1]](sys.argv[2])
