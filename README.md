# mojo-subprocess

<!-- badges -->
[![ci](https://github.com/amarbaro/mojo-subprocess/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/amarbaro/mojo-subprocess/actions/workflows/ci.yml) [![latest release](https://img.shields.io/github/v/release/amarbaro/mojo-subprocess)](https://github.com/amarbaro/mojo-subprocess/releases/latest) [![license](https://img.shields.io/github/license/amarbaro/mojo-subprocess)](https://github.com/amarbaro/mojo-subprocess/blob/main/LICENSE) [![checks](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/amarbaro/mojo-subprocess/badges/checks.json)](https://github.com/amarbaro/mojo-subprocess/actions/workflows/ci.yml)
<!-- /badges -->

Python's `subprocess.run` for Mojo: run a program, capture stdout and stderr, feed it input, with timeout, cwd, env and check. Large outputs on both pipes are drained together, so nothing deadlocks. 164 lines of code (`mojo-loc`) on top of mojo-posix (vendored in `src/posix`).

Install: `pixi workspace channel add https://conda.modular.com/max https://prefix.dev/amarbaro/amarbaro`, then `pixi add mojo-subprocess` (import `subprocess`). From source: `git clone https://github.com/amarbaro/mojo-subprocess`, then `mojo run -I mojo-subprocess/src app.mojo`.
Toolchains: Mojo 1.2 stable, and the nightly 1.3.0.dev2026110805 in the weekly [mojo-libs](https://github.com/amarbaro/mojo-libs) matrix (36 libraries on stable, 35 on nightly).

```mojo
from subprocess import run


def main() raises:
    var r = run(["git", "rev-parse", "HEAD"], timeout=5.0)
    if r.returncode == 0:
        print(r.text())                        # stdout as text; r.stdout / r.stderr are bytes
    var cat = run(["sort"], input="b\na\n".as_bytes())
```

| Call | Does |
|---|---|
| `run(argv, input=Span(), capture_output=True, timeout=-1.0, cwd="", env=[], check=False, close_stdin=False, capture_stderr=True) -> CompletedProcess` | Runs `argv[0]` (searched on PATH). `input` goes to stdin (otherwise stdin is inherited). `timeout` in seconds kills the child (SIGKILL) and raises `... timed out after S seconds`. `env` as `NAME=value` replaces the environment; empty inherits. `check=True` raises `... returned non-zero exit status N.` Raises when the program cannot start, and on an empty `argv`. `close_stdin=True` gives the child an empty stdin (EOF) when there is no input, like Python's `input=b""`. `capture_stderr=False` captures stdout only. |
| `check_output(argv, timeout=-1.0, cwd="", env=[]) -> List[UInt8]` | `run(..., check=True).stdout`; stderr goes to this process's stderr, as in Python. |
| `CompletedProcess.args`, `.returncode`, `.stdout`, `.stderr`, `.text()` | Exit code, or minus the signal number; captured bytes; stdout as UTF-8. |

**Checked against Python subprocess:** exit codes and signal deaths (`-9`, `-15`, `-2`), a 3 MB + 3 MB flood on stdout and stderr at once, a 5 MB stdin echo, a child that exits without reading its input, `head` closing early, cwd and env, argv with spaces, empty strings and Unicode, empty input (EOF), stdout and stderr byte-identical; timeout, missing program, empty argv, `check` and `check_output` raise where Python raises, with the same return codes (the error texts are this library's own, see docs/api.md). `scripts/check.sh`, each scenario twice. 6 of 6 mutants caught. Builds and passes on Mojo 1.2.0 and the 1.3 nightly.

**Speed** (7800X3D, load average about 29 at the time): `run(["true"])` 418 µs and 0.60 GB/s through `cat`; Python 543 to 1,155 µs and 0.35 to 0.47 GB/s across runs.

**Requires** Linux 5.3 or newer for the pidfd (older kernels fall back to polling `waitpid` every millisecond) and glibc 2.29 or newer (`posix_spawn_file_actions_addchdir_np`). The program is looked up on this process's PATH, also when `env` sets another PATH (Python uses the PATH from `env`); pass an absolute path in that case.

- API: [docs/api.md](docs/api.md) · design: [docs/design.md](docs/design.md) · agent skill: [skills/mojo-subprocess/SKILL.md](skills/mojo-subprocess/SKILL.md)
- License: Apache-2.0
