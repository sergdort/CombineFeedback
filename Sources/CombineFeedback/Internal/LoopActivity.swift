import Foundation

/// Reports whether a running feedback loop is idle.
///
/// A `Store` owns one and gives it to its `FeedbackLoop`. The loop attaches its
/// `Floodgate` when it starts, so the `Store` can tell when no event waits and
/// no thread drains the loop.
final class LoopActivity: @unchecked Sendable {
  private let probe = Atomic<(() -> Bool)?>(nil)

  /// `true` before the loop starts and after it ends.
  var isIdle: Bool {
    probe.value?() ?? true
  }

  func attach(_ isIdle: @escaping () -> Bool) {
    probe.value = isIdle
  }
}
