import SwiftUI

struct ContentView: View {

    @State var isTwoFingerPanOnly = false
    @State var viewportState: ViewportState = .initial
    
    @State var zoomRequest: ZoomRequest = .none

    var body: some View {
        ZStack(alignment: .bottom) {

            ZoomPanRepresentable(
                image: UIImage(named: "sample")!,
                isTwoFingerPanOnly: isTwoFingerPanOnly,
                viewportState: $viewportState,
                zoomRequest: $zoomRequest
            )
            .ignoresSafeArea()
            .background(.black)

            HStack {
                Button("Reset"){
                    zoomRequest = .reset
                }
                
                Button("ズーム2倍,移動(1000,500)"){
                    zoomRequest = .set(scale: 2, centerInImage: CGPoint(x: 1000, y: 500))
                }
                Toggle("1本指でパン移動をできないようにする", isOn: $isTwoFingerPanOnly)
                Text(String(format: "scale: %.3f", viewportState.scale))
                Text(String(format: "position: (%.1f, %.1f)", viewportState.translation.x, viewportState.translation.y))
                Text(String(format: "center: (%.1f, %.1f)", viewportState.centerInImage.x, viewportState.centerInImage.y))
                Text(String(format: "visible: (%.1f, %.1f, %.1f, %.1f)",
                            viewportState.visibleRectInImage.minX,
                            viewportState.visibleRectInImage.minY,
                            viewportState.visibleRectInImage.width,
                            viewportState.visibleRectInImage.height))
            }
            .fixedSize(horizontal: true, vertical: false)

        }
    }
}

#Preview {
    ContentView()
}
