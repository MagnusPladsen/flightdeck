import SwiftUI

struct OverviewSection: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                OverviewHeader()
                ResourceCardsRow()
                ServersCard()
                HStack(alignment: .top, spacing: 14) {
                    AgentsCard()
                    VStack(spacing: 14) {
                        UsageCard()
                        TopProcessesCard()
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .background(theme.background)
    }
}
