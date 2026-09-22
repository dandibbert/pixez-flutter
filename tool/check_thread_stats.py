"""Stress the production Darwin sampler without requiring Flutter.

Run on macOS with the existing Xcode command-line tools. Only Flutter channel
registration is omitted from the temporary compilation unit; sampling functions
are compiled unchanged. This is not an iOS playback or thermal test.
"""

from pathlib import Path
import subprocess
import tempfile


root = Path(__file__).resolve().parents[1]
source = (root / "ios/Runner/ThreadStatsPlugin.swift").read_text()
source = source.replace("import Flutter\n", "")
start = source.index("    static func bind(")
end = source.index("    static func sample()", start)
source = source[:start] + source[end:]
check = r"""
let thread = mach_thread_self()
func refs() -> mach_port_urefs_t {
    var value: mach_port_urefs_t = 0
    precondition(mach_port_get_refs(mach_task_self_, thread,
        mach_port_right_t(MACH_PORT_RIGHT_SEND), &value) == KERN_SUCCESS)
    return value
}
let before = refs()
for _ in 0..<1000 { _ = ThreadStatsPlugin.sample() }
let after = refs()
print("1,000 samples: main-thread send rights before=\(before), after=\(after)")
mach_port_deallocate(mach_task_self_, thread)
precondition(after == before, "Sampling leaked Mach send rights")
"""
with tempfile.TemporaryDirectory(prefix="pixez-thread-stress-") as folder:
    path = Path(folder)
    (path / "main.swift").write_text(source + check)
    subprocess.run(
        ["swiftc", str(path / "main.swift"), "-o", str(path / "check")], check=True
    )
    subprocess.run([str(path / "check")], check=True)
