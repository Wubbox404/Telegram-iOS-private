import Foundation
import UIKit

final class DemoModeChatsController: UITableViewController {
    private let store: DemoModeStore
    private var snapshot: DemoAccountSnapshot
    private var observer: NSObjectProtocol?
    private let storiesHeader = DemoModeStoriesHeader()
    private let searchController = UISearchController(searchResultsController: nil)
    private var query = ""

    init(store: DemoModeStore) {
        self.store = store
        self.snapshot = store.snapshot
        super.init(style: .plain)
        self.title = "Чаты"
        self.tabBarItem.badgeValue = nil
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
        self.tableView.rowHeight = 76.0
        self.tableView.register(DemoModeChatCell.self, forCellReuseIdentifier: DemoModeChatCell.reuseIdentifier)

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Изм.",
            style: .plain,
            target: self,
            action: #selector(self.toggleEditing)
        )
        self.navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                image: DemoModeUI.image(assetName: "Chat List/Create", fallbackSystemName: "square.and.pencil"),
                style: .plain,
                target: self,
                action: #selector(self.addChat)
            ),
            UIBarButtonItem(
                image: UIImage(systemName: "plus.circle"),
                style: .plain,
                target: self,
                action: #selector(self.addStory)
            )
        ]

        self.searchController.searchResultsUpdater = self
        self.searchController.obscuresBackgroundDuringPresentation = false
        self.searchController.searchBar.placeholder = "Поиск"
        self.navigationItem.searchController = self.searchController
        self.navigationItem.hidesSearchBarWhenScrolling = false
        self.definesPresentationContext = true

        self.storiesHeader.onSelect = { [weak self] story in
            guard let self else {
                return
            }
            self.store.markStoryViewed(id: story.id)
            self.present(DemoModeStoryController(story: story), animated: true)
        }
        self.storiesHeader.onAdd = { [weak self] in
            self?.addStory()
        }
        self.refresh()

        self.observer = NotificationCenter.default.addObserver(
            forName: .demoModeStoreDidChange,
            object: self.store,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let targetHeight: CGFloat = self.snapshot.stories.isEmpty ? 0.0 : 94.0
        if self.storiesHeader.frame.width != self.tableView.bounds.width || self.storiesHeader.frame.height != targetHeight {
            self.storiesHeader.frame = CGRect(x: 0.0, y: 0.0, width: self.tableView.bounds.width, height: targetHeight)
            self.tableView.tableHeaderView = targetHeight > 0.0 ? self.storiesHeader : nil
        }
    }

    private var filteredChats: [DemoChat] {
        guard !self.query.isEmpty else {
            return self.snapshot.chats
        }
        return self.snapshot.chats.filter {
            $0.profile.name.localizedCaseInsensitiveContains(self.query)
                || $0.profile.username.localizedCaseInsensitiveContains(self.query)
                || ($0.lastMessage?.text.localizedCaseInsensitiveContains(self.query) ?? false)
        }
    }

    private func refresh() {
        self.snapshot = self.store.snapshot
        self.storiesHeader.update(stories: self.snapshot.stories, owner: self.snapshot.owner)
        let unreadCount = self.snapshot.chats.reduce(0, { $0 + $1.unreadCount })
        self.tabBarItem.badgeValue = unreadCount > 0 ? String(unreadCount) : nil
        self.tableView.reloadData()
        self.view.setNeedsLayout()
    }

    @objc private func toggleEditing() {
        self.setEditing(!self.isEditing, animated: true)
        self.navigationItem.leftBarButtonItem?.title = self.isEditing ? "Готово" : "Изм."
    }

    @objc private func addChat() {
        let alert = UIAlertController(title: "Новый демо-чат", message: "Создайте локальный профиль", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Имя"
            field.autocapitalizationType = .words
        }
        alert.addTextField { field in
            field.placeholder = "Имя пользователя"
            field.autocapitalizationType = .none
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Добавить", style: .default, handler: { [weak self, weak alert] _ in
            guard
                let self,
                let name = alert?.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines),
                !name.isEmpty
            else {
                return
            }
            let username = alert?.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.store.addChat(profile: DemoProfile(name: name, username: username, isContact: false))
        }))
        self.present(alert, animated: true)
    }

    @objc private func addStory() {
        let alert = UIAlertController(title: "Новая история", message: "История хранится только на этом устройстве", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Подпись"
            field.autocapitalizationType = .sentences
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Добавить", style: .default, handler: { [weak self, weak alert] _ in
            guard let self else {
                return
            }
            let caption = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.store.addStory(
                DemoStory(
                    authorName: self.store.snapshot.owner.name,
                    caption: caption.isEmpty ? "Демонстрационная история" : caption,
                    accentHex: self.store.snapshot.owner.accentHex
                )
            )
        }))
        self.present(alert, animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.filteredChats.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DemoModeChatCell.reuseIdentifier, for: indexPath)
        guard let cell = cell as? DemoModeChatCell else {
            return cell
        }
        cell.update(chat: self.filteredChats[indexPath.row])
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.navigationController?.pushViewController(
            DemoModeChatController(store: self.store, chatId: self.filteredChats[indexPath.row].id),
            animated: true
        )
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            self.store.deleteChat(id: self.filteredChats[indexPath.row].id)
        }
    }
}

