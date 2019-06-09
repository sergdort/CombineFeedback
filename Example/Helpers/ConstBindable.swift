import Combine
import SwiftUI

final class ConstBindable<T>: BindableObject {
    let didChange = PassthroughSubject<Void, Never>()
    let value: T

    init(value: T) {
        self.value = value
    }
}
