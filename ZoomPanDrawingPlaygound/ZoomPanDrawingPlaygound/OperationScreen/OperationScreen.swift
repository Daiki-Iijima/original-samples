import DrawingKit
import SwiftUI
import UIKit
import YamatoAPIKit
import YamatoAppContracts

// MARK: - OperationScreen
/// ✅ Viewは「レイアウト」と「Viewにしか置けない参照」だけを持つ
///
/// なぜViewに残す？
/// - DrawingCanvasView の参照（UIKit bridge）は View のライフサイクルに密接でStoreに置きにくい
/// - sheet / overlayの表示構造はSwiftUIの責務
///
/// それ以外（状態やルール）はStoreへ
struct OperationScreen: View {
    
    // MARK: External
    let services: YamatoServices
    let payload: ProjectOpenPayload
    let selectedImageURL: URL
    
    // MARK: Env
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.scenePhase) private var scenePhase
    private var isPhoneLayout: Bool { hSizeClass == .compact }
    
    // MARK: Store
    @StateObject public var store: OperationStore
    
    // MARK: View-only references
    /// UIKit bridge の参照：Viewからしか自然に管理しづらい
    @State public var canvas: DrawingCanvasView? = nil
    
    /// 既存ロジックが参照してるので保持（ズーム対象を一時保持など）
    @State private var pendingZoomRect: CanvasRect? = nil
    
    /// 設定を表示させるか
    @State private var showConfigSheet: Bool = false
    
    // MARK: Init
    init(services: YamatoServices, payload: ProjectOpenPayload, selectedImageURL: URL) {
        self.services = services
        self.payload = payload
        self.selectedImageURL = selectedImageURL
        _store = StateObject(
            wrappedValue: OperationStore(
                services: services,
                payload: payload,
                selectedImageURL: selectedImageURL
            )
        )
    }
    
    // MARK: Body
    var body: some View {
        ZStack {
            content
            
            // StoreとModelの両方のローディングを1箇所で表示
            if store.isBooting || store.model.isLoading {
                loadingOverlay
            }
        }
        //  iPhone用
        .sheet(item: presentedPanelBinding) { route in
            IPhoneSheets(
                route: route,
                store: store,
                canvas: $canvas,
                saveMergedToPhotos: { img in
                    saveMergedToPhotos(currentLoadedImage: img)
                }
            )
        }
        //  設定画面用
        .sheet(isPresented: $showConfigSheet) {
            OperationConfigView(onClose: { showConfigSheet = false })
                .onDisappear {
                    // 設定変更後の反映（overlayを作り直す）
                    syncOverlayRects()
                }
        }
        .task {
            await store.boot()
            syncOverlayRects()       // 初期反映（既存関数に繋ぐ）
        }
        .onChangeCompat(of: store.config) { _, _ in
            syncOverlayRects()
        }
        .onChangeCompat(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await store.refreshProjectsIfNeeded()
                syncOverlayRects()
            }
        }
        .onChangeCompat(of: store.overlayRects) { _, _ in
            // rect元データが更新されたら表示用へ再合成して反映
            syncOverlayRects()
        }
        .applyBindingsForOperation(
            canvas: $canvas,
            
            // Storeの@PublishedをBindingにして既存バインド資産へ渡す
            interactionMode: interactionModeBinding,
            lastInteractionMode: lastInteractionModeBinding,
            drawingSettings: drawingSettingsBinding,
            overlayRects: overlayRectsBinding,
            selectedRectIDs: selectedRectIDsBinding,
            isUnconfirmedPartsVisible: isUnconfirmedPartsVisibleBinding,
            presentedPanel: presentedPanelBinding,
            
            onCanvasChanged: {
                // “キャンバスが作られた/差し替わった” タイミングはView側で反映するのが自然
                applyInteractionModeToCanvas()
                syncCanvasToolState()
                syncOverlayRects()
            },
            onModeChanged: { old, new in
                store.closePanelsForModeSwitch(from: old, to: new)
                applyInteractionModeToCanvas()
                syncCanvasToolState()
            },
            onOverlayChanged: {
                syncOverlayRects()
            },
            onUnconfirmedChanged: { visible in
                store.setUnconfirmedPartsVisible(visible)
                syncOverlayRects()
            },
            onPresentedPanelChanged: { route in
                store.setUnconfirmedPartsVisible(route == .unconfirmedParts)
                syncOverlayRects()
            },
            onDrawingSettingChanged: {
                syncCanvasToolState()
                applyInteractionModeToCanvas() // ツール切替時にmodeも確実に更新
            }
        )
    }
}

// MARK: - View composition
extension OperationScreen {
    
    private var content: some View {
        ZStack(alignment: .top) {
            canvasLayer
            
            if isPhoneLayout {
                phoneOverlay
            } else {
                ipadOverlay
            }
        }
    }
    
