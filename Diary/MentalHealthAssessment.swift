//
// MentalHealthAssessment.swift
// Science Club One(1.0-発表用)
//
// Created by 日隈奏斗(メイン) on 2025/07/12.
//

import Foundation
import SwiftData

// メンタルヘルス診断の結果を保存するためのSwiftDataモデル
@Model
final class MentalHealthAssessment {
    // 各診断結果を一意に識別するためのUUID
    var id = UUID()
    // 診断が実行された日時
    var date = Date()
    // PHQ-9診断の合計スコア（初期値0）
    var phq9Score = 0
    // GAD-7診断の合計スコア（初期値0）
    var gad7Score = 0
    // PHQ-9の各質問に対する回答（整数配列、初期値は空）
    var phq9Answers: [Int] = []
    // GAD-7の各質問に対する回答（整数配列、初期値は空）
    var gad7Answers: [Int] = []
    // その他の診断結果やメモを格納するための文字列（初期値は空）
    var notes = ""
    
    // 新規追加：選択機能関連
    // ユーザーが選択したテストの種類を文字列の配列で保存
    var selectedTests: [String] = []
    // PHQ-9診断が完了したかどうかを示すブール値（初期値false）
    var isPhq9Completed: Bool = false
    // GAD-7診断が完了したかどうかを示すブール値（初期値false）
    var isGad7Completed: Bool = false
    
    // 将来の拡張用
    // 年齢層に基づく解釈結果を格納する文字列（初期値は空）
    var ageGroupInterpretation: String = ""
    // ユーザーの年齢を格納する整数（初期値0）
    var userAge: Int = 0
    
    // 初期化メソッド（引数なし）
    init() {}
}

