import PocketCastsDataModel
import PocketCastsServer
import SafariServices
import UIKit
import Combine
import Kingfisher
import PocketCastsUtils
import SwiftUI

class MainTabBarController: UITabBarController, NavigationProtocol {

    enum Tab: Int { case podcasts, filter, discover, settings, upNext }

    var pcTabs = [Tab]()

    let playPauseCommand = UIKeyCommand(title: L10n.keycommandPlayPause, action: #selector(handlePlayPauseKey), input: " ", modifierFlags: [])

    /// Styles its badge as a plain red dot on the item itself, since Liquid Glass ignores the tab bar
    /// appearance that does it for the older tab bar.
    private lazy var settingsTabBarItem: UITabBarItem = {
        let item = UITabBarItem(title: L10n.settings, image: UIImage(systemName: "gearshape"), tag: pcTabs.firstIndex(of: .settings) ?? -1)
        item.badgeColor = .clear
        item.setBadgeTextAttributes([.foregroundColor: UIColor.systemRed], for: .normal)
        item.setBadgeTextAttributes([.foregroundColor: UIColor.systemRed], for: .selected)
        return item
    }()

    private lazy var upNextTabBarItem = UITabBarItem(title: L10n.upNext, image: UIImage(named: "upnext_tab"), tag: pcTabs.firstIndex(of: .upNext) ?? -1)

    /// The last Up Next count rendered into the tab, used to pulse the tab only
    /// when the queue actually changes (not on every refresh notification).
    private var previousUpNextCount: Int?

    /// `true` while the Up Next "pulse" spring is in flight, so a burst of
    /// rapid adds doesn't stack overlapping transforms on the target (the tab
    /// button, or the mini player artwork when minimized).
    /// Not `private`: set from the pulse code in `+Animations`.
    var isPulsingUpNextTarget = false

    /// The viewDidAppear can trigger more than once per lifecycle, setting this flag on the first did appear prevents use from prompting more than once per lifecycle. But still wait until the tab bar has appeared to do so.
    var viewDidAppearBefore: Bool = false

    /// Displayed during database migrations
    var alert: ShiftyLoadingAlert?

    private let errorBanner: UIView = {
        let view = UIView()
        view.backgroundColor = LiquidGlass.isEnabled ? UIColor.clear : ThemeColor.primaryUi03()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.alpha = 0
        return view
    }()

    private var errorBottomSpacing: NSLayoutConstraint?
    private var dismissErrorWorkItem: DispatchWorkItem?

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.textColor = AppTheme.mainTextColor()
        label.font = .font(ofSize: 14, weight: .medium, scalingWith: .largeTitle)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = false
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()

    // MARK: - State

    private let errorBannerHeight: CGFloat = LiquidGlass.isEnabled ? 60 : 48

    override func viewDidLoad() {
        super.viewDidLoad()

        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitHorizontalSizeClass.self]) { (controller: MainTabBarController, _) in
            if let scene = controller.view.window?.windowScene {
                Theme.systemIsDark = (scene.traitCollection.userInterfaceStyle == .dark)
            }
            controller.fixTarBarTraitCollectionOnIpadForiOS18()
            controller.fireSystemThemeMayHaveChanged()
        }

        fixTarBarTraitCollectionOnIpadForiOS18()

        pcTabs = [.podcasts, .filter, .discover, .upNext, .settings]

        var vcsInTab = [UIViewController]()

        let podcastsController = PodcastListViewController()
        podcastsController.tabBarItem = UITabBarItem(title: L10n.podcastsPlural, image: UIImage(named: "podcasts_tab"), tag: pcTabs.firstIndex(of: .podcasts)!)

        let filtersViewController = PlaylistsViewController()
        filtersViewController.tabBarItem = UITabBarItem(title: L10n.playlists, image: UIImage(named: "playlists_tab"), tag: pcTabs.firstIndex(of: .filter)!)

        let discoverViewController = DiscoverCollectionViewController()

        discoverViewController.tabBarItem = UITabBarItem(title: L10n.discover, image: UIImage(named: "discover_tab"), tag: pcTabs.firstIndex(of: .discover)!)

