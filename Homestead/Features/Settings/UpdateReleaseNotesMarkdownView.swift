import SwiftUI

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
