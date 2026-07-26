import Foundation
import UIKit

final class DemoModeRootController: UITabBarController {
    private let store: DemoModeStore
    private let exit: () -> Void
    private let watermark = DemoModeWatermarkView()

    init(store: DemoModeStore = .shared, exit: @escaping () -> Void) {
        self.store = store
        self.exit = exit
        super.init(nibName: nil, bundle: nil)
        self.overrideUserInterfaceStyle = .dark
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let contacts = DemoModeContactsController(store: self.store)
        let calls = DemoModeCallsController()
        let chats = DemoModeChatsController(store: self.store)
        let settings = DemoModeSettingsController(store: self.store, exit: self.exit)

        let contactsNavigation = self.navigationController(
            root: contacts,
            title: "Контакты",
            asset: "Chat List/Tabs/IconContacts",
            fallback: "person.crop.circle"
        )
        let callsNavigation = self.navigationController(
            root: calls,
            title: "Звонки",
            asset: "Chat List/Tabs/IconCalls",
            fallback: "phone"
        )
        let chatsNavigation = self.navigationController(
            root: chats,
            title: "Чаты",
            asset: "Chat List/Tabs/IconChats",
            fallback: "bubble.left.and.bubble.right.fill"
        )
        let settingsNavigation = self.navigationController(
            root: settings,
            title: "Настройки",
            asset: "Chat List/Tabs/IconSettings",
            fallback: "gearshape.fill"
        )

        self.viewControllers = [
            contactsNavigation,
            callsNavigation,
            chatsNavigation,
            settingsNavigation
        ]
        self.selectedIndex = 2
        self.tabBar.tintColor = DemoModeUI.telegramBlue
        self.tabBar.unselectedItemTintColor = .white

        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior = .onScrollDown
        } else {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterialDark)
            self.tabBar.standardAppearance = appearance
            self.tabBar.scrollEdgeAppearance = appearance
        }

        self.view.addSubview(self.watermark)
        NSLayoutConstraint.activate([
            self.watermark.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -12.0),
            self.watermark.bottomAnchor.constraint(equalTo: self.tabBar.topAnchor, constant: -8.0)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.view.bringSubviewToFront(self.watermark)
    }

    private func navigationController(
        root: UIViewController,
        title: String,
        asset: String,
        fallback: String
    ) -> UINavigationController {
        let navigationController = UINavigationController(rootViewController: root)
        navigationController.navigationBar.prefersLargeTitles = false
        navigationController.view.backgroundColor = .black
        navigationController.tabBarItem = UITabBarItem(
            title: title,
            image: DemoModeUI.image(assetName: asset, fallbackSystemName: fallback),
            selectedImage: nil
        )
        return navigationController
    }
}

final class DemoModeContactsController: UITableViewController {
    private let store: DemoModeStore
    private var snapshot: DemoAccountSnapshot
    private var observer: NSObjectProtocol?

    init(store: DemoModeStore) {
        self.store = store
        self.snapshot = store.snapshot
        super.init(style: .plain)
        self.title = "Контакты"
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
        self.tableView.rowHeight = 66.0
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
        let identifier = "contact"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier) ?? UITableViewCell(style: .subtitle, reuseIdentifier: identifier)
        let profile = self.snapshot.chats[indexPath.row].profile
        var configuration = cell.defaultContentConfiguration()
        configuration.text = profile.name
        configuration.secondaryText = profile.isContact ? "в контактах" : "был(а) недавно"
        configuration.image = DemoModeUI.avatarImage(profile: profile, size: CGSize(width: 48.0, height: 48.0))
        configuration.imageProperties.cornerRadius = 24.0
        cell.contentConfiguration = configuration
        cell.backgroundColor = .black
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        self.navigationController?.pushViewController(
            DemoModeProfileController(profile: self.snapshot.chats[indexPath.row].profile),
            animated: true
        )
    }
}

final class DemoModeCallsController: UITableViewController {
    init() {
        super.init(style: .insetGrouped)
        self.title = "Звонки"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        DemoModeUI.configureTable(self.tableView)
        self.tableView.backgroundView = self.emptyState()
    }

    private func emptyState() -> UIView {
        let container = UIView()
        let image = UIImageView(image: UIImage(systemName: "phone.arrow.up.right"))
        image.tintColor = .secondaryLabel
        image.contentMode = .scaleAspectFit
        let title = UILabel()
        title.text = "Недавних звонков нет"
        title.textColor = .secondaryLabel
        title.font = UIFont.systemFont(ofSize: 18.0, weight: .semibold)
        let stack = UIStackView(arrangedSubviews: [image, title])
        stack.axis = .vertical
        stack.spacing = 16.0
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            image.widthAnchor.constraint(equalToConstant: 48.0),
            image.heightAnchor.constraint(equalToConstant: 48.0),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }
}
