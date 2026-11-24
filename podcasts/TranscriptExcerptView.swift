import SwiftUI

struct TranscriptExcerptView: View {
    @EnvironmentObject var theme: Theme
    let tapAction: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = 16

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(.clear)
                .background(theme.primaryUi02Active)
                .cornerRadius(8.0)
                .shadow(
                    color: .black.opacity(0.2),
                    radius: 3, x: 0, y: 1
                )
                .frame(minHeight: 48.0)
            HStack(spacing: 12.0) {
                Text(L10n.viewTranscript)
                    .font(size: 15.0, style: .body, weight: .medium)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(theme.primaryText01)
                Spacer()
                Image("listview_arrow")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(theme.primaryIcon02)
                    .frame(width: iconSize/2, height: iconSize)
            }
            .padding(.horizontal, 16.0)
        }
        .padding(.horizontal, 16.0)
        .padding(.top, 16.0)
        .padding(.bottom, 14.0)
        .onTapGesture {
            tapAction()
        }
    }
}
