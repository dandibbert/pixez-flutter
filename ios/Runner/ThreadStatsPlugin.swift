import Darwin
import Flutter
import Foundation

/// Reports this process's own CPU usage, broken down by thread.
///
/// Dart can only observe its own isolate. When the UI is asleep and the device
/// still warms up, the work is on some other thread — the raster thread, a
/// plugin's queue, or the Rust HTTP runtime — and none of them are reachable
/// from Dart. Mach exposes them for the calling task, which is allowed in a
/// sandboxed app because it only ever inspects itself.
struct ThreadStatsPlugin {
    /// Spelled out rather than taken from the headers: these are C macros and
    /// are not reliably re-exported into Swift across SDK versions.
    private static let usageScale: Double = 1000
    private static let idleFlag: Int32 = 0x1
    private static let threadBasicInfoCount = mach_msg_type_number_t(
        MemoryLayout<thread_basic_info_data_t>.size / MemoryLayout<natural_t>.size
    )
    private static let absolutetimeInfoCount = mach_msg_type_number_t(
        MemoryLayout<task_absolutetime_info_data_t>.size
            / MemoryLayout<natural_t>.size
    )

    static func bind(_ engineBridge: FlutterImplicitEngineBridge) {
        let channel = FlutterMethodChannel(
            name: "com.perol.dev/threads",
            binaryMessenger: engineBridge.applicationRegistrar.messenger()
        )
        channel.setMethodCallHandler { call, result in
            guard call.method == "sample" else {
                result(FlutterMethodNotImplemented)
                return
            }
            result(Self.sample())
        }
    }

    static func sample() -> [String: Any] {
        return [
            "cpuSeconds": cpuSeconds(),
            "threads": threadBreakdown(),
        ]
    }

    /// Total CPU time this process has burned since launch, across every
    /// thread including ones that have already exited. Sampling it twice and
    /// dividing by wall time is the only honest way to get a CPU percentage.
    private static func cpuSeconds() -> Double {
        var info = task_absolutetime_info()
        var count = absolutetimeInfoCount
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_ABSOLUTETIME_INFO),
                    $0,
                    &count
                )
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }

        var timebase = mach_timebase_info_data_t()
        guard mach_timebase_info(&timebase) == KERN_SUCCESS, timebase.denom != 0 else {
            return 0
        }
        let ticks = Double(info.total_user) + Double(info.total_system)
        let nanos = ticks * Double(timebase.numer) / Double(timebase.denom)
        return nanos / 1_000_000_000
    }

    /// Live threads and what each is doing right now, busiest first. Named so
    /// a hot thread can be attributed to whatever created it.
    private static func threadBreakdown() -> [[String: Any]] {
        var list: thread_act_array_t?
        var count: mach_msg_type_number_t = 0
        guard task_threads(mach_task_self_, &list, &count) == KERN_SUCCESS,
              let threads = list
        else {
            return []
        }
        defer {
            vm_deallocate(
                mach_task_self_,
                vm_address_t(UInt(bitPattern: UnsafeRawPointer(threads))),
                vm_size_t(Int(count) * MemoryLayout<thread_t>.stride)
            )
        }

        var entries: [[String: Any]] = []
        for index in 0..<Int(count) {
            var info = thread_basic_info()
            var infoCount = threadBasicInfoCount
            let kr = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                    thread_info(
                        threads[index],
                        thread_flavor_t(THREAD_BASIC_INFO),
                        $0,
                        &infoCount
                    )
                }
            }
            guard kr == KERN_SUCCESS else { continue }
            if info.flags & idleFlag != 0 { continue }
            let usage = Double(info.cpu_usage) / usageScale * 100
            entries.append(["name": name(of: threads[index]), "cpu": usage])
        }
        entries.sort {
            ($0["cpu"] as? Double ?? 0) > ($1["cpu"] as? Double ?? 0)
        }
        return Array(entries.prefix(5))
    }

    private static func name(of thread: thread_t) -> String {
        guard let handle = pthread_from_mach_thread_np(thread) else {
            return "thread-\(thread)"
        }
        var buffer = [CChar](repeating: 0, count: 64)
        if pthread_getname_np(handle, &buffer, buffer.count) == 0 {
            let name = String(cString: buffer)
            if !name.isEmpty { return name }
        }
        return "thread-\(thread)"
    }
}
