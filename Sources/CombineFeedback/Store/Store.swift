import Combine
import Foundation

open class Store<State, Event> {
  private let box: StoreBoxBase<State, Event>

  public var state: State {
    box._current
  }

  public var publisher: AnyPublisher<State, Never> {
    box.publisher
  }

  init(box: StoreBoxBase<State, Event>) {
    self.box = box
  }

  public init<M: StateMachine>(
    initial: State,
    machine: M
  ) where M.State == State, M.Event == Event {
    self.box = RootStoreBox(
      initial: initial,
      machine: machine
    )
  }

  open func send(event: Event) {
    box.send(event: event)
  }

  public func scope<S>(
    getValue: @Sendable @escaping (State) -> S
  ) -> Store<S, Event> {
    Store<S, Event>(
      box: box.scoped(getValue: getValue, event: { $0 })
    )
  }

  public func scope<S, E>(
    getValue: @Sendable @escaping (State) -> S,
    event: @Sendable @escaping (E) -> Event
  ) -> Store<S, E> {
    Store<S, E>(
      box: box.scoped(getValue: getValue, event: event)
    )
  }

  public func scoped<S, E>(
    to scope: WritableKeyPath<State, S>,
    event: @Sendable @escaping (E) -> Event
  ) -> Store<S, E> {
    return Store<S, E>(box: box.scoped(to: scope, event: event))
  }
}

/// A `Store` may cross isolation boundaries when its `State` and `Event` are
/// `Sendable`; a `Store` over other state or events keeps working exactly as
/// before and is simply not `Sendable`.
///
/// The conformance is conditional because both directions cross threads: `state`
/// and `publisher` hand `State` back to whoever observes, and `send(event:)`
/// carries `Event` into the loop.
///
/// It is `@unchecked` because `Store` is an open class, so the compiler cannot
/// verify subclass state, and because two of the guarantees live in the
/// implementation rather than in the type:
///
/// - `Store` stores an immutable `StoreBoxBase`. A root box owns a
///   `CurrentValueSubject` that already serialises reads and writes, and a scoped
///   box derives from its parent without holding mutable state of its own.
/// - `send(event:)` goes through `Feedback.input`, whose `Floodgate` queues events
///   behind an `NSLock`/`Atomic` pair. Reduction is exclusive per drain, so
///   concurrent sends from any number of threads are ordered, never dropped and
///   never reduced concurrently.
///
/// Everything else is compiler-checked. Scope projections and event transforms
/// are `@Sendable`, so the compiler diagnoses closures that capture
/// non-`Sendable` state at the `scope` call — an error wherever the capture is
/// known non-`Sendable`, but only a warning in generic contexts (such as
/// `IfLetStoreView`) where the captured type may still prove `Sendable` after
/// instantiation. Key-path scopes wrap the key path (immutable metadata) in a
/// narrow `@unchecked Sendable` box so the projection stays capture-free.
///
/// Subclasses must restate `@unchecked Sendable` to acknowledge the same
/// contract; the compiler warns on any subclass that does not, since only the
/// subclass author knows whether the added state upholds it. Restating it on a
/// generic subclass drops the `State`/`Event` conditionality, so constrain
/// generic subclasses (for example `where State: Sendable, Event: Sendable`)
/// instead of conforming them unconditionally.
///
/// One boundary stays contractual: a scoped store reads its parent outside the
/// event-drain lock, so do not transfer a scoped store across isolation unless
/// every ancestor state is `Sendable`. Transferring a `Sendable`-projected
/// store whose parent holds non-`Sendable` mutable state is a contract
/// violation, exactly like any other `@unchecked` escape hatch.
/// Reducer, feedback and effect closures still run on whichever thread drives
/// the loop, so the isolation of anything they capture remains the caller's
/// responsibility.
extension Store: @unchecked Sendable where State: Sendable, Event: Sendable {}

extension Array {
  func appending(_ element: Element) -> [Element] {
    var copy = self

    copy.append(element)

    return copy
  }
}

public extension Publisher where Self.Failure == Never {
  func assign<Root: AnyObject>(
    to keyPath: WritableKeyPath<Root, Self.Output>, weakly object: Root
  ) -> AnyCancellable {
    return self.sink { [weak object] output in
      object?[keyPath: keyPath] = output
    }
  }
}
