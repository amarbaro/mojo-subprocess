#!/usr/bin/env bash
# The gate: every scenario in tools/oracle.py run by the Python oracle and by CASES (tests/cases.mojo
# built), outputs byte-identical, each in a fresh scratch dir, each twice to catch flakiness.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${CASES:?FAIL setup: set CASES to the built case runner}"
PY=${ORACLE_PY:-python3}
D=${CHECK_DIR:-.work/check}
mkdir -p "$D"; fail=0; n=0
for c in $($PY -I tools/oracle.py --list); do
  for run in 1 2; do
    for side in exp got; do
      w=$(mktemp -d "$PWD/$D/$c.$side.XXXX")
      if [ $side = exp ]; then $PY -I tools/oracle.py "$c" "$w" > "$D/$c.$side" 2>&1 || true
      else timeout 60 "$CASES" "$c" "$w" > "$D/$c.$side" 2>&1 || true; fi
      rm -rf "$w"
    done
    [ -s "$D/$c.exp" ] || { echo "FAIL $c: empty oracle output"; fail=$((fail+1)); continue; }
    cmp -s "$D/$c.exp" "$D/$c.got" || { echo "FAIL $c (run $run)"; diff "$D/$c.exp" "$D/$c.got" | head -6; fail=$((fail+1)); }
  done
  n=$((n+1))
done
echo "scenarios: $n, each twice; failures: $fail"
[ "$fail" -eq 0 ] || { echo "FAIL check: $fail"; exit 1; }
echo "PASS all"
