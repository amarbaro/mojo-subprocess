# Every public call once, plus the README example.
from subprocess import run, check_output


def check(ok: Bool, what: String) raises:
    if not ok:
        raise Error("FAIL api: " + what)


def main() raises:
    var r = run(["sh", "-c", "echo out; echo err >&2; exit 2"])
    check(r.returncode == 2 and r.text() == "out\n" and len(r.stderr) == 4, "run")
    check(r.args[0] == "sh", "args")
    var data = "abc".as_bytes()
    check(run(["cat"], input=data).text() == "abc", "input")
    check(String(from_utf8_lossy=check_output(["echo", "hi"])) == "hi\n", "check_output")
    var raised = False
    try:
        _ = check_output(["false"])
    except:
        raised = True
    check(raised, "check_output raises on failure")
    var nocap = run(["true"], capture_output=False)
    check(nocap.returncode == 0 and len(nocap.stdout) == 0, "no capture")
    print("PASS api")
