import PocketCastsDataModel
import PocketCastsUtils
import UIKit

class AddCustomViewController: PCViewController, UITextFieldDelegate {
    private let fileUrl: URL
    private let uuid: String
    private let episodeToEdit: UserEpisode?
    private var destinationUrl: URL?
    private var duration: TimeInterval = 0
    private var artwork: UIImage?
    private var avFileUtil: AVFileUtil?
    private let nameTextfield = UITextField()

    init(fileUrl: URL) {
        self.fileUrl = fileUrl
        uuid = UUID().uuidString.lowercased()
        episodeToEdit = nil
        super.init(nibName: nil, bundle: nil)
    }

    init(episode: UserEpisode) {
        fileUrl = URL(fileURLWithPath: DownloadManager.shared.path(for: episode))
        uuid = episode.uuid
        episodeToEdit = episode
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        view = UIView()
        view.backgroundColor = AppTheme.colorForStyle(.primaryUi01)
        nameTextfield.borderStyle = .roundedRect
        nameTextfield.returnKeyType = .done
        nameTextfield.delegate = self
        nameTextfield.accessibilityLabel = L10n.fileUploadNameRequired
        nameTextfield.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nameTextfield)
        NSLayoutConstraint.activate([
            nameTextfield.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            nameTextfield.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            nameTextfield.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            nameTextfield.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = episodeToEdit == nil ? L10n.fileUploadAddFile : L10n.fileUploadEditFile
        nameTextfield.text = episodeToEdit?.title ?? fileUrl.deletingPathExtension().lastPathComponent
        nameTextfield.addTarget(self, action: #selector(nameChanged), for: .editingChanged)
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        customRightBtn = UIBarButtonItem(title: L10n.fileUploadSave, style: .plain, target: self, action: #selector(saveTapped))
        guard episodeToEdit == nil else { return }
        do {
            let destination = try DownloadManager.shared.addLocalFile(url: fileUrl, uuid: uuid)
            destinationUrl = destination
            avFileUtil = AVFileUtil(fileURL: destination, durationHandler: { [weak self] duration in
                DispatchQueue.main.async { self?.duration = duration }
            }, titleHandler: { _ in }, artworkHandler: { [weak self] image in
                DispatchQueue.main.async { self?.artwork = image }
            })
        } catch {
            customRightBtn?.isEnabled = false
            showError(error)
        }
    }

    @objc private func nameChanged() {
        customRightBtn?.isEnabled = !(nameTextfield.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @objc private func saveTapped() {
        guard let name = nameTextfield.text, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let episode = episodeToEdit {
            UserEpisodeManager.updateUserEpisode(uuid: uuid, title: name, color: Int(episode.imageColor))
            navigationController?.popViewController(animated: true)
        } else if let destinationUrl {
            do {
                let size = try destinationUrl.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                _ = try UserEpisodeManager.addUserEpisode(uuid: uuid, title: name, localFileUrl: destinationUrl, artwork: artwork, color: 1, fileSize: size, duration: duration)
                dismiss(animated: true)
            } catch { showError(error) }
        }
    }

    @objc func cancelTapped() {
        if episodeToEdit == nil {
            if let destinationUrl { StorageManager.removeItem(at: destinationUrl) }
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    private func showError(_ error: Error) {
        SJUIUtils.showAlert(title: L10n.fileUploadAddFile, message: error.localizedDescription, from: self)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
