import UIKit
import Combine
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils

class TranscriptViewController: PlayerItemViewController {
    let source: TranscriptErrorView.ViewSource

    private let playbackManager: TranscriptPlaybackManaging
    private var transcript: TranscriptModel?
    private var previousRange: NSRange?

    private var canScrollToDismiss = true

    private var isSearching = false
    private var searchIndicesResult: [Int] = []
    private var currentSearchIndex = 0
    private var searchTerm: String?

    private let debounce = Debounce(delay: Constants.defaultDebounceTime)

    private var kmpSearch: KMPSearch?

    private var transcriptManager: TranscriptManager?

    private var transcriptViewTopConstraint: NSLayoutConstraint?
    private var topGradientTopConstraint: NSLayoutConstraint?
    private var topGradientHeightConstraint: NSLayoutConstraint?
    var playButtonTapped: ((Bool) -> Void)?

    private var showFromEpisode: Bool {
        source == .episode
    }

    init(playbackManager: TranscriptPlaybackManaging, source: TranscriptErrorView.ViewSource = .player) {
        self.playbackManager = playbackManager
        self.source = source
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        parent?.view.overrideUserInterfaceStyle = .unspecified
        dismissSearch()
        resetSearch()
    }

    deinit {
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    private func setupViews() {
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self, UITraitHorizontalSizeClass.self]) { (controller: TranscriptViewController, previousTraitCollection: UITraitCollection) in
            if controller.traitCollection.preferredContentSizeCategory != previousTraitCollection.preferredContentSizeCategory {
                controller.refreshText()
                controller.refreshError()
                controller.refreshActionButtons()
            }
            controller.updateTextMargins()
        }

        view.addSubview(transcriptView)
        view.keyboardLayoutGuide.usesBottomSafeArea = showFromEpisode
        let transcriptViewTopConstraint = transcriptView.topAnchor.constraint(equalTo: view.topAnchor)
        self.transcriptViewTopConstraint = transcriptViewTopConstraint
        NSLayoutConstraint.activate(
            [
                transcriptViewTopConstraint,
                transcriptView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
                transcriptView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                transcriptView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ]
        )

        updateTextMargins()
        transcriptView.scrollIndicatorInsets = .init(top: 0.75 * Sizes.topGradientHeight, left: 0, bottom: bottomContainerInset, right: 0)

