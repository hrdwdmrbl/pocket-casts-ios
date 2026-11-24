import Foundation
import SwiftUI

class ImportHostingController<Content>: PCHostingController<Content> where Content: View {
    var viewModel: ImportViewModel?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let viewModel else { return }

        if navigationController?.viewControllers.first == self {
            let dismissItem = UIBarButtonItem(title: L10n.accessibilityDismiss, style: .plain, target: viewModel, action: #selector(viewModel.dismissTapped))
            dismissItem.setTitleTextAttributes([NSAttributedString.Key.font: UIFont.font(with: .body, weight: .medium),
                                                NSAttributedString.Key.foregroundColor: ThemeColor.primaryIcon01()], for: .normal)
            navigationItem.rightBarButtonItem = dismissItem
        }

        navigationController?.navigationBar.isHidden = false
    }
}
