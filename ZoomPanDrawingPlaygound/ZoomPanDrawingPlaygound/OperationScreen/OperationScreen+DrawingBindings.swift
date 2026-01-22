import DrawingKit
import SwiftUI

extension OperationScreen {

    var toolBinding: Binding<DrawMode> {
        Binding(
            get: { drawingSettings.tool },
            set: { drawingSettings.tool = $0 }
        )
    }

    var stampKindBinding: Binding<StampKind> {
        Binding(
            get: { drawingSettings.stamp.kind },
            set: { drawingSettings.stamp.kind = $0 }
        )
    }

    var activeColorBinding: Binding<Color> {
        Binding(
            get: {
                switch drawingSettings.tool {
                case .stamp: return drawingSettings.stamp.color
                default: return drawingSettings.pen.color
                }
            },
            set: { newValue in
                switch drawingSettings.tool {
                case .stamp: drawingSettings.stamp.color = newValue
                default: drawingSettings.pen.color = newValue
                }
            }
        )
    }

    var activeSizeBinding: Binding<CGFloat> {
        Binding(
            get: {
                switch drawingSettings.tool {
                case .stamp: return drawingSettings.stamp.size
                default: return drawingSettings.pen.width
                }
            },
            set: { newValue in
                switch drawingSettings.tool {
                case .stamp: drawingSettings.stamp.size = newValue
                default: drawingSettings.pen.width = newValue
                }
            }
        )
    }

    var activeOpacityBinding: Binding<CGFloat> {
        Binding(
            get: {
                switch drawingSettings.tool {
                case .stamp: return drawingSettings.stamp.opacity
                default: return drawingSettings.pen.opacity
                }
            },
            set: { newValue in
                switch drawingSettings.tool {
                case .stamp: drawingSettings.stamp.opacity = newValue
                default: drawingSettings.pen.opacity = newValue
                }
            }
        )
    }

    var eraserRadiusBinding: Binding<CGFloat> {
        Binding(
            get: { drawingSettings.eraser.radius },
            set: { drawingSettings.eraser.radius = $0 }
        )
    }
}
