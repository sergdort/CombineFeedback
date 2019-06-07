import Combine
import Foundation

public struct DispatchQueueScheduler: Scheduler {
    public typealias SchedulerTimeType = DispatchTime
    public typealias SchedulerOptions = Never

    public static var main: DispatchQueueScheduler {
        return DispatchQueueScheduler(queue: DispatchQueue.main)
    }

    public var now: DispatchTime {
        return DispatchTime.now()
    }

    /// Returns the minimum tolerance allowed by the scheduler.
    public var minimumTolerance: Double {
        return 0
    }

    private let queue: DispatchQueue

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    public func schedule(options: Never?, _ action: @escaping () -> Void) {
        self.queue.async(execute: action)
    }

    public func schedule(
        after date: DispatchTime,
        tolerance: DispatchTime.Stride,
        options: SchedulerOptions?,
        _ action: @escaping () -> Void
    ) {
        self.schedule(options: options, action)
    }

    public func schedule(
        after date: DispatchTime,
        interval: DispatchTime.Stride,
        tolerance: DispatchTime.Stride,
        options: DispatchQueueScheduler.SchedulerOptions?,
        _ action: @escaping () -> Void
    ) -> Cancellable {
        let workItem = DispatchWorkItem(block: action)
        self.queue.async(execute: workItem)
        return workItem
    }
}

extension DispatchWorkItem: Cancellable {}

extension DispatchTime: Strideable {
    public func advanced(by n: Double) -> DispatchTime {
        return self + Double.seconds(n)
    }

    public func distance(to other: DispatchTime) -> Double {
        return Double(other.uptimeNanoseconds - uptimeNanoseconds)
    }
}

extension Double: SchedulerTimeIntervalConvertible {
    public static func seconds(_ s: Int) -> Double {
        return Double(s)
    }

    public static func seconds(_ s: Double) -> Double {
        return s
    }

    public static func milliseconds(_ ms: Int) -> Double {
        return Double(ms) / 1000
    }

    public static func microseconds(_ us: Int) -> Double {
        return Double(us) / 1_000_000
    }

    public static func nanoseconds(_ ns: Int) -> Double {
        return Double(ns) / 1_000_000_000
    }
}
