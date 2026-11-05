import CasePaths
import Combine
import CombineFeedback
import Testing

// `Store`'s thread-safety is a compile-time contract: a `Store` is `Sendable`
// exactly when its state and events are. These tests pair compile-time coverage
// — declarations that stop compiling if the conformance or its `where` clause
// regresses — with deterministic runtime coverage of sending and observing from
// isolation domains other than the one that created the store.

// MARK: - Machines under test

private struct Counter: StateMachine {
  struct State: Equatable, Sendable {
    var count = 0
  }

  enum Event: Equatable, Sendable {
    case increment
    case add(Int)
  }

  @StateMachineBuilder<State, Event>
  var body: some StateMachine<State, Event> {
    Reducer<State, Event> { state, event in
      switch event {
      case .increment: state.count += 1
      case let .add(value): state.count += value
      }
    }
  }
}

private struct Outer: StateMachine {
  struct State: Equatable, Sendable {
    var child = Counter.State()
  }

  @CasePathable
  enum Event: Equatable, Sendable {
    case child(Counter.Event)
  }

  @StateMachineBuilder<State, Event>
  var body: some StateMachine<State, Event> {
    Scope(state: \.child, event: \.child) {
      Counter()
    }
  }
}

/// Classes never conform to `Sendable` implicitly, so this keeps the state and
/// events of `ReferenceMachine` non-`Sendable`.
private final class ReferenceCounter {
  var count = 0
}

private struct ReferenceMachine: StateMachine {
  struct State {
    var counter = ReferenceCounter()
  }

  enum Event {
    case apply(ReferenceCounter)
  }

  @StateMachineBuilder<State, Event>
  var body: some StateMachine<State, Event> {
    Reducer<State, Event> { state, event in
      switch event {
      case let .apply(counter): state.counter = counter
      }
    }
  }
}

/// The shape downstream consumers use once `Store` is `Sendable`: a `Sendable`
/// façade holds the store directly instead of boxing it in a mutex.
private final class CounterController: Sendable {
  let store: Store<Counter.State, Counter.Event>

  init(store: Store<Counter.State, Counter.Event>) {
    self.store = store
  }

  func increment() {
    store.send(event: .increment)
  }
}

/// Subclasses inherit the unchecked conformance and must acknowledge it by
/// restating `@unchecked Sendable`, which is the only way to silence the
/// compiler's "must restate inherited '@unchecked Sendable' conformance"
/// warning. Declaring that idiom here keeps it compiling.
private final class CounterSubclass: Store<Counter.State, Counter.Event>, @unchecked Sendable {
  init() {
    super.init(initial: Counter.State(), machine: Counter())
  }
}

private func requireSendable<T: Sendable>(_ value: T) {}

// MARK: - Compile-time coverage

struct StoreSendableTests {
  /// A root store, a `scope(getValue:)` store, a `scope(getValue:event:)` store
  /// and a `scoped(to:event:)` store all satisfy `Sendable` over `Sendable`
  /// state and events. Every `requireSendable` call here is a compile-time
  /// assertion: dropping the conformance or loosening its constraints fails
  /// this file's build.
  @Test func sendableStateAndEventStoresAtEveryScopeAreSendable() {
    let store = Store(initial: Counter.State(), machine: Counter())
    requireSendable(store)

    let projected = store.scope(getValue: \.count)
    requireSendable(projected)

    let mapped = store.scope(
      getValue: { $0.count },
      event: { (event: Int) in Counter.Event.add(event) }
    )
    requireSendable(mapped)

    let keyPathScoped = store.scoped(
      to: \.count,
      event: { (event: Int) in Counter.Event.add(event) }
    )
    requireSendable(keyPathScoped)

    let controller = CounterController(store: store)
    requireSendable(controller)

    let subclass = CounterSubclass()
    requireSendable(subclass)

    // Scope projections and event transforms must be `@Sendable`: they are
    // stored in the scoped box and run on whichever thread drives the loop,
    // so the compiler diagnoses closures that capture non-`Sendable` state.
    // Non-capturing projections like these are implicitly `@Sendable`.
    let projectCount: @Sendable (Counter.State) -> Int = { $0.count }
    let addToCounter: @Sendable (Int) -> Counter.Event = { .add($0) }
    requireSendable(store.scope(getValue: projectCount, event: addToCounter))

    // The projections are the live ones, not compile-only fixtures.
    keyPathScoped.send(event: 5)
    #expect(store.state.count == 5)
    #expect(projected.state == 5)
    #expect(mapped.state == 5)
    #expect(controller.store.state.count == 5)

    subclass.send(event: .increment)
    #expect(subclass.state.count == 1)
  }

