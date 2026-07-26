import Foundation
import UIKit

final class DemoModeChatController: UIViewController {
    private let store: DemoModeStore
    private let chatId: UUID
    private var chat: DemoChat?
    private var observer: NSObjectProtocol?

    private let backgroundImageView = UIImageView()
    private let scrollView = UIScrollView()
    private let messagesStack = UIStackView()
    private let composer = DemoModeComposerView()

    init(store: DemoModeStore, chatId: UUID) {
        self.store = store
        self.chatId = chatId
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
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
        self.view.backgroundColor = .black

        self.backgroundImageView.image = UIImage(named: "Demo Wallpaper")
        self.backgroundImageView.contentMode = .scaleAspectFill
        self.backgroundImageView.alpha = 0.54
        self.backgroundImageView.backgroundColor = UIColor(red: 0.035, green: 0.025, blue: 0.065, alpha: 1.0)
        self.backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.backgroundImageView)

        let tint = UIView()
        tint.backgroundColor = UIColor(red: 0.17, green: 0.07, blue: 0.24, alpha: 0.24)
        tint.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(tint)

        self.scrollView.alwaysBounceVertical = true
        self.scrollView.keyboardDismissMode = .interactive
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.scrollView)

        self.messagesStack.axis = .vertical
        self.messagesStack.spacing = 3.0
        self.messagesStack.alignment = .fill
        self.messagesStack.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.addSubview(self.messagesStack)

        self.composer.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.composer)
        self.composer.onSend = { [weak self] text in
            guard let self else {
                return
            }
            self.store.addMessage(chatId: self.chatId, text: text, isOutgoing: true)
        }

        NSLayoutConstraint.activate([
            self.backgroundImageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.backgroundImageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.backgroundImageView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.backgroundImageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            tint.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            tint.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            tint.topAnchor.constraint(equalTo: self.view.topAnchor),
            tint.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            self.scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.scrollView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.composer.topAnchor),

            self.messagesStack.leadingAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.leadingAnchor, constant: 8.0),
            self.messagesStack.trailingAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.trailingAnchor, constant: -8.0),
            self.messagesStack.topAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.topAnchor, constant: 18.0),
            self.messagesStack.bottomAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.bottomAnchor, constant: -10.0),
            self.messagesStack.widthAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.widthAnchor, constant: -16.0),

            self.composer.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 8.0),
            self.composer.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -8.0),
            self.composer.bottomAnchor.constraint(equalTo: self.view.keyboardLayoutGuide.topAnchor, constant: -6.0),
            self.composer.heightAnchor.constraint(greaterThanOrEqualToConstant: 50.0)
        ])

        self.observer = NotificationCenter.default.addObserver(
            forName: .demoModeStoreDidChange,
            object: self.store,
            queue: .main
        ) { [weak self] _ in
            self?.reloadChat(animated: true)
        }
        self.reloadChat(animated: false)
    }

    private func reloadChat(animated: Bool) {
        guard let chat = self.store.snapshot.chats.first(where: { $0.id == self.chatId }) else {
            return
        }
        self.chat = chat
        self.configureNavigation(profile: chat.profile)

        self.messagesStack.arrangedSubviews.forEach {
            self.messagesStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let profileNotice = DemoModeProfileNoticeView(profile: chat.profile)
        profileNotice.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.openProfile)))
        self.messagesStack.addArrangedSubview(profileNotice)

        let day = DemoModeCenteredPillLabel(text: "Сегодня")
        self.messagesStack.addArrangedSubview(day)

        for (index, message) in chat.messages.enumerated() {
            let previous = index > 0 ? chat.messages[index - 1] : nil
            let next = index + 1 < chat.messages.count ? chat.messages[index + 1] : nil
            let row = DemoModeMessageRow(
                message: message,
                joinsPrevious: previous?.isOutgoing == message.isOutgoing,
                joinsNext: next?.isOutgoing == message.isOutgoing
            )
            self.messagesStack.addArrangedSubview(row)
            if animated && index == chat.messages.count - 1 {
                row.alpha = 0.0
                row.transform = CGAffineTransform(translationX: message.isOutgoing ? 18.0 : -18.0, y: 10.0).scaledBy(x: 0.94, y: 0.94)
                UIView.animate(
                    withDuration: 0.38,
                    delay: 0.0,
                    usingSpringWithDamping: 0.78,
                    initialSpringVelocity: 0.35,
                    options: [.allowUserInteraction, .beginFromCurrentState]
                ) {
                    row.alpha = 1.0
                    row.transform = .identity
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.scrollToBottom(animated: animated)
        }
    }

    private func configureNavigation(profile: DemoProfile) {
        let name = UILabel()
        name.text = profile.name
        name.textColor = .white
        name.textAlignment = .center
        name.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        let status = UILabel()
        status.text = "был(а) недавно"
        status.textColor = .secondaryLabel
        status.textAlignment = .center
        status.font = UIFont.systemFont(ofSize: 12.5)
        let titleView = UIStackView(arrangedSubviews: [name, status])
        titleView.axis = .vertical
        titleView.alignment = .center
        titleView.spacing = -1.0
        titleView.isUserInteractionEnabled = true
        titleView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.openProfile)))
        self.navigationItem.titleView = titleView

        let avatar = DemoModeAvatarView(profile: profile, size: 36.0)
        avatar.isUserInteractionEnabled = true
        avatar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.openProfile)))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: avatar)
    }

    @objc private func openProfile() {
        guard let profile = self.chat?.profile else {
            return
        }
        self.navigationController?.pushViewController(DemoModeProfileController(profile: profile), animated: true)
    }

    private func scrollToBottom(animated: Bool) {
        let bottom = max(
            -self.scrollView.adjustedContentInset.top,
            self.scrollView.contentSize.height - self.scrollView.bounds.height + self.scrollView.adjustedContentInset.bottom
        )
        self.scrollView.setContentOffset(CGPoint(x: 0.0, y: bottom), animated: animated)
    }
}

