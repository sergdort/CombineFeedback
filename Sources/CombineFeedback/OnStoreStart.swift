import Foundation

/// Starts an `AsyncSequence` when this feedback is subscribed.
///
/// The sequence is subscribed to once per feedback subscription. A finite
/// sequence is one-shot: completion does not restart it after later state
/// updates. Cancelling the feedback subscription cancels iteration and removes
/// events already queued by this effect.
///
/// In optional `IfLet` or case-based `Scope` composition, tearing down and
/// re-entering the child feedback creates a new feedback subscription and thus
/// a new sequence subscription.
@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
public struct OnStoreStart<State, Event, Sequence: AsyncSequence & Sendable>: StateMachine
  where Sequence.Element == Event,
  Sequence.Failure == Never
{
  public typealias Body = Never

  private let onChange: OnChange<State, Event, Bool>

  public init(_ sequence: @escaping () -> Sequence) {
    onChange = OnChange(of: { _ in true }) { _ in
      sequence()
    }
  }

  public func _resolve() -> ResolvedMachine<State, Event> {
    onChange._resolve()
  }
}
