import Combine

extension Publisher {
    public func replaceError(
        replace: @escaping (Failure) -> Self.Output
    ) -> AnyPublisher<Self.Output, Never> {
        return `catch` { error in
            Just(replace(error))
        }.eraseToAnyPublisher()
    }

    public func ignoreError() -> AnyPublisher<Output, Never> {
        return `catch` { _ in
            Empty()
        }.eraseToAnyPublisher()
    }
}
