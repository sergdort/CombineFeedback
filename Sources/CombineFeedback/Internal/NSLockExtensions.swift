import Foundation

extension NSLock {
  func perform<Result>(_ action: () -> Result) -> Result {
    lock()
    defer { unlock() }

    return action()
  }
}
