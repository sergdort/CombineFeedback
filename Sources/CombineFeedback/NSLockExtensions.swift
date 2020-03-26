import Foundation

extension NSLock {
    internal func perform<Result>(_ action: () -> Result) -> Result {
        lock()
        defer { unlock() }

        return action()
    }
}
