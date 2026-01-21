import Foundation

//  描画モード
public enum DrawMode: Equatable {
    //  ペンで線を書くモード
    case pen

    //  スタンプを置くモード
    case stamp

    //  消しゴムモード
    case eraser

    //  何もしないモード(入力無視モード)
    case none
}
