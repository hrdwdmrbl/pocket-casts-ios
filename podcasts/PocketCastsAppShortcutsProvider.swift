import AppIntents

struct PocketCastsAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SearchTranscriptsIntent(),
            phrases: ["Search transcripts in \(.applicationName)"],
            shortTitle: LocalizedStringResource("transcript_intent_search_title", defaultValue: "Search Transcripts"),
            systemImageName: "text.magnifyingglass"
        )
        AppShortcut(
            intent: GetTranscriptIntent(),
            phrases: ["Get a transcript from \(.applicationName)"],
            shortTitle: LocalizedStringResource("transcript_intent_get_title", defaultValue: "Get Transcript"),
            systemImageName: "text.document"
        )
        AppShortcut(
            intent: SetSleepTimerIntent(),
            phrases: [
                "\(.applicationName): Set sleep timer",
                "Start sleep timer in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource(
                "siri_shortcut_set_sleep_timer_title",
                defaultValue: "Set sleep timer",
                table: "AppIntents"
            ),
            systemImageName: "moon.zzz.fill"
        )
    }
}
