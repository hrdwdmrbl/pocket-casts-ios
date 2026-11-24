import SwiftUI
import PocketCastsDataModel
import Combine
import PocketCastsUtils
import CoreMedia
import UniformTypeIdentifiers

enum ShareDestination: Hashable {
    case instagram
    case copyLink
    case systemSheet(vc: UIViewController)

    var name: String {
        switch self {
        case .instagram:
            L10n.shareInstagramStories
        case .copyLink:
            L10n.shareCopyLink
        case .systemSheet:
            L10n.shareMoreActions
        }
    }

    var icon: Image {
        switch self {
        case .instagram:
            Image("instagram")
        case .copyLink:
            Image(systemName: "link")
        case .systemSheet:
            Image(systemName: "ellipsis")
        }
    }

    enum ShareError: Error {
        case noMatchingItemIdentifier
    }

    @MainActor
    func share(_ option: SharingModal.Option,
               style: ShareImageStyle,
               clipTime: ClipTime,
               clipUUID: String,
               progress: Binding<Float?>,
               presentFrom rect: CurrentValueSubject<CGRect, Never>) async throws {
        let url = try await option.shareURL
        switch self {
        case .instagram:
            let item = try await option.shareData(url: url, style: style, destination: self, clipUUID: clipUUID, progress: progress).mapFirst { shareItem -> (Data, UTType)? in
                if let data = shareItem.item as? Data {
                    return (data, .mpeg4Movie)
                } else if let image = shareItem.item as? UIImage, let data = image.pngData() {
                    return (data, .png)
                } else {
                    return nil
                }
            }

            guard let item else {
                throw ShareError.noMatchingItemIdentifier
            }

            instagramShare(data: item.0, type: item.1, url: url.absoluteString)
        case .copyLink:
            UIPasteboard.general.string = url.absoluteString
            Toast.show(L10n.shareCopiedToClipboard)
        case .systemSheet(let vc):
            let data = try await option.shareData(url: url, style: style, destination: self, clipUUID: clipUUID, progress: progress)
            let activityViewController = UIActivityViewController(activityItems: data, applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = vc.view
            activityViewController.popoverPresentationController?.sourceRect = rect.value
            let receiver = rect.sink { rect in
                activityViewController.popoverPresentationController?.sourceRect = rect
            }
            activityViewController.completionWithItemsHandler = { _, _, _, _ in
                receiver.cancel()
            }
            vc.presentedViewController?.present(activityViewController, animated: true, completion: {
            })
        }
    }

    @MainActor
    private func instagramShare(data: Data, type: UTType, url: String) {
        let attributionURL = url
        let appID = ApiCredentials.instagramAppID

        guard let urlScheme = URL(string: "instagram-stories://share?source_application=\(appID)"),
              UIApplication.shared.canOpenURL(urlScheme) else {
            return
        }

        let backgroundTopColor = UIColor.green
        let backgroundBottomColor = UIColor.systemPink

        let dataKey = type == .mpeg4Movie ? "com.instagram.sharedSticker.backgroundVideo" : "com.instagram.sharedSticker.backgroundImage"
        let pasteboardItems = [[dataKey: data,
                                "com.instagram.sharedSticker.backgroundTopColor": backgroundTopColor.hexString(),
                                "com.instagram.sharedSticker.backgroundBottomColor": backgroundBottomColor.hexString(),
                                "com.instagram.sharedSticker.contentURL": attributionURL]]
        let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [.expirationDate: Date().addingTimeInterval(5.minutes)]

        UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)

        UIApplication.shared.open(urlScheme)
    }

    var isIncluded: Bool {
        switch self {
        case .instagram:
            if let url = URL(string: "instagram-stories://share"), UIApplication.shared.canOpenURL(url) {
                true
            } else {
                false
            }
        default:
            true
        }
    }

    enum Constants {
        static let displayedAppsCount = 3
    }

    static func ==(lhs: ShareDestination, rhs: ShareDestination) -> Bool {
        lhs.name == rhs.name && lhs.icon == rhs.icon
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    static var displayedApps: Array<ShareDestination>.SubSequence {
        apps.prefix(Constants.displayedAppsCount)
    }

    private static var apps: [Self] {
        let thirdPartyApps: [Self] = [.instagram]
        return thirdPartyApps.compactMap({ destination -> Self? in
            guard destination.isIncluded else { return nil }
            return destination
        })
    }
}

extension ShareDestination {
    enum VideoExportError: Error {
        case failedToDownload
    }

    func export(info: ShareImageInfo, style: ShareImageStyle, episode: some BaseEpisode, startTime: CMTime, duration: CMTime, scale: CGFloat, progress: Progress, to url: URL) async throws -> URL {
        guard let playerItem = DownloadManager.shared.downloadParallelToStream(of: episode) else {
            throw VideoExportError.failedToDownload
        }

        func exportVideo() async throws -> URL {
            let size: CGSize
            switch self {
            case .instagram:
                size = CGSize(width: style.videoSize.width, height: style.videoSize.height)
            default:
                size = CGSize(width: style.previewSize.width, height: style.previewSize.height)
            }

            let parameters = await VideoExporter.Parameters(duration: CMTimeGetSeconds(duration), size: size, scale: scale, episodeAsset: playerItem.asset, audioStartTime: startTime, audioDuration: duration, fileType: .mp4)
            try await VideoExporter.export(view: AnimatedShareImageView(info: info, style: style, size: size), with: parameters, to: url, progress: progress)

            return url
        }

        switch style {
        case .audio:
            switch self {
            case .instagram:
                // Instagram will not accept a straight m4a file for sharing so we need to generate a video clip to share
                return try await exportVideo()
            default:
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("audio_export-\(UUID().uuidString)", conformingTo: .m4a)
                try await AudioClipExporter.exportAudioClip(from: playerItem.asset, startTime: startTime, duration: duration, to: url, progress: progress)
                return url
            }
        default:
            return try await exportVideo()
        }
    }
}
