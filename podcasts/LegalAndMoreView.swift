import SwiftUI
import WebKit

struct LegalAndMoreView: View {
    @EnvironmentObject var theme: Theme

    @Binding var navigationPath: [AboutNavigationPathComponent]

    var body: some View {
        ZStack {
            ThemeColor.primaryUi04(for: theme.activeTheme).color
                .ignoresSafeArea()
            List {
                Section {
                    AboutRow(mainText: L10n.aboutTermsOfService, showChevronIcon: true) {
                        navigationPath.append(.termsOfService)
                    }
                    AboutRow(mainText: L10n.aboutPrivacyPolicy, showChevronIcon: true) {
                        navigationPath.append(.privacyPolicy)
                    }
                    AboutRow(mainText: L10n.aboutAcknowledgements, showChevronIcon: true) {
                        navigationPath.append(.acknowledgements)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .colorScheme(theme.activeTheme.isDark ? .dark : .light)
            .scrollContentBackground(.hidden)
        }
        .navigationBarTitle(L10n.aboutLegalAndMore, displayMode: .inline)
    }

    enum Constants {
        static let termsOfUseURL = URL(string: "https://support.pocketcasts.com/article/terms-of-use-overview/")!
        static let privacyPolicyURL = URL(string: "https://support.pocketcasts.com/article/privacy-policy/")!
        static let acknowledgementsURL = Bundle.main.url(forResource: "acknowledgements", withExtension: "html")!
    }
}

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        if url.isFileURL {
            view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            view.load(URLRequest(url: url))
        }
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
