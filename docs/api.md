# API

`from subprocess import run, check_output, CompletedProcess`

| Call | Does |
|---|---|
| `run(argv, input=Span(), capture_output=True, timeout=-1.0, cwd="", env=[], check=False, close_stdin=False, capture_stderr=True) -> CompletedProcess` | Runs `argv[0]` (searched on PATH). `input` goes to stdin (otherwise stdin is inherited). `timeout` in seconds kills the child (SIGKILL) and raises `... timed out after S seconds`. `env` as `NAME=value` replaces the environment; empty inherits. `check=True` raises `... returned non-zero exit status N.` Raises when the program cannot start, and on an empty `argv`. `close_stdin=True` gives the child an empty stdin (EOF) when there is no input, like Python's `input=b""`. `capture_stderr=False` captures stdout only. |
| `check_output(argv, timeout=-1.0, cwd="", env=[]) -> List[UInt8]` | `run(..., check=True).stdout`; stderr goes to this process's stderr, as in Python. |
| `CompletedProcess.args`, `.returncode`, `.stdout`, `.stderr`, `.text()` | Exit code, or minus the signal number; captured bytes; stdout as UTF-8. |

`run` sets SIGPIPE to ignored in this process, as Python does at startup; children get default handlers back.

Error texts: `Command '<argv0>' timed out after S seconds`, `Command '<argv0>' returned non-zero exit status N.`, `posix: subprocess: cannot run '<argv0>': <strerror> (errno N)`, `subprocess: empty argv`. Python's texts quote the whole argv list; these name the program only.
