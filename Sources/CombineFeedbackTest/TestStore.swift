import Combine
import CombineFeedback
import CustomDump
import Foundation
import IssueReporting

// MARK: - A TestStore-like facility for CombineFeedback state machines.
//
// Philosophy: test the destination, not the journey. You drive the real Store +
// real feedback loop, mock dependencies through the machine's initializer, and
// assert by waiting for a state predicate. The (event ->) state trajectory is
// recorded only for failure diagnostics; it never touches a passing test.
//
// Deliberately omitted for now (additive, non-breaking when added later):
//   - full-history / snapshot assertion
//   - in-flight effect leak detection
//   - controllable clocks (time is the consumer's concern: inject a scheduler)

/// Drives a state machine for testing: send events, then `wait` for the state
/// the user would observe.
///
/// `@unchecked Sendable`: the underlying `Store` serialises event processing
/// (Floodgate) and exposes state through a thread-safe `CurrentValueSubject`,
/// and the trajectory recorder is mutex-guarded, so the store is safe to use
/// across isolation boundaries in tests.
public final class TestStore<State, Event>: @unchecked Sendable {
  /// The underlying production store. Exposed so tests can `scope` or inspect it.
  public let store: Store<State, Event>

  private let trajectory = Locked<[State]>([])
  private var bag = Set<AnyCancellable>()

  public init<M: StateMachine>(
    initial: State,
    machine: M
  ) where M.State == State, M.Event == Event {
    let store = Store(initial: initial, machine: machine)
    self.store = store
    store.publisher.sink { [trajectory] state in
      trajectory.withLock { $0.append(state) }
    }
    .store(in: &bag)
  }

  /// The current state of the machine.
  public var state: State { store.state }

  /// Sends an event into the loop, exactly as the production store would.
  public func send(_ event: Event) {
    store.send(event: event)
  }

  /// Suspends until `predicate(state)` is true, or reports a test failure after
  /// `timeout`.
  ///
  /// On success this returns the instant the loop reaches a matching state
  /// (microseconds with immediate mocks). The full timeout only elapses when the
  /// machine never arrives — i.e. a real bug — at which point an issue is
  /// reported at the call site (via swift-issue-reporting, so it surfaces in both
  /// XCTest and Swift Testing) with the last state and the observed trajectory.
  public func wait(
    timeout: TimeInterval = 0.1,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column,
    until predicate: (State) -> Bool
  ) async {
    let deadline = Date().addingTimeInterval(timeout)
    while true {
      if predicate(store.state) { return }
      if Date() >= deadline {
        reportIssue(
          Self.timeoutMessage(
            timeout: timeout,
            lastState: store.state,
            trajectory: trajectory.value
          ),
          fileID: fileID,
          filePath: filePath,
          line: line,
          column: column
        )
        return
      }
      await Task.yield()
    }
  }

  private static func timeoutMessage(
    timeout: TimeInterval,
    lastState: State,
    trajectory: [State]
  ) -> String {
    var out = "wait(until:) timed out after \(Int(timeout * 1000))ms — predicate never satisfied.\n"
    out += "  Last state: \(dump(lastState))\n"
    out += "  Observed trajectory:\n"
    for state in trajectory {
      out += "    \(dump(state))\n"
    }
    return out
  }

  private static func dump(_ state: State) -> String {
    var rendered = ""
    customDump(state, to: &rendered)
    // Keep each state on a single indented line in the trajectory list.
    return rendered.replacingOccurrences(of: "\n", with: "\n    ")
  }
}

/// Minimal mutex wrapper so the trajectory recorder is safe across the
/// background executor threads that async feedbacks emit from.
private final class Locked<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: Value
  init(_ value: Value) { self._value = value }
  func withLock<R>(_ body: (inout Value) -> R) -> R {
    lock.lock(); defer { lock.unlock() }
    return body(&_value)
  }
  var value: Value { withLock { $0 } }
}
