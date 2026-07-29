import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AccountContext
import DemoStudioCore

class DemoStudioTableController: ViewController, UITableViewDataSource, UITableViewDelegate {
    let context: AccountContext
    let tableView: UITableView
    var presentationData: PresentationData
    private var tableNode: ASDisplayNode?

    init(context: AccountContext, title: String, style: UITableView.Style = .insetGrouped) {
        self.context = context
        self.tableView = UITableView(frame: .zero, style: style)
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }

        super.init(
            navigationBarPresentationData: NavigationBarPresentationData(
                presentationData: self.presentationData,
                style: .glass
            )
        )

        self._hasGlassStyle = true
        self.title = title
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationItem.backBarButtonItem = UIBarButtonItem(
            title: self.presentationData.strings.Common_Back,
            style: .plain,
            target: nil,
            action: nil
        )
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadDisplayNode() {
        let rootNode = ASDisplayNode()
        rootNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor

        let tableView = self.tableView
        let tableNode = ASDisplayNode(viewBlock: {
            return tableView
        })
        self.tableNode = tableNode
        rootNode.addSubnode(tableNode)
        self.displayNode = rootNode

        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.keyboardDismissMode = .interactive
        self.tableView.contentInsetAdjustmentBehavior = .never
        if #available(iOS 13.0, *) {
            self.tableView.automaticallyAdjustsScrollIndicatorInsets = false
        }
        self.tableView.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor
        self.tableView.separatorColor = self.presentationData.theme.list.itemBlocksSeparatorColor
        self.tableView.tintColor = self.presentationData.theme.list.itemAccentColor

        self.scrollToTop = { [weak tableView] in
            tableView?.setContentOffset(.zero, animated: true)
        }
    }

    override func containerLayoutUpdated(
        _ layout: ContainerViewLayout,
        transition: ContainedViewLayoutTransition
    ) {
        super.containerLayoutUpdated(layout, transition: transition)

        let navigationHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
        let tableFrame = CGRect(
            x: 0.0,
            y: navigationHeight,
            width: layout.size.width,
            height: max(0.0, layout.size.height - navigationHeight)
        )
        if let tableNode = self.tableNode {
            transition.updateFrame(node: tableNode, frame: tableFrame)
        }

        let bottomInset = layout.insets(options: [.input]).bottom
        if self.tableView.contentInset.bottom != bottomInset {
            self.tableView.contentInset.bottom = bottomInset
            self.tableView.verticalScrollIndicatorInsets.bottom = bottomInset
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return nil
    }

    func tableView(
        _ tableView: UITableView,
        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        return nil
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        return nil
    }

    func configuredCell(
        title: String,
        subtitle: String? = nil,
        detail: String? = nil,
        symbol: String? = nil,
        color: UIColor? = nil,
        accessory: UITableViewCell.AccessoryType = .disclosureIndicator
    ) -> UITableViewCell {
        let cell = UITableViewCell(style: subtitle == nil ? .value1 : .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
        cell.textLabel?.text = title
        cell.textLabel?.textColor = self.presentationData.theme.list.itemPrimaryTextColor
        cell.detailTextLabel?.text = subtitle ?? detail
        cell.detailTextLabel?.textColor = self.presentationData.theme.list.itemSecondaryTextColor
        cell.accessoryType = accessory
        if let symbol {
            let image = UIImage(systemName: symbol)
            cell.imageView?.image = image
            cell.imageView?.tintColor = color ?? self.presentationData.theme.list.itemAccentColor
        }
        return cell
    }

    func presentTextPrompt(
        title: String,
        message: String? = nil,
        placeholder: String? = nil,
        initialValue: String = "",
        keyboardType: UIKeyboardType = .default,
        actionTitle: String = "Готово",
        completion: @escaping (String) -> Void
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = placeholder
            field.text = initialValue
            field.keyboardType = keyboardType
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: actionTitle, style: .default, handler: { [weak alert] _ in
            completion(alert?.textFields?.first?.text ?? "")
        }))
        self.present(alert, animated: true)
    }

    func presentConfirmation(
        title: String,
        message: String? = nil,
        destructiveTitle: String,
        completion: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: destructiveTitle, style: .destructive, handler: { _ in
            completion()
        }))
        alert.popoverPresentationController?.sourceView = self.view
        alert.popoverPresentationController?.sourceRect = CGRect(
            x: self.view.bounds.midX,
            y: self.view.bounds.maxY,
            width: 1.0,
            height: 1.0
        )
        self.present(alert, animated: true)
    }
}

final class DemoStudioAvatarView: UIView {
    private let imageView = UIImageView()
    private let initialsLabel = UILabel()

    init(profile: DemoProfile, size: CGFloat) {
        super.init(frame: .zero)

        self.translatesAutoresizingMaskIntoConstraints = false
        self.widthAnchor.constraint(equalToConstant: size).isActive = true
        self.heightAnchor.constraint(equalToConstant: size).isActive = true
        self.layer.cornerRadius = size * 0.5
        self.clipsToBounds = true
        self.backgroundColor = DemoStudioColors.avatarColor(seed: profile.displayName)

        self.imageView.contentMode = .scaleAspectFill
        self.imageView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.imageView)

        self.initialsLabel.text = DemoStudioColors.initials(profile.displayName)
        self.initialsLabel.textColor = .white
        self.initialsLabel.font = UIFont.systemFont(ofSize: size * 0.34, weight: .semibold)
        self.initialsLabel.textAlignment = .center
        self.initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.initialsLabel)

        if let url = DemoStudioStore.shared.assetURL(fileName: profile.avatarFileName),
           let image = UIImage(contentsOfFile: url.path) {
            self.imageView.image = image
            self.initialsLabel.isHidden = true
        }

        NSLayoutConstraint.activate([
            self.imageView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.imageView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.imageView.topAnchor.constraint(equalTo: self.topAnchor),
            self.imageView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.initialsLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.initialsLabel.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.initialsLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

enum DemoStudioColors {
    static func avatarColor(seed: String) -> UIColor {
        let palette: [UIColor] = [
            UIColor(red: 0.20, green: 0.55, blue: 0.96, alpha: 1.0),
            UIColor(red: 0.52, green: 0.36, blue: 0.95, alpha: 1.0),
            UIColor(red: 0.96, green: 0.35, blue: 0.45, alpha: 1.0),
            UIColor(red: 0.15, green: 0.72, blue: 0.55, alpha: 1.0),
            UIColor(red: 0.95, green: 0.58, blue: 0.20, alpha: 1.0)
        ]
        let value = seed.unicodeScalars.reduce(0) { partial, scalar in
            return (partial &* 31 &+ Int(scalar.value)) & 0x7fffffff
        }
        return palette[value % palette.count]
    }

    static func initials(_ name: String) -> String {
        let words = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
        let value = String(words)
        return value.isEmpty ? "?" : value.uppercased()
    }

    static func image(symbol: String, background: UIColor) -> UIImage? {
        let size = CGSize(width: 30.0, height: 30.0)
        return UIGraphicsImageRenderer(size: size).image { _ in
            background.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 7.0).fill()
            guard let symbolImage = UIImage(systemName: symbol)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) else {
                return
            }
            let target = CGRect(
                x: (size.width - 18.0) * 0.5,
                y: (size.height - 18.0) * 0.5,
                width: 18.0,
                height: 18.0
            )
            symbolImage.draw(in: target)
        }
    }
}
