import Foundation
import UIKit

final class DemoModeSettingsController: UITableViewController {
    private let store: DemoModeStore
    private let exit: () -> Void
    private var snapshot: DemoAccountSnapshot
    private var observer: NSObjectProtocol?

    private let sections: [[(title: String, icon: String, color: UIColor)]] = [
        [
            ("Мой профиль", "person.crop.circle.fill", .systemRed)
        ],
        [
            ("Прокси", "arrow.left.arrow.right.circle.fill", .systemGreen),
            ("Кошелёк", "wallet.bifold.fill", .systemBlue)
        ],
        [
            ("Избранное", "bookmark.fill", .systemBlue),
            ("Недавние звонки", "phone.fill", .systemGreen),
            ("Устройства", "laptopcomputer.and.iphone", .systemOrange),
            ("Папки с чатами", "folder.fill", .systemCyan)
        ],
        [
            ("Уведомления и звуки", "bell.badge.fill", .systemRed),
            ("Конфиденциальность", "lock.fill", .systemGray),
            ("Данные и память", "externaldrive.fill", .systemGreen),
            ("Оформление", "circle.lefthalf.filled", .systemCyan),
            ("Энергосбережение", "battery.50percent", .systemOrange),
            ("Язык", "globe", .systemPurple)
        ],
        [
            ("Telegram Premium", "star.fill", .systemPurple),
            ("Мои звёзды", "star.circle.fill", .systemOrange),
            ("Telegram для бизнеса", "storefront.fill", .systemPink),
            ("Отправить подарок", "gift.fill", .systemTeal)
        ],
        [
            ("Редактор демо", "slider.horizontal.3", .systemBlue),
            ("Выйти из Demo Mode", "rectangle.portrait.and.arrow.right", .systemRed)
        ]
    ]

    init(store: DemoModeStore, exit: @escaping () -> Void) {
        self.store = store
        self.exit = exit
        self.snapshot = store.snapshot
        super.init(style: .insetGrouped)
        self.title = "Настройки"
        self.overrideUserInterfaceStyle = .dark
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        DemoModeUI.configureTable(self.tableView)
        self.tableView.rowHeight = 56.0
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "qrcode"),
            style: .plain,
            target: nil,
            action: nil
        )
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Изм.",
            style: .plain,
            target: self,
            action: #selector(self.editProfile)
        )
        self.rebuildHeader()

        self.observer = NotificationCenter.default.addObserver(
            forName: .demoModeStoreDidChange,
            object: self.store,
            queue: .main
        ) { [weak self] _ in
            guard let self else {
                return
            }
            self.snapshot = self.store.snapshot
            self.rebuildHeader()
            self.tableView.reloadData()
        }
    }

    private func rebuildHeader() {
        let owner = self.snapshot.owner
        let header = UIView(frame: CGRect(x: 0.0, y: 0.0, width: self.view.bounds.width, height: 250.0))
        let avatar = DemoModeAvatarView(profile: owner, size: 120.0)
        let name = UILabel()
        name.text = owner.name
        name.textColor = .white
        name.font = UIFont.systemFont(ofSize: 33.0, weight: .bold)
        name.translatesAutoresizingMaskIntoConstraints = false
        let details = UILabel()
        let username = owner.username.isEmpty ? "" : " • @\(owner.username)"
        details.text = "\(owner.phone)\(username)"
        details.textColor = .secondaryLabel
        details.font = UIFont.systemFont(ofSize: 16.0, weight: .medium)
        details.translatesAutoresizingMaskIntoConstraints = false
        let demo = UILabel()
        demo.text = "ЛОКАЛЬНЫЙ ДЕМО-АККАУНТ"
        demo.textColor = UIColor.white.withAlphaComponent(0.36)
        demo.font = UIFont.systemFont(ofSize: 11.0, weight: .bold)
        demo.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(avatar)
        header.addSubview(name)
        header.addSubview(details)
        header.addSubview(demo)
        NSLayoutConstraint.activate([
            avatar.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            avatar.topAnchor.constraint(equalTo: header.topAnchor, constant: 18.0),
            name.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            name.topAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 14.0),
            details.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            details.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 5.0),
            demo.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            demo.topAnchor.constraint(equalTo: details.bottomAnchor, constant: 9.0)
        ])
        self.tableView.tableHeaderView = header
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sections[section].count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = self.sections[indexPath.section][indexPath.row]
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.backgroundColor = DemoModeUI.groupedDark
        cell.textLabel?.text = item.title
        cell.imageView?.image = UIImage(systemName: item.icon)
        cell.imageView?.tintColor = item.color
        cell.accessoryType = .disclosureIndicator
        if item.title == "Мои звёзды" {
            cell.detailTextLabel?.text = "⭐️ \(self.snapshot.starBalance)"
        } else if item.title == "Язык" {
            cell.detailTextLabel?.text = "Русский"
        } else if item.title == "Энергосбережение" {
            cell.detailTextLabel?.text = "Выкл."
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let title = self.sections[indexPath.section][indexPath.row].title
        switch title {
        case "Мой профиль":
            self.navigationController?.pushViewController(DemoModeProfileController(profile: self.snapshot.owner), animated: true)
        case "Мои звёзды":
            self.navigationController?.pushViewController(DemoModeStarsController(store: self.store), animated: true)
        case "Редактор демо":
            self.navigationController?.pushViewController(DemoModeEditorController(store: self.store), animated: true)
        case "Выйти из Demo Mode":
            self.confirmExit()
        default:
            let controller = DemoModePlaceholderController(title: title)
            self.navigationController?.pushViewController(controller, animated: true)
        }
    }

    @objc private func editProfile() {
        DemoModeEditorAlerts.editProfile(
            self.snapshot.owner,
            from: self,
            completion: { [weak self] profile in
                self?.store.updateOwner(profile)
            }
        )
    }

    private func confirmExit() {
        let alert = UIAlertController(
            title: "Выйти из Demo Mode?",
            message: "Локальные демо-данные сохранятся.",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Выйти", style: .destructive, handler: { [weak self] _ in
            self?.exit()
        }))
        alert.popoverPresentationController?.sourceView = self.view
        alert.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.maxY, width: 1.0, height: 1.0)
        self.present(alert, animated: true)
    }
}

