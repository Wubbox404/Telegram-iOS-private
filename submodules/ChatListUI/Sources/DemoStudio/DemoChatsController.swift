import Foundation
import UIKit
import AccountContext
import DemoStudioCore

final class DemoChatsController: DemoStudioTableController {
    private let store = DemoStudioStore.shared
    private var observer: NSObjectProtocol?

    init(context: AccountContext) {
        super.init(context: context, title: "Локальные чаты", style: .plain)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(self.createChat)
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
        self.tableView.rowHeight = 76.0
        self.observer = NotificationCenter.default.addObserver(
            forName: .demoStudioDidChange,
            object: self.store,
            queue: .main
        ) { [weak self] _ in
            self?.tableView.reloadData()
        }
    }

    private var chats: [(DemoChat, DemoProfile)] {
        let document = self.store.document
        let profiles = Dictionary(uniqueKeysWithValues: document.profiles.map { ($0.id, $0) })
        return document.chats.compactMap { chat in
            profiles[chat.profileId].map { (chat, $0) }
        }.sorted { lhs, rhs in
            if lhs.0.isPinned != rhs.0.isPinned {
                return lhs.0.isPinned
            }
            return lhs.0.updatedAt > rhs.0.updatedAt
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.chats.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let chats = self.chats
        guard indexPath.row < chats.count else {
            return UITableViewCell()
        }
        let (chat, profile) = chats[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = self.presentationData.theme.chatList.itemBackgroundColor
        let stateSuffix = "\(chat.isPinned ? " 📌" : "")\(chat.isMuted ? " 🔕" : "")"
        cell.textLabel?.text = "\(profile.displayName)\(profile.isPremium ? " \(profile.premiumEmoji)" : "")\(stateSuffix)"
        cell.textLabel?.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        cell.textLabel?.textColor = self.presentationData.theme.list.itemPrimaryTextColor
        cell.detailTextLabel?.text = self.subtitle(chat: chat)
        cell.detailTextLabel?.textColor = self.presentationData.theme.list.itemSecondaryTextColor
        cell.imageView?.image = DemoStudioColors.image(
            symbol: "person.fill",
            background: DemoStudioColors.avatarColor(seed: profile.displayName)
        )
        cell.accessoryType = .disclosureIndicator
        if chat.unreadCount > 0 {
            let badge = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: 34.0, height: 24.0))
            badge.text = "\(chat.unreadCount)"
            badge.textColor = .white
            badge.backgroundColor = self.presentationData.theme.chatList.unreadBadgeActiveBackgroundColor
            badge.font = UIFont.systemFont(ofSize: 14.0, weight: .semibold)
            badge.textAlignment = .center
            badge.layer.cornerRadius = 12.0
            badge.clipsToBounds = true
            cell.accessoryView = badge
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let chats = self.chats
        guard indexPath.row < chats.count else {
            return
        }
        self.push(DemoChatController(context: self.context, chatId: chats[indexPath.row].0.id))
    }

    override func tableView(
        _ tableView: UITableView,
        leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let chats = self.chats
        guard indexPath.row < chats.count else {
            return nil
        }
        let chat = chats[indexPath.row].0
        let pin = UIContextualAction(
            style: .normal,
            title: chat.isPinned ? "Открепить" : "Закрепить"
        ) { [weak self] _, _, completion in
            self?.store.updateChat(id: chat.id) { value in
                value.isPinned.toggle()
            }
            completion(true)
        }
        pin.backgroundColor = .systemOrange
        let read = UIContextualAction(style: .normal, title: "Прочитано") { [weak self] _, _, completion in
            self?.store.markChatRead(id: chat.id)
            completion(true)
        }
        read.backgroundColor = .systemBlue
        return UISwipeActionsConfiguration(actions: [pin, read])
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let chats = self.chats
        guard indexPath.row < chats.count else {
            return nil
        }
        let chat = chats[indexPath.row].0
        let mute = UIContextualAction(style: .normal, title: chat.isMuted ? "Со звуком" : "Без звука") { [weak self] _, _, completion in
            self?.store.updateChat(id: chat.id) { value in
                value.isMuted.toggle()
            }
            completion(true)
        }
        mute.backgroundColor = .systemPurple
        let archive = UIContextualAction(style: .normal, title: chat.isArchived ? "Вернуть" : "Архив") { [weak self] _, _, completion in
            self?.store.updateChat(id: chat.id) { value in
                value.isArchived.toggle()
            }
            completion(true)
        }
        archive.backgroundColor = .systemGray
        let delete = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] _, _, completion in
            self?.store.removeChat(id: chat.id)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete, mute, archive])
    }

    private func subtitle(chat: DemoChat) -> String {
        let archivePrefix = chat.isArchived ? "Архив • " : ""
        if !chat.draft.isEmpty {
            return "\(archivePrefix)Черновик: \(chat.draft)"
        }
        guard let message = chat.messages.last else {
            return "\(archivePrefix)Нет сообщений"
        }
        let prefix = message.author == .owner ? "Вы: " : ""
        if let gift = message.gift {
            return "\(archivePrefix)\(prefix)🎁 \(gift.title)"
        }
        if message.mediaFileName != nil {
            return "\(archivePrefix)\(prefix)🖼 Фото"
        }
        return "\(archivePrefix)\(prefix)\(message.text)"
    }

    @objc private func createChat() {
        let document = self.store.document
        let usedProfileIds = Set(document.chats.map(\.profileId))
        let profiles = document.profiles.filter { !usedProfileIds.contains($0.id) }
        guard !profiles.isEmpty else {
            let alert = UIAlertController(
                title: "Нет свободных профилей",
                message: "Сначала создайте новый профиль собеседника.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
            return
        }
        let sheet = UIAlertController(title: "Выберите собеседника", message: nil, preferredStyle: .actionSheet)
        for profile in profiles {
            sheet.addAction(UIAlertAction(title: profile.displayName, style: .default, handler: { [weak self] _ in
                guard let self else {
                    return
                }
                let chatId = self.store.createChat(profileId: profile.id)
                self.push(DemoChatController(context: self.context, chatId: chatId))
            }))
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
        self.present(sheet, animated: true)
    }
}
