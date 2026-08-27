import Combine
import Foundation

final class ManualPublisher<Output>: Publisher {
  typealias Failure = Never

  private let lock = NSLock()
  private var subscriptions: [Subscription] = []
  private var cancels = 0

  var cancelCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return cancels
  }

  func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
    let subscription = Subscription(parent: self, subscriber: AnySubscriber(subscriber))
    lock.lock()
    subscriptions.append(subscription)
    lock.unlock()
    subscriber.receive(subscription: subscription)
  }

  private func didCancel(_ subscription: Subscription) {
    lock.lock()
    cancels += 1
    subscriptions.removeAll { $0 === subscription }
    lock.unlock()
  }

  private final class Subscription: Combine.Subscription {
    private weak var parent: ManualPublisher?
    private var subscriber: AnySubscriber<Output, Never>?

    init(parent: ManualPublisher, subscriber: AnySubscriber<Output, Never>) {
      self.parent = parent
      self.subscriber = subscriber
    }

    func request(_ demand: Subscribers.Demand) {}

    func cancel() {
      subscriber = nil
      parent?.didCancel(self)
    }
  }
}
