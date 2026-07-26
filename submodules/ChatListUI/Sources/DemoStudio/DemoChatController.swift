import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import DemoStudioCore
import WallpaperBackgroundNode

final class DemoChatController: ViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let context: AccountContext
    private let store = DemoStudioStore.shared
    private let chatId: UUID
    private let wallpaperNode: WallpaperBackgroundNode
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let composer = DemoChatComposerView()
    private var observer: NSObjectProtocol?
    private var profile: DemoProfile?
    private var pendingDraft = ""
    private var didLoadDraft = false
    private var pendingMediaAuthor: DemoMessageAuthor?

    init(context: AccountContext, chatId: UUID) {
        self.context = context
        self.chatId = chatId
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.wallpaperNode = createWallpaperBackgroundNode(
            context: context,
            forChatDisplay: true,
            useSharedAnimationPhase: true
        )
        super.init(
            navigationBarPresentationData: NavigationBarPresentationData(
                presentationData: presentationData,
                style: .glass
            )
        )
        self._hasGlassStyle = true
        self.hidesBottomBarWhenPushed = true
        self.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let draft = self.pendingDraft
        self.store.updateChat(id: self.chatId) { chat in
            chat.draft = draft
        }
    }

    override func loadDisplayNode() {
        let rootNode = ASDisplayNode()
        self.displayNode = rootNode
        rootNode.addSubnode(self.wallpaperNode)

        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        self.wallpaperNode.update(wallpaper: presentationData.chatWallpaper, animated: false)

        self.scrollView.alwaysBounceVertical = true
        self.scrollView.keyboardDismissMode = .interactive
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        rootNode.view.addSubview(self.scrollView)

        self.stackView.axis = .vertical
        self.stackView.alignment = .fill
        self.stackView.spacing = 3.0
        self.stackView.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.addSubview(self.stackView)

        self.composer.translatesAutoresizingMaskIntoConstraints = false
        rootNode.view.addSubview(self.composer)

        NSLayoutConstraint.activate([
            self.scrollView.leadingAnchor.constraint(equalTo: rootNode.view.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: rootNode.view.trailingAnchor),
            self.scrollView.topAnchor.constraint(equalTo: rootNode.view.safeAreaLayoutGuide.topAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.composer.topAnchor),
            self.stackView.leadingAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.leadingAnchor, constant: 10.0),
            self.stackView.trailingAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.trailingAnchor, constant: -10.0),
            self.stackView.topAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.topAnchor, constant: 12.0),
            self.stackView.bottomAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.bottomAnchor, constant: -10.0),
            self.stackView.widthAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.widthAnchor, constant: -20.0),
            self.composer.leadingAnchor.constraint(equalTo: rootNode.view.leadingAnchor, constant: 8.0),
            self.composer.trailingAnchor.constraint(equalTo: rootNode.view.trailingAnchor, constant: -8.0)
        ])

        if #available(iOS 15.0, *) {
            self.composer.bottomAnchor.constraint(
                equalTo: rootNode.view.keyboardLayoutGuide.topAnchor,
                constant: -5.0
            ).isActive = true
        } else {
            self.composer.bottomAnchor.constraint(
                equalTo: rootNode.view.safeAreaLayoutGuide.bottomAnchor,
                constant: -5.0
            ).isActive = true
        }

        self.composer.onSend = { [weak self] author, text in
            guard let self else {
                return
            }
            self.pendingDraft = ""
            self.store.appendMessage(
                chatId: self.chatId,
                message: DemoMessage(author: author, text: text)
            )
        }
        self.composer.onDraftChanged = { [weak self] text in
            guard let self else {
                return
            }
            self.pendingDraft = text
        }
        self.composer.onAttachment = { [weak self] author in
            guard let self else {
                return
            }
            self.pendingMediaAuthor = author
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            self.present(picker, animated: true)
        }

        self.observer = NotificationCenter.default.addObserver(
            forName: .demoStudioDidChange,
            object: self.store,
            queue: .main
        ) { [weak self] _ in
            self?.reload(animated: true)
        }

        self.store.markChatRead(id: self.chatId)
        self.reload(animated: false)
    }

    override func containerLayoutUpdated(
        _ layout: ContainerViewLayout,
        transition: ContainedViewLayoutTransition
    ) {
        super.containerLayoutUpdated(layout, transition: transition)
        transition.updateFrame(node: self.wallpaperNode, frame: CGRect(origin: .zero, size: layout.size))
        self.wallpaperNode.updateLayout(
            size: layout.size,
            displayMode: .aspectFill,
            transition: transition
        )
    }

    private func reload(animated: Bool) {
        let document = self.store.document
        guard let chat = document.chats.first(where: { $0.id == self.chatId }),
              let profile = document.profiles.first(where: { $0.id == chat.profileId }) else {
            return
        }
        self.profile = profile
        self.title = "\(profile.displayName)\(profile.isPremium ? " \(profile.premiumEmoji)" : "")"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "info.circle"),
            style: .plain,
            target: self,
            action: #selector(self.openProfile)
        )
        self.composer.updateProfileName(profile.displayName)
        if !self.didLoadDraft {
            self.didLoadDraft = true
            self.pendingDraft = chat.draft
            self.composer.updateDraft(chat.draft)
        }

        let previousCount = self.stackView.arrangedSubviews.count
        self.stackView.arrangedSubviews.forEach { view in
            self.stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        self.stackView.addArrangedSubview(DemoChatDatePill(text: "Сегодня"))
        for message in chat.messages {
            let bubble = DemoChatBubbleView(message: message)
            bubble.onDelete = { [weak self] id in
                self?.store.updateChat(id: chat.id) { value in
                    value.messages.removeAll(where: { $0.id == id })
                }
            }
            self.stackView.addArrangedSubview(bubble)
        }

        DispatchQueue.main.async { [weak self] in
            self?.scrollToBottom(animated: animated && previousCount > 0)
        }
    }

    private func scrollToBottom(animated: Bool) {
        let height = self.scrollView.contentSize.height
        let visible = self.scrollView.bounds.height
        guard height > visible else {
            return
        }
        self.scrollView.setContentOffset(
            CGPoint(x: 0.0, y: height - visible + self.scrollView.adjustedContentInset.bottom),
            animated: animated
        )
    }

    @objc private func openProfile() {
        guard let profile else {
            return
        }
        (self.navigationController as? NavigationController)?.pushViewController(
            DemoProfilePreviewController(context: self.context, profileId: profile.id)
        )
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        defer {
            self.pendingMediaAuthor = nil
        }
        guard let author = self.pendingMediaAuthor,
              let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage,
              let data = image.jpegData(compressionQuality: 0.88),
              let fileName = self.store.writeAsset(
                data: data,
                fileExtension: "jpg",
                ownerId: self.chatId
              ) else {
            return
        }
        self.store.appendMessage(
            chatId: self.chatId,
            message: DemoMessage(
                author: author,
                text: "",
                mediaFileName: fileName
            )
        )
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        self.pendingMediaAuthor = nil
    }
}

