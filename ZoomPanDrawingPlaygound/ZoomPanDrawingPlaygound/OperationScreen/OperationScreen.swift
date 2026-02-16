import DrawingKit
import YamatoScannerFeature
import SwiftUI
import UIKit
import YamatoAPIKit
import YamatoAppContracts

public enum OperationScreenMode: Equatable, Sendable {
    case normal
    case checkback
}

// MARK: - OperationScreen
///  Viewは「レイアウト」と「Viewにしか置けない参照」だけを持つ
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
    
    /// 全画面表示用の状態
    @State private var fullScreenRoute: FullScreenRoute? = nil
    
    @State private var mode: OperationScreenMode = .normal
    
    //  チェックバック中かどうか
    @State private var isCheckbackSending: Bool = false
    @State private var checkbackError: String? = nil

    // MARK: Init
    init(
        services: YamatoServices,
        payload: ProjectOpenPayload,
        selectedImageURL: URL,
    ) {
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
    
    private var isCheckbackOnly: Bool {
        if case .checkback = mode {
            return true
        }
        
        return false
    }
    
    // MARK: Body
    var body: some View {
        ZStack {
            content
            
            // StoreとModelの両方のローディングを1箇所で表示
            if store.isBooting || store.model.isLoading {
                loadingOverlay
            }
            
            if store.isCheckingBack {
                loadingOverlay("チェックバック送信中…")
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
        //  画面が再描画されたら実行
        .onChangeCompat(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await store.refreshProjectsIfNeeded()
                syncOverlayRects()
            }
        }
        .onChangeCompat(of: store.renderingRects) { _, _ in
            
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
                //  チェックバックモードではモードチェンジできないように
                guard !isCheckbackOnly else { return }
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
                //  チェックバックモードでは描画ツールも触らせない
                guard !isCheckbackOnly else { return }
                
                syncCanvasToolState()
                applyInteractionModeToCanvas() // ツール切替時にmodeも確実に更新
            }
        )
        .fullScreenCover(item: $fullScreenRoute) { route in
            switch route {
            case .pipeScanner(let projectID):
                PipeCollectScannerView(
                    projectID: projectID,
                    service: PipeCheckServiceAdapter(services: services),
                    onFinish: { items in
//                        store.collectedPipes = items
                        
                        //  デモデータ追加
                        let demo = ScanItemDemoFactenum.make(
                              projectID: store.currentProjectID!
                          )
                        
                        mode = .checkback
                        store.acceptCollectedPipes(demo)
                        fullScreenRoute = nil
                    }
                )
            }
        }
    }
    
    private func loadingOverlay(_ title: String) -> some View {
        ZStack {
            Color.black.opacity(0.18).ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                Text(title)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

}

// MARK: - View composition
extension OperationScreen {
    
    private var content: some View {
        ZStack(alignment: .top) {
            canvasLayer
            
            if isCheckbackOnly{
                checkbackOnlyOverlay
            }else{
                if isPhoneLayout {
                    phoneOverlay
                } else {
                    ipadOverlay
                }
            }
            
        }
    }
    
    
    private var checkbackOnlyOverlay: some View {
        Group {
            // ✅上部に最低限の戻る/完了ボタンだけ欲しいならここ
            // 何も要らないなら消してOK
            VStack {
                HStack {
                    Button("戻る") { /* dismiss */ }
                    Spacer()
                    .disabled(store.isCheckingBack || store.selectedRectIDs.isEmpty)
                }
                .padding()
                Spacer()
            }

            // 未確認部材一覧パネルをチェックバックパネルとして使う
            //  チェックバックパネル1枚だけ表示
            IPadPanels(
                visiblePanels: [.checkback],
                store: store,
                canvas: $canvas,
                openProject: store.openProject,
                setUnconfirmedPartsVisible: setUnconfirmedPartsVisible,
                saveMergedToPhotos: saveMergedToPhotos,
                selectedRectsAction: { canvasRects in
                    Task{
                        await store.checkBackSelectedPipes()
                    }
                }
            )
            
            if isCheckbackSending {
                ZStack {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    ProgressView("チェックバック送信中…")
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
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
                visiblePanels: .default,
                store: store,
                canvas: $canvas,
                openProject: store.openProject,
                setUnconfirmedPartsVisible: setUnconfirmedPartsVisible,
                saveMergedToPhotos: saveMergedToPhotos,
                selectedRectsAction: {_ in
                    Task{
                        await store.checkBackSelectedPipes()
                    }
                }
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
            onOpenPipeScanner: {
                if let projectID = store.currentProjectID {
                    fullScreenRoute = .pipeScanner(projectID: projectID)
                }
            },
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
        Binding(get: { store.renderingRects }, set: { store.renderingRects = $0 })
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
