import SwiftUI

struct CollapsibleUpdateReleaseNotesView: View {
    @Binding var isExpanded: Bool
    @State private var fullTextHeight: CGFloat = 0
    @State private var collapsedTextHeight: CGFloat = 0

    private let markdown: String
    private let omittingLeadingHeading: String?
    private let summary: AttributedString

    init(
        markdown: String,
        omittingLeadingHeading: String? = nil,
        isExpanded: Binding<Bool>
    ) {
        self.markdown = markdown
        self.omittingLeadingHeading = omittingLeadingHeading
        _isExpanded = isExpanded

        let document = HAUpdateReleaseNotesDocument(markdown: markdown)
            .omittingLeadingHeading(matching: omittingLeadingHeading)
        summary = Self.inlineMarkdown(document.summaryText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
            if isExpanded {
                UpdateReleaseNotesMarkdownView(
                    markdown: markdown,
                    omittingLeadingHeading: omittingLeadingHeading
                )

                if isTruncated {
                    Button("less") {
                        withAnimation(.snappy) {
                            isExpanded = false
                        }
                    }
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                }
            } else {
                collapsedSummary
            }
        }
    }

    private var collapsedSummary: some View {
        Text(summary)
            .font(.callout)
            .lineLimit(3)
            .truncationMode(.tail)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                collapsedTextHeight = height
            }
            .background {
                Text(summary)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        fullTextHeight = height
                    }
            }
            .overlay(alignment: .bottomTrailing) {
                if isTruncated {
                    HStack(spacing: 0) {
                        LinearGradient(
                            colors: [.clear, Color(.systemBackground)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 56)

                        Button("more") {
                            withAnimation(.snappy) {
                                isExpanded = true
                            }
                        }
                        .font(.caption.bold())
                        .foregroundStyle(Color.accentColor)
                        .padding(.leading, 2)
                        .background(Color(.systemBackground))
                    }
                    .frame(height: UIFont.preferredFont(forTextStyle: .callout).lineHeight)
                }
            }
    }

    private var isTruncated: Bool {
        fullTextHeight > collapsedTextHeight + 1
    }

    private static func inlineMarkdown(_ source: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
    }
}

struct UpdateReleaseNotesMarkdownView: View {
    let document: HAUpdateReleaseNotesDocument

    init(markdown: String, omittingLeadingHeading: String? = nil) {
        document = HAUpdateReleaseNotesDocument(markdown: markdown)
            .omittingLeadingHeading(matching: omittingLeadingHeading)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            ForEach(Array(document.blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .tint(Color.accentColor)
    }

    @ViewBuilder
    private func blockView(_ block: HAUpdateReleaseNotesDocument.Block) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(inlineMarkdown(text))
                .font(level <= 2 ? .headline : .subheadline.weight(.semibold))
                .padding(.top, AppSpacing.xSmall)
        case .paragraph(let text):
            Text(inlineMarkdown(text))
                .font(.subheadline)
        case .unorderedListItem(let depth, let text):
            listItem(marker: "•", depth: depth, text: text)
        case .orderedListItem(let depth, let ordinal, let text):
            listItem(marker: "\(ordinal).", depth: depth, text: text)
        case .quote(let text):
            HStack(alignment: .top, spacing: AppSpacing.small) {
                Capsule()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: 3)
                Text(inlineMarkdown(text))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .code(let text):
            ScrollView(.horizontal) {
                Text(text)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .padding(AppSpacing.small)
            }
            .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 8))
        case .divider:
            Divider()
        }
    }

    private func listItem(marker: String, depth: Int, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
            Text(marker)
                .frame(minWidth: 14, alignment: .trailing)
            Text(inlineMarkdown(text))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.subheadline)
        .padding(.leading, CGFloat(depth) * AppSpacing.medium)
    }

    private func inlineMarkdown(_ source: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
    }
}

private extension HAUpdateReleaseNotesDocument {
    var summaryText: String {
        blocks.compactMap { block in
            switch block {
            case .heading(_, let text), .paragraph(let text), .quote(let text):
                text
            case .unorderedListItem(_, let text):
                "• \(text)"
            case .orderedListItem(_, let ordinal, let text):
                "\(ordinal). \(text)"
            case .code(let text):
                text
            case .divider:
                nil
            }
        }
        .joined(separator: "\n")
    }
}
