# Quality 1.0 公開チェックリスト

このチェックリストは、公開を急がず、未確認の安全性やプラットフォーム差を残さないためのものです。チェックが付いていない項目を、公開済みとは扱いません。

最終確認日: 2026-08-01

## IssueとPR

- [x] Foundation #20 — [PR #23](https://github.com/VIUK-Light/Yohaku-Journal/pull/23)
- [x] 回帰テスト #2 — [PR #25](https://github.com/VIUK-Light/Yohaku-Journal/pull/25)
- [x] アクセシビリティ #3 — [PR #26](https://github.com/VIUK-Light/Yohaku-Journal/pull/26)
- [ ] Architecture #18 — [PR #31](https://github.com/VIUK-Light/Yohaku-Journal/pull/31)
- [ ] Insights #19 — [PR #32](https://github.com/VIUK-Light/Yohaku-Journal/pull/32)
- [ ] Safety #13 — [PR #33](https://github.com/VIUK-Light/Yohaku-Journal/pull/33)
- [ ] Content #17 — [PR #34](https://github.com/VIUK-Light/Yohaku-Journal/pull/34)
- [ ] Safety #21 — [PR #29](https://github.com/VIUK-Light/Yohaku-Journal/pull/29)
- [ ] Backup policy #4 — [PR #28](https://github.com/VIUK-Light/Yohaku-Journal/pull/28)
- [ ] Data protection #22 — [PR #27](https://github.com/VIUK-Light/Yohaku-Journal/pull/27)
- [ ] Diary #16 — [PR #30](https://github.com/VIUK-Light/Yohaku-Journal/pull/30)
- [ ] Platform QA #1
- [ ] Release #15

CIでは、Mac Catalystを有効にし、Mac上のDesigned for iPad経路を無効にし、Launch Screen設定を維持していることを静的に検査します。これは実機・シミュレータでのレイアウト確認の代替ではありません。

## 機能と安全性

- [ ] 新規記録、既存記録編集、削除、キャンセル、保存失敗を確認
- [ ] 瞬間記録を同日に複数保存できる
- [ ] 一日振り返りは同日重複を作らない
- [ ] セルフチェックの独自結果が診断・重症度・他人の断定になっていない
- [ ] 根拠確認中の標準尺度が再開されていない
- [ ] 相談先へ2タップ以内で到達できる
- [ ] アプリ切替画面に日記本文が残らない
- [ ] 暗号化バックアップ、復元、競合、全削除を実機で確認

## データとプライバシー

- [ ] `Documentation/Privacy.md`と最終版の実装が一致する
- [ ] 広告、解析SDK、アカウント、クラウド同期がないことを監査
- [ ] 外部リンクは利用者の操作時だけ開く
- [ ] App Store Connectのプライバシー申告を最終バイナリと照合
- [ ] バックアップ機能を「利用可能」と案内するのは#22マージ後だけにする

## UIとアクセシビリティ

- [ ] iPhone縦・横で上下の黒帯や固定余白がない
- [ ] iPad横でサイドバーと内容が並ぶ
- [ ] iPad縦で内容を全画面操作できる
- [ ] Mac Catalystで横長・狭幅を切り替えられる
- [ ] 気分レールのタップ領域が44pt以上ある
- [ ] VoiceOver、Dynamic Type、キーボード操作、ダークモードを確認
- [ ] スクリーンショットをPRへ添付

## 実行する検証

```sh
git diff --check
xcodegen generate
xcodebuild -list -project "Science Club Diary.xcodeproj"
xcodebuild test -project "Science Club Diary.xcodeproj" -scheme "Science Club Diary" -destination "platform=iOS Simulator,id=<one-iPhone-UDID>" -derivedDataPath "$RUNNER_TEMP/yohaku-test-derived" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO COMPILER_INDEX_STORE_ENABLE=NO
```

ビルド前に `df -h /System/Volumes/Data` と `memory_pressure -Q` を確認します。空き容量10GB未満、またはメモリ空き25%未満の場合は、ビルドを開始せず理由をPRへ記録します。