        let settingsViewController = SettingsViewController()
        settingsViewController.tabBarItem = settingsTabBarItem

        let upNextViewController = UpNextViewController(source: .tabBar, showingInTab: true)
        upNextViewController.tabBarItem = upNextTabBarItem
        vcsInTab = [podcastsController, filtersViewController, discoverViewController, upNextViewController, settingsViewController]

        viewControllers = vcsInTab.map { SJUIUtils.navController(for: $0) }
        selectedIndex = UserDefaults.standard.integer(forKey: Constants.UserDefaults.lastTabOpened)

        NavigationManager.shared.mainViewControllerDidLoad(controller: self)
        setupMiniPlayer()
        updateTabBarColor()
        setupKeyboardShortcuts()

        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: Constants.Notifications.themeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(textEditingDidStart), name: Constants.Notifications.textEditingDidStart, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(textEditingDidEnd), name: Constants.Notifications.textEditingDidEnd, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleFollowSystemThemeTurnedOn), name: Constants.Notifications.followSystemThemeTurnedOn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(refreshUpNextTabBadge), name: Constants.Notifications.upNextQueueChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshUpNextTabBadge), name: Constants.Notifications.upNextEpisodeRemoved, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshUpNextTabBadge), name: Constants.Notifications.playbackTrackChanged, object: nil)
        // `upNextEpisodeAdded` refreshes the badge via the genie animation's tail, not here.
        NotificationCenter.default.addObserver(self, selector: #selector(animateEpisodeAddedToUpNext(_:)), name: Constants.Notifications.upNextEpisodeAdded, object: nil)
        refreshUpNextTabBadge()
        setupErrorBanner()
        setupErrorObservers()
    }

    private var cancellables = Set<AnyCancellable>()

    private var systemAppearanceObservation: Any?

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        updateErrorBannerSafeAreaInsets()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        registerSceneAppearanceObserverIfNeeded()
        fireSystemThemeMayHaveChanged()

        // if this key was never set lets default to Discovery or Podcast depending of podcasts followed
        if UserDefaults.standard.object(forKey: Constants.UserDefaults.lastTabOpened) == nil {
            selectedIndex = DataManager.shared.podcastCount() > 0 ? Tab.podcasts.rawValue: Tab.discover.rawValue
        }

        updateDatabaseIndexes()
        optimizeDatabaseIfNeeded()
    }

    /// Update database indexes and delete unused columns
    /// This is outside of migrations and done just once
    /// because for larger databases it's very time consuming
    private func updateDatabaseIndexes() {
        guard !Settings.upgradedIndexes else {
            return
        }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }

            if DataManager.shared.podcastCount() > 100 {
                self.presentLoader()
            }
            DataManager.shared.cleanUp()
            self.dismissLoader()
            Settings.upgradedIndexes = true
        }
    }

    private func optimizeDatabaseIfNeeded() {
        return
    }

    // TODO: This workaround is planned to be replaced later.
    private func fixTarBarTraitCollectionOnIpadForiOS18() {
        if #available(iOS 18.0, *),
           UIDevice.current.userInterfaceIdiom == .pad {
            traitOverrides.horizontalSizeClass = .compact
            if let rootHorizontalSizeClass = view.window?.traitCollection.horizontalSizeClass {
                tabBar.traitOverrides.horizontalSizeClass = rootHorizontalSizeClass
                if let viewControllers {
                    for vc in viewControllers {
                        vc.traitOverrides.horizontalSizeClass = rootHorizontalSizeClass
                    }
                }
            }
        }
    }

    @objc func themeDidChange() {
        updateTabBarColor()
        updateErrorColor()
        setNeedsStatusBarAppearanceUpdate()
        refreshUpNextTabBadge()
    }

    private func setupMiniPlayer() {
        let miniPlayer = MiniPlayerViewController(nibName: "MiniPlayerViewController", bundle: nil)
        NavigationManager.shared.miniPlayer = miniPlayer

        if LiquidGlass.isEnabled, #available(iOS 26.0, *) {
            miniPlayer.hostTabBarController = self
            // Load the view so XIB outlets and observers are wired up before
            // it's installed as a tab accessory contentView.
            miniPlayer.loadViewIfNeeded()
        } else {
            miniPlayer.view.translatesAutoresizingMaskIntoConstraints = false
            view.insertSubview(miniPlayer.view, belowSubview: tabBar)

            NSLayoutConstraint.activate([
                miniPlayer.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                miniPlayer.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                miniPlayer.view.bottomAnchor.constraint(equalTo: tabBar.topAnchor)
            ])

            miniPlayer.changeHeightTo(miniPlayer.desiredHeight())
        }
    }

    // MARK: - UITabBarDelegate

    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        let tabIndex = item.tag
        if tabIndex == selectedIndex, let navController = selectedViewController as? UINavigationController, navController.visibleViewController == navController.viewControllers.first {
            // the user has tapped on a tab they are already at the root of, so trigger an action so we can handle this
            NotificationCenter.postOnMainThread(notification: Constants.Notifications.tappedOnSelectedTab, object: tabIndex)
        }

        UserDefaults.standard.set(tabIndex, forKey: Constants.UserDefaults.lastTabOpened)
    }

    // MARK: - NavigationProtocol

    func showInSafariViewController(urlString: String) {
        guard let url = URL(string: urlString) else { return }

        let safariViewController = SFSafariViewController(with: url)
        topController().present(safariViewController, animated: true, completion: nil)
    }

    func navigateToPodcastList(_ animated: Bool) {
        if !switchToTab(.podcasts) { return }

        if let navController = selectedViewController as? UINavigationController {
            navController.popToRootViewController(animated: true)
        }
    }

    func navigateToPodcast(_ podcast: Podcast, source: PodcastScreenSource) {
        appDelegate()?.miniPlayer()?.closeUpNextAndFullPlayer(completion: { [weak self] in

            guard let strongSelf = self else { return }

            if let navController = strongSelf.selectedViewController as? UINavigationController {
                if let existingPodcastController = navController.topViewController as? PodcastViewController {
                    if let existingUuid = existingPodcastController.podcast?.uuid, existingUuid == podcast.uuid {
                        return // we're already on this podcast
                    } else {
                        navController.popViewController(animated: false)
                    }
                }

                let podcastController = PodcastViewController(podcast: podcast)
                podcastController.screenSource = source
                navController.pushViewController(podcastController, animated: true)
            }
        })
    }

    func navigateToPodcastInfo(_ podcastInfo: PodcastInfo, source: PodcastScreenSource) {
        appDelegate()?.miniPlayer()?.closeUpNextAndFullPlayer(completion: { [weak self] in
            guard let navController = self?.selectedViewController as? UINavigationController else {
                return
            }

            navController.popToRootViewController(animated: false)
            let podcastController = PodcastViewController(podcastInfo: podcastInfo, existingImage: nil)
            podcastController.screenSource = source
            navController.pushViewController(podcastController, animated: true)
        })
    }

    func navigateTo(podcast searchResult: PodcastSearchResult, source: PodcastScreenSource) {
        if let navController = selectedViewController as? UINavigationController {
            let podcastController = PodcastViewController(podcastInfo: PodcastInfo(from: searchResult), existingImage: nil)
            podcastController.screenSource = source
            navController.pushViewController(podcastController, animated: true)
        }
    }

    func navigateToEpisode(_ episodeUuid: String, podcastUuid: String?, timestamp: TimeInterval?) {
        if let navController = selectedViewController as? UINavigationController {
            navController.dismiss(animated: false, completion: nil)

            // I know it looks dodgy, but the episode card won't load properly if you just dismissed another view controller. Need to figure out the actual bug...but for now:
            // (before you ask, using the completion block doesn't work above, regardless of whether animated is true or false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5.seconds) {
                if EpisodeLoadingController.needsLoading(uuid: episodeUuid), let podcastUuid {
                    let episodeController = EpisodeLoadingController(episodeUuid: episodeUuid,
                                                                     podcastUuid: podcastUuid,
                                                                     timestamp: timestamp)

                    let nav = UINavigationController(rootViewController: episodeController)
                    nav.modalPresentationStyle = .formSheet
                    nav.isNavigationBarHidden = true

                    navController.present(nav, animated: true)
                } else {
                    let episodeController = EpisodeDetailViewController(episodeUuid: episodeUuid, source: .homeScreenWidget, timestamp: timestamp)
                    episodeController.modalPresentationStyle = .formSheet

                    navController.present(episodeController, animated: true)
                }
            }
        }
    }

    func navigateToDiscover(_ animated: Bool) {
        switchToTab(.discover)
    }

    func navigateToDiscover(category: String, animated: Bool) {
        switchToTab(.discover)
        if let index = pcTabs.firstIndex(of: .discover),
           let navController = viewControllers?[safe: index] as? UINavigationController {
            navController.popToRootViewController(animated: false)
            if let discoverDelegate = navController.topViewController as? DiscoverDelegate {
                discoverDelegate.navigateTo(category: category)
            }
        }
    }

    func navigateToDiscover(listID: String, animated: Bool) {
        switchToTab(.discover)
        if let index = pcTabs.firstIndex(of: .discover),
           let navController = viewControllers?[safe: index] as? UINavigationController {
            navController.popToRootViewController(animated: false)
            if let discoverDelegate = navController.topViewController as? DiscoverDelegate {
                discoverDelegate.navigateTo(listID: listID)
            }
        }
    }

    func navigateToDiscoverNetworks(_ animated: Bool) {
        switchToTab(.discover)
        if let index = pcTabs.firstIndex(of: .discover),
           let navController = viewControllers?[safe: index] as? UINavigationController {
            navController.popToRootViewController(animated: false)
            if let discoverController = navController.topViewController as? DiscoverCollectionViewController {
                discoverController.navigateToNetworks()
            }
        }
    }

    func navigateToUpNext(_ animated: Bool) {
        switchToTab(.upNext)
    }

    func navigateToSettings(row: SettingsViewController.TableRow? = nil, animated: Bool) {
        switchToTab(.settings)
        guard let navController = selectedViewController as? UINavigationController else {
            return
        }
        navController.popToRootViewController(animated: animated)
        guard let settingsViewController = navController.topViewController as? SettingsViewController,
              let row else {
            return
        }
        settingsViewController.selectRow(row)
    }

    func navigateToFilter(_ filter: EpisodeFilter?, animated: Bool) {
        guard switchToTab(.filter) else { return }

        guard let navController = selectedViewController as? UINavigationController else {
            return
        }
        navController.popToRootViewController(animated: false)

        guard let filter,
              let filtersViewController = navController.topViewController as? PlaylistsViewController else {
            return
        }
        filtersViewController.showFilter(filter)
    }

    func navigateToAddFilter() {
        guard switchToTab(.filter),
              let navController = selectedViewController as? UINavigationController else {
            return
        }
        navController.popToRootViewController(animated: false)

        (navController.topViewController as? PlaylistsViewController)?.presentFilterPreview()
    }

    func presentManualPlaylistsChooser(for episode: Episode, rootViewController: UIViewController?, source: String) {
        guard let navController = selectedViewController as? UINavigationController else {
            return
        }
        let manualPlaylistsChooser = ManualPlaylistsChooserViewController(episode: episode)
        let navVC = SJUIUtils.navController(for: manualPlaylistsChooser)
        if presentedViewController is PlayerContainerViewController {
            presentedViewController?.present(navVC, animated: true, completion: nil)
        } else {
            let root = rootViewController ?? navController.topViewController
            root?.present(navVC, animated: true, completion: nil)
        }
    }

    func navigateToAddCustom(_ url: URL) {
        appDelegate()?.miniPlayer()?.closeUpNextAndFullPlayer(completion: {
            self.switchToTab(.settings)

            if let navController = self.selectedViewController as? UINavigationController {
                if let existingUploadedViewController = (navController.viewControllers.last as? UploadedViewController) {
                    existingUploadedViewController.closeAllChildrenViewControllers()
                }
                navController.popToRootViewController(animated: false)

                let uploadedViewController = UploadedViewController()
                uploadedViewController.fileURL = url
                navController.pushViewController(uploadedViewController, animated: false)
            }
        })
    }

    func navigateToFiles() {
        switchToTab(.settings)

        if let navController = selectedViewController as? UINavigationController {
            navController.popToRootViewController(animated: false)

            let filesController = UploadedViewController()
            navController.pushViewController(filesController, animated: true)
        }
    }

    func showPrivacyPolicy() {
        showInSafariViewController(urlString: ServerConstants.Urls.privacyPolicy)
    }

    func showTermsOfUse() {
        showInSafariViewController(urlString: ServerConstants.Urls.termsOfUse)
    }

    func navigateToFilterTab() {
        switchToTab(.filter)
    }

    func showSettings(row: SettingsViewController.TableRow?) {
        switchToTab(.settings)
        guard let navController = selectedViewController as? UINavigationController else { return }

        if navController.presentedViewController != nil {
            navController.dismiss(animated: false)
        }

        navController.popViewController(animated: false)
        let settingViewController = SettingsViewController()
        navController.pushViewController(settingViewController, animated: row == nil)

        guard let row else { return }

        settingViewController.selectRow(row)
    }

    func showSettingsAppearance(showThemeSelection: Bool = false) {
        switchToTab(.settings)
        if let navController = selectedViewController as? UINavigationController {
            navController.popToRootViewController(animated: false)

            let appearanceViewController = AppearanceViewController()
            navController.pushViewController(appearanceViewController, animated: !showThemeSelection)
            if showThemeSelection {
                appearanceViewController.presentThemePicker(selectedTheme: Theme.preferredLightTheme()) { theme in
                    Theme.setPreferredLightTheme(theme, systemIsDark: Theme.systemIsDark)
                }
            }
        }
    }

    func showHeadphoneSettings() {
        let state = NavigationManager.shared.miniPlayer?.playerOpenState

        // Dismiss any presented views if the player is not already open/dismissing since it will dismiss itself
        if state != .open, state != .animating {
            dismissPresentedViewController()
        }

        switchToTab(.settings)
        if let navController = selectedViewController as? UINavigationController {
            navController.popToRootViewController(animated: false)
            navController.pushViewController(HeadphoneSettingsViewController(), animated: true)
        }
    }

    func showGeneralSettings(row: GeneralSettingsViewController.TableRow?) {
        let state = NavigationManager.shared.miniPlayer?.playerOpenState

        // Dismiss any presented views if the player is not already open/dismissing since it will dismiss itself
        if state != .open, state != .animating {
            dismissPresentedViewController()
        }

        switchToTab(.settings)
        if let navController = selectedViewController as? UINavigationController {
            navController.popToRootViewController(animated: false)
            let generalSettingsController = GeneralSettingsViewController()
            generalSettingsController.scrollToRow = row
            navController.pushViewController(generalSettingsController, animated: true)
        }
    }

    func dismissPresentedViewController(completion: (() -> Void)? = nil) {
        presentedViewController?.dismiss(animated: true, completion: completion)
    }

    private func topController() -> UIViewController {
        var topController: UIViewController = self
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }

        return topController
    }

    @discardableResult
    private func switchToTab(_ tab: Tab) -> Bool {
        guard let miniPlayer = NavigationManager.shared.miniPlayer else { return false }

        if miniPlayer.playerOpenState == .animating {
            return false // can't switch tabs while animating
        }

        if miniPlayer.playerOpenState == .open {
            miniPlayer.closeFullScreenPlayer()
        }

        selectedIndex = pcTabs.firstIndex(of: tab)!

        return true
    }

    // MARK: - Orientation

    // we implement this here to lock all views (except presented modal VCs to portrait)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }

    // MARK: - End of Year

    private func updateTabBarColor() {
        tabBar.unselectedItemTintColor = AppTheme.unselectedTabBarItemColor
        tabBar.tintColor = AppTheme.tabBarItemTintColor

        // Liquid Glass renders its own translucent material, so skip the opaque
        // background appearance below — but the theme tint above must still apply.
        guard !LiquidGlass.isEnabled else { return }

        self.view.backgroundColor = AppTheme.viewBackgroundColor

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = AppTheme.tabBarBackgroundColor

        // Change badge colors
        [appearance.stackedLayoutAppearance,
         appearance.inlineLayoutAppearance,
         appearance.compactInlineLayoutAppearance]
            .forEach {
                $0.normal.badgeBackgroundColor = .clear
                $0.normal.badgeTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.systemRed]
            }

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    @objc private func willEnterForeground() {
        fireSystemThemeMayHaveChanged()
    }

    // The window's `overrideUserInterfaceStyle` masks system appearance changes
    // from view controllers inside it, so `traitCollectionDidChange` never fires
    // for system light/dark flips. Observe at the scene level instead — scene
    // traits aren't affected by the per-window override.
    private func registerSceneAppearanceObserverIfNeeded() {
        guard systemAppearanceObservation == nil,
              LiquidGlass.isEnabled,
              let scene = view.window?.windowScene else { return }
        systemAppearanceObservation = scene.registerForTraitChanges(
            [UITraitUserInterfaceStyle.self]
        ) { [weak self] (scene: UIWindowScene, _: UITraitCollection) in
            Theme.systemIsDark = (scene.traitCollection.userInterfaceStyle == .dark)
            self?.fireSystemThemeMayHaveChanged()
        }
    }

    private var lastNotifiedAboutDark: Bool?
    private func fireSystemThemeMayHaveChanged() {
        if !Settings.shouldFollowSystemTheme { return } // if the user has turned this off, then ignore system theme changes

        let isDark = Theme.systemIsDark
        if lastNotifiedAboutDark == nil || isDark != lastNotifiedAboutDark {
            lastNotifiedAboutDark = isDark
            NotificationCenter.postOnMainThread(notification: Constants.Notifications.systemThemeMayHaveChanged, object: isDark)
        }
    }

    @objc private func handleFollowSystemThemeTurnedOn() {
        lastNotifiedAboutDark = nil
        fireSystemThemeMayHaveChanged()
    }

    // There are different areas of the app that relies on presenting VCs from the tab bar
    // However, sometimes the tab bar is already displaying the player.
    // This code simple checks if the tab bar is already presenting something and, if yes,
    // present the VC through the presentedViewController
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        if let presentedViewController, !presentedViewController.isBeingDismissed {
            presentedViewController.present(viewControllerToPresent, animated: flag, completion: completion)
            return
        }

        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake && Settings.shakeToRestartSleepTimer {
            PlaybackManager.shared.restartSleepTimer()
        }
    }
}

