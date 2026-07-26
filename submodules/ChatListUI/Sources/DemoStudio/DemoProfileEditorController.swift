import Foundation
import UIKit
import Display
import AccountContext
import DemoStudioCore

final class DemoProfileEditorController: DemoStudioTableController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private enum Section: Int, CaseIterable {
        case identity
        case appearance
        case content
        case chat
    }

    private let store = DemoStudioStore.shared
    private var profile: DemoProfile

    init(context: AccountContext, profile: DemoProfile, isNew: Bool) {
        self.profile = profile
        super.init(context: context, title: isNew ? "Новый профиль" : "Профиль")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Сохранить",
            style: .done,
            target: self,
            action: #selector(self.save)
        )
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let storedProfile = self.store.document.profiles.first(where: { $0.id == self.profile.id }) {
            self.profile = storedProfile
            self.tableView.reloadData()
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
        case .identity:
            return 7
        case .appearance:
            return 6
        case .content:
            return 3
        case .chat:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else {
            return nil
        }
        switch section {
        case .identity:
            return "Основные данные"
        case .appearance:
            return "Оформление профиля"
        case .content:
            return "Контент профиля"
        case .chat:
            return "Переписка"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else {
            return nil
        }
        switch section {
        case .identity:
            return "Локальный username может совпадать с существующим Telegram username."
        case .appearance:
            return "Рейтинг ограничен диапазоном 0–10. Premium, эмодзи и фон существуют только в Demo Studio."
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        switch section {
        case .identity:
            switch indexPath.row {
            case 0:
                return self.configuredCell(title: "Имя", detail: self.profile.firstName)
            case 1:
                return self.configuredCell(title: "Фамилия", detail: self.profile.lastName)
            case 2:
                return self.configuredCell(
                    title: "Username",
                    detail: self.profile.username.isEmpty ? "Не задан" : "@\(self.profile.username)"
                )
            case 3:
                return self.configuredCell(title: "Телефон", detail: self.profile.phone)
            case 4:
                return self.configuredCell(title: "Страна", detail: self.profile.country)
            case 5:
                return self.configuredCell(
                    title: "Регистрация",
                    detail: self.profile.registrationDate.map(Self.dateFormatter.string) ?? "Не задана"
                )
            default:
                return self.configuredCell(title: "О себе", subtitle: self.profile.bio)
            }
        case .appearance:
            switch indexPath.row {
            case 0:
                return self.configuredCell(
                    title: "Фотография",
                    detail: self.profile.avatarFileName == nil ? "Не выбрана" : "Выбрана",
                    symbol: "photo.fill",
                    color: .systemBlue
                )
            case 1:
                let cell = self.configuredCell(title: "Telegram Premium", accessory: .none)
                let toggle = UISwitch()
                toggle.isOn = self.profile.isPremium
                toggle.addTarget(self, action: #selector(self.togglePremium(_:)), for: .valueChanged)
                cell.accessoryView = toggle
                return cell
            case 2:
                return self.configuredCell(title: "Premium-эмодзи", detail: self.profile.premiumEmoji)
            case 3:
                return self.configuredCell(title: "Фон Premium", detail: self.profile.premiumBackgroundHex)
            case 4:
                return self.configuredCell(title: "Уровень рейтинга", detail: "\(self.profile.ratingLevel) / 10")
            default:
                let cell = self.configuredCell(title: "В контактах", accessory: .none)
                let toggle = UISwitch()
                toggle.isOn = self.profile.isContact
                toggle.addTarget(self, action: #selector(self.toggleContact(_:)), for: .valueChanged)
                cell.accessoryView = toggle
                return cell
            }
        case .content:
            if indexPath.row == 0 {
                return self.configuredCell(
                    title: "Истории",
                    detail: "\(self.profile.stories.count)",
                    symbol: "circle.dashed",
                    color: .systemPurple
                )
            } else if indexPath.row == 1 {
                return self.configuredCell(
                    title: "Публикации",
                    detail: "\(self.profile.publications.count)",
                    symbol: "square.grid.2x2.fill",
                    color: .systemBlue
                )
            } else {
                return self.configuredCell(
                    title: "Подарки",
                    detail: "\(self.profile.gifts.count)",
                    symbol: "gift.fill",
                    color: .systemPink
                )
            }
        case .chat:
            let hasChat = self.store.document.chats.contains(where: { $0.profileId == self.profile.id })
            return self.configuredCell(
                title: hasChat ? "Открыть локальный чат" : "Создать локальный чат",
                symbol: "bubble.left.fill",
                color: .systemBlue
            )
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else {
            return
        }
        switch section {
        case .identity:
            self.editIdentity(row: indexPath.row)
        case .appearance:
            self.editAppearance(row: indexPath.row)
        case .content:
            self.store.upsertProfile(self.profile)
            if indexPath.row == 0 {
                self.push(DemoStoriesController(context: self.context, profileId: self.profile.id))
            } else if indexPath.row == 1 {
                self.push(DemoPublicationsController(context: self.context, profileId: self.profile.id))
            } else {
                self.push(DemoProfileGiftsController(context: self.context, profileId: self.profile.id))
            }
        case .chat:
            self.store.upsertProfile(self.profile)
            let chatId = self.store.createChat(profileId: self.profile.id)
            self.push(DemoChatController(context: self.context, chatId: chatId))
        }
    }

    private func editIdentity(row: Int) {
        switch row {
        case 0:
            self.prompt(title: "Имя", value: self.profile.firstName) { [weak self] value in
                self?.profile.firstName = value
            }
        case 1:
            self.prompt(title: "Фамилия", value: self.profile.lastName) { [weak self] value in
                self?.profile.lastName = value
            }
        case 2:
            self.prompt(title: "Username", value: self.profile.username, placeholder: "@username") { [weak self] value in
                self?.profile.username = DemoProfile.normalizedUsername(value)
            }
        case 3:
            self.prompt(title: "Телефон", value: self.profile.phone, keyboardType: .phonePad) { [weak self] value in
                self?.profile.phone = value
            }
        case 4:
            self.prompt(title: "Страна", value: self.profile.country) { [weak self] value in
                self?.profile.country = value
            }
        case 5:
            self.prompt(
                title: "Дата регистрации",
                value: self.profile.registrationDate.map(Self.dateFormatter.string) ?? "",
                placeholder: "ГГГГ-ММ-ДД"
            ) { [weak self] value in
                self?.profile.registrationDate = Self.dateFormatter.date(from: value)
            }
        default:
            self.prompt(title: "О себе", value: self.profile.bio) { [weak self] value in
                self?.profile.bio = value
            }
        }
    }

    private func editAppearance(row: Int) {
        switch row {
        case 0:
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            self.present(picker, animated: true)
        case 1, 5:
            break
        case 2:
            self.prompt(title: "Premium-эмодзи", value: self.profile.premiumEmoji) { [weak self] value in
                self?.profile.premiumEmoji = value
            }
        case 3:
            self.prompt(
                title: "Цвет фона",
                value: self.profile.premiumBackgroundHex,
                placeholder: "#6C5CE7"
            ) { [weak self] value in
                self?.profile.premiumBackgroundHex = value
            }
        default:
            self.prompt(
                title: "Уровень рейтинга",
                value: "\(self.profile.ratingLevel)",
                placeholder: "0–10",
                keyboardType: .numberPad
            ) { [weak self] value in
                self?.profile.ratingLevel = min(10, max(0, Int(value) ?? 0))
            }
        }
    }

    private func prompt(
        title: String,
        value: String,
        placeholder: String? = nil,
        keyboardType: UIKeyboardType = .default,
        update: @escaping (String) -> Void
    ) {
        self.presentTextPrompt(
            title: title,
            placeholder: placeholder,
            initialValue: value,
            keyboardType: keyboardType
        ) { [weak self] value in
            update(value)
            self?.tableView.reloadData()
        }
    }

    @objc private func togglePremium(_ sender: UISwitch) {
        self.profile.isPremium = sender.isOn
        self.tableView.reloadData()
    }

    @objc private func toggleContact(_ sender: UISwitch) {
        self.profile.isContact = sender.isOn
    }

    @objc private func save() {
        let trimmedName = self.profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.profile.firstName = trimmedName.isEmpty ? "Без имени" : trimmedName
        self.store.upsertProfile(self.profile)
        (self.navigationController as? NavigationController)?.popViewController(animated: true)
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        guard let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage,
              let data = image.jpegData(compressionQuality: 0.88),
              let fileName = self.store.writeAsset(data: data, fileExtension: "jpg", ownerId: self.profile.id) else {
            return
        }
        self.profile.avatarFileName = fileName
        self.tableView.reloadData()
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
