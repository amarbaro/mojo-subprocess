#!/usr/bin/env bash
# CI entry point (GitHub runner or local): install, build, then every gate. MOJO=path overrides the toolchain.
# Ends with "PASS n/m" (or "FAIL k/m"): the README checks badge parses that line.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v uv >/dev/null || { echo "FAIL setup: uv not installed"; exit 1; }
uv sync -q || { echo "FAIL setup: uv sync"; exit 1; }  # also with MOJO= set: the oracle's Python lives in this venv
MOJO=${MOJO:-.venv/bin/mojo}
"$MOJO" --version
[ -x .venv/bin/python ] && export ORACLE_PY=${ORACLE_PY:-.venv/bin/python}
mkdir -p .work/t
for t in tests/cases:.work/cases tests/api:.work/t/api examples/quickstart:.work/t/quickstart; do
  "$MOJO" build -O3 -I src ${MOJO_FLAGS:-} "${t%%:*}.mojo" -o "${t##*:}" 2>.work/build.err || { echo "FAIL build: ${t%%:*}.mojo"; cat .work/build.err; echo "FAIL 4/4"; exit 1; }
done
m=4; ok=0
gate() { local name=$1; shift; if "$@"; then ok=$((ok+1)); echo "ok $name"; else echo "FAIL $name"; echo "FAIL $((m-ok))/$m"; exit 1; fi; }
gate oracle env CASES=.work/cases scripts/check.sh
gate mutants env MOJO="$MOJO" scripts/mutants.sh
gate api .work/t/api
gate quickstart sh -c '.work/t/quickstart > /dev/null'
echo "PASS $ok/$m"
echo "PASS ci"