        view.addSubview(activityIndicatorView)
        NSLayoutConstraint.activate(
            [
                activityIndicatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: -Sizes.activityIndicatorSize / 2),
                activityIndicatorView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -Sizes.activityIndicatorSize / 2)
            ]
        )

        view.addSubview(errorView)
        NSLayoutConstraint.activate(
            [
                errorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                errorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                errorView.widthAnchor.constraint(equalTo: view.readableContentGuide.widthAnchor, constant: -Sizes.textMargin)
            ]
        )

        view.addSubview(topGradient)
        topGradient.translatesAutoresizingMaskIntoConstraints = false
        let topGradientTopConstraint = topGradient.topAnchor.constraint(equalTo: view.topAnchor)
        let topGradientHeightConstraint = topGradient.heightAnchor.constraint(equalToConstant: Sizes.topGradientHeight)
        self.topGradientTopConstraint = topGradientTopConstraint
        self.topGradientHeightConstraint = topGradientHeightConstraint
        NSLayoutConstraint.activate(
            [
                topGradientTopConstraint,
                topGradient.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                topGradient.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                topGradientHeightConstraint
            ]
        )

        view.addSubview(bottomGradient)
        bottomGradient.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(
            [
                bottomGradient.bottomAnchor.constraint(equalTo: showFromEpisode ? view.safeAreaLayoutGuide.bottomAnchor : view.bottomAnchor),
                bottomGradient.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                bottomGradient.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                bottomGradient.heightAnchor.constraint(equalToConstant: Sizes.bottomGradientHeight)
            ]
        )

        view.addSubview(hiddenTextView)

        stackView.addArrangedSubview(closeButton)
        stackView.addArrangedSubview(UIView())

        shareButton.isHidden = false
        stackView.addArrangedSubview(shareButton)

        playButton.isHidden = !showFromEpisode
        stackView.addArrangedSubview(playButton)

        stackView.addArrangedSubview(searchButton)

        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        let topMargin = showFromEpisode ? 8.0 : 0.0
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: topMargin),
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            closeButton.widthAnchor.constraint(equalToConstant: 44)
        ])
    }

    // Only return the searchView as the input acessory view
    // if search has been enabled.
    // This prevents the input acessory view from appearing
    // when selecting text
    override var inputAccessoryView: UIView? {
        isSearching ? searchView : nil
    }

    lazy var searchView: TranscriptSearchAccessoryView = {
        let view = TranscriptSearchAccessoryView()
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    @objc private func displaySearch() {
        isSearching = true

        // Keep the inputAccessoryView dark
        parent?.view.overrideUserInterfaceStyle = .dark

        hiddenTextView.becomeFirstResponder()

        // Move focus to the textView on the input accessory view
        searchView.textField.becomeFirstResponder()
        searchView.enableUpDownButtons(false)
    }

    @objc private func playEpisode() {
        playButton.buttonState = playbackManager.isPlayingEpisode ? .play : .pause
        playButtonTapped?(playbackManager.isPlayingEpisode)
    }

    @objc private func shareEpisode() {
        guard let transcript else { return }

        let transcriptText = transcript.attributedText.string
        let activityViewController = UIActivityViewController(activityItems: [transcriptText], applicationActivities: nil)

        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }

        present(activityViewController, animated: true)
    }

    private func dismissSearch() {
        isSearching = false

        searchView.textField.resignFirstResponder()

        resignFirstResponder()
    }

    private lazy var transcriptView: UITextView = {
        let textView = UITextView(usingTextLayoutManager: false)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = .systemFont(ofSize: 16)
        textView.isEditable = false
        textView.showsVerticalScrollIndicator = true
        textView.inputAccessoryView = nil
        return textView
    }()

    private lazy var activityIndicatorView: AngularActivityIndicator = {
        let activityIndicatorView = AngularActivityIndicator(size: CGSize(width: Sizes.activityIndicatorSize, height: Sizes.activityIndicatorSize), lineWidth: 2.0, duration: 1.0)
        activityIndicatorView.color = ThemeColor.playerContrast02()
        activityIndicatorView.hidesWhenStopped = true
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicatorView
    }()

    private lazy var errorView: TranscriptErrorView = {
        let source: TranscriptErrorView.ViewSource = source == .episode ? .episode : .player
        return TranscriptErrorView(source: source) { [weak self] in
            self?.retryLoad()
        }
    }()

    private lazy var closeButton: TintableImageButton! = {
        let closeButton = TintableImageButton()
        closeButton.setImage(UIImage(named: "close"), for: .normal)
        closeButton.tintColor = showFromEpisode ? ThemeColor.primaryInteractive01() : ThemeColor.primaryIcon02()
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        return closeButton
    }()

    private lazy var searchButton: RoundButton = {
        let titleColor = showFromEpisode ? ThemeColor.primaryInteractive01() : .white
        let tintColor = showFromEpisode ? ThemeColor.primaryInteractive01().withAlphaComponent(0.1) : .white.withAlphaComponent(0.2)

        var configuration = UIButton.Configuration.filled()
        configuration.contentInsets = .init(top: 4, leading: 12, bottom: 4, trailing: 12)
        configuration.baseForegroundColor = titleColor
        configuration.baseBackgroundColor = tintColor

        let searchButton = RoundButton(type: .system)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.font(with: .callout, maxSizeCategory: .extraExtraExtraLarge)
        ]
        searchButton.setAttributedTitle(NSAttributedString(string: L10n.search, attributes: attributes), for: .normal)
        searchButton.addTarget(self, action: #selector(displaySearch), for: .touchUpInside)
        searchButton.setTitleColor(titleColor, for: .normal)
        searchButton.tintColor = tintColor
        searchButton.layer.masksToBounds = true
        searchButton.configuration = configuration
        searchButton.titleLabel?.adjustsFontForContentSizeCategory = false
        return searchButton
    }()

    private lazy var playButton: RoundPlayPauseButton = {
        let playButton = RoundPlayPauseButton.makeButton(playbackManager: playbackManager)
        playButton.addTarget(self, action: #selector(playEpisode), for: .touchUpInside)
        playButton.titleLabel?.adjustsFontForContentSizeCategory = false
        return playButton
    }()

    private lazy var shareButton: RoundButton = {
        let titleColor = showFromEpisode ? ThemeColor.primaryInteractive01() : .white
        let tintColor = showFromEpisode ? ThemeColor.primaryInteractive01().withAlphaComponent(0.1) : .white.withAlphaComponent(0.2)

        var configuration = UIButton.Configuration.filled()
        configuration.contentInsets = .init(top: 4, leading: 12, bottom: 4, trailing: 12)
        configuration.baseForegroundColor = titleColor
        configuration.baseBackgroundColor = tintColor

        let shareButton = RoundButton(type: .system)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.font(with: .callout, maxSizeCategory: .extraExtraExtraLarge)
        ]
        shareButton.setAttributedTitle(NSAttributedString(string: L10n.share, attributes: attributes), for: .normal)
        shareButton.addTarget(self, action: #selector(shareEpisode), for: .touchUpInside)
        shareButton.setTitleColor(titleColor, for: .normal)
        shareButton.tintColor = tintColor
        shareButton.layer.masksToBounds = true
        shareButton.configuration = configuration
        shareButton.titleLabel?.adjustsFontForContentSizeCategory = false
        return shareButton
    }()

    private lazy var hiddenTextView: UITextField = {
        let textView = UITextField()
        textView.layer.opacity = 0
        return textView
    }()

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        return stackView
    }()

    private lazy var topGradient: GradientView = {
        GradientView(firstColor: Colors.gradientColor, secondColor: Colors.gradientColor.withAlphaComponent(0))
    }()

    private lazy var bottomGradient: GradientView = {
        GradientView(firstColor: Colors.gradientColor.withAlphaComponent(0), secondColor: Colors.gradientColor)
    }()

    var bottomContainerInset: CGFloat {
        0.7 * Sizes.bottomGradientHeight
    }

    override func willBeAddedToPlayer() {
        updateColors()
        loadTranscript()
        addObservers()
        transcriptView.delegate = self
    }

    override func willBeRemovedFromPlayer() {
        removeAllCustomObservers()
    }

    override func themeDidChange() {
        updateColors()
    }

    private func updateColors() {
        let primaryColor =  showFromEpisode ? ThemeColor.primaryUi01() : PlayerColorHelper.playerBackgroundColor01()
        let secondaryColor =  showFromEpisode ? ThemeColor.primaryText01() : ThemeColor.playerContrast02()
        let activityIndicatorViewColor: UIColor = showFromEpisode ? ThemeColor.primaryIcon02() : ThemeColor.playerContrast02()
        let activityIndicatorViewStyle: UIScrollView.IndicatorStyle = showFromEpisode ? (Theme.shared.activeTheme.isDark ? .white : .black) : .white

        view.backgroundColor = primaryColor
        transcriptView.backgroundColor =  primaryColor
        transcriptView.textColor = secondaryColor
        transcriptView.indicatorStyle = activityIndicatorViewStyle
        activityIndicatorView.color = activityIndicatorViewColor
        updateGradientColors()
    }

    private func updateGradientColors() {
        let gradientColor = showFromEpisode ? ThemeColor.primaryUi01() : Colors.gradientColor
        topGradient.updateColors(firstColor: gradientColor, secondColor: gradientColor.withAlphaComponent(0))
        bottomGradient.updateColors(firstColor: gradientColor.withAlphaComponent(0), secondColor: gradientColor)
    }

    @objc private func update() {
        updateColors()
        resetKmp()
        resetSearch()
        loadTranscript()
    }

    @objc private func closeTapped() {
        containerDelegate?.dismissTranscript()
    }

    private func setupLoadingState() {
        transcriptView.isHidden = true
        restoreControlButtonsLayout()
        setControlButtonsVisible(false)
        errorView.isHidden = true
        activityIndicatorView.startAnimating()
    }

    private func setupShowTranscriptState() {
        transcriptView.isHidden = false
        setControlButtonsVisible(true)
        errorView.isHidden = true
        activityIndicatorView.stopAnimating()
    }

    private func setControlButtonsVisible(_ visible: Bool) {
        let buttons: [UIButton] = [searchButton, shareButton, playButton]
        buttons.forEach { setControlButton($0, visible: visible) }
    }

    private func setControlButton(_ button: UIButton, visible: Bool) {
        guard !button.isHidden else { return }
        button.alpha = visible ? 1 : 0
        button.isUserInteractionEnabled = visible
    }

    private func restoreControlButtonsLayout() {
        shareButton.isHidden = false
        searchButton.isHidden = false
    }

    private var currentEpisodeUUID: String?

    private func loadTranscript() {
        guard let episodeUUID = playbackManager.episodeUUID,
              let podcastUUID = playbackManager.parentIdentifier else { return }
        let shouldResetPosition = currentEpisodeUUID != episodeUUID
        currentEpisodeUUID = episodeUUID
        let manager = TranscriptManager(episodeUUID: episodeUUID, podcastUUID: podcastUUID)
        transcriptManager = manager
        setupLoadingState()
        Task { [weak self] in
            do {
                let transcript = try await manager.loadTranscript()
                self?.show(transcript: transcript, resetPosition: shouldResetPosition)
            } catch {
                self?.show(error: error)
            }
        }
    }

    private func retryLoad() {
        errorView.isHidden = true
        loadTranscript()
    }

    private func resetSearch() {
        searchIndicesResult = []
        currentSearchIndex = 0
        searchView.textField.text = ""
        searchTerm = nil
        updateNumberOfResults()
        refreshText()
    }

    private func resetKmp() {
        kmpSearch = nil
    }

    private func refreshActionButtons() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.font(with: .callout, maxSizeCategory: .extraExtraExtraLarge)
        ]
        searchButton.setAttributedTitle(NSAttributedString(string: L10n.search, attributes: attributes), for: .normal)
        shareButton.setAttributedTitle(NSAttributedString(string: L10n.share, attributes: attributes), for: .normal)
        playButton.updateSize()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateTextMargins()
    }

    private func updateTextMargins() {
        let readableFrame = view.readableContentGuide.layoutFrame
        guard !readableFrame.isEmpty else { return }
        let leftMargin = readableFrame.minX + Sizes.textMargin
        let rightMargin = view.bounds.maxX - readableFrame.maxX + Sizes.textMargin
        let topInset = 0.75 * Sizes.topGradientHeight
        transcriptView.textContainerInset = .init(top: topInset, left: leftMargin, bottom: bottomContainerInset, right: rightMargin)
    }

    @MainActor
    private func refreshError() {
        errorView.setTextAttributes(makeStyle(alignment: .center))
    }

    @MainActor
    private func refreshText() {
        guard let transcript else {
            return
        }
        transcriptView.attributedText = styleText(transcript: transcript)
    }

    private func show(transcript: TranscriptModel, resetPosition: Bool) {
        setupShowTranscriptState()
        self.transcript = transcript
        transcriptView.attributedText = styleText(transcript: transcript)
        if resetPosition {
            transcriptView.setContentOffset(.zero, animated: false)
        }
    }

    private func makeStyle(alignment: NSTextAlignment = .natural) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.2
        paragraphStyle.paragraphSpacing = 10
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = alignment

        var standardFont = UIFont.preferredFont(forTextStyle: .body)

        if let descriptor = UIFontDescriptor.preferredFontDescriptor(
            withTextStyle: .body)
            .withDesign(.serif) {
            standardFont =  UIFont(descriptor: descriptor, size: 0)
        }

        let normalStyle: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle,
            .font: standardFont,
            .foregroundColor: showFromEpisode ? ThemeColor.primaryText01() : ThemeColor.playerContrast02()
        ]

        return normalStyle
    }

    private func styleText(transcript: TranscriptModel, position: Double = -1) -> NSAttributedString {
        let formattedText = NSMutableAttributedString(attributedString: transcript.attributedText)
        formattedText.beginEditing()
        let normalStyle = makeStyle()
        var highlightStyle = normalStyle
        highlightStyle[.foregroundColor] = showFromEpisode ? ThemeColor.primaryInteractive01() : ThemeColor.playerContrast01()

        let fullLength = NSRange(location: 0, length: formattedText.length)
        formattedText.addAttributes(normalStyle, range: fullLength)

        if position != -1, let range = transcript.firstCue(containing: position)?.characterRange {
            formattedText.addAttributes(highlightStyle, range: range)
        }

        let speakerFont = UIFont.font(ofSize: 12, scalingWith: .footnote)
        formattedText.enumerateAttribute(.transcriptSpeaker, in: fullLength, options: [.reverse, .longestEffectiveRangeNotRequired]) { value, range, _ in
            if value == nil {
                return
            }
            formattedText.addAttribute(.font, value: speakerFont, range: range)
        }

        if let searchTerm {
            let length = formattedText.length
            let searchTermLength = searchTerm.count
            searchIndicesResult.enumerated().forEach { index, indice in
                if indice + searchTermLength <= length {
                    let backgroundColor = showFromEpisode ? ThemeColor.primaryText01().withAlphaComponent(index == currentSearchIndex ? 1 : 0.6) : .white.withAlphaComponent(index == currentSearchIndex ? 1 : 0.4)
                    let highlightStyle: [NSAttributedString.Key: Any] = [
                        .backgroundColor: backgroundColor,
                        .foregroundColor: showFromEpisode ? ThemeColor.primaryUi01() : index == currentSearchIndex ? UIColor.black : ThemeColor.playerContrast01()
                    ]

                    formattedText.addAttributes(highlightStyle, range: NSRange(location: indice, length: searchTermLength))
                }
            }
        }
        formattedText.endEditing()
        return formattedText
    }

    private func show(error: Error) {
        activityIndicatorView.stopAnimating()
        // Collapse the transcript-only controls so the play button sits at the trailing edge.
        shareButton.isHidden = true
        searchButton.isHidden = true
        setControlButton(playButton, visible: true)
        var message = L10n.transcriptErrorFailedToLoad
        if let transcriptError = error as? TranscriptError {
            message = transcriptError.localizedDescription
        }
        errorView.isHidden = false
        errorView.setMessage(message, attributes: makeStyle(alignment: .center))
    }

    private func addObservers() {
        if !showFromEpisode {
            addCustomObserver(Constants.Notifications.playbackTrackChanged, selector: #selector(update))
        }
    }

    // MARK: - Search

    func performSearch(_ term: String) {
        Task {
            findOccurrences(of: term)
            updateNumberOfResults()
            refreshText()
            scrollToFirstResult()
        }
    }

    func findOccurrences(of term: String) {
        guard let transcriptText = transcript?.attributedText.string,
              !term.isEmpty else {
            resetSearch()
            return
        }

        if kmpSearch == nil {
            kmpSearch = KMPSearch(text: transcriptText)
        }
        searchIndicesResult = kmpSearch?.search(for: term) ?? []
        currentSearchIndex = 0
        searchTerm = term
    }

    @MainActor
    func updateNumberOfResults() {
        if searchTerm == nil {
            searchView.updateLabel("")
            searchView.enableUpDownButtons(false)
            return
        }

        if searchIndicesResult.isEmpty {
            searchView.updateLabel("0")
            searchView.enableUpDownButtons(false)
            return
        }

        searchView.enableUpDownButtons(true)
        searchView.updateLabel(L10n.searchResults(currentSearchIndex + 1, searchIndicesResult.count))
    }

    func scrollToFirstResult() {
        guard let searchTerm,
              let firstResultRange = searchIndicesResult.first.map({ NSRange(location: $0, length: searchTerm.count)}) else {
            return
        }
        transcriptView.scrollToRange(firstResultRange)
    }

    // MARK: - Constants

    private enum Sizes {
        static let topGradientHeight: CGFloat = 60
        static let bottomGradientHeight: CGFloat = 60
        static let activityIndicatorSize: CGFloat = 30
        static let textMargin: CGFloat = 8
    }

    private enum Colors {
        static var gradientColor: UIColor {
            PlayerColorHelper.playerBackgroundColor01()
        }
    }
}