final class DemoModeStarsController: UITableViewController {
    private let store: DemoModeStore
    private var snapshot: DemoAccountSnapshot
    private var observer: NSObjectProtocol?

    init(store: DemoModeStore) {
        self.store = store
        self.snapshot = store.snapshot
        super.init(style: .plain)
        self.title = "Звёзды Telegram"
        self.overrideUserInterfaceStyle = .dark
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        DemoModeUI.configureTable(self.tableView)
        self.tableView.rowHeight = 74.0
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Баланс ⭐️ \(self.snapshot.starBalance)",
            style: .plain,
            target: self,
            action: #selector(self.editBalance)
        )
        let segmented = UISegmentedControl(items: ["Все операции", "Зачисления", "Списания"])
        segmented.selectedSegmentIndex = 0
        segmented.isUserInteractionEnabled = false
        segmented.frame = CGRect(x: 16.0, y: 10.0, width: self.view.bounds.width - 32.0, height: 36.0)
        let header = UIView(frame: CGRect(x: 0.0, y: 0.0, width: self.view.bounds.width, height: 56.0))
        header.addSubview(segmented)
        self.tableView.tableHeaderView = header

        self.observer = NotificationCenter.default.addObserver(
            forName: .demoModeStoreDidChange,
            object: self.store,
            queue: .main
        ) { [weak self] _ in
            guard let self else {
                return
            }
            self.snapshot = self.store.snapshot
            self.navigationItem.rightBarButtonItem?.title = "Баланс ⭐️ \(self.snapshot.starBalance)"
            self.tableView.reloadData()
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.snapshot.starTransactions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let transaction = self.snapshot.starTransactions[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = DemoModeUI.groupedDark
        cell.textLabel?.text = transaction.title
        cell.textLabel?.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        cell.detailTextLabel?.text = "\(transaction.subtitle)\n\(DemoModeSettingsDateFormatter.date.string(from: transaction.timestamp))"
        cell.detailTextLabel?.numberOfLines = 2

        let amount = UILabel()
        amount.text = "\(transaction.amount > 0 ? "+" : "")\(transaction.amount) ⭐️"
        amount.textColor = transaction.amount >= 0 ? .systemGreen : .systemRed
        amount.font = UIFont.systemFont(ofSize: 18.0, weight: .bold)
        amount.sizeToFit()
        cell.accessoryView = amount
        return cell
    }

    @objc private func editBalance() {
        DemoModeEditorAlerts.integer(
            title: "Баланс звёзд",
            message: "Укажите итоговое количество",
            value: self.snapshot.starBalance,
            from: self
        ) { [weak self] value in
            self?.store.setStarBalance(value)
        }
    }
}

final class DemoModeEditorController: UITableViewController {
    private let store: DemoModeStore
    private let imagePicker = DemoModeImagePicker()
    private let rows = [
        ("Изменить свой профиль", "person.crop.circle"),
        ("Изменить фото профиля", "photo.circle"),
        ("Добавить чат и профиль", "bubble.left.and.bubble.right"),
        ("Изменить профиль чата", "person.text.rectangle"),
        ("Добавить историю", "circle.dashed.inset.filled"),
        ("Добавить историю с фото", "photo.on.rectangle.angled"),
        ("Изменить баланс звёзд", "star.circle"),
        ("Добавить операцию со звёздами", "list.bullet.rectangle"),
        ("Сбросить демо-данные", "arrow.counterclockwise")
    ]

