import Foundation

/// アプリ側で保持・保存する描画データのパッケージ
///
/// - DrawingKit の internal 型（Stroke や Element など）に直接依存しない
/// - JSON としてローカル保存・将来のマイグレーションを想定
/// - imageKey / drawingKey により保存単位を一意に識別する
struct DrawingPackage: Codable {

    /// パッケージのバージョン
    /// - フォーマット変更時のマイグレーション判定に使用
    /// - JSON を読む側で switch できるようにするため Int で保持
    var packageVersion: Int = 1

    /// 元画像を識別するキー
    /// - 例: 画像URL、UUID、プロジェクトID + ページ番号など
    /// - DrawingLocalStore ではディレクトリ名として使われる
    var imageKey: String

    /// 同一 imageKey 内での描画バリエーション識別子
    /// - 例: "autosave", "manual", "v1", "edit-20260213" など
    /// - ファイル名（drawingKey.json）として使われる
    var drawingKey: String

    /// 作成日時
    /// - 初回保存時にセット
    /// - 履歴表示や並び替えに利用可能
    var createdAt: Date = Date()

    /// 更新日時
    /// - 保存するたびに更新する想定
    /// - autosave / 手動保存の判定にも使える
    var updatedAt: Date = Date()

    /// DrawingCanvasView.exportDrawingData() から取得した生データ
    ///
    /// - DrawingKit 内部の構造を JSON に露出させないため Data として保持
    /// - 将来 DrawingKit 側の実装が変わっても互換性を保ちやすい
    /// - 実体は JSON / バイナリ / 圧縮データ いずれでもOK
    var drawingData: Data
}