extension TranscriptViewController: UIScrollViewDelegate {

    // Only allow scroll to dismiss if scrolling bottom from the top
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if canScrollToDismiss {
            scrollViewHandler?.scrollViewDidScroll?(scrollView)
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        canScrollToDismiss = scrollView.contentOffset.y == 0
    }
}

extension TranscriptViewController: UITextViewDelegate {
}

extension TranscriptViewController: TranscriptSearchAccessoryViewDelegate {
    func doneTapped() {
        dismissSearch()
        resetSearch()
        searchView.removeFromSuperview()
    }

    func searchButtonTapped() {
        becomeFirstResponder()
    }

    func search(_ term: String) {
        if term.isEmpty {
            debounce.cancel()
            resetSearch()
            return
        }

        debounce.call { [weak self] in
            self?.performSearch(term)
        }
    }

    func previousMatch() {
        updateCurrentSearchIndex(decrement: true)
        processMatch()
    }

    func nextMatch() {
        updateCurrentSearchIndex(decrement: false)
        processMatch()
    }

    private func updateCurrentSearchIndex(decrement: Bool) {
        if decrement {
            currentSearchIndex = (currentSearchIndex - 1 < 0) ? searchIndicesResult.count - 1 : currentSearchIndex - 1
        } else {
            currentSearchIndex = (currentSearchIndex + 1 >= searchIndicesResult.count) ? 0 : currentSearchIndex + 1
        }
    }

