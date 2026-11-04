---
name: mojo-subprocess
description: "Run external programs from Mojo with mojo-subprocess (Python subprocess.run semantics): capture stdout/stderr, pass input, timeout, cwd, env, check. Use whenever Mojo code shells out to git, ffmpeg, compilers or any CLI."
---

# mojo-subprocess

```mojo
from subprocess import run, check_output
var r = run(["ffmpeg", "-i", src, dst], timeout=600.0)
if r.returncode != 0: raise Error(String(from_utf8_lossy=r.stderr))
var head = check_output(["git", "rev-parse", "HEAD"])
```

- argv is a list: no shell, no quoting. For pipes or globbing, run `["/bin/sh", "-c", "..."]` yourself.
- A timeout raises after killing the child; catch it if a slow run is expected.
- `capture_output=False` lets the child write to this process's own stdout/stderr.

Gate: `scripts/ci.sh` (Python subprocess oracle, mutants, api, quickstart).
