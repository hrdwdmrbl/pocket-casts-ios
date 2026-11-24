import Foundation

public enum ServerNotifications {
    public static let podcastsRefreshed = NSNotification.Name(rawValue: "PCRefreshed")
    public static let podcastRefreshFailed = NSNotification.Name(rawValue: "PCRefFailed")
    public static let podcastRefreshThrottled = NSNotification.Name(rawValue: "PCRefreshedThrottled")
    public static let episodeTypeOrLengthChanged = NSNotification.Name(rawValue: "SJEpisodeTypeChanged")
    public static let userEpisodesRefreshed = NSNotification.Name(rawValue: "SJUserEpisodesRefreshed")
}
