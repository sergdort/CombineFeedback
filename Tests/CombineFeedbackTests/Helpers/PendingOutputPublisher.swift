import Combine

struct PendingOutputPublisher<Output>: Publisher {
  typealias Failure = Never

  let outputs: [Output]

  init(_ outputs: [Output]) {
    self.outputs = outputs
  }

  func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
    subscriber.receive(subscription: Subscription(outputs: outputs, subscriber: AnySubscriber(subscriber)))
  }

  private final class Subscription: Combine.Subscription {
    private var outputs: [Output]
    private var subscriber: AnySubscriber<Output, Never>?

    init(outputs: [Output], subscriber: AnySubscriber<Output, Never>) {
      self.outputs = outputs
      self.subscriber = subscriber
    }

    func request(_ demand: Subscribers.Demand) {
      guard let subscriber else { return }

      for output in outputs {
        _ = subscriber.receive(output)
      }
      outputs = []
    }

    func cancel() {
      subscriber = nil
      outputs = []
    }
  }
}
