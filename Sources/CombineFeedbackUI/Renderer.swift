import SwiftUI
import CombineFeedback

public protocol Renderer {
    associatedtype State
    associatedtype Event

    func render(context: Context<State, Event>) -> AnyView
}