private final class DemoChatComposerView: UIVisualEffectView, UITextFieldDelegate {
    private let sideControl = UISegmentedControl(items: ["Я", "Он/она"])
    private let attachmentButton = UIButton(type: .system)
    private let textField = UITextField()
    private let sendButton = UIButton(type: .system)
    var onSend: ((DemoMessageAuthor, String) -> Void)?
    var onDraftChanged: ((String) -> Void)?
    var onAttachment: ((DemoMessageAuthor) -> Void)?

    init() {
        super.init(effect: UIBlurEffect(style: .systemChromeMaterialDark))
        self.layer.cornerRadius = 24.0
        self.clipsToBounds = true

        self.sideControl.selectedSegmentIndex = 0
        self.sideControl.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.sideControl)

        self.attachmentButton.setImage(UIImage(systemName: "paperclip"), for: .normal)
        self.attachmentButton.tintColor = .systemBlue
        self.attachmentButton.addTarget(self, action: #selector(self.attach), for: .touchUpInside)
        self.attachmentButton.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.attachmentButton)

        self.textField.placeholder = "Сообщение"
        self.textField.textColor = .label
        self.textField.returnKeyType = .send
        self.textField.delegate = self
        self.textField.addTarget(self, action: #selector(self.textChanged), for: .editingChanged)
        self.textField.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.textField)

        self.sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        self.sendButton.tintColor = .systemBlue
        self.sendButton.addTarget(self, action: #selector(self.send), for: .touchUpInside)
        self.sendButton.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.sendButton)

