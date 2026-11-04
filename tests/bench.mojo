# Spawn latency (run(["true"]) x 200) and pipe throughput (cat of 256 MiB through stdin/stdout).
from std.time import perf_counter_ns
from subprocess import run


def main() raises:
    var t0 = perf_counter_ns()
    for _ in range(200):
        _ = run(["true"])
    var spawn_us = Float64(perf_counter_ns() - t0) / 200e3
    var data = List[UInt8](length=256 << 20, fill=97)
    t0 = perf_counter_ns()
    var r = run(["cat"], input=data)
    var gbs = Float64(len(r.stdout)) / Float64(perf_counter_ns() - t0)
    print("spawn us", spawn_us, " cat GB/s", gbs, " bytes", len(r.stdout))