    init(store: DemoModeStore) {
        self.store = store
        super.init(style: .insetGrouped)
        self.title = "Редактор демо"
        self.overrideUserInterfaceStyle = .dark
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        DemoModeUI.configureTable(self.tableView)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = self.rows[indexPath.row]
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundColor = DemoModeUI.groupedDark
        cell.textLabel?.text = row.0
        cell.imageView?.image = UIImage(systemName: row.1)
        cell.imageView?.tintColor = indexPath.row == self.rows.count - 1 ? .systemRed : DemoModeUI.telegramBlue
        cell.accessoryType = indexPath.row == self.rows.count - 1 ? .none : .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.row {
        case 0:
            DemoModeEditorAlerts.editProfile(self.store.snapshot.owner, from: self) { [weak self] profile in
                self?.store.updateOwner(profile)
            }
        case 1:
            self.imagePicker.present(from: self) { [weak self] image in
                guard let self else {
                    return
                }
                var profile = self.store.snapshot.owner
                profile.avatarData = image.jpegData(compressionQuality: 0.86)
                self.store.updateOwner(profile)
            }
        case 2:
            DemoModeEditorAlerts.addChat(from: self) { [weak self] profile in
                self?.store.addChat(profile: profile)
            }
        case 3:
            self.navigationController?.pushViewController(DemoModeChatProfilesEditorController(store: self.store), animated: true)
        case 4:
            DemoModeEditorAlerts.addStory(owner: self.store.snapshot.owner, from: self) { [weak self] story in
                self?.store.addStory(story)
            }
        case 5:
            self.imagePicker.present(from: self) { [weak self] image in
                guard let self else {
                    return
                }
                DemoModeEditorAlerts.addStory(
                    owner: self.store.snapshot.owner,
                    imageData: image.jpegData(compressionQuality: 0.86),
                    from: self
                ) { [weak self] story in
                    self?.store.addStory(story)
                }
            }
        case 6:
            DemoModeEditorAlerts.integer(
                title: "Баланс звёзд",
                message: "Укажите итоговое количество",
                value: self.store.snapshot.starBalance,
                from: self
            ) { [weak self] value in
                self?.store.setStarBalance(value)
            }
        case 7:
            DemoModeEditorAlerts.addStarsTransaction(from: self) { [weak self] title, amount in
                self?.store.addStarsTransaction(title: title, subtitle: amount >= 0 ? "Зачисление" : "Списание", amount: amount)
            }
        default:
            self.confirmReset()
        }
    }

    private func confirmReset() {
        let alert = UIAlertController(title: "Сбросить демо-данные?", message: "Будут восстановлены стартовые чаты, истории и звёзды.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Сбросить", style: .destructive, handler: { [weak self] _ in
            self?.store.reset()
        }))
        alert.popoverPresentationController?.sourceView = self.view
        self.present(alert, animated: true)
    }
}

private enum DemoModeEditorAlerts {
    static func editProfile(_ profile: DemoProfile, from controller: UIViewController, completion: @escaping (DemoProfile) -> Void) {
        let alert = UIAlertController(title: "Профиль", message: "Данные локального демо-аккаунта", preferredStyle: .alert)
        let values = [
            ("Имя", profile.name),
            ("Username", profile.username),
            ("О себе", profile.about)
        ]
        for value in values {
            alert.addTextField { field in
                field.placeholder = value.0
                field.text = value.1
            }
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { [weak alert] _ in
            guard
                let fields = alert?.textFields,
                let name = fields[0].text?.trimmingCharacters(in: .whitespacesAndNewlines),
                !name.isEmpty
            else {
                return
            }
            var updated = profile
            updated.name = name
            updated.username = fields[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            updated.about = fields[2].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            completion(updated)
        }))
        controller.present(alert, animated: true)
    }

