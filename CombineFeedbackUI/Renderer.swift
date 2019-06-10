import SwiftUI
import CombineFeedback

public protocol Renderer {
    associatedtype State
    associatedtype Event

    func render(state: State, callback: Callback<Event>) -> AnyView
}
