import SwiftUI

struct ContentView: View {

    @State var isTwoFingerPanOnly = false

    var body: some View {
        ZStack(alignment: .bottom) {

            ZoomPanRepresentable(
                image: UIImage(named: "sample")!, isTwoFingerPanOnly: isTwoFingerPanOnly
            )
            .ignoresSafeArea()
            .background(.black)

            Toggle("1本指でパン移動をできないようにする", isOn: $isTwoFingerPanOnly)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

#Preview {
    ContentView()
}
