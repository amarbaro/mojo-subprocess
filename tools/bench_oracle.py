import subprocess, time
t = time.perf_counter()
for _ in range(200): subprocess.run(["true"], capture_output=True)
s = (time.perf_counter() - t) / 200 * 1e6
data = b"a" * (256 << 20); t = time.perf_counter()
r = subprocess.run(["cat"], input=data, capture_output=True)
print("python spawn us", round(s), " cat GB/s", round(len(r.stdout) / (time.perf_counter() - t) / 1e9, 2))
