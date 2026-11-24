import PocketCastsServer

public extension AutoAddLimitReachedAction {
    func description(short: Bool = false) -> String {
        switch self {
        case .stopAdding:
            return short ? L10n.autoAddToUpNextStopShort : L10n.autoAddToUpNextStop
        case .addToTopOnly:
            return short ? L10n.autoAddToUpNextTopOnlyShort : L10n.autoAddToUpNextTopOnly
        }
    }
}
