import Foundation
import PocketCastsUtils

public class ServerSettings {

    // MARK: - Skip Forward

    private static let skipForwardAmount = "JumpForwardAmountInSeconds"
    public class func setSkipForwardTime(_ time: Int) {
        UserDefaults.standard.set(time, forKey: ServerSettings.skipForwardAmount)
    }

    public class func skipForwardTime() -> Int {
        UserDefaults.standard.integer(forKey: ServerSettings.skipForwardAmount)
    }

    // MARK: - Skip Back

    private static let skipBackAmount = "JumpBackAmountInSeconds"
    public class func setSkipBackTime(_ time: Int) {
        UserDefaults.standard.set(time, forKey: ServerSettings.skipBackAmount)
    }

    public class func skipBackTime() -> Int {
        UserDefaults.standard.integer(forKey: ServerSettings.skipBackAmount)
    }

    // MARK: Home Grid Order

    private static let homeGridSortOrderKey = "SJPodcastLibrarySort"

    public class func setHomeGridSortOrder(_ order: Int) {
        UserDefaults.standard.set(order, forKey: homeGridSortOrderKey)
    }

    public class func homeGridSortOrder() -> Int {
        UserDefaults.standard.integer(forKey: homeGridSortOrderKey)
    }

    // MARK: Audio Only

    public class func setAudioOnly(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: ServerConstants.UserDefaults.audioOnlyKey)
    }

    public class func audioOnly() -> Bool {
        UserDefaults.standard.bool(forKey: ServerConstants.UserDefaults.audioOnlyKey)
    }

    public class func lastRefreshStartTime() -> Date? {
        UserDefaults.standard.object(forKey: ServerConstants.UserDefaults.lastRefreshStartTime) as? Date
    }

    public class func lastRefreshEndTime() -> Date? {
        UserDefaults.standard.object(forKey: ServerConstants.UserDefaults.lastRefreshEndTime) as? Date
    }

    // Push Token
    public class func pushToken() -> String? {
        UserDefaults.standard.string(forKey: ServerConstants.UserDefaults.pushToken)
    }

    public class func setPushToken(token: String) {
        UserDefaults.standard.set(token, forKey: ServerConstants.UserDefaults.pushToken)
    }

    public class func removePushToken() {
        UserDefaults.standard.removeObject(forKey: ServerConstants.UserDefaults.pushToken)
    }

    // MARK: - Auto add to Up Next Limit

    public static let autoAddLimitKey = "AutoAddToUpNextLimit"
    public class func autoAddToUpNextLimit() -> Int {
        UserDefaults.standard.integer(forKey: autoAddLimitKey)
    }

    public class func setAutoAddToUpNextLimit(_ limit: Int) {
        UserDefaults.standard.setValue(limit, forKey: autoAddLimitKey)
    }

    public static let onAutoAddLimitReachedKey = "AutoAddLimitReachedKey"
    public class func onAutoAddLimitReached() -> AutoAddLimitReachedAction {

        return AutoAddLimitReachedAction(rawValue: Int32(UserDefaults.standard.integer(forKey: onAutoAddLimitReachedKey))) ?? .stopAdding
    }

    public class func setOnAutoAddLimitReached(action: AutoAddLimitReachedAction) {
        UserDefaults.standard.setValue(action.rawValue, forKey: onAutoAddLimitReachedKey)
    }
}