        NSLayoutConstraint.activate([
            self.sideControl.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 8.0),
            self.sideControl.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 7.0),
            self.sideControl.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -7.0),
            self.sideControl.widthAnchor.constraint(equalToConstant: 112.0),
            self.attachmentButton.leadingAnchor.constraint(equalTo: self.sideControl.trailingAnchor, constant: 5.0),
            self.attachmentButton.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            self.attachmentButton.widthAnchor.constraint(equalToConstant: 30.0),
            self.attachmentButton.heightAnchor.constraint(equalToConstant: 30.0),
            self.textField.leadingAnchor.constraint(equalTo: self.attachmentButton.trailingAnchor, constant: 4.0),
            self.textField.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            self.sendButton.leadingAnchor.constraint(equalTo: self.textField.trailingAnchor, constant: 5.0),
            self.sendButton.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -8.0),
            self.sendButton.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            self.sendButton.widthAnchor.constraint(equalToConstant: 34.0),
            self.sendButton.heightAnchor.constraint(equalToConstant: 34.0),
            self.heightAnchor.constraint(greaterThanOrEqualToConstant: 50.0)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateProfileName(_ value: String) {
        let first = value.split(separator: " ").first.map(String.init) ?? "Он/она"
        self.sideControl.setTitle(first, forSegmentAt: 1)
    }

    func updateDraft(_ value: String) {
        guard self.textField.text != value else {
            return
        }
        self.textField.text = value
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.send()
        return false
    }

    @objc private func send() {
        guard let value = self.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return
        }
        let author: DemoMessageAuthor = self.sideControl.selectedSegmentIndex == 0 ? .owner : .profile
        self.textField.text = ""
        self.onDraftChanged?("")
        self.onSend?(author, value)
    }

    @objc private func textChanged() {
        self.onDraftChanged?(self.textField.text ?? "")
    }

    @objc private func attach() {
        let author: DemoMessageAuthor = self.sideControl.selectedSegmentIndex == 0 ? .owner : .profile
        self.onAttachment?(author)
    }
}

private final class DemoChatBubbleView: UIView {
    let messageId: UUID
    var onDelete: ((UUID) -> Void)?

    init(message: DemoMessage) {
        self.messageId = message.id
        super.init(frame: .zero)

        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .bottom
        row.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(row)

        let spacer = UIView()
        let bubble = UIVisualEffectView(effect: UIBlurEffect(
            style: message.author == .owner ? .systemUltraThinMaterialLight : .systemThinMaterialDark
        ))
        bubble.layer.cornerRadius = 18.0
        bubble.clipsToBounds = true
        bubble.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 5.0
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        bubble.contentView.addSubview(contentStack)

        if let url = DemoStudioStore.shared.assetURL(fileName: message.mediaFileName),
           let image = UIImage(contentsOfFile: url.path) {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 12.0
            imageView.heightAnchor.constraint(equalToConstant: 180.0).isActive = true
            contentStack.addArrangedSubview(imageView)
        }

        let label = UILabel()
        let giftPrefix = message.gift.map { "🎁 \($0.title)\n" } ?? ""
        let time = DemoChatBubbleView.timeFormatter.string(from: message.timestamp)
        let messageText = message.text.isEmpty && message.mediaFileName != nil ? "" : message.text
        label.text = "\(giftPrefix)\(messageText)   \(time)\(message.author == .owner ? " ✓✓" : "")"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16.0)
        label.numberOfLines = 0
        contentStack.addArrangedSubview(label)

        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: bubble.contentView.leadingAnchor, constant: 8.0),
            contentStack.trailingAnchor.constraint(equalTo: bubble.contentView.trailingAnchor, constant: -8.0),
            contentStack.topAnchor.constraint(equalTo: bubble.contentView.topAnchor, constant: 8.0),
            contentStack.bottomAnchor.constraint(equalTo: bubble.contentView.bottomAnchor, constant: -8.0),
            bubble.widthAnchor.constraint(lessThanOrEqualTo: self.widthAnchor, multiplier: 0.82),
            row.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            row.topAnchor.constraint(equalTo: self.topAnchor),
            row.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])

        if message.author == .owner {
            bubble.contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.72)
            row.addArrangedSubview(spacer)
            row.addArrangedSubview(bubble)
        } else {
            bubble.contentView.backgroundColor = UIColor.black.withAlphaComponent(0.20)
            row.addArrangedSubview(bubble)
            row.addArrangedSubview(spacer)
        }

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(self.longPressed(_:)))
        bubble.addGestureRecognizer(longPress)
        bubble.isUserInteractionEnabled = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func longPressed(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else {
            return
        }
        self.onDelete?(self.messageId)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private final class DemoChatDatePill: UILabel {
    init(text: String) {
        super.init(frame: .zero)
        self.text = text
        self.textColor = .white
        self.font = UIFont.systemFont(ofSize: 14.0, weight: .semibold)
        self.textAlignment = .center
        self.backgroundColor = UIColor.black.withAlphaComponent(0.40)
        self.layer.cornerRadius = 14.0
        self.clipsToBounds = true
        self.heightAnchor.constraint(equalToConstant: 28.0).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
