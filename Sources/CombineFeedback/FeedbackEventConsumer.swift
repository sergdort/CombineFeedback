import Foundation

struct Token: Equatable {
    let value: UUID

    init() {
        value = UUID()
    }
}

public class FeedbackEventConsumer<Event> {
    func process(_ event: Event, for token: Token) {
        fatalError("This is an abstract class. You must subclass this and provide your own implementation")
    }

    func unqueueAllEvents(for token: Token) {
        fatalError("This is an abstract class. You must subclass this and provide your own implementation")
    }
}

extension FeedbackEventConsumer {
    func pullback<LocalEvent>(_ f: @escaping (LocalEvent) -> Event) -> FeedbackEventConsumer<LocalEvent> {
        return PullBackConsumer(upstream: self, pull: f)
    }
}

final class PullBackConsumer<LocalEvent, Event>: FeedbackEventConsumer<LocalEvent> {
    private let upstream: FeedbackEventConsumer<Event>
    private let pull: (LocalEvent) -> Event

    init(upstream: FeedbackEventConsumer<Event>, pull: @escaping (LocalEvent) -> Event) {
        self.pull = pull
        self.upstream = upstream
        super.init()
    }

    override func process(_ event: LocalEvent, for token: Token) {
        self.upstream.process(pull(event), for: token)
    }

    override func unqueueAllEvents(for token: Token) {
        self.upstream.unqueueAllEvents(for: token)
    }
}
