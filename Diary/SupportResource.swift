import Foundation

/// 相談先を表示する順序と、画面上の注意レベルを表す。
///
/// 医療的な重症度や利用者の状態を判定する値ではない。
enum SupportUrgency: Int, CaseIterable, Comparable {
    case immediate
    case anytime
    case information

    static func < (lhs: SupportUrgency, rhs: SupportUrgency) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var sectionTitle: String {
        switch self {
        case .immediate: return "今すぐ話したいとき"
        case .anytime: return "自分に合う方法で相談する"
        case .information: return "相談先を探す"
        }
    }
}

enum SupportContactKind: String, Equatable {
    case phone
    case web

    var systemImage: String {
        switch self {
        case .phone: return "phone"
        case .web: return "safari"
        }
    }
}

/// アプリ内の全画面で共有する相談先の表示モデル。
///
/// destinationStringを文字列として保持し、壊れたURLでアプリを強制終了しない。
/// URLの妥当性はユニットテストで検証する。
struct SupportResource: Identifiable {
    let id: String
    let name: String
    let summary: String
    let audience: String
    let availability: String
    let contactLabel: String
    let contactKind: SupportContactKind
    let destinationString: String
    let sourceURLString: String
    let urgency: SupportUrgency
    let lastVerified: String

    var destinationURL: URL? {
        URL(string: destinationString)
    }

    var sourceURL: URL? {
        URL(string: sourceURLString)
    }
}

/// 公式情報を確認した日と出典を含む、相談先の唯一の供給元。
///
/// 最終確認日: 2026-08-01
/// 主な出典: 厚生労働省「まもろうよ こころ」、総務省消防庁
enum SupportResourceCatalog {
    static let lastVerified = "2026-08-01"

    static let resources: [SupportResource] = [
        SupportResource(
            id: "emergency-119",
            name: "119番",
            summary: "今すぐ自分や周りの人に危険があり、救急車が必要なときの緊急通報です。",
            audience: "緊急の助けが必要な人",
            availability: "24時間",
            contactLabel: "119",
            contactKind: .phone,
            destinationString: "tel:119",
            sourceURLString: "https://www.fdma.go.jp/mission/enrichment/kyukyumusen_kinkyutuhou/119.html",
            urgency: .immediate,
            lastVerified: lastVerified
        ),
        SupportResource(
            id: "inochi-sos",
            name: "#いのちSOS",
            summary: "「死にたい」「消えたい」などの気持ちを、専門の相談員と一緒に整理できる無料電話です。",
            audience: "つらい気持ちを今すぐ話したい人",
            availability: "24時間・365日",
            contactLabel: "0120-061-338",
            contactKind: .phone,
            destinationString: "tel:0120061338",
            sourceURLString: "https://www.mhlw.go.jp/mamorouyokokoro/soudan/tel/",
            urgency: .immediate,
            lastVerified: lastVerified
        ),
        SupportResource(
            id: "yorisoi-hotline",
            name: "よりそいホットライン",
            summary: "ガイダンスから、悩みや状況に合う専門的な相談につながる無料電話です。",
            audience: "今の困りごとを電話で相談したい人",
            availability: "24時間対応（050は050-3655-0279）",
            contactLabel: "0120-279-338",
            contactKind: .phone,
            destinationString: "tel:01200279338",
            sourceURLString: "https://www.mhlw.go.jp/mamorouyokokoro/soudan/tel/",
            urgency: .immediate,
            lastVerified: lastVerified
        ),
        SupportResource(
            id: "child-sos-24h",
            name: "24時間子供SOSダイヤル",
            summary: "いじめや、そのほかの子どものSOSについて、地域の教育委員会の相談機関につながります。",
            audience: "子ども・学生",
            availability: "24時間",
            contactLabel: "0120-0-78310",
            contactKind: .phone,
            destinationString: "tel:0120078310",
            sourceURLString: "https://www.mhlw.go.jp/mamorouyokokoro/soudan/tel/",
            urgency: .anytime,
            lastVerified: lastVerified
        ),
        SupportResource(
            id: "childline",
            name: "チャイルドライン",
            summary: "18歳までの子どもが、名前を言わずに気持ちを話せる無料電話です。",
            audience: "18歳まで",
            availability: "毎日16時〜21時（年末年始を除く）",
            contactLabel: "0120-99-7777",
            contactKind: .phone,
            destinationString: "tel:0120997777",
            sourceURLString: "https://www.mhlw.go.jp/mamorouyokokoro/soudan/tel/",
            urgency: .anytime,
            lastVerified: lastVerified
        ),
        SupportResource(
            id: "public-mental-health",
            name: "こころの健康相談統一ダイヤル",
            summary: "電話をかけた地域の、都道府県・政令指定都市による公的な相談機関につながります。",
            audience: "地域の公的な窓口へ相談したい人",
            availability: "曜日・時間は地域ごとに異なります",
            contactLabel: "0570-064-556",
            contactKind: .phone,
            destinationString: "tel:0570064556",
            sourceURLString: "https://www.mhlw.go.jp/mamorouyokokoro/soudan/tel/",
            urgency: .anytime,
            lastVerified: lastVerified
        ),
        SupportResource(
            id: "mhlw-sns",
            name: "SNS・チャット相談",
            summary: "電話で話しにくいときに、年代や希望する方法に合うSNS・チャット相談を選べます。",
            audience: "文字で相談したい人",
            availability: "窓口ごとに異なります",
            contactLabel: "厚生労働省の一覧を開く",
            contactKind: .web,
            destinationString: "https://www.mhlw.go.jp/mamorouyokokoro/soudan/sns/",
            sourceURLString: "https://www.mhlw.go.jp/mamorouyokokoro/soudan/sns/",
            urgency: .anytime,
            lastVerified: lastVerified
        ),
        SupportResource(
            id: "anata-no-ibasho",
            name: "あなたのいばしょ",
            summary: "年齢や性別を問わず、無料・匿名でチャット相談を利用できます。",
            audience: "文字で、いつでも相談したい人",
            availability: "24時間・365日",
            contactLabel: "チャット相談を開く",
            contactKind: .web,
            destinationString: "https://talkme.jp/",
            sourceURLString: "https://www.mhlw.go.jp/mamorouyokokoro/soudan/sns/",
            urgency: .anytime,
            lastVerified: lastVerified
        ),
        SupportResource(
            id: "mhlw-support-directory",
            name: "相談方法・窓口の一覧",
            summary: "悩み、相談方法、地域に合わせて、公的機関や支援団体の窓口を探せます。",
            audience: "どこに相談すればよいか探したい人",
            availability: "Webページ",
            contactLabel: "厚生労働省の一覧を開く",
            contactKind: .web,
            destinationString: "https://www.mhlw.go.jp/mamorouyokokoro/soudan/",
            sourceURLString: "https://www.mhlw.go.jp/mamorouyokokoro/soudan/",
            urgency: .information,
            lastVerified: lastVerified
        )
    ]

    static func resources(for urgency: SupportUrgency) -> [SupportResource] {
        resources.filter { $0.urgency == urgency }
    }
}