extension DemoModeChatsController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        self.query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.tableView.reloadData()
    }
}

private final class DemoModeChatCell: UITableViewCell {
    static let reuseIdentifier = "DemoModeChatCell"

    private let avatarView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let timeLabel = UILabel()
    private let badgeLabel = UILabel()
    private let pinView = UIImageView(image: UIImage(systemName: "pin.fill"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .black
        self.selectionStyle = .default

        self.avatarView.contentMode = .scaleAspectFill
        self.avatarView.layer.cornerRadius = 30.0
        self.avatarView.layer.masksToBounds = true

        self.titleLabel.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        self.titleLabel.textColor = .white
        self.messageLabel.font = UIFont.systemFont(ofSize: 15.5)
        self.messageLabel.textColor = .secondaryLabel
        self.messageLabel.numberOfLines = 2
        self.timeLabel.font = UIFont.systemFont(ofSize: 13.0)
        self.timeLabel.textColor = .secondaryLabel

        self.badgeLabel.font = UIFont.systemFont(ofSize: 13.0, weight: .semibold)
        self.badgeLabel.textColor = .black
        self.badgeLabel.backgroundColor = UIColor(white: 0.65, alpha: 1.0)
        self.badgeLabel.textAlignment = .center
        self.badgeLabel.layer.cornerRadius = 12.0
        self.badgeLabel.layer.masksToBounds = true

        self.pinView.tintColor = .secondaryLabel
        self.pinView.contentMode = .scaleAspectFit

        for view in [self.avatarView, self.titleLabel, self.messageLabel, self.timeLabel, self.badgeLabel, self.pinView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.contentView.addSubview(view)
        }

        NSLayoutConstraint.activate([
            self.avatarView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 12.0),
            self.avatarView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            self.avatarView.widthAnchor.constraint(equalToConstant: 60.0),
            self.avatarView.heightAnchor.constraint(equalToConstant: 60.0),

            self.titleLabel.leadingAnchor.constraint(equalTo: self.avatarView.trailingAnchor, constant: 12.0),
            self.titleLabel.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 10.0),
            self.titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: self.timeLabel.leadingAnchor, constant: -8.0),

            self.timeLabel.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -12.0),
            self.timeLabel.firstBaselineAnchor.constraint(equalTo: self.titleLabel.firstBaselineAnchor),

            self.messageLabel.leadingAnchor.constraint(equalTo: self.titleLabel.leadingAnchor),
            self.messageLabel.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: 4.0),
            self.messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: self.badgeLabel.leadingAnchor, constant: -8.0),
            self.messageLabel.bottomAnchor.constraint(lessThanOrEqualTo: self.contentView.bottomAnchor, constant: -8.0),

            self.badgeLabel.trailingAnchor.constraint(equalTo: self.timeLabel.trailingAnchor),
            self.badgeLabel.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -10.0),
            self.badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 24.0),
            self.badgeLabel.heightAnchor.constraint(equalToConstant: 24.0),

            self.pinView.trailingAnchor.constraint(equalTo: self.timeLabel.trailingAnchor),
            self.pinView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -12.0),
            self.pinView.widthAnchor.constraint(equalToConstant: 17.0),
            self.pinView.heightAnchor.constraint(equalToConstant: 17.0)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(chat: DemoChat) {
        self.avatarView.image = DemoModeUI.avatarImage(profile: chat.profile, size: CGSize(width: 120.0, height: 120.0))
        self.titleLabel.text = chat.profile.name + (chat.isMuted ? "  🔇" : "")
        self.messageLabel.text = chat.lastMessage?.text ?? "Нет сообщений"
        if let date = chat.lastMessage?.timestamp {
            self.timeLabel.text = DateFormatter.demoModeTime.string(from: date)
        } else {
            self.timeLabel.text = ""
        }
        self.badgeLabel.text = chat.unreadCount > 0 ? String(chat.unreadCount) : nil
        self.badgeLabel.isHidden = chat.unreadCount == 0
        self.pinView.isHidden = !chat.isPinned || chat.unreadCount > 0
    }
}

