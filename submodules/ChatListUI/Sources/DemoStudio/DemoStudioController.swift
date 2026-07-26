import Foundation
import UIKit
import Display
import AccountContext
import DemoStudioCore

public func demoStudioController(context: AccountContext) -> ViewController {
    return DemoStudioController(context: context)
}

public func activateDemoStudio(accountPeerId: Int64) {
    DemoStudioStore.shared.activate(scope: String(accountPeerId))
}

public struct DemoOwnerProfilePresentation {
    public let firstName: String
    public let lastName: String
    public let username: String
    public let phone: String
    public let bio: String
    public let avatarPath: String?

    public var displayName: String {
        return "\(self.firstName) \(self.lastName)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Returns only a visual override. Callers must never write these values to
/// TelegramCore, Postbox or a network request.
public func demoOwnerProfilePresentation() -> DemoOwnerProfilePresentation? {
    let value = DemoStudioStore.shared.document.ownerProfile
    guard value.isEnabled else {
        return nil
    }
    return DemoOwnerProfilePresentation(
        firstName: value.firstName,
        lastName: value.lastName,
        username: value.username,
        phone: value.phone,
        bio: value.bio,
        avatarPath: DemoStudioStore.shared.assetURL(fileName: value.avatarFileName)?.path
    )
}

final class DemoStudioController: DemoStudioTableController {
    private enum Section: Int, CaseIterable {
        case notice
        case content
        case economy
        case owner
        case maintenance
    }

    private let store = DemoStudioStore.shared
    private var observer: NSObjectProtocol?

    init(context: AccountContext) {
        self.store.activate(scope: String(context.account.peerId.toInt64()))
        super.init(context: context, title: "Demo Studio")
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func loadDisplayNode() {
        super.loadDisplayNode()
        self.observer = NotificationCenter.default.addObserver(
            forName: .demoStudioDidChange,
            object: self.store,
            queue: .main
        ) { [weak self] _ in
            self?.tableView.reloadData()
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else {
            return 0
        }
        switch section {
        case .notice:
            return 1
        case .content:
            return 2
        case .economy:
            return 2
        case .owner:
            return 1
        case .maintenance:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else {
            return nil
        }
        switch section {
        case .notice:
            return nil
        case .content:
            return "Локальные профили и переписки"
        case .economy:
            return "Звёзды и подарки"
        case .owner:
            return "Мой профиль"
        case .maintenance:
            return "Хранилище"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let document = self.store.document
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch section {
        case .notice:
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
            cell.textLabel?.text = "Только локально"
            cell.textLabel?.textColor = self.presentationData.theme.list.itemAccentColor
            cell.textLabel?.font = UIFont.systemFont(ofSize: 16.0, weight: .semibold)
            cell.detailTextLabel?.text = "Демо-профили, сообщения, звёзды и подарки сохраняются отдельно и никогда не отправляются в Telegram."
            cell.detailTextLabel?.numberOfLines = 0
            cell.detailTextLabel?.textColor = self.presentationData.theme.list.itemSecondaryTextColor
            cell.selectionStyle = .none
            cell.imageView?.image = UIImage(systemName: "lock.shield")
            cell.imageView?.tintColor = self.presentationData.theme.list.itemAccentColor
            return cell
        case .content:
            if indexPath.row == 0 {
                return self.configuredCell(
                    title: "Профили собеседников",
                    detail: "\(document.profiles.count)",
                    symbol: "person.crop.circle.badge.plus",
                    color: .systemPurple
                )
            } else {
                return self.configuredCell(
                    title: "Локальные чаты",
                    detail: "\(document.chats.count)",
                    symbol: "bubble.left.and.bubble.right.fill",
                    color: .systemBlue
                )
            }
        case .economy:
            if indexPath.row == 0 {
                return self.configuredCell(
                    title: "Баланс и история Stars",
                    detail: "⭐️ \(document.starsBalance)",
                    symbol: "star.fill",
                    color: .systemOrange
                )
            } else {
                let giftCount = document.profiles.reduce(0) { $0 + $1.gifts.count } + document.ownerProfile.gifts.count
                return self.configuredCell(
                    title: "Локальные подарки",
                    detail: "\(giftCount)",
                    symbol: "gift.fill",
                    color: .systemPink
                )
            }
        case .owner:
            return self.configuredCell(
                title: "Визуальный профиль и номер",
                subtitle: document.ownerProfile.isEnabled ? "Локальная подмена включена" : "Используется настоящий профиль",
                symbol: "person.crop.circle.fill",
                color: .systemRed
            )
        case .maintenance:
            let cell = self.configuredCell(
                title: "Удалить все демо-данные",
                symbol: "trash.fill",
                color: .systemRed,
                accessory: .none
            )
            cell.textLabel?.textColor = self.presentationData.theme.list.itemDestructiveColor
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else {
            return
        }
        switch section {
        case .notice:
            break
        case .content:
            if indexPath.row == 0 {
                self.push(DemoProfilesController(context: self.context))
            } else {
                self.push(DemoChatsController(context: self.context))
            }
        case .economy:
            if indexPath.row == 0 {
                self.push(DemoStarsController(context: self.context))
            } else {
                self.push(DemoGiftsController(context: self.context))
            }
        case .owner:
            self.push(DemoOwnerProfileController(context: self.context))
        case .maintenance:
            self.presentConfirmation(
                title: "Удалить все демо-данные?",
                message: "Настоящий аккаунт Telegram и его переписки не изменятся.",
                destructiveTitle: "Удалить"
            ) { [weak self] in
                self?.store.reset()
            }
        }
    }
}
