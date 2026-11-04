# mojo-subprocess

<!-- badges -->
[![ci](https://github.com/amarbaro/mojo-subprocess/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/amarbaro/mojo-subprocess/actions/workflows/ci.yml) [![latest release](https://img.shields.io/github/v/release/amarbaro/mojo-subprocess)](https://github.com/amarbaro/mojo-subprocess/releases/latest) [![license](https://img.shields.io/github/license/amarbaro/mojo-subprocess)](https://github.com/amarbaro/mojo-subprocess/blob/main/LICENSE) [![checks](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/amarbaro/mojo-subprocess/badges/checks.json)](https://github.com/amarbaro/mojo-subprocess/actions/workflows/ci.yml)
<!-- /badges -->

Python's `subprocess.run` for Mojo: run a program, capture stdout and stderr, feed it input, with timeout, cwd, env and check. Large outputs on both pipes are drained together, so nothing deadlocks. 164 lines of code (`mojo-loc`) on top of mojo-posix (vendored in `src/posix`).

```mojo
from subprocess import run

var r = run(["git", "rev-parse", "HEAD"], timeout=5.0)
if r.returncode == 0:
    print(r.text())                        # stdout as text; r.stdout / r.stderr are bytes
var cat = run(["sort"], input="b\na\n".as_bytes())
```

**Checked against Python subprocess:** exit codes and signal deaths (`-9`, `-15`, `-2`), a 3 MB + 3 MB flood on stdout and stderr at once, a 5 MB stdin echo, a child that exits without reading its input, `head` closing early, cwd and env, argv with spaces, empty strings and Unicode, empty input (EOF), stdout and stderr byte-identical; timeout, missing program, empty argv, `check` and `check_output` raise where Python raises, with the same return codes (the error texts are this library's own, see docs/api.md). `scripts/check.sh`, each scenario twice. 6 of 6 mutants caught. Builds and passes on Mojo 1.2.0 and the 1.3 nightly.

**Speed** (7800X3D, load average about 29 at the time): `run(["true"])` 418 µs and 0.60 GB/s through `cat`; Python 543 to 1,155 µs and 0.35 to 0.47 GB/s across runs.

**Requires** Linux 5.3 or newer for the pidfd (older kernels fall back to polling `waitpid` every millisecond) and glibc 2.29 or newer (`posix_spawn_file_actions_addchdir_np`). The program is looked up on this process's PATH, also when `env` sets another PATH (Python uses the PATH from `env`); pass an absolute path in that case.

- API: [docs/api.md](docs/api.md) · design: [docs/design.md](docs/design.md) · agent skill: [skills/mojo-subprocess/SKILL.md](skills/mojo-subprocess/SKILL.md)
- License: Apache-2.0
