import SwiftUI
import CombineFeedbackUI

struct TrafficLightView: View {
    @StateObject
    var context: ViewContext<TrafficLight.State, TrafficLight.Event>
    
    init(context: ViewContext<TrafficLight.State, TrafficLight.Event>) {
        self._context = StateObject(wrappedValue: context)
        logInit(of: self)
    }
    
    var body: some View {
        logBody(of: self)
        return VStack {
            Circle()
                .frame(width: 150, height: 150)
                .animation(.default)
                .foregroundColor(Color.red.opacity(context.isRed ? 1 : 0.5))
            Circle()
                .frame(width: 150, height: 150)
                .animation(.default)
                .foregroundColor(Color.yellow.opacity(context.isYellow ? 1 : 0.5))
            Circle()
                .frame(width: 150, height: 150)
                .animation(.default)
                .foregroundColor(Color.green.opacity(context.isGreen ? 1 : 0.5))
        }
        .padding()
        .background(Color.black)
    }
}

#if DEBUG
struct TrafficLightView_Preview: PreviewProvider {
    
    static var previews: some View {
        TrafficLightView(
            context: .empty(.green)
        )
        .previewLayout(.sizeThatFits)
    }
}
#endif

