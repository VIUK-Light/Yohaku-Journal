import SwiftUI
import UIKit

// 記事データを表現するための構造体
// Identifiableプロトコルに準拠することで、Listなどで各要素を一意に識別できるようになります。
struct Article: Identifiable {
    let id = UUID() // 各記事を一意に識別するためのID
    let title: String // 記事のタイトル
    let category: String // 記事のカテゴリ（例: "恋愛", "ストレス管理"）
    let content: String // 記事の本文
    let imageName: String // アセットに画像がない場合に使用するSF Symbolの名前
    let imageFileName: String? // アセットカタログにある画像ファイル名（オプショナル）
    
    // 構造体のイニシャライザ（初期化メソッド）
    // imageFileNameはデフォルトでnilに設定されており、指定しない場合はSF Symbolが使われます。
    init(title: String, category: String, content: String, imageName: String, imageFileName: String? = nil) {
        self.title = title
        self.category = category
        self.content = content
        self.imageName = imageName
        self.imageFileName = imageFileName
    }
}

// 記事の一覧を表示するメインのビュー
struct ArticleListView: View {
    // 表示する記事データの配列。ここでは直接コード内にデータを定義しています。
    let articles: [Article] = [
        Article(
            title: "好きじゃない人に好かれたときの心の向き合い方と対応",
            category: "恋愛",
            content: "誰にでも、特に恋愛感情を持っていない相手から好意を寄せられることは起こり得ます。そのとき、どう心を整理し、どのように対応すればよいのでしょうか。\nまずは自分の気持ちを大切に「申し訳ない」「悪い気がする」と感じても、自分の気持ちを無理に変える必要はありません。好きじゃないからといって、相手を嫌いになる必要もありません。「今は恋愛感情がない」と素直に認めて大丈夫です。\n \n\n・相手への対応のポイント\n距離を取る必要以上に親しくしたり、特別な対応をしないことで、相手に「脈なし」であることを自然に伝えることができます。態度にメリハリをつける誰にでも同じように優しくすると誤解を招きやすいので、好意を持たれて困る相手には少し素っ気ない態度を心がけましょう。\n\n・無理に付き合わない\n「付き合ってもいいかも」と思えない場合は、無理に相手に合わせる必要はありません。自分の気持ちを大切にして断るのも選択肢です。\n\n・はっきり伝える\n告白された場合は、やんわりと「今はそういう気持ちはありません」など、相手の気持ちを尊重しつつも自分の意思を伝えましょう。心がモヤモヤしたときは罪悪感や気まずさを感じるのは自然なことです。どうしても気になる場合は、信頼できる友人に相談したり、自分の気持ちをノートに書き出して整理してみましょう。相手と距離を取ることが難しい場合は、物理的に接触の機会を減らす、周囲の人と一緒に行動するなどの工夫も有効です。\n\n・好かれやすい人の特徴\n誰にでも優しく接する、面倒見が良い、自然体でいるなどの特徴が、好意を持たれやすい傾向につながることがあります。必ずしも悪いことではありませんが、相手によって態度を調整することで不要な誤解を減らすことができます。\n\n好きじゃない人に好かれることは、決してあなたが悪いわけでも、相手が悪いわけでもありません。自分の気持ちを大切にしながら、相手にも配慮した対応を心がけてみてください。",
            imageName: "heart.circle.fill",
            imageFileName: "好きじゃない人に好かれたときの心の向き合い方と対応"
        ),
        Article(
            title: "ストレスと上手に付き合う方法",
            category: "ストレス管理",
            content: "ストレスは日常生活において避けられないものですが、適切に対処することで心の健康を維持できます。\n\n1. 深呼吸の習慣：4秒で息を吸い、4秒間止めて、4秒で吐き出す\n2. 軽い運動：1日15分の散歩でも効果的\n3. リラックス時間の確保：好きな音楽を聞いたり、読書をしたり\n4. 十分な睡眠：毎晩7-9時間の睡眠を心がける\n5. 人との繋がり：信頼できる人との会話",
            imageName: "figure.mind.and.body"
           
        ),
        Article(
            title: "睡眠の質を高める5つのヒント",
            category: "睡眠",
            content: "良質な睡眠は心の健康にとって重要な要素です。\n\n1. 規則正しい就寝時間：毎日同じ時間に寝る\n2. 就寝前のルーティン：リラックスできる活動を取り入れる\n3. 寝室環境の整備：暗く、静かで、涼しい環境を作る\n4. スマホやタブレットを控える：就寝1時間前から画面を見ない\n5. カフェインの摂取時間：午後2時以降は控える",
            imageName: "bed.double.fill"
           
        ) ,
        Article(
            title: "マインドフルネス入門",
            category: "リラクゼーション",
            content: "マインドフルネスは「今、ここ」に意識を向ける練習です。\n\n基本的な練習方法：\n1. 静かな場所を見つける\n2. 背筋を伸ばして座る\n3. 呼吸に注意を向ける\n4. 心が逸れても判断せず、呼吸に戻る\n5. 5分から始めて、徐々に時間を延ばす\n\nマインドフルネスの効果：\n・ストレス軽減\n・集中力の向上\n・感情の安定\n・睡眠の質向上",
            imageName: "leaf.fill"
           
        ),
        Article(
            title: "感情を理解し、受け入れる方法",
            category: "感情管理",
            content: "感情は人間として自然な反応です。感情を抑圧するのではなく、理解し受け入れることが大切です。\n\n感情との向き合い方：\n1. 感情に名前を付ける：「今、私は不安を感じている」\n2. 体の感覚に注意を向ける：緊張、重さ、温度など\n3. 判断せずに観察する：良い悪いではなく、ただ存在を認める\n4. 感情は一時的なものと理解する：必ず変化する\n5. 必要に応じてサポートを求める",
            imageName: "heart.circle.fill"
           
        ),
        Article(
            title: "好きな人ができたとき、どうすればいい？",
            category: "恋愛",
            content: "人を好きになったときや、大切な人と関わるとき、心がふと大きく揺れることがあります。嬉しさや期待、不安や戸惑い――そんな複雑な気持ちに戸惑うのは、あなただけではありません。大人になっても、心は思いがけないタイミングで揺れ動くものです。\n「こんなことで悩むなんて」「もっと強くならなきゃ」と思うこともあるでしょう。でも、どんな気持ちもあなたの大切な一部です。嬉しいも、寂しいも、焦りも、すべてが今のあなたをつくっています。\nふとした瞬間に感じたことをノートに書いてみたり、静かな場所で深呼吸しながら自分の心に問いかけてみたり、信頼できる人に素直な気持ちを話してみるのも良いでしょう。小さなことでも、自分の心の声を受け止めることで、気持ちが少し楽になることがあります。\n心が疲れたときは、無理に前向きになろうとせず、休むことを選んでみてください。好きな音楽や香り、自然の中で過ごす時間も心を癒す助けになります。どうしてもつらいときは、専門家に相談するのもひとつの方法です。心の疲れは、体と同じようにケアが必要です。 \n「こんな自分でもいい」「今の自分を認めてみよう」と思えたとき、心は少しずつ軽くなります。うまくいかない日も、前向きになれない日も、すべてがあなたの人生の一部です。心が動く瞬間を大切にしながら、やさしく自分と向き合う時間を持ってみませんか。それが、より豊かな毎日への第一歩です。",
            imageName: "heart.circle.fill",
            imageFileName: "好きじゃない人に好かれたときの心の向き合い方と対応"
        ),
        Article(
            title: "「不安」とうまくつき合う方法",
            category: "感情管理",
            content: "「不安」とうまくつき合う方法\n\n将来のことや人間関係、仕事や生活の変化など、不安を感じる場面は誰にでもあります。不安を無理に消そうとせず、「今、自分は不安なんだ」と認めてあげることが大切です。\n不安な気持ちを紙に書き出してみたり、信頼できる人に話してみることで、心が少し軽くなることもあります。自分ひとりで抱え込まず、必要に応じて専門家のサポートを受けるのも選択肢のひとつです。",
            imageName: "heart.circle.fill",
            imageFileName: "不安１"
        ),
        Article(
            title: "「心の疲れ」に気づくサインとセルフケア",
            category: "疲労",
            content: "日々の生活の中で、知らず知らずのうちに心が疲れてしまうことがあります。朝起きるのがつらい、何をしても気分が晴れない、集中力が続かない――そんなサインを感じたときは、心が「休みたい」と伝えているのかもしれません。\n自分のペースで深呼吸をしたり、短い散歩をしたり、好きな音楽を聴くなど、小さなセルフケアを取り入れてみましょう。心の疲れを早めに察知し、無理をしないことが、健やかな毎日につながります。",
            imageName: "heart.circle.fill"

        )
    ]