    static func addChat(from controller: UIViewController, completion: @escaping (DemoProfile) -> Void) {
        let alert = UIAlertController(title: "Новый чат", message: "Создайте связанный профиль", preferredStyle: .alert)
        for placeholder in ["Имя", "Username", "Страна", "О себе"] {
            alert.addTextField { field in
                field.placeholder = placeholder
            }
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Добавить", style: .default, handler: { [weak alert] _ in
            guard
                let fields = alert?.textFields,
                let name = fields[0].text?.trimmingCharacters(in: .whitespacesAndNewlines),
                !name.isEmpty
            else {
                return
            }
            completion(
                DemoProfile(
                    name: name,
                    username: fields[1].text ?? "",
                    about: fields[3].text ?? "",
                    country: (fields[2].text?.isEmpty ?? true) ? "Россия" : (fields[2].text ?? "Россия"),
                    isContact: false
                )
            )
        }))
        controller.present(alert, animated: true)
    }

    static func addStory(
        owner: DemoProfile,
        imageData: Data? = nil,
        from controller: UIViewController,
        completion: @escaping (DemoStory) -> Void
    ) {
        let alert = UIAlertController(title: "Новая история", message: "Подпись можно изменить позже сбросом данных", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Подпись"
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Добавить", style: .default, handler: { [weak alert] _ in
            let caption = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            completion(
                DemoStory(
                    authorName: owner.name,
                    caption: caption,
                    imageData: imageData,
                    accentHex: owner.accentHex
                )
            )
        }))
        controller.present(alert, animated: true)
    }

    static func integer(title: String, message: String, value: Int, from controller: UIViewController, completion: @escaping (Int) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { field in
            field.keyboardType = .numberPad
            field.text = String(value)
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { [weak alert] _ in
            guard let text = alert?.textFields?.first?.text, let value = Int(text) else {
                return
            }
            completion(value)
        }))
        controller.present(alert, animated: true)
    }

    static func addStarsTransaction(from controller: UIViewController, completion: @escaping (String, Int) -> Void) {
        let alert = UIAlertController(title: "Операция со звёздами", message: "Для списания укажите отрицательное число", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Название"
        }
        alert.addTextField { field in
            field.placeholder = "Количество"
            field.keyboardType = .numbersAndPunctuation
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Добавить", style: .default, handler: { [weak alert] _ in
            guard
                let fields = alert?.textFields,
                let amountText = fields[1].text,
                let amount = Int(amountText)
            else {
                return
            }
            let title = fields[0].text?.trimmingCharacters(in: .whitespacesAndNewlines)
            completion((title?.isEmpty ?? true) ? "Операция" : (title ?? "Операция"), amount)
        }))
        controller.present(alert, animated: true)
    }
}

private final class DemoModeChatProfilesEditorController: UITableViewController {
    private let store: DemoModeStore
    private var snapshot: DemoAccountSnapshot
    private var observer: NSObjectProtocol?

    init(store: DemoModeStore) {
        self.store = store
        self.snapshot = store.snapshot
        super.init(style: .insetGrouped)
        self.title = "Профили чатов"
        self.overrideUserInterfaceStyle = .dark
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        DemoModeUI.configureTable(self.tableView)
        self.observer = NotificationCenter.default.addObserver(
            forName: .demoModeStoreDidChange,
            object: self.store,
            queue: .main
        ) { [weak self] _ in
            guard let self else {
                return
            }
            self.snapshot = self.store.snapshot
            self.tableView.reloadData()
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.snapshot.chats.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let chat = self.snapshot.chats[indexPath.row]
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.backgroundColor = DemoModeUI.groupedDark
        cell.textLabel?.text = chat.profile.name
        cell.detailTextLabel?.text = chat.profile.username.isEmpty ? "без username" : "@\(chat.profile.username)"
        cell.imageView?.image = DemoModeUI.avatarImage(profile: chat.profile, size: CGSize(width: 48.0, height: 48.0))
        cell.imageView?.layer.cornerRadius = 24.0
        cell.imageView?.layer.masksToBounds = true
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let chat = self.snapshot.chats[indexPath.row]
        DemoModeEditorAlerts.editProfile(chat.profile, from: self) { [weak self] profile in
            guard let self else {
                return
            }
            var updated = chat
            updated.profile = profile
            self.store.updateChat(updated)
        }
    }
}

private final class DemoModePlaceholderController: UIViewController {
    private let screenTitle: String

    init(title: String) {
        self.screenTitle = title
        super.init(nibName: nil, bundle: nil)
        self.title = title
        self.overrideUserInterfaceStyle = .dark
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemGroupedBackground
        let label = UILabel()
        label.text = "\(self.screenTitle)\n\nЭкран сохранён в интерфейсе форка.\nВ Demo Mode сетевые действия отключены."
        label.textColor = .secondaryLabel
        label.font = UIFont.systemFont(ofSize: 17.0)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 32.0),
            label.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -32.0),
            label.centerYAnchor.constraint(equalTo: self.view.centerYAnchor)
        ])
    }
}

private enum DemoModeSettingsDateFormatter {
    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM HH:mm"
        return formatter
    }()
}
