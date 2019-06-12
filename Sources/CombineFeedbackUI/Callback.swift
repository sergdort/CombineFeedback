import Combine

public struct Callback<Event> {
    private let _send: (Event) -> Void

    public init(send: @escaping (Event) -> Void) {
        _send = send
    }

    public init(subscriber: AnySubscriber<Event, Never>) {
        _send = { event in
            _ = subscriber.receive(event)
        }
    }

    public init(subject: AnySubject<Event, Never>) {
        _send = subject.send
    }

    public func send(event: Event) {
        _send(event)
    }

    internal static var empty: Callback<Event> {
        return Callback(send: { _ in })
    }
}