    // ビューの本体を定義します
    var body: some View {
        // 画面遷移やナビゲーションバーを提供するためのコンテナビュー
        NavigationStack {
            // `articles`配列の各要素をリスト形式で表示します
            List(articles) { article in
                // 各行をタップすると`ArticleDetailView`に遷移するナビゲーションリンク
                NavigationLink(destination: ArticleDetailView(article: article)) {
                    // 各行の見た目を定義する`ArticleRow`ビュー
                    ArticleRow(article: article)
                }
            }
            .navigationTitle("心の健康記事") // ナビゲーションバーのタイトル
            .navigationBarTitleDisplayMode(.large) // タイトルを大きなスタイルで表示
        }
    }
}

// 記事リストの各行の見た目を定義するビュー
struct ArticleRow: View {
    let article: Article // この行に表示する記事データ
    
    var body: some View {
        // 水平方向にビューを配置するHStack
        HStack(spacing: 16) {
            // `imageFileName`がnilでない場合（つまり、アセットに画像がある場合）
            if let imageFileName = article.imageFileName, UIImage(named: imageFileName) != nil {
                // アセットが存在する場合だけ画像を表示
                Image(imageFileName)
                    .resizable() // 画像サイズを変更可能にする
                    .aspectRatio(contentMode: .fill) // アスペクト比を保ちつつフレームを埋める
                    .frame(width: 60, height: 60) // 画像のサイズを指定
                    .clipShape(RoundedRectangle(cornerRadius: 8)) // 画像の角を丸くする
            } else {
                // アセットがない場合はSF Symbolにフォールバック
                Image(systemName: article.imageName)
                    .font(.title) // アイコンのサイズ
                    .foregroundColor(.blue) // アイコンの色
                    .frame(width: 60, height: 60) // フレームサイズを画像の場合と合わせる
            }
            
            // 記事のタイトルとカテゴリを垂直に配置するVStack
            VStack(alignment: .leading, spacing: 4) {
                // 記事のタイトル
                Text(article.title)
                    .font(.headline) // フォントを見出しスタイルに
                    .lineLimit(2) // 表示される行数を最大2行に制限
                
                // 記事のカテゴリ
                Text(article.category)
                    .font(.subheadline) // フォントを準見出しスタイルに
                    .foregroundColor(.secondary) // 文字色を少し薄くする
                    .padding(.horizontal, 8) // 左右の余白
                    .padding(.vertical, 2)   // 上下の余白
                    .background(Color.blue.opacity(0.1)) // 薄い青色の背景
                    .cornerRadius(8) // 背景の角を丸くする
            }
            
            Spacer() // 右側に余白を作り、コンテンツを左に寄せる
        }
        .padding(.vertical, 8) // 行全体の上下に余白を追加
    }
}

