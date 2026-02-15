import DrawingKit
import SwiftUI

// MARK: - Common binding applicator (そのまま使ってOK)
extension View {
    // iOS16 では old/new が取れないので lastInteractionMode を外から渡す
    func applyBindingsForOperation(
        canvas: Binding<DrawingCanvasView?>,
        interactionMode: Binding<InteractionMode>,
        lastInteractionMode: Binding<InteractionMode>,
        drawingSettings: Binding<DrawingSettings>,
        overlayRects: Binding<[CanvasRect]>,
        selectedRectIDs: Binding<Set<UUID>>,
        isUnconfirmedPartsVisible: Binding<Bool>,
        presentedPanel: Binding<PanelRoute?>,
        onCanvasChanged: @escaping () -> Void,
        onModeChanged: @escaping (_ old: InteractionMode, _ new: InteractionMode) -> Void,
        onOverlayChanged: @escaping () -> Void,
        onUnconfirmedChanged: @escaping (_ visible: Bool) -> Void,
        onPresentedPanelChanged: @escaping (_ route: PanelRoute?) -> Void,
        onDrawingSettingChanged: @escaping () -> Void,
    ) -> some View {
        self
            .onChangeCompat(of: canvas.wrappedValue) { _, _ in
                onCanvasChanged()
            }
            .onChangeCompat(of: interactionMode.wrappedValue) { _, newValue in
                let oldValue = lastInteractionMode.wrappedValue
                lastInteractionMode.wrappedValue = newValue
                onModeChanged(oldValue, newValue)
            }
            .onChangeCompat(of: drawingSettings.wrappedValue) { _, _ in
                onDrawingSettingChanged()
            }
            .onChangeCompat(of: overlayRects.wrappedValue) { _, _ in
                onOverlayChanged()
            }
            .onChangeCompat(of: selectedRectIDs.wrappedValue) { _, _ in
                onOverlayChanged()
            }
            .onChangeCompat(of: isUnconfirmedPartsVisible.wrappedValue) { _, visible in
                onUnconfirmedChanged(visible)
            }
            .onChangeCompat(of: presentedPanel.wrappedValue) { _, route in
                onPresentedPanelChanged(route)
            }
    }
}