private final class DemoModeMessageRow: UIView {
    init(message: DemoMessage, joinsPrevious: Bool, joinsNext: Bool) {
        super.init(frame: .zero)
        self.translatesAutoresizingMaskIntoConstraints = false

        let bubble = UIView()
        bubble.backgroundColor = message.isOutgoing ? DemoModeUI.outgoingBlue : DemoModeUI.incomingDark
        bubble.layer.cornerRadius = 18.0
        bubble.layer.cornerCurve = .continuous
        bubble.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(bubble)

        let text = UILabel()
        text.text = message.text
        text.textColor = .white
        text.font = UIFont.systemFont(ofSize: 17.0)
        text.numberOfLines = 0
        text.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(text)

        let time = UILabel()
        time.text = DemoModeChatDateFormatter.time.string(from: message.timestamp) + (message.isOutgoing ? " ✓✓" : "")
        time.textColor = UIColor.white.withAlphaComponent(0.56)
        time.font = UIFont.systemFont(ofSize: 11.0)
        time.translatesAutoresizingMaskIntoConstraints = false
        bubble.addSubview(time)

        let leading = bubble.leadingAnchor.constraint(equalTo: self.leadingAnchor)
        let trailing = bubble.trailingAnchor.constraint(equalTo: self.trailingAnchor)
        if message.isOutgoing {
            leading.isActive = false
            trailing.isActive = true
            bubble.leadingAnchor.constraint(greaterThanOrEqualTo: self.leadingAnchor, constant: 70.0).isActive = true
        } else {
            trailing.isActive = false
            leading.isActive = true
            bubble.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor, constant: -70.0).isActive = true
        }