// 記事の詳細画面を表示するビュー
struct ArticleDetailView: View {
    let article: Article // 表示する記事データ
    @Environment(\.dismiss) private var dismiss // このビューを閉じるための環境変数

    var body: some View {
        // 内容が画面に収まらない場合にスクロール可能にする
        ScrollView {
            // 全体を垂直に配置するVStack
            VStack(alignment: .leading, spacing: 20) {
                // ヘッダー部分（画像、タイトル、カテゴリ）
                VStack(spacing: 16) {
                    // `imageFileName`の有無に応じて画像またはSF Symbolを表示
                    if let imageFileName = article.imageFileName, UIImage(named: imageFileName) != nil {
                        Image(imageFileName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200) // 高さを200ポイントに固定
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: article.imageName)
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                    }
                    
                    // 記事のタイトル
                    Text(article.title)
                        .font(.largeTitle.bold()) // 大きな太字のタイトル
                        .multilineTextAlignment(.center) // 中央揃え
                    
                    // 記事のカテゴリ（リスト表示時と同様のスタイル）
                    Text(article.category)
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(20)
                }
                .frame(maxWidth: .infinity) // 横幅を画面いっぱいに広げる
                
                // ヘッダーと本文の間の区切り線
                Divider()
                
                // 記事の本文
                Text(article.content)
                    .font(.body) // 本文用のフォントスタイル
                    .lineSpacing(4) // 行間を少し広げて読みやすくする
            }
            .padding() // 全体に余白を追加
        }
        .navigationTitle(article.title) // ナビゲーションバーに記事タイトルを表示
        .navigationBarTitleDisplayMode(.inline) // タイトルを小さなインラインスタイルで表示
        .toolbar {
            // ツールバーにアイテムを追加
            ToolbarItem(placement: .navigationBarTrailing) {
                // 完了ボタン。タップするとビューを閉じる
                Button("完了") {
                    dismiss()
                }
            }
        }
    }
}
