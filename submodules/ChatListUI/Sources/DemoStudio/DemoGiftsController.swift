import Foundation
import UIKit
import AccountContext
import DemoStudioCore

final class DemoGiftsController: DemoStudioTableController {
    private enum Section: Int, CaseIterable {
        case instructions
        case gifts
    }

    private let store = DemoStudioStore.shared
    private var observer: NSObjectProtocol?

    init(context: AccountContext) {
        super.init(context: context, title: "Подарки")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Добавить",
            style: .plain,
            target: self,
            action: #selector(self.addManualGift)
        )
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

    private var gifts: [DemoGift] {
        return self.store.document.ownerProfile.gifts.sorted { $0.receivedAt > $1.receivedAt }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else {
            return 0
        }
        return section == .instructions ? 1 : max(1, self.gifts.count)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == Section.gifts.rawValue ? "В моём профиле" : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        if section == .instructions {
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
            cell.textLabel?.text = "Как добавить настоящий Telegram Gift"
            cell.textLabel?.textColor = self.presentationData.theme.list.itemAccentColor
            cell.textLabel?.font = UIFont.systemFont(ofSize: 16.0, weight: .semibold)
            cell.detailTextLabel?.text = "Откройте любой уникальный подарок в Telegram, нажмите ⋯ → «ДЕМО: Подарил мне» и выберите собеседника."
            cell.detailTextLabel?.numberOfLines = 0
            cell.detailTextLabel?.textColor = self.presentationData.theme.list.itemSecondaryTextColor
            cell.imageView?.image = UIImage(systemName: "gift.fill")
            cell.imageView?.tintColor = .systemPink
            cell.selectionStyle = .none
            return cell
        }
        let gifts = self.gifts
        if gifts.isEmpty {
            let cell = self.configuredCell(
                title: "Подарков пока нет",
                subtitle: "Добавьте вручную или через меню подарка",
                symbol: "gift",
                color: .systemPink,
                accessory: .none
            )
            cell.selectionStyle = .none
            return cell
        }
        guard indexPath.row < gifts.count else {
            return UITableViewCell()
        }
        let gift = gifts[indexPath.row]
        let senderName = self.store.document.profiles
            .first(where: { $0.id == gift.senderProfileId })?
            .displayName ?? "Неизвестный пользователь"
        return self.configuredCell(
            title: gift.title,
            subtitle: "Подарил: \(senderName) • скрыт",
            symbol: "gift.fill",
            color: .systemPink,
            accessory: .none
        )
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard indexPath.section == Section.gifts.rawValue else {
            return nil
        }
        let gifts = self.gifts
        guard indexPath.row < gifts.count else {
            return nil
        }
        let gift = gifts[indexPath.row]
        return UISwipeActionsConfiguration(actions: [
            UIContextualAction(style: .destructive, title: "Удалить", handler: { [weak self] _, _, completion in
                self?.store.update { document in
                    document.ownerProfile.gifts.removeAll(where: { $0.id == gift.id })
                }
                completion(true)
            })
        ])
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == Section.gifts.rawValue else {
            return
        }
        let gifts = self.gifts
        guard indexPath.row < gifts.count else {
            return
        }
        let gift = gifts[indexPath.row]
        let sheet = UIAlertController(title: gift.title, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Изменить", style: .default, handler: { [weak self] _ in
            self?.editGift(gift)
        }))
        sheet.addAction(UIAlertAction(title: "Удалить", style: .destructive, handler: { [weak self] _ in
            self?.store.update { document in
                document.ownerProfile.gifts.removeAll(where: { $0.id == gift.id })
            }
        }))
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        sheet.popoverPresentationController?.sourceView = self.view
        sheet.popoverPresentationController?.sourceRect = tableView.rectForRow(at: indexPath)
        self.present(sheet, animated: true)
    }

    @objc private func addManualGift() {
        self.presentTextPrompt(
            title: "Название подарка",
            placeholder: "Plush Pepe",
            actionTitle: "Дальше"
        ) { [weak self] title in
            self?.presentTextPrompt(
                title: "Slug",
                placeholder: "PlushPepe-1234",
                actionTitle: "Дальше"
            ) { [weak self] slug in
                self?.selectSender(title: title, slug: slug)
            }
        }
    }

    private func selectSender(title: String, slug: String) {
        let profiles = self.store.document.profiles
        guard !profiles.isEmpty else {
            let alert = UIAlertController(
                title: "Нет профилей",
                message: "Сначала создайте собеседника.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
            return
        }
        let sheet = UIAlertController(title: "Кто подарил?", message: nil, preferredStyle: .actionSheet)
        for profile in profiles {
            sheet.addAction(UIAlertAction(title: profile.displayName, style: .default, handler: { [weak self] _ in
                self?.storeGift(
                    DemoGift(
                        slug: slug.isEmpty ? nil : slug,
                        title: title.isEmpty ? "Telegram Gift" : title,
                        senderProfileId: profile.id,
                        displayedOnProfile: false
                    ),
                    sender: profile
                )
            }))
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
        self.present(sheet, animated: true)
    }

    private func editGift(_ gift: DemoGift) {
        self.presentTextPrompt(
            title: "Название подарка",
            initialValue: gift.title,
            actionTitle: "Дальше"
        ) { [weak self] title in
            self?.presentTextPrompt(
                title: "Slug",
                initialValue: gift.slug ?? "",
                actionTitle: "Сохранить"
            ) { [weak self] slug in
                self?.store.update { document in
                    guard let index = document.ownerProfile.gifts.firstIndex(where: { $0.id == gift.id }) else {
                        return
                    }
                    document.ownerProfile.gifts[index].title = title
                    document.ownerProfile.gifts[index].slug = slug.isEmpty ? nil : slug
                }
            }
        }
    }

    private func storeGift(_ gift: DemoGift, sender: DemoProfile) {
        self.store.update { document in
            document.ownerProfile.gifts.append(gift)
            let chatIndex: Int
            if let current = document.chats.firstIndex(where: { $0.profileId == sender.id }) {
                chatIndex = current
            } else {
                document.chats.append(DemoChat(profileId: sender.id))
                chatIndex = document.chats.count - 1
            }
            document.chats[chatIndex].messages.append(DemoMessage(
                author: .profile,
                text: "Подарил(а) вам подарок",
                gift: gift
            ))
            document.chats[chatIndex].unreadCount += 1
            document.chats[chatIndex].updatedAt = Date()
        }
    }
}
