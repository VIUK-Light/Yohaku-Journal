//
// SelectableButton.swift
// Science Club One(1.0-発表用)
//
// Created by 日隈奏斗(メイン) on 2025/07/12.
//

import SwiftUI

// SelectableButton は、選択状態に応じて見た目が変わる汎用ボタンコンポーネントです。
// - 選択中: 背景色=accentColor(既定) / 文字色=白 / 枠線あり / わずかに拡大 & 触覚フィードバック
// - 非選択: 背景色=systemGray6 / 文字色=primary / 枠線なし

// SwiftUI の View として再利用可能なボタン
struct SelectableButton: View {
    // 表示するラベル文字列
    let label: String
    // 選択中かどうかのフラグ（見た目の切り替えに利用）
    let isSelected: Bool
    // 選択時に使う背景色（デフォルトは .accentColor）
    let backgroundColor: Color
    // タップ時に呼ばれるアクション
    let action: () -> Void
    
    // イニシャライザ
    // - Parameters:
    //   - label: ボタンに表示するテキスト
    //   - isSelected: 選択状態（見た目の切り替えに使用）
    //   - backgroundColor: 選択時の背景色（省略時は .accentColor）
    //   - action: タップ時に実行されるクロージャ
    // 備考: action は非同期ではないが、必要であれば呼び出し側で Task などに包む
    init(label: String, isSelected: Bool, backgroundColor: Color = .accentColor, action: @escaping () -> Void) {
        self.label = label
        self.isSelected = isSelected
        self.backgroundColor = backgroundColor
        self.action = action
    }
    
    // View 本体
    var body: some View {
        // タップで action を実行
        Button(action: {
            // ここで外から渡された処理を呼び出す
            action()
        }) {
            // ラベル表示
            Text(label)
                // 読みやすい太字寄りのサブヘッドライン
                .font(.subheadline.weight(.semibold))
                // 選択時は白文字 / 非選択時は標準の前景色
                .foregroundStyle(isSelected ? .white : DiaryTheme.ink)
                // タップ領域と見た目の余白
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                // 横幅いっぱいに広げる（親の幅に合わせる）
                .frame(maxWidth: .infinity)
                // 背景（角丸の塗りつぶし）: 選択時=指定色 / 非選択時=薄いグレー
                .background(
                    // 角丸の形状（連続曲線で滑らかな角）
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? backgroundColor : DiaryTheme.elevatedSurface)
                )
                // 枠線（選択時のみ 2pt の線を表示）
                .overlay(
                    // 角丸の枠線。選択時は backgroundColor、非選択時は非表示
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? backgroundColor : DiaryTheme.line, lineWidth: isSelected ? 2 : 1)
                )
        }
        .frame(minWidth: 44, minHeight: 44)
        .focusable(true)
        .accessibilityLabel(label)
        .accessibilityValue(isSelected ? "選択中" : "未選択")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        // 選択時はわずかに拡大して強調
        .scaleEffect(isSelected ? 1.05 : 1)
        // isSelected の変化に合わせてアニメーション
        .animation(.easeOut(duration: 0.15), value: isSelected)
        // 選択状態の切り替えで触覚フィードバック（視覚・聴覚にも対応する場合あり）
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
