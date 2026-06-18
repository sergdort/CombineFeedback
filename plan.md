# Plan: StoreBinding SwiftUI API

## Goal

Replace the public SwiftUI context wrapper API with a native `@StoreBinding` dynamic property so SwiftUI views can observe a `Store` directly while still sending events and creating SwiftUI bindings from state.

## Constraints

- This is a new major version with no public compatibility burden for `WithContextView`, `ViewContext`, `Widget`, or `Context`.
- Observation is whole-state only, with duplicate suppression through the existing `Equatable & Sendable` default and an explicit custom `removeDuplicates` initializer.
- Do not add TCA-style fine-grained observation, macros, projection-based view state, or Swift Observation integration in this feature.
- Keep `IfLetStoreView`, `SwitchStoreView`, and `CaseLetStoreView` as public composition helpers, but remove their dependency on the old context API.

## Execution Sketch

```swift
@propertyWrapper
public struct StoreBinding<State, Event>: DynamicProperty {
  @ObservedObject private var subscription: StoreBindingSubscription<State, Event>
  private let store: Store<State, Event>

  public var wrappedValue: State { subscription.latestValue }
  public var projectedValue: StoreBinding<State, Event> { self }

  public init(_ store: Store<State, Event>, removeDuplicates: @escaping @Sendable (State, State) -> Bool)
  public func send(_ event: Event)
  public func binding<Value>(for keyPath: KeyPath<State, Value>, event: @escaping (Value) -> Event) -> Binding<Value>
  public func binding<Value>(for keyPath: KeyPath<State, Value>, event: Event) -> Binding<Value>
  public func action(for event: Event) -> () -> Void
  public func scoped<ScopedState, ScopedEvent>(to value: @escaping (State) -> ScopedState, event: @escaping (ScopedEvent) -> Event) -> StoreBinding<ScopedState, ScopedEvent>
}
```

`StoreBindingSubscription` is private infrastructure that mirrors the current `ViewContext` subscription behavior: initialize from `store.state`, subscribe to `store.publisher.removeDuplicates(by:)`, receive on `UIScheduler.shared`, and publish `latestValue` for SwiftUI invalidation.

`IfLetStoreView` observes optional state with `@StoreBinding` and keeps its public scoped-store `then`/`else` API. `SwitchStoreView` observes enum state with `@StoreBinding`, keeps the environment store reference for `CaseLetStoreView`, and preserves the existing case-routing call-site shape.

## Call Flow

Happy path, state rendering:

```text
SwiftUI evaluates View.body
-> @StoreBinding.wrappedValue returns StoreBindingSubscription.latestValue
-> view reads plain value-type State
-> body renders from that state
```

Happy path, event sending:

```text
Button action calls $state.send(.increment)
-> StoreBinding.send forwards to Store.send(event:)
-> StoreBox processes event through the state machine feedback loop
-> Store.publisher emits the new State
-> StoreBindingSubscription receives on UIScheduler.shared
-> @Published latestValue changes
-> SwiftUI invalidates the observing view
```

Important duplicate path:

```text
Store emits duplicate State according to removeDuplicates
-> StoreBindingSubscription suppresses the emission
-> @Published latestValue does not change
-> SwiftUI does not re-render because of that duplicate emission
```

## Work Steps

1. Add `StoreBinding.swift` with `StoreBinding` and private `StoreBindingSubscription`.
2. Implement projected helpers: `send(_:)`, `binding(for:event:)`, `action(for:)`, and scoped binding creation.
3. Remove old public context surface: `ViewContext`, `WithContextView`, `Context`, `Widget`, and `Store.context(removeDuplicates:)`.
4. Rework `IfLetStoreView`, `SwitchStoreView`, and `CaseLetStoreView` around `StoreBinding`.
5. Update README and examples to use `@StoreBinding`.
6. Add focused tests where practical and run package verification.

## Behavioral Contract

@must @tdd
Scenario: StoreBinding exposes the store initial state
  Given a store initialized with state `count = 0`
  When a view or test helper reads `StoreBinding.wrappedValue`
  Then the value is the store's current state
  Verification: test-first where practical, otherwise implementation-first if SwiftUI `DynamicProperty` scaffolding dominates the test.

@must @tdd
Scenario: StoreBinding sends events through the store
  Given a store whose reducer increments count on `.increment`
  When `$state.send(.increment)` is called
  Then the store processes the event and publishes state `count = 1`
  Verification: test-first against the projected API or a minimal SwiftUI-adapter test.

@must implementation-first
Scenario: StoreBinding creates SwiftUI bindings from state key paths
  Given a text field uses `$state.binding(for: \.email, event: Event.emailChanged)`
  When the binding setter receives `"a@example.com"`
  Then the store receives `Event.emailChanged("a@example.com")`
  Verification: implementation-first with a focused unit test if the setter can be exercised without full SwiftUI rendering.

@must implementation-first
Scenario: IfLetStoreView and SwitchStoreView keep scoped-store routing working
  Given optional or enum state helpers are used from SwiftUI
  When their bodies are evaluated
  Then they render matching scoped content through `Store` scoping without exposing the old context API
  Verification: implementation-first plus compile verification of examples.

@migration characterization-first
Scenario: Old context API is removed from the public surface
  Given code tries to use `WithContextView`, `ViewContext`, `Widget`, or `Context`
  When the package is built after this major-version change
  Then those symbols are no longer available as public API
  Verification: grep source/docs/examples and ensure no references remain except unrelated UIKit `context` parameters.

@deferred
Scenario: Property-level invalidation avoids re-rendering views that did not read changed properties
  Given a state change affects an unobserved property
  When a view using `@StoreBinding` renders only another property
  Then no property-level invalidation guarantee is provided in this feature.

## Verification

- Run `swift test`.
- Run `swift build`.
- Grep for `WithContextView`, `ViewContext`, `Widget`, and `Context` after implementation.
- Inspect updated README and examples for `@StoreBinding`, `state.property`, `$state.send(...)`, `$state.binding(...)`, and `$state.action(...)` usage.

## Plannotator Notes

- Plannotator review completed and approved before implementation.