  /// The conformance is conditional, not blanket: a `Store` over non-`Sendable`
  /// state and events still constructs, sends and reduces. That is what keeps
  /// the constraint honest — a store that cannot safely cross threads is simply
  /// not `Sendable`, and using one where `Sendable` is required is a compile
  /// error rather than a silencer.
  @Test func storesOverNonSendableStateAndEventsStillRun() {
    let store = Store(initial: ReferenceMachine.State(), machine: ReferenceMachine())
    let replacement = ReferenceCounter()
    replacement.count = 3

    store.send(event: .apply(replacement))

    #expect(store.state.counter === replacement)
    #expect(store.state.counter.count == 3)
  }

  // MARK: - Cross-isolation send

  @Test func sendFromDetachedTaskAppliesAndIsVisibleToTheCaller() async {
    let store = Store(initial: Counter.State(), machine: Counter())

    await Task.detached { store.send(event: .increment) }.value

    #expect(store.state.count == 1)
  }

  /// The downstream shape: a `Sendable` façade that holds the store itself and
  /// commands it from another isolation domain, with no mutex in between.
  @Test func sendableControllerCommandsFromDetachedTask() async {
    let controller = CounterController(store: Store(initial: Counter.State(), machine: Counter()))

    await Task.detached { controller.increment() }.value

    #expect(controller.store.state.count == 1)
  }

  @Test func sendThroughScopedStoreFromDetachedTaskReachesParentAndChild() async {
    let parent = Store(initial: Outer.State(), machine: Outer())
    let scoped = parent.scope(
      getValue: \.child,
      event: { (event: Counter.Event) in Outer.Event.child(event) }
    )

    await Task.detached { scoped.send(event: .increment) }.value

    #expect(scoped.state.count == 1)
    #expect(parent.state.child.count == 1)
  }

  /// Concurrent sends from many tasks are serialised by the loop: every event
  /// is reduced exactly once, and every state is published exactly once (the
  /// initial state plus one per event). The recorded set of states is therefore
  /// deterministic even though the interleaving is not.
  @Test func concurrentSendsFromManyTasksAreSerializedWithoutDroppingEvents() async {
    let store = Store(initial: Counter.State(), machine: Counter())
    let states = LockedArray<Int>()
    let cancellable = store.publisher.sink { states.append($0.count) }

    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 50 {
        group.addTask { store.send(event: .increment) }
      }
    }
    cancellable.cancel()

    #expect(states.values.first == 0)
    #expect(states.values.count == 51)
    #expect(states.values.sorted() == Array(0 ... 50))
    #expect(store.state.count == 50)
  }

  // MARK: - Cross-isolation observation

  @Test func detachedObserverSeesCurrentStateFirstThenEachUpdate() async {
    let store = Store(initial: Counter.State(), machine: Counter())

    let observed = await Task.detached { () -> [Int] in
      let states = LockedArray<Int>()
      let cancellable = store.publisher.sink { states.append($0.count) }
      store.send(event: .increment)
      store.send(event: .add(2))
      cancellable.cancel()
      return states.values
    }.value

    #expect(observed == [0, 1, 3])
    #expect(store.state.count == 3)
  }

  @Test func detachedObserverOfScopedStoreSeesChildState() async {
    let parent = Store(initial: Outer.State(), machine: Outer())
    let scoped = parent.scoped(
      to: \.child,
      event: { (event: Counter.Event) in Outer.Event.child(event) }
    )

    let observed = await Task.detached { () -> [Int] in
      let states = LockedArray<Int>()
      let cancellable = scoped.publisher.sink { states.append($0.count) }
      scoped.send(event: .add(4))
      cancellable.cancel()
      return states.values
    }.value

    #expect(observed == [0, 4])
    #expect(scoped.state.count == 4)
    #expect(parent.state.child.count == 4)
  }
}