// MARK: - Error Status

extension MainTabBarController {

    private func setupErrorBanner() {
        view.addSubview(errorBanner)
        errorBanner.addSubview(errorLabel)

        let bottomSpacing = errorBanner.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        bottomSpacing.priority = .defaultLow
        self.errorBottomSpacing = bottomSpacing

        errorBanner.isUserInteractionEnabled = true
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(errorTapped))
        errorBanner.addGestureRecognizer(tapRecognizer)

        NSLayoutConstraint.activate([
            // Pin banner to the very bottom of the view (below tab bar)
            errorBanner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorBanner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomSpacing,
            errorBanner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            // Error label
            errorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            errorLabel.centerXAnchor.constraint(equalTo: errorBanner.centerXAnchor),
            errorLabel.topAnchor.constraint(equalTo: errorBanner.topAnchor, constant: 0),
            errorLabel.bottomAnchor.constraint(equalTo: errorBanner.bottomAnchor, constant: 0)
        ])
    }

    private func setupErrorObservers() {
        let errorRelevantNotifications = Set([Constants.Notifications.playbackFailed, Constants.Notifications.playbackStarted, Constants.Notifications.playbackPaused])

        for notificationName in errorRelevantNotifications {
            NotificationCenter.default.addObserver(self, selector: #selector(updateError(notification:)), name: notificationName, object: nil)
        }
    }

    @objc private func updateError(notification: NSNotification) {
        DispatchQueue.main.async { [weak self] in
            guard
                let error = PlaybackManager.shared.activeError else {
                self?.hideError()
                return
            }
            if self?.errorBanner.isHidden == true {
                self?.showError(error, autoDismissAfter: 5)
            }
        }
    }

    private func showError(_ error: PlaybackManager.PlaybackError, autoDismissAfter seconds: TimeInterval? = nil) {
        errorLabel.attributedText = error.shortUserAttributedMessage(mainColor: AppTheme.mainTextColor(), interactiveColor: ThemeColor.primaryInteractive01())
        errorBanner.isUserInteractionEnabled = error.userAction != nil
        errorBanner.layoutIfNeeded()
        errorBanner.isHidden = false
        errorBottomSpacing?.priority = .required
        UIView.animate(withDuration: 0.3,
                       delay: 0,
                       options: .curveEaseInOut) { [weak self] in
            guard let self else { return }
            self.errorBanner.alpha = 1
            // Push child content up so it doesn't hide behind the shifted tab bar
            self.updateErrorBannerSafeAreaInsets()
            self.view.layoutIfNeeded()
        }

        dismissErrorWorkItem?.cancel()
        if let seconds {
            let item = DispatchWorkItem { [weak self] in self?.hideError() }
            dismissErrorWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
        }
    }

    private func updateErrorBannerSafeAreaInsets() {
        guard errorBottomSpacing?.priority == .required else { return }

        let baseBottom = view.safeAreaInsets.bottom - additionalSafeAreaInsets.bottom
        let insets = UIEdgeInsets(top: 0, left: 0, bottom: errorBannerHeight - baseBottom, right: 0)
        if additionalSafeAreaInsets != insets {
            additionalSafeAreaInsets = insets
        }
    }

    @objc private func hideError() {
        errorBottomSpacing?.priority = .defaultLow
        UIView.animate(withDuration: 0.3,
                       delay: 0,
                       options: .curveEaseInOut) { [weak self] in
            guard let self else { return }
            self.errorBanner.alpha = 0

            // Reset content insets
            self.additionalSafeAreaInsets = .zero
            self.view.layoutIfNeeded()
        } completion: { [weak self] _ in
            self?.errorBanner.isHidden = true
        }
    }

    @objc private func errorTapped() {
        guard let error = PlaybackManager.shared.activeError,
              let url = error.userAction
        else {
            return
        }
        #if !APPCLIP
        let safariViewController = SFSafariViewController(with: url)
        safariViewController.modalPresentationStyle = .formSheet
        self.present(safariViewController, animated: true, completion: nil)
        #endif
    }

    private func updateErrorColor() {
        errorBanner.backgroundColor = LiquidGlass.isEnabled ? UIColor.clear : AppTheme.tabBarBackgroundColor
        errorLabel.textColor = AppTheme.mainTextColor()
    }
}

// MARK: - Up Next tab badge

extension MainTabBarController {
    @objc func refreshUpNextTabBadge() {
        guard #available(iOS 26.0, *) else { return }

        // Clamping lives in `composeUpNextTabImage`; track the true count here.
        let count = PlaybackManager.shared.queue.upNextCount()
        let previous = previousUpNextCount
        previousUpNextCount = count

        // Nothing to redraw if the count didn't move. The composed image is a
        // template, so the tab bar re-tints it on theme changes for free — no
        // rebuild needed there either.
        guard count != previous else { return }

        guard count > 0 else {
            resetUpNextTabImage()
            return
        }

        // A template image so the tab bar tints it like every other item.
        upNextTabBarItem.image = Self.composeUpNextTabImage(count: count)
        upNextTabBarItem.selectedImage = Self.composeUpNextTabImage(count: count, isSelected: true)

        // Only celebrate the queue growing — a drain (playing/removing) shouldn't pop.
        if previous.map({ count > $0 }) ?? false { pulseUpNextTarget() }
    }

    func resetUpNextTabImage() {
        upNextTabBarItem.image = UIImage(named: "upnext_tab")
        upNextTabBarItem.selectedImage = nil
    }
}
