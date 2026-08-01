import SwiftUI
import UIKit

struct ArticleListView: View {
    @State private var searchText = ""
    @State private var selectedCategory: String?
    @State private var showingSupportResources = false

    private var filteredArticles: [Article] {
        ArticleCatalog.filteredArticles(
            query: searchText,
            category: selectedCategory
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    categoryPicker
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(DiaryTheme.canvas)
                        .listRowSeparator(.hidden)
                }

                if filteredArticles.isEmpty {
                    emptySearchResult
                        .listRowBackground(DiaryTheme.canvas)
                        .listRowSeparator(.hidden)
                } else {
                    Section("\(filteredArticles.count)件の記事") {
                        ForEach(filteredArticles) { article in
                            NavigationLink {
                                ArticleDetailView(article: article)
                            } label: {
                                ArticleRow(article: article)
                            }
                            .listRowBackground(DiaryTheme.surface)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(DiaryTheme.canvas)
            .navigationTitle("読む")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "タイトルや本文を検索")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSupportResources = true
                    } label: {
                        Label("相談先", systemImage: "person.2")
                    }
                    .accessibilityHint("相談方法と窓口を表示します")
                }
            }
            .sheet(isPresented: $showingSupportResources) {
                ConsultationResourcesView()
            }
        }
        .tint(DiaryTheme.accent)
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryButton(title: "すべて", category: nil)
                ForEach(ArticleCatalog.categories, id: \.self) { category in
                    categoryButton(title: category, category: category)
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("記事カテゴリ")
    }

    private func categoryButton(title: String, category: String?) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.bold())
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .foregroundStyle(isSelected ? Color.white : DiaryTheme.ink)
            .background(
                isSelected ? DiaryTheme.accent : DiaryTheme.elevatedSurface,
                in: Capsule()
            )
            .overlay {
                if !isSelected {
                    Capsule().stroke(DiaryTheme.line, lineWidth: 1)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var emptySearchResult: some View {
        VStack(spacing: 12) {
            DiaryLineIcon(kind: .journal, color: DiaryTheme.muted, size: 42)
            Text("該当する記事がありません")
                .font(.headline)
            Text("検索語を短くするか、別のカテゴリを選んでください。")
                .font(.subheadline)
                .foregroundStyle(DiaryTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

struct ArticleRow: View {
    let article: Article

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            articleThumbnail

            VStack(alignment: .leading, spacing: 7) {
                Text(article.title)
                    .font(.headline)
                    .foregroundStyle(DiaryTheme.ink)
                    .lineLimit(2)

                Text(article.summary)
                    .font(.subheadline)
                    .foregroundStyle(DiaryTheme.muted)
                    .lineLimit(2)

                Text(article.category)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DiaryTheme.accent)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityHint("記事を開きます")
    }

    @ViewBuilder
    private var articleThumbnail: some View {
        if let imageFileName = article.imageFileName,
           UIImage(named: imageFileName) != nil {
            Image(imageFileName)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
        } else {
            DiaryLineIcon(kind: .journal, color: DiaryTheme.accent, size: 32)
                .frame(width: 64, height: 64)
                .background(DiaryTheme.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityHidden(true)
        }
    }
}

struct ArticleDetailView: View {
    let article: Article
    @State private var showingSupportResources = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                articleMetadata
                Divider()

                Text(article.content)
                    .font(.body)
                    .foregroundStyle(DiaryTheme.ink)
                    .lineSpacing(6)
                    .textSelection(.enabled)

                safetyNotice

                if let supportPrompt = article.metadata.supportPrompt {
                    supportSection(prompt: supportPrompt)
                }

                sourcesSection
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background(DiaryTheme.canvas)
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingSupportResources = true
                } label: {
                    Label("相談先", systemImage: "person.2")
                }
                .accessibilityHint("相談方法と窓口を表示します")
            }
        }
        .sheet(isPresented: $showingSupportResources) {
            ConsultationResourcesView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                DiaryLineIcon(kind: .journal, color: DiaryTheme.accent, size: 32)
                Text(article.category)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DiaryTheme.accent)
            }

            Text(article.title)
                .font(.largeTitle.bold())
                .foregroundStyle(DiaryTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(article.summary)
                .font(.title3)
                .foregroundStyle(DiaryTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var articleMetadata: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(article.metadata.intendedReaders, systemImage: "person")
            Label("内容確認日: \(article.metadata.lastReviewed)", systemImage: "calendar")
            Label("医療的な診断ではなく、考えるための一般情報です", systemImage: "info.circle")
        }
        .font(.subheadline)
        .foregroundStyle(DiaryTheme.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .diarySurface(padding: 14, radius: 14)
    }

    private var safetyNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("安全について", systemImage: "checkmark.shield")
                .font(.headline)
                .foregroundStyle(DiaryTheme.accent)

            Text(article.metadata.safetyNote)
                .font(.subheadline)
                .foregroundStyle(DiaryTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(DiaryTheme.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func supportSection(prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(prompt)
                .font(.subheadline)
                .foregroundStyle(DiaryTheme.ink)

            Button("相談先を確認する") {
                showingSupportResources = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .diarySurface()
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("出典")
                .font(.title2.bold())

            Text("本文は端末内で読めます。次のリンクを選んだときだけ、外部ブラウザを開きます。")
                .font(.caption)
                .foregroundStyle(DiaryTheme.muted)

            ForEach(article.metadata.sources) { source in
                Link(destination: source.url) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(source.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(DiaryTheme.ink)
                            Text(source.organization)
                                .font(.caption)
                                .foregroundStyle(DiaryTheme.muted)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(DiaryTheme.accent)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if source.id != article.metadata.sources.last?.id {
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .diarySurface()
    }
}
