# Run uname, capture its output, fail loudly on a non-zero exit.
from subprocess import run


def main() raises:
    var r = run(["uname", "-sr"], timeout=5.0)
    if r.returncode != 0:
        raise Error(String(from_utf8_lossy=r.stderr))
    print("kernel:", r.text(), end="")
