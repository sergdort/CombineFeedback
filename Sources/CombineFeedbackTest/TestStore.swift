import Combine
@_spi(Testing) import CombineFeedback
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
/// The test store reduces events only on the main thread, so it is isolated to
/// the main actor. Events from observations and effects that finish on other
/// threads wait in the queue, and the main queue reduces them when the test
/// suspends. This gives two rules that hold in every test:
///
/// - When `send` returns, the loop has reduced the event and started its
///   feedbacks.
/// - No event reduces between two lines of synchronous test code. Events from
///   other threads reduce only at an `await`.
///
/// A production `Store` reduces an event on the thread that sends it. Every
/// order of events the test store produces is also an order that production
/// can produce.
@MainActor
public final class TestStore<State, Event> {
  /// The underlying production store. Exposed so tests can `scope` or inspect it.
  public let store: Store<State, Event>

  /// Every state the loop has emitted, plus how far `wait` has consumed it.
  ///
  /// `wait` matches against this recorded trajectory rather than the
  /// instantaneous `store.state`, so a state the machine only *passed through*
  /// (a spinner between idle and loaded) is still observable even if the effect
  /// executor replaced it before `wait` ran. Sequential `wait`s advance the
  /// cursor, which makes ordered waypoints deterministic regardless of
  /// scheduling.
  private struct Recorder {
    var states: [State] = []
    var cursor: Int = 0
  }
  private let recorder = Locked<Recorder>(Recorder())
  private var bag = Set<AnyCancellable>()

  public init<M: StateMachine>(
    initial: State,
    machine: M
  ) where M.State == State, M.Event == Event {
    let store = Store(initial: initial, machine: machine, drainsOnMainThread: true)
    self.store = store
    store.publisher.sink { [recorder] state in
      recorder.withLock { $0.states.append(state) }
    }
    .store(in: &bag)
  }

  /// The current state of the machine.
  public var state: State { store.state }

  /// Sends an event into the loop. The loop reduces the event and starts its
  /// feedbacks before `send` returns.
  public func send(_ event: Event) {
    store.send(event: event)
  }

  /// Suspends until some state the loop has reached satisfies `predicate`, or
  /// reports a test failure after `timeout`.
  ///
  /// Matching is against the recorded trajectory from the point the previous
  /// `wait` left off — not the instantaneous `store.state` — so a transient
  /// state the machine passed through is still observable, and sequential
  /// `wait`s consume waypoints in order.
  ///
  /// Each `Task.yield()` lets the main queue reduce events from other threads.
  /// On success this returns as soon as a state matches (microseconds with
  /// immediate mocks). The full timeout only elapses when the machine never
  /// arrives — i.e. a real bug — at which point an issue is reported at the
  /// call site (via swift-issue-reporting, so it surfaces in both XCTest and
  /// Swift Testing) with the last state and the observed trajectory.
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
      if consumeMatch(predicate) { return }
      if Date() >= deadline {
        let snapshot = recorder.value
        reportIssue(
          Self.timeoutMessage(
            timeout: timeout,
            lastState: snapshot.states.last ?? store.state,
            trajectory: snapshot.states
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

  /// Scans the trajectory from the cursor forward. If a recorded state matches,
  /// advances the cursor past it and returns `true`; otherwise leaves the cursor
  /// in place so newly appended states are considered on the next attempt.
  private func consumeMatch(_ predicate: (State) -> Bool) -> Bool {
    recorder.withLock { recorder in
      var index = recorder.cursor
      while index < recorder.states.count {
        if predicate(recorder.states[index]) {
          recorder.cursor = index + 1
          return true
        }
        index += 1
      }
      return false
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

/// Minimal mutex wrapper for the trajectory recorder. The store's publisher
/// sink is a nonisolated closure, so the recorder does not rely on the main
/// actor even though the test store only drains on the main thread.
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
