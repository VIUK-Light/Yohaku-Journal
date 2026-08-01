import Foundation

struct ArticleSource: Identifiable, Hashable {
    let title: String
    let organization: String
    let url: URL

    var id: URL { url }

    init(title: String, organization: String, urlString: String) {
        guard let url = URL(string: urlString), url.scheme == "https" else {
            preconditionFailure("Article source must use a valid HTTPS URL: \(urlString)")
        }
        self.title = title
        self.organization = organization
        self.url = url
    }
}

struct ArticleMetadata {
    let intendedReaders: String
    let lastReviewed: String
    let safetyNote: String
    let sources: [ArticleSource]
    let supportPrompt: String?
}

struct Article: Identifiable {
    /// アップデート後も変わらない、検索・リンク用の固定ID。
    let id: String
    let title: String
    let category: String
    let summary: String
    let content: String
    let imageFileName: String?
    let metadata: ArticleMetadata

    init(
        id: String,
        title: String,
        category: String,
        summary: String,
        content: String,
        imageFileName: String? = nil,
        metadata: ArticleMetadata
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.summary = summary
        self.content = content
        self.imageFileName = imageFileName
        self.metadata = metadata
    }
}

private enum ArticleSources {
    static let youthStress = ArticleSource(
        title: "ストレスとこころ",
        organization: "厚生労働省",
        urlString: "https://www.mhlw.go.jp/kokoro/youth/stress/kokoro/index.html"
    )

    static let youthSelfCare = ArticleSource(
        title: "こころのセルフメンテ",
        organization: "厚生労働省",
        urlString: "https://www.mhlw.go.jp/kokoro/youth/self/index.html"
    )

    static let youthConsultation = ArticleSource(
        title: "どんなふうに相談すればいいの？",
        organization: "厚生労働省",
        urlString: "https://www.mhlw.go.jp/kokoro/youth/consultation/way/index.html"
    )

    static let sleepGuidance = ArticleSource(
        title: "睡眠対策・健康づくりのための睡眠ガイド2023",
        organization: "厚生労働省",
        urlString: "https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/kenkou_iryou/kenkou/suimin/index.html"
    )

    static let selfCare = ArticleSource(
        title: "手軽にできるこころのセルフケア",
        organization: "こころの耳（厚生労働省委託事業）",
        urlString: "https://kokoro.mhlw.go.jp/lp/selfcare/"
    )

    static let youngPeople = ArticleSource(
        title: "若者の皆さんへ",
        organization: "こども家庭庁",
        urlString: "https://www.cfa.go.jp/for-young-people"
    )

    static let dateDV = ArticleSource(
        title: "デートDVって?",
        organization: "内閣府男女共同参画局",
        urlString: "https://www.gender.go.jp/policy/no_violence/date_dv/index.html"
    )

    static let youngSexualViolence = ArticleSource(
        title: "若年層の性暴力防止に向けた取組",
        organization: "内閣府男女共同参画局",
        urlString: "https://www.gender.go.jp/policy/no_violence/jakunenseibouryoku/index.html"
    )

    static let studentSupport = ArticleSource(
        title: "子供のSOSの相談窓口",
        organization: "文部科学省",
        urlString: "https://www.mext.go.jp/a_menu/shotou/seitoshidou/06112210.htm"
    )
}

/// 本文は端末内に同梱し、オフラインでも読めるローカル記事カタログ。
/// 出典リンクを開く操作だけが外部ブラウザを利用する。
enum ArticleCatalog {
    static let reviewDate = "2026-08-01"

