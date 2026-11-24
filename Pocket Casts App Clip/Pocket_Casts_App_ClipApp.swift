import SwiftUI
import PocketCastsServer

@main
struct Pocket_Casts_App_ClipApp: App {

    init() {
        ServerConfig.shared.refreshDelegate = ServerRefreshManager.shared
        ServerConfig.shared.playbackDelegate = PlaybackManager.shared

        ServerSettings.setSkipBackTime(10)
        ServerSettings.setSkipForwardTime(45)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                NowPlayingView()
                    .background(Color(UIColor.systemBackground))
            }
            .onAppear {
            }
        }
    }
}
