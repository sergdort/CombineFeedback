@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
struct ArrayAsyncSequence<Element: Sendable>: AsyncSequence, Sendable {
  typealias Failure = Never

  let elements: [Element]

  init(_ elements: [Element]) {
    self.elements = elements
  }

  func makeAsyncIterator() -> Iterator {
    Iterator(elements: elements)
  }

  struct Iterator: AsyncIteratorProtocol, Sendable {
    private let elements: [Element]
    private var index = 0

    init(elements: [Element]) {
      self.elements = elements
    }

    mutating func next() async -> Element? {
      guard index < elements.count else { return nil }
      defer { index += 1 }
      return elements[index]
    }
  }
}
