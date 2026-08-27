import Foundation

final class LockedArray<Element>: @unchecked Sendable {
  private let lock = NSLock()
  private var elements: [Element] = []

  var values: [Element] {
    lock.lock()
    defer { lock.unlock() }
    return elements
  }

  func append(_ element: Element) {
    lock.lock()
    defer { lock.unlock() }
    elements.append(element)
  }
}
