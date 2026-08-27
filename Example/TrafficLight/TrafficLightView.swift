import SwiftUI
import CombineFeedback

struct TrafficLightView: View {
  @StoreBinding<TrafficLight.State, TrafficLight.Event> private var state: TrafficLight.State

  init(store: Store<TrafficLight.State, TrafficLight.Event>) {
    self._state = StoreBinding(store)
    logInit(of: self)
  }

  var body: some View {
    VStack {
      Circle()
        .fill(Color.red.opacity(state.isRed ? 1 : 0.5))
        .frame(width: 150, height: 150)
      Circle()
        .fill(Color.yellow.opacity(state.isYellow ? 1 : 0.5))
        .frame(width: 150, height: 150)
      Circle()
        .fill(Color.green.opacity(state.isGreen ? 1 : 0.5))
        .frame(width: 150, height: 150)
    }
    .padding()
    .background(Color.black)
  }
}

#if DEBUG
struct TrafficLightView_Preview: PreviewProvider {
  static var previews: some View {
    TrafficLightView(
      store: .empty(.green)
    )
    .previewLayout(.sizeThatFits)
  }
}
#endif
