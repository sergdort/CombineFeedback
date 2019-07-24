import Foundation
import Combine

/// A scheduler that implements virtualized time, for use in testing.
/// This implementation is *heavily* based on the TestScheduler in
/// ReactiveSwift: https://github.com/ReactiveCocoa/ReactiveSwift/blob/master/Sources/Scheduler.swift
public class TestScheduler: Scheduler {
    public typealias SchedulerTimeType = DispatchQueue.SchedulerTimeType
    public typealias SchedulerOptions = Never

    private final class ScheduledAction {
        let date: SchedulerTimeType
        let action: () -> Void

        init(date: SchedulerTimeType, action: @escaping () -> Void) {
            self.date = date
            self.action = action
        }

        func less(_ rhs: ScheduledAction) -> Bool {
            return date < rhs.date
        }
    }

    private let lock = NSRecursiveLock()
    private var _currentDate: SchedulerTimeType
    private var scheduledActions: [ScheduledAction] = []

    public var now: SchedulerTimeType {
        let d: SchedulerTimeType

        lock.lock()
        d = _currentDate
        lock.unlock()

        return d
    }

    public var minimumTolerance: SchedulerTimeType.Stride {
        return SchedulerTimeType.Stride(.nanoseconds(1))
    }

    public init() {
        lock.name = "CombineFeedback.TestScheduler"
        _currentDate = SchedulerTimeType(DispatchTime.now())
    }

    private func schedule(_ action: ScheduledAction) -> Void {
        lock.lock()
        scheduledActions.append(action)
        scheduledActions.sort { $0.less($1) }
        lock.unlock()
    }

    public func schedule(options: Never?, _ action: @escaping () -> Void) {
        schedule(ScheduledAction(date: now, action: action))
    }

    public func schedule(
        after date: DispatchQueue.SchedulerTimeType,
        tolerance: DispatchQueue.SchedulerTimeType.Stride,
        options: Never?,
        _ action: @escaping () -> Void
    ) {
        schedule(ScheduledAction(date: date, action: action))
    }

    public func schedule(
        after date: DispatchQueue.SchedulerTimeType,
        interval: DispatchQueue.SchedulerTimeType.Stride,
        tolerance: DispatchQueue.SchedulerTimeType.Stride,
        options: Never?,
        _ action: @escaping () -> Void
    ) -> Cancellable {
        let scheduledAction = ScheduledAction(date: date, action: action)
        schedule(scheduledAction)

        return AnyCancellable {
            self.lock.lock()
            self.scheduledActions = self.scheduledActions.filter { $0 !== scheduledAction }
            self.lock.unlock()
        }
    }

    /// Advances the virtualized clock by an extremely tiny interval, dequeuing
    /// and executing any actions along the way.
    ///
    /// This is intended to be used as a way to execute actions that have been
    /// scheduled to run as soon as possible.
    public func advance() {
        advance(by: .nanoseconds(1))
    }

    /// Advances the virtualized clock by the given interval, dequeuing and
    /// executing any actions along the way.
    ///
    /// - parameters:
    ///   - interval: Interval by which the current date will be advanced.
    public func advance(by interval: DispatchQueue.SchedulerTimeType.Stride) {

        lock.lock()
        advance(to: now.advanced(by: interval))
        lock.unlock()
    }


    /// Advances the virtualized clock to the given future date, dequeuing and
    /// executing any actions up until that point.
    ///
    /// - parameters:
    ///   - newDate: Future date to which the virtual clock will be advanced.
    public func advance(to newDate: SchedulerTimeType) {
        lock.lock()
        assert(now.dispatchTime <= newDate.dispatchTime)

        while scheduledActions.count > 0 {
            if newDate.dispatchTime < scheduledActions[0].date.dispatchTime {
                break
            }

            _currentDate = scheduledActions[0].date

            let scheduledAction = scheduledActions.remove(at: 0)
            scheduledAction.action()
        }

        _currentDate = newDate

        lock.unlock()
    }

    /// Dequeues and executes all scheduled actions, leaving the scheduler's
    /// date at `DispatchTime.distantFuture`.
    public func run() {
        advance(to: SchedulerTimeType(DispatchTime.distantFuture))
    }
}
