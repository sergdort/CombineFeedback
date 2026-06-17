import Combine
import CombineFeedback
import SwiftUI

extension TrafficLight {
    final class ViewModel: Store<TrafficLight.State, TrafficLight.Event> {
        init() {
            super.init(
                initial: .red,
                machine: TrafficLight()
            )
        }
    }
}