    private var phoneOverlay: some View {
        VStack(spacing: 0) {
            OperationPhoneTopBar(
                interactionMode: interactionModeBinding,
                viewportScale: store.viewportState.scale,
                onBack: { /* dismiss */ },
                onResetZoom: { store.zoomRequest = .reset },
                onForceQuit: { /* your logic */ },
                onOpenConfig: { showConfigSheet = true}
            )
            
            Spacer()
            
            OperationPhoneBottomBar(
                interactionMode: interactionModeBinding,
                presentedPanel: presentedPanelBinding,
                onUploadImage: { /* upload */ }
            )
            .padding(.init(top: 0, leading: 8, bottom: 16, trailing: 8))
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    private var ipadOverlay: some View {
        Group {
            topBarLayer
            IPadPanels(
                store: store,
                canvas: $canvas,
                openProject: openProject,
                setUnconfirmedPartsVisible: setUnconfirmedPartsVisible,
                saveMergedToPhotos: saveMergedToPhotos
            )
        }
    }
    
    private var topBarLayer: some View {
        let onBack: () -> Void = { /* dismiss */ }
        let onResetZoom: () -> Void = { store.zoomRequest = .reset }
        let onUploadImage: () -> Void = { /* upload */ }
        
        let onSaveLocal: () -> Void = {
            saveDrawingLocal(imageName: store.currentLoadedImage.name, userName: payload.authSession.name)
        }
        let onLoadLocal: () -> Void = {
            loadDrawingLocal(imageName: store.currentLoadedImage.name, userName: payload.authSession.name)
        }
        
        return OperationiPadTopBar(
            interactionMode: interactionModeBinding,
            viewportScale: store.viewportState.scale,
            isUnconfirmedPartsVisible: isUnconfirmedPartsVisibleBinding,
            isMemoVisible: isMemoVisibleBinding,
            isLinkProjectsVisible: isLinkProjectsVisibleBinding,
            isDrawingSettingsPanelVisible: isDrawingSettingsPanelVisibleBinding,
            onBack: onBack,
            onResetZoom: onResetZoom,
            onUploadImage: onUploadImage,
            onSaveLocal: onSaveLocal,
            onLoadLocal: onLoadLocal,
            onSavePhotos: { },
            onOpenConfig: { showConfigSheet = true }
        )
        .padding()
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.18).ignoresSafeArea()
            ProgressView("読み込み中…")
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Bindings (ObservableObject -> Binding)
extension OperationScreen {
    
    /// SwiftUIの `ObservableObject` は `@Published` を `$store.xxx` で直接渡せないため
    /// ここで “既存のBinding依存コード” に繋ぐためのBindingを用意する
    
    private var presentedPanelBinding: Binding<PanelRoute?> {
        Binding(get: { store.presentedPanel }, set: { store.presentedPanel = $0 })
    }
    
    private var interactionModeBinding: Binding<InteractionMode> {
        Binding(get: { store.interactionMode }, set: { store.interactionMode = $0 })
    }
    
    private var lastInteractionModeBinding: Binding<InteractionMode> {
        Binding(get: { store.lastInteractionMode }, set: { store.lastInteractionMode = $0 })
    }
    
    private var drawingSettingsBinding: Binding<DrawingSettings> {
        Binding(get: { store.drawingSettings }, set: { store.drawingSettings = $0 })
    }
    
    private var overlayRectsBinding: Binding<[CanvasRect]> {
        Binding(get: { store.overlayRects }, set: { store.overlayRects = $0 })
    }
    
    private var selectedRectIDsBinding: Binding<Set<UUID>> {
        Binding(get: { store.selectedRectIDs }, set: { store.selectedRectIDs = $0 })
    }
    
    private var isUnconfirmedPartsVisibleBinding: Binding<Bool> {
        Binding(get: { store.isUnconfirmedPartsVisible }, set: { store.isUnconfirmedPartsVisible = $0 })
    }
    
    private var isMemoVisibleBinding: Binding<Bool> {
        Binding(get: { store.isMemoVisible }, set: { store.isMemoVisible = $0 })
    }
    
    private var isLinkProjectsVisibleBinding: Binding<Bool> {
        Binding(get: { store.isLinkProjectsVisible }, set: { store.isLinkProjectsVisible = $0 })
    }
    
    private var isDrawingSettingsPanelVisibleBinding: Binding<Bool> {
        Binding(get: { store.isDrawingSettingsPanelVisible }, set: { store.isDrawingSettingsPanelVisible = $0 })
    }
}

// MARK: - Overlay sync (View -> Canvas)
extension OperationScreen {
    
    /// Canvasへ渡す “表示用rect” をStoreのルールで作って反映する
    ///
    /// なぜView？
    /// - `canvas?.setOverlayRects(...)` はUIKit参照を触るのでView側が責務を持つ
    public func syncOverlayRects() {
        let display = store.makeDisplayOverlayRects()
        canvas?.setOverlayRects(display)
    }
}
