@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
actor AsyncGate {
  private var continuations: [CheckedContinuation<Void, Never>] = []
  private var isOpen = false

  func wait() async {
    if isOpen {
      return
    }

    await withCheckedContinuation { continuation in
      if isOpen {
        continuation.resume()
      } else {
        continuations.append(continuation)
      }
    }
  }

  func open() {
    isOpen = true
    let continuations = self.continuations
    self.continuations = []

    for continuation in continuations {
      continuation.resume()
    }
  }
}
