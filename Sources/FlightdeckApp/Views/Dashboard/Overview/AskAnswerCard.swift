import SwiftUI

/// Claude's answer to a question asked from the search bar.
struct AskAnswerCard: View {
    @Environment(\.theme) private var theme
    var asker: ClaudeAsker

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(asker.question).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                Spacer()
                IconButton(systemImage: "xmark", help: "Close") { asker.dismiss() }
                    .foregroundStyle(theme.muted)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(theme.border))
    }

    @ViewBuilder
    private var content: some View {
        switch asker.status {
        case .asking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Asking Claude…").foregroundStyle(theme.muted)
            }
            .font(.system(size: 13))
        case .answered(let answer):
            Text(markdown(answer))
                .font(.system(size: 13))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        case .failed(let message):
            Text(message).font(.system(size: 13)).foregroundStyle(theme.error)
        case nil:
            EmptyView()
        }
    }

    private func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
