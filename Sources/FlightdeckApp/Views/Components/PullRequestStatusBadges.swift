import MonitorCore
import SwiftUI

/// A pull request's CI result and review decision as two small icons.
struct PullRequestStatusBadges: View {
    @Environment(\.theme) private var theme
    var pullRequest: PullRequestInfo

    var body: some View {
        HStack(spacing: 4) {
            if let review = pullRequest.review {
                Image(systemName: review.symbolName).foregroundStyle(review.color(in: theme)).help(review.title)
            }
            if let checks = pullRequest.checks {
                Image(systemName: checks.symbolName).foregroundStyle(checks.color(in: theme)).help(checks.title)
            }
        }
        .font(.caption.weight(.semibold))
    }
}

extension CheckStatus {
    var title: String {
        switch self {
        case .passing: "Checks passing"
        case .failing: "Checks failing"
        case .pending: "Checks running"
        }
    }

    var symbolName: String {
        switch self {
        case .passing: "checkmark.circle.fill"
        case .failing: "xmark.circle.fill"
        case .pending: "clock.fill"
        }
    }

    func color(in theme: Theme) -> Color {
        switch self {
        case .passing: theme.success
        case .failing: theme.error
        case .pending: theme.warning
        }
    }
}

extension ReviewState {
    var title: String {
        switch self {
        case .approved: "Approved"
        case .changesRequested: "Changes requested"
        case .reviewRequired: "Review required"
        }
    }

    var symbolName: String {
        switch self {
        case .approved: "checkmark.seal.fill"
        case .changesRequested: "exclamationmark.bubble.fill"
        case .reviewRequired: "eye"
        }
    }

    func color(in theme: Theme) -> Color {
        switch self {
        case .approved: theme.success
        case .changesRequested: theme.error
        case .reviewRequired: theme.muted
        }
    }
}