    private func processMatch() {
        if searchIndicesResult.isEmpty {
            return
        }

        updateNumberOfResults()
        refreshText()
        transcriptView.scrollToRange(.init(location: searchIndicesResult[currentSearchIndex], length: searchTerm?.count ?? 0))
    }
}

class RoundButton: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = bounds.height / 2
    }
}

fileprivate class RoundPlayPauseButton: RoundButton {
    private var cancellables = Set<AnyCancellable>()
    private var playbackManager: TranscriptPlaybackManaging?

    enum ButtonState {
        case play
        case pause

        var imageName: String {
            switch self {
            case .play:
                return "play.fill"
            case .pause:
                return "pause.fill"
            }
        }

        var buttonTitle: String {
            switch self {
            case .play:
                return L10n.play
            case .pause:
                return L10n.pause
            }
        }
    }

    var buttonState: ButtonState = .play {
        didSet {
            let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            let image = UIImage(systemName: buttonState.imageName, withConfiguration: config)?
                .withRenderingMode(.alwaysTemplate)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.font(with: .callout, maxSizeCategory: .extraExtraExtraLarge)
            ]
            setAttributedTitle(NSAttributedString(string: buttonState.buttonTitle, attributes: attributes), for: .normal)
            setImage(image, for: .normal)
        }
    }

    func updateSize() {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.font(with: .callout, maxSizeCategory: .extraExtraExtraLarge)
        ]
        setAttributedTitle(NSAttributedString(string: buttonState.buttonTitle, attributes: attributes), for: .normal)
    }

    static func makeButton(playbackManager: TranscriptPlaybackManaging) -> RoundPlayPauseButton {
        let titleColor = ThemeColor.primaryInteractive01()
        let tintColor = ThemeColor.primaryInteractive01().withAlphaComponent(0.1)

        var  bg = UIBackgroundConfiguration.clear()
        bg.backgroundColor = tintColor
        var configuration = UIButton.Configuration.filled()
        configuration.contentInsets = .init(top: 4, leading: 12, bottom: 4, trailing: 12)
        configuration.imagePadding = 8.0
        configuration.background = bg
        configuration.baseForegroundColor = ThemeColor.primaryInteractive01()

        let playButton = RoundPlayPauseButton(type: .system)
        playButton.playbackManager = playbackManager
        playButton.buttonState = playbackManager.isPlayingEpisode ? .pause : .play
        playButton.setupObservers()
        playButton.setTitleColor(titleColor, for: .normal)
        playButton.tintColor = tintColor
        playButton.layer.masksToBounds = true
        playButton.configuration = configuration
        return playButton
    }

    func setupObservers() {
        Publishers.Merge3(
            NotificationCenter.default.publisher(for: Constants.Notifications.playbackStarted),
            NotificationCenter.default.publisher(for: Constants.Notifications.playbackPaused),
            NotificationCenter.default.publisher(for: Constants.Notifications.playbackEnded)
        )
        .receive(on: RunLoop.main)
        .sink { [unowned self] _ in
            self.updatePlayingState()
        }
        .store(in: &cancellables)
    }

    private func updatePlayingState() {
        buttonState = playbackManager?.isPlayingEpisode == true ? .pause : .play
    }
}
