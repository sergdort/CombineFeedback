import Combine

extension Publishers {
    public struct Feedbackloop<Output, Event>: Publisher {
        public typealias Failure = Never
        let initial: Output
        let reduce: Reducer<Output, Event>
        let feedbacks: [Feedback<Output, Event>]

        public init(
            initial: Output,
            reduce: @escaping Reducer<Output, Event>,
            feedbacks: [Feedback<Output, Event>]
        ) {
            self.initial = initial
            self.reduce = reduce
            self.feedbacks = feedbacks
        }

        public func receive<S>(subscriber: S) where S: Combine.Subscriber, Failure == S.Failure, Output == S.Input {
            let subscriber = Subscriber(subscriber: subscriber)
            let floodgate = Floodgate<Output, Event>(state: initial, reducer: reduce)
            for feedback in self.feedbacks {
                subscriber.add(cancelable: feedback.events(floodgate.stateDidChange.eraseToAnyPublisher(), floodgate))
            }
            subscriber.receive(subscription: floodgate)
            subscriber.add(cancelable: floodgate.stateDidChange.sink { state in
                _ = subscriber.receive(state)
            })
            floodgate.bootstrap()
        }

        private final class Subscriber<S: Combine.Subscriber, Input>
        : Combine.Subscriber where S.Input == Input, S.Failure == Failure {
            private let subscriber: S
            private let bag = Atomic([Cancellable]())

            init(subscriber: S) {
                self.subscriber = subscriber
            }

            func receive(subscription: Combine.Subscription) {
                self.subscriber.receive(subscription: subscription)
            }

            func receive(_ input: Input) -> Subscribers.Demand {
                return self.subscriber.receive(input)
            }

            func receive(completion: Subscribers.Completion<Never>) {
                self.subscriber.receive(completion: completion)
                self.bag.withValue { items in
                    for item in items {
                        item.cancel()
                    }
                }
            }

            func add(cancelable: Cancellable) {
                self.bag.modify { items in
                    items.append(cancelable)
                }
            }
        }
    }
}