        let topInset: CGFloat = joinsPrevious ? 1.5 : 4.0
        let bottomInset: CGFloat = joinsNext ? 1.5 : 4.0
        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: self.topAnchor, constant: topInset),
            bubble.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -bottomInset),
            bubble.widthAnchor.constraint(lessThanOrEqualTo: self.widthAnchor, multiplier: 0.82),
            text.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 13.0),
            text.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -13.0),
            text.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 8.0),
            time.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -10.0),
            time.topAnchor.constraint(equalTo: text.bottomAnchor, constant: 2.0),
            time.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -6.0),
            time.leadingAnchor.constraint(greaterThanOrEqualTo: bubble.leadingAnchor, constant: 14.0)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class DemoModeCenteredPillLabel: UIView {
    init(text: String) {
        super.init(frame: .zero)
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14.0, weight: .semibold)
        label.backgroundColor = UIColor(red: 0.16, green: 0.13, blue: 0.19, alpha: 0.88)
        label.layer.cornerRadius = 14.0
        label.layer.masksToBounds = true
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            label.topAnchor.constraint(equalTo: self.topAnchor, constant: 10.0),
            label.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -8.0),
            label.heightAnchor.constraint(equalToConstant: 28.0),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 82.0)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class DemoModeProfileNoticeView: UIView {
    init(profile: DemoProfile) {
        super.init(frame: .zero)
        self.backgroundColor = UIColor(red: 0.13, green: 0.12, blue: 0.16, alpha: 0.94)
        self.layer.cornerRadius = 23.0
        self.layer.cornerCurve = .continuous
        self.isUserInteractionEnabled = true

        let name = UILabel()
        name.text = profile.name
        name.textColor = .white
        name.font = UIFont.systemFont(ofSize: 18.0, weight: .semibold)
        name.textAlignment = .center
        let contact = UILabel()
        contact.text = profile.isContact ? "В контактах" : "Не в контактах"
        contact.textColor = .secondaryLabel
        contact.font = UIFont.systemFont(ofSize: 15.0)
        contact.textAlignment = .center
        let details = UILabel()
        details.text = "Страна телефона   \(profile.country)\nРегистрация        \(profile.registration)\n\nⓘ  Неофициальный аккаунт"
        details.textColor = .secondaryLabel
        details.font = UIFont.systemFont(ofSize: 14.0, weight: .medium)
        details.numberOfLines = 0
        details.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [name, contact, details])
        stack.axis = .vertical
        stack.spacing = 7.0
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 18.0),
            stack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -18.0),
            stack.topAnchor.constraint(equalTo: self.topAnchor, constant: 16.0),
            stack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -16.0)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class DemoModeComposerView: UIView, UITextFieldDelegate {
    var onSend: ((String) -> Void)?

    private let glassView = DemoModeUI.makeGlassEffectView(interactive: true)
    private let textField = UITextField()
    private let actionButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)

        let attach = UIButton(type: .system)
        attach.setImage(UIImage(systemName: "paperclip"), for: .normal)
        attach.tintColor = .white
        attach.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(attach)

        self.glassView.layer.cornerRadius = 23.0
        self.glassView.layer.masksToBounds = true
        self.glassView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.glassView)

        self.textField.placeholder = "Сообщение"
        self.textField.textColor = .white
        self.textField.returnKeyType = .send
        self.textField.delegate = self
        self.textField.addTarget(self, action: #selector(self.textChanged), for: .editingChanged)
        self.textField.translatesAutoresizingMaskIntoConstraints = false
        self.glassView.contentView.addSubview(self.textField)

        self.actionButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        self.actionButton.tintColor = .white
        self.actionButton.translatesAutoresizingMaskIntoConstraints = false
        self.actionButton.addTarget(self, action: #selector(self.send), for: .touchUpInside)
        self.addSubview(self.actionButton)

        NSLayoutConstraint.activate([
            attach.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            attach.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            attach.widthAnchor.constraint(equalToConstant: 44.0),
            attach.heightAnchor.constraint(equalToConstant: 44.0),
            self.actionButton.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.actionButton.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self.actionButton.widthAnchor.constraint(equalToConstant: 44.0),
            self.actionButton.heightAnchor.constraint(equalToConstant: 44.0),
            self.glassView.leadingAnchor.constraint(equalTo: attach.trailingAnchor, constant: 2.0),
            self.glassView.trailingAnchor.constraint(equalTo: self.actionButton.leadingAnchor, constant: -2.0),
            self.glassView.topAnchor.constraint(equalTo: self.topAnchor, constant: 2.0),
            self.glassView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -2.0),
            self.textField.leadingAnchor.constraint(equalTo: self.glassView.contentView.leadingAnchor, constant: 15.0),
            self.textField.trailingAnchor.constraint(equalTo: self.glassView.contentView.trailingAnchor, constant: -12.0),
            self.textField.topAnchor.constraint(equalTo: self.glassView.contentView.topAnchor),
            self.textField.bottomAnchor.constraint(equalTo: self.glassView.contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func textChanged() {
        let hasText = !(self.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        self.actionButton.setImage(UIImage(systemName: hasText ? "paperplane.fill" : "mic.fill"), for: .normal)
        self.actionButton.tintColor = hasText ? DemoModeUI.telegramBlue : .white
    }

    @objc private func send() {
        guard
            let text = self.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        else {
            return
        }
        self.onSend?(text)
        self.textField.text = ""
        self.textChanged()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.send()
        return false
    }
}

private enum DemoModeChatDateFormatter {
    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

final class DemoModeProfileController: UITableViewController {
    private let profile: DemoProfile

    init(profile: DemoProfile) {
        self.profile = profile
        super.init(style: .insetGrouped)
        self.title = profile.name
        self.overrideUserInterfaceStyle = .dark
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        DemoModeUI.configureTable(self.tableView)
        self.tableView.tableHeaderView = self.makeHeader()
    }

    private func makeHeader() -> UIView {
        let header = UIView(frame: CGRect(x: 0.0, y: 0.0, width: self.view.bounds.width, height: 224.0))
        let avatar = DemoModeAvatarView(profile: self.profile, size: 112.0)
        let name = UILabel()
        name.text = self.profile.name
        name.textColor = .white
        name.font = UIFont.systemFont(ofSize: 30.0, weight: .bold)
        name.translatesAutoresizingMaskIntoConstraints = false
        let username = UILabel()
        username.text = self.profile.username.isEmpty ? "демонстрационный профиль" : "@\(self.profile.username)"
        username.textColor = .secondaryLabel
        username.font = UIFont.systemFont(ofSize: 16.0)
        username.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(avatar)
        header.addSubview(name)
        header.addSubview(username)
        NSLayoutConstraint.activate([
            avatar.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            avatar.topAnchor.constraint(equalTo: header.topAnchor, constant: 14.0),
            name.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            name.topAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 12.0),
            username.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            username.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 4.0)
        ])
        return header
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 3 : 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.backgroundColor = DemoModeUI.groupedDark
        if indexPath.section == 0 {
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Телефон"
                cell.detailTextLabel?.text = self.profile.phone.isEmpty ? "скрыт" : self.profile.phone
            case 1:
                cell.textLabel?.text = "Страна телефона"
                cell.detailTextLabel?.text = self.profile.country
            default:
                cell.textLabel?.text = "Регистрация"
                cell.detailTextLabel?.text = self.profile.registration
            }
        } else {
            cell.textLabel?.text = self.profile.about.isEmpty ? "Нет описания" : self.profile.about
            cell.textLabel?.numberOfLines = 0
        }
        return cell
    }
}
