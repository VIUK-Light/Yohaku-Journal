import XCTest

final class ArticleCatalogTests: XCTestCase {
    func testArticlesHaveStableAndCompleteMetadata() {
        let articles = ArticleCatalog.articles
        let ids = articles.map(\.id)

        XCTAssertFalse(articles.isEmpty)
        XCTAssertEqual(Set(ids).count, ids.count)

        for article in articles {
            XCTAssertFalse(article.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(article.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(article.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(article.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(article.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(article.metadata.intendedReaders.isEmpty)
            XCTAssertEqual(article.metadata.lastReviewed, ArticleCatalog.reviewDate)
            XCTAssertFalse(article.metadata.safetyNote.isEmpty)
            XCTAssertFalse(article.metadata.sources.isEmpty)
            XCTAssertEqual(Set(article.metadata.sources).count, article.metadata.sources.count)

            for source in article.metadata.sources {
                XCTAssertEqual(source.url.scheme, "https")
                XCTAssertNotNil(source.url.host)
                XCTAssertFalse(source.title.isEmpty)
                XCTAssertFalse(source.organization.isEmpty)
            }
        }
    }

    func testCategoriesAreUniqueAndSorted() {
        let categories = ArticleCatalog.categories

        XCTAssertEqual(Set(categories).count, categories.count)
        XCTAssertEqual(categories, categories.sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        })
    }

    func testSearchIncludesTitleSummaryAndBodyAndTrimsInput() {
        let titleMatches = ArticleCatalog.filteredArticles(query: "  不安  ", category: nil)
        let bodyMatches = ArticleCatalog.filteredArticles(query: "返信がなかった", category: nil)
        let summaryMatches = ArticleCatalog.filteredArticles(query: "一律の正解", category: nil)

        XCTAssertTrue(titleMatches.contains { $0.id == "anxiety-facts-and-next-step" })
        XCTAssertTrue(bodyMatches.contains { $0.id == "emotions-name-and-observe" })
        XCTAssertTrue(summaryMatches.contains { $0.id == "stress-small-options" })
    }

    func testCategoryFilterIsAppliedTogetherWithSearch() {
        let articles = ArticleCatalog.filteredArticles(query: "", category: "睡眠")

        XCTAssertFalse(articles.isEmpty)
        XCTAssertTrue(articles.allSatisfy { $0.category == "睡眠" })
    }

    func testEmptySearchReturnsTheWholeCatalog() {
        XCTAssertEqual(
            ArticleCatalog.filteredArticles(query: "   ", category: nil).map(\.id),
            ArticleCatalog.articles.map(\.id)
        )
    }

    func testBoundaryArticleUsesTheOfficialYouthFacingDatingViolenceSource() {
        let article = ArticleCatalog.articles.first { $0.id == "boundaries-unreturned-affection" }
        let source = article?.metadata.sources.first {
            $0.organization == "内閣府男女共同参画局"
        }

        XCTAssertEqual(source?.url.absoluteString, "https://www.gender.go.jp/policy/no_violence/date_dv/index.html")
        XCTAssertEqual(source?.title, "デートDVって?")
    }
}