    static let articles: [Article] = [
        Article(
            id: "boundaries-unreturned-affection",
            title: "好意に応えられないときの伝え方",
            category: "人間関係",
            summary: "自分の意思と安全を守りながら、相手を決めつけずに伝えるヒントです。",
            content: """
            好意を向けられても、同じ気持ちを返す義務はありません。申し訳なさや気まずさがあっても、自分の意思を無理に変えなくて大丈夫です。

            伝えるときは、相手の性格や気持ちを決めつけず、「私は今、交際したいとは思っていません」のように自分の意思を短く伝える方法があります。詳しい理由を説明したくないときは、説明しない選択もできます。曖昧な態度で我慢する必要も、わざと冷たく振る舞う必要もありません。

            断った後も繰り返し連絡される、行動を監視される、脅される、触られるなど、怖さや危険を感じることがあれば、二人だけで解決しようとしないでください。記録を残し、家族・先生・学校の相談室など信頼できる大人と一緒に安全な距離を考えられます。

            相手との関係より、まず自分の安全と意思が大切です。どちらが悪いかをアプリが判定することはできません。困っている事実を、そのまま相談して構いません。
            """,
            imageFileName: "好きじゃない人に好かれたときの心の向き合い方と対応",
            metadata: ArticleMetadata(
                intendedReaders: "中学生・高校生を含む、人間関係に迷っている人",
                lastReviewed: reviewDate,
                safetyNote: "恐怖、監視、脅し、身体的・性的な行為がある場合は、安全を優先して信頼できる大人や相談窓口につながってください。",
                sources: [ArticleSources.dateDV, ArticleSources.youngSexualViolence, ArticleSources.studentSupport],
                supportPrompt: "断っても続く連絡や、怖い・危険だと感じることを一人で抱えないため、相談先を確認できます。"
            )
        ),
        Article(
            id: "stress-small-options",
            title: "ストレスに気づいたときの小さな選択肢",
            category: "ストレス",
            summary: "一律の正解ではなく、今の自分に合う対処を一つ選ぶための記事です。",
            content: """
            ストレスへの反応は人によって異なります。眠りにくい、体が重い、イライラする、集中しづらいなど、いつもとの違いに気づくことが最初の手がかりになります。これだけで病気かどうかは決まりません。

            試せそうなことを一つだけ選んでみましょう。苦しくない範囲で息をゆっくり吐く、少し体を動かす、音楽を聴く、場所を変える、予定を減らす、誰かに話すなどがあります。全部を行う必要はなく、合わない方法はやめて構いません。

            「何をしたか」と「その後どう感じたか」を短く記録すると、自分に合う方法を探す材料になります。効果を約束するものではなく、変化がなくても失敗ではありません。

            眠れない、食べられない、学校や日常生活がつらい状態が続くときや、自分だけでは抱えにくいときは、家族・先生・保健室・医療機関・相談窓口へ話すことも選択肢です。
            """,
            metadata: ArticleMetadata(
                intendedReaders: "ストレスや疲れを感じている中学生・高校生と一般の利用者",
                lastReviewed: reviewDate,
                safetyNote: "セルフケアで改善しないことは本人の責任ではありません。生活への影響が続く場合は相談してください。",
                sources: [ArticleSources.youthStress, ArticleSources.youthSelfCare, ArticleSources.selfCare],
                supportPrompt: "一人で対処し続けることが難しいときは、相談先を確認できます。"
            )
        ),
        Article(
            id: "sleep-observe-rhythm",
            title: "眠りを整えるために観察できること",
            category: "睡眠",
            summary: "必要な睡眠や生活リズムの個人差を前提に、変えやすい点を探します。",
            content: """
            必要な睡眠時間や眠りやすい条件には個人差があります。数字だけを達成目標にするのではなく、朝の目覚め、日中の眠気、授業や活動への影響を一緒に見てください。

            起きる時刻、朝に光を浴びたか、日中に体を動かしたか、寝室の明るさや音、就寝前の画面やカフェインなどを一つずつ記録すると、眠りとの関係を探しやすくなります。すべてを一度に変える必要はありません。

            スマートフォンを使う必要がある日もあります。「絶対に見ない」と決める代わりに、明るさを下げる、通知を減らす、置く場所を変えるなど、自分が続けられる調整を選べます。

            眠れない、眠っても休めた感じがしない、日中の強い眠気が続いて生活に影響するときは、生活習慣だけが原因とは限りません。保護者や学校の保健室、医療機関に相談してください。
            """,
            metadata: ArticleMetadata(
                intendedReaders: "眠りや日中の眠気が気になる中学生・高校生と一般の利用者",
                lastReviewed: reviewDate,
                safetyNote: "強い眠気があるときの運転や危険な作業は避け、症状が続く場合は医療機関へ相談してください。",
                sources: [ArticleSources.sleepGuidance],
                supportPrompt: "眠りの問題が続いて学校や生活に影響しているときは、相談先も確認できます。"
            )
        ),
        Article(
            id: "attention-short-practice",
            title: "今の感覚に気づく短い練習",
            category: "リラクゼーション",
            summary: "気持ちを消そうとせず、注意を今いる場所へ戻す短い方法です。",
            content: """
            落ち着きたいとき、今の感覚に注意を向ける方法があります。必ず落ち着く方法ではなく、試して合わなければ途中でやめて大丈夫です。

            まず、安全で少し休める場所を選びます。姿勢は座っても立っても構いません。息を変えようとせず、吸っていること、吐いていることに気づきます。次に、足が床に触れる感覚や、聞こえる音を一つ確かめます。注意がそれても、失敗ではありません。

            長く続ける必要はありません。終えた後に「少し違う」「変わらない」「かえって落ち着かない」など、実際の感覚を記録できます。

            呼吸や体への注意で苦しい記憶が浮かぶ、息苦しさが増すなど不快になった場合は中止し、目を開けて周囲を確認してください。無理に続けず、信頼できる人へ声をかけても構いません。
            """,
            metadata: ArticleMetadata(
                intendedReaders: "短い休息やリラクゼーションを試したい人",
                lastReviewed: reviewDate,
                safetyNote: "不快感や苦しさが増えた場合は中止してください。この練習は治療の代わりではありません。",
                sources: [ArticleSources.youthSelfCare, ArticleSources.selfCare],
                supportPrompt: nil
            )
        ),
        Article(
            id: "emotions-name-and-observe",
            title: "感情を決めつけずに記録する",
            category: "感情",
            summary: "感情、体の感覚、起きた出来事を分けて眺める方法です。",
            content: """
            うれしい、悲しい、腹が立つ、不安、よくわからない。どの表現を選んでも、選ばなくても構いません。感情にすぐ名前を付けられないこともあります。

            日記には「起きた出来事」「体で感じたこと」「頭に浮かんだこと」を分けて書けます。たとえば、出来事は「返信がなかった」、体の感覚は「胸が重い」、考えは「嫌われたかもしれない」です。考えは事実と同じとは限らないため、分けておくと後で見返しやすくなります。

            感情を良い・悪いで採点したり、早く消そうとしたりする必要はありません。書くことでつらさが強くなる日は、記録を中断する、別のことをする、誰かと一緒に過ごすという選択もできます。

            強い苦しさが続く、生活が難しい、自分を傷つけたい気持ちがあるときは、日記だけで解決しようとせず、信頼できる大人や相談先へつながってください。
            """,
            metadata: ArticleMetadata(
                intendedReaders: "自分の気持ちを整理したい中学生・高校生と一般の利用者",
                lastReviewed: reviewDate,
                safetyNote: "記録で苦しさが増す場合は中断してください。危険を感じるときは相談や緊急支援を優先してください。",
                sources: [ArticleSources.youthStress, ArticleSources.youthConsultation],
                supportPrompt: "記録より先に誰かへ話したいときは、相談先を確認できます。"
            )
        ),
        Article(
            id: "liking-someone-with-boundaries",
            title: "好きな人ができたときに大切にしたいこと",
            category: "人間関係",
            summary: "相手の気持ちを推測せず、自分と相手の意思・境界線を尊重します。",
            content: """
            誰かを好きになると、うれしさ、不安、期待、戸惑いなどが同時に起こることがあります。どんな感情があるかを日記に残すことはできますが、相手の気持ちは、視線、返信の速さ、点数などから決められません。

            話したいことがあるなら、相手が答えやすい場所とタイミングを考え、断られても受け止められる伝え方を選びます。返事を急がせない、連絡を繰り返さない、相手が嫌だと言ったことを続けないことは、お互いの安心につながります。

            自分にも断る権利があります。交際していても、会うこと、連絡すること、触れること、性的なことは、その都度それぞれが選べます。怖さ、監視、脅し、強制がある状態を「好きだから仕方ない」と受け入れる必要はありません。

            一人で考えるのが難しいときは、信頼できる友人や大人に、実際に起きたことと自分の気持ちを分けて話してみてください。
            """,
            metadata: ArticleMetadata(
                intendedReaders: "恋愛や親しい関係について考えている中学生・高校生と若者",
                lastReviewed: reviewDate,
                safetyNote: "同意のない性的な行為、監視、脅し、暴力は、恋愛の一部として我慢する必要はありません。",
                sources: [ArticleSources.dateDV, ArticleSources.youngSexualViolence, ArticleSources.youngPeople],
                supportPrompt: "関係の中で怖さや強制を感じるときに利用できる相談先があります。"
            )
        ),
        Article(
            id: "anxiety-facts-and-next-step",
            title: "不安があるとき、事実と心配を分けてみる",
            category: "感情",
            summary: "不安を消すのではなく、今わかることと次の小さな行動を整理します。",
            content: """
            将来、人間関係、学校、生活の変化などで不安になることがあります。不安があることだけで、弱い人や病気だと決まるわけではありません。

            紙や日記を二つに分け、「今わかっている事実」と「頭に浮かぶ心配」を書く方法があります。たとえば事実は「明日発表がある」、心配は「失敗したら全員に嫌われるかもしれない」です。心配を否定せず、事実とは分けて置きます。

            次に、今できる行動を一つだけ選びます。必要な物を準備する、先生に質問する、休憩する、誰かに話すなどです。何も選べない日は、休むことや助けを求めることも行動です。

            不安で眠れない、学校へ行けない、体調への影響が続く場合は、一人で解決できないから失敗なのではありません。家族・先生・保健室・医療機関・相談窓口を利用できます。
            """,
            metadata: ArticleMetadata(
                intendedReaders: "不安や心配を整理したい中学生・高校生と一般の利用者",
                lastReviewed: reviewDate,
                safetyNote: "強い不安や生活への影響が続く場合は、セルフケアだけに頼らず相談してください。",
                sources: [ArticleSources.youthStress, ArticleSources.youthConsultation, ArticleSources.studentSupport],
                supportPrompt: "相談で何を話せばよいかわからないときも、相談先を確認できます。"
            )
        ),
        Article(
            id: "tiredness-not-a-diagnosis",
            title: "心や体の疲れに気づいたとき",
            category: "休息",
            summary: "疲れを診断せず、いつもとの違いと生活への影響を記録します。",
            content: """
            朝起きにくい、集中しづらい、気分が晴れない、体が重いなどは、疲れやストレスがあるときに起こることがあります。一方で、睡眠、体調、環境などさまざまな理由も考えられ、このアプリだけでは原因を決められません。

            「いつから」「どの場面で」「眠りや食事はどうだったか」「学校や生活にどんな影響があったか」を短く残すと、相談するときの材料になります。記録できないほど疲れている日は、書かずに休んで構いません。

            予定を減らす、横になる、水分や食事をとる、静かな場所に移る、誰かに伝えるなど、今できることを一つ選べます。無理に前向きになる必要はありません。

            不調が続く、急に強くなった、日常生活が難しい、体の症状が気になる場合は、保護者、学校の保健室、医療機関などへ相談してください。
            """,
            metadata: ArticleMetadata(
                intendedReaders: "心や体の疲れ、集中しづらさが気になる人",
                lastReviewed: reviewDate,
                safetyNote: "急な強い症状や体の異常がある場合は、アプリの記録より医療機関への相談を優先してください。",
                sources: [ArticleSources.youthStress, ArticleSources.sleepGuidance, ArticleSources.youthConsultation],
                supportPrompt: "疲れや不調が続いているときは、相談先を確認できます。"
            )
        )
    ]

    static var categories: [String] {
        Array(Set(articles.map(\.category))).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    static func filteredArticles(query: String, category: String?) -> [Article] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return articles.filter { article in
            let matchesCategory = category == nil || article.category == category
            guard matchesCategory else { return false }
            guard !normalizedQuery.isEmpty else { return true }

            let searchableText = [
                article.title,
                article.category,
                article.summary,
                article.content,
                article.metadata.intendedReaders
            ].joined(separator: "\n")
            return searchableText.localizedStandardContains(normalizedQuery)
        }
    }
}