private final class DemoModeStoriesHeader: UIView {
    var onSelect: ((DemoStory) -> Void)?
    var onAdd: (() -> Void)?

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .black
        self.scrollView.showsHorizontalScrollIndicator = false
        self.stackView.axis = .horizontal
        self.stackView.alignment = .top
        self.stackView.spacing = 12.0
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.stackView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.scrollView)
        self.scrollView.addSubview(self.stackView)
        NSLayoutConstraint.activate([
            self.scrollView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.scrollView.topAnchor.constraint(equalTo: self.topAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.stackView.leadingAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.leadingAnchor, constant: 12.0),
            self.stackView.trailingAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.trailingAnchor, constant: -12.0),
            self.stackView.topAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.topAnchor, constant: 8.0),
            self.stackView.bottomAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.bottomAnchor, constant: -6.0),
            self.stackView.heightAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.heightAnchor, constant: -14.0)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(stories: [DemoStory], owner: DemoProfile) {
        self.stackView.arrangedSubviews.forEach {
            self.stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let addButton = DemoModeStoryButton(
            title: "Моя история",
            profile: owner,
            viewed: true,
            showsAdd: true
        )
        addButton.onTap = { [weak self] in
            self?.onAdd?()
        }
        self.stackView.addArrangedSubview(addButton)

        for story in stories {
            let profile = DemoProfile(name: story.authorName, accentHex: story.accentHex)
            let button = DemoModeStoryButton(title: story.authorName, profile: profile, viewed: story.isViewed)
            button.onTap = { [weak self] in
                self?.onSelect?(story)
            }
            self.stackView.addArrangedSubview(button)
        }
    }
}

private final class DemoModeStoryButton: UIControl {
    var onTap: (() -> Void)?

    init(title: String, profile: DemoProfile, viewed: Bool, showsAdd: Bool = false) {
        super.init(frame: .zero)
        self.translatesAutoresizingMaskIntoConstraints = false
        self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)

        let ring = UIView()
        ring.layer.cornerRadius = 29.0
        ring.layer.borderWidth = viewed ? 1.5 : 2.5
        ring.layer.borderColor = (viewed ? UIColor.secondaryLabel : UIColor(hex: "#8D5CF6")).cgColor
        ring.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(ring)

        let avatar = DemoModeAvatarView(profile: profile, size: 50.0)
        ring.addSubview(avatar)

        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 11.0)
        label.textColor = .white
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(label)

        NSLayoutConstraint.activate([
            self.widthAnchor.constraint(equalToConstant: 66.0),
            ring.topAnchor.constraint(equalTo: self.topAnchor),
            ring.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            ring.widthAnchor.constraint(equalToConstant: 58.0),
            ring.heightAnchor.constraint(equalToConstant: 58.0),
            avatar.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
            avatar.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
            label.topAnchor.constraint(equalTo: ring.bottomAnchor, constant: 4.0),
            label.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        ])

        if showsAdd {
            let add = UIImageView(image: UIImage(systemName: "plus.circle.fill"))
            add.tintColor = DemoModeUI.telegramBlue
            add.backgroundColor = .black
            add.layer.cornerRadius = 9.0
            add.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(add)
            NSLayoutConstraint.activate([
                add.trailingAnchor.constraint(equalTo: ring.trailingAnchor),
                add.bottomAnchor.constraint(equalTo: ring.bottomAnchor),
                add.widthAnchor.constraint(equalToConstant: 20.0),
                add.heightAnchor.constraint(equalToConstant: 20.0)
            ])
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func pressed() {
        self.onTap?()
    }
}

final class DemoModeStoryController: UIViewController {
    private let story: DemoStory

    init(story: DemoStory) {
        self.story = story
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .overFullScreen
        self.overrideUserInterfaceStyle = .dark
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .black

        let background = UIImageView()
        background.contentMode = .scaleAspectFill
        background.clipsToBounds = true
        if let imageData = self.story.imageData {
            background.image = UIImage(data: imageData)
        } else {
            background.image = DemoModeUI.avatarImage(
                profile: DemoProfile(name: self.story.authorName, accentHex: self.story.accentHex),
                size: CGSize(width: 800.0, height: 1400.0)
            )
        }
        background.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(background)

        let dim = UIView()
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        dim.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(dim)

        let title = UILabel()
        title.text = self.story.authorName
        title.textColor = .white
        title.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(title)

        let caption = UILabel()
        caption.text = self.story.caption
        caption.textColor = .white
        caption.font = UIFont.systemFont(ofSize: 20.0, weight: .semibold)
        caption.numberOfLines = 0
        caption.textAlignment = .center
        caption.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(caption)

        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark"), for: .normal)
        close.tintColor = .white
        close.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        close.layer.cornerRadius = 20.0
        close.translatesAutoresizingMaskIntoConstraints = false
        close.addTarget(self, action: #selector(self.close), for: .touchUpInside)
        self.view.addSubview(close)

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            background.topAnchor.constraint(equalTo: self.view.topAnchor),
            background.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            dim.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            dim.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            dim.topAnchor.constraint(equalTo: self.view.topAnchor),
            dim.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            title.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 18.0),
            title.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 12.0),
            close.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -14.0),
            close.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            close.widthAnchor.constraint(equalToConstant: 40.0),
            close.heightAnchor.constraint(equalToConstant: 40.0),
            caption.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 30.0),
            caption.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -30.0),
            caption.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -54.0)
        ])
    }

    @objc private func close() {
        self.dismiss(animated: true)
    }
}

private extension DateFormatter {
    static let demoModeTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}
