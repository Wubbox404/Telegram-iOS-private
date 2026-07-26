import Foundation
import UIKit
import AccountContext
import DemoStudioCore

final class DemoProfilePreviewController: DemoStudioTableController {
    private enum Section: Int, CaseIterable {
        case identity
        case status
        case content
    }

    private let store = DemoStudioStore.shared
    private let profileId: UUID
    private var observer: NSObjectProtocol?

    init(context: AccountContext, profileId: UUID) {
        self.profileId = profileId
        super.init(context: context, title: "Профиль")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Изм.",
            style: .plain,
            target: self,
            action: #selector(self.edit)
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

    private var profile: DemoProfile? {
        return self.store.document.profiles.first(where: { $0.id == self.profileId })
    }

    override func loadDisplayNode() {
        super.loadDisplayNode()
        self.rebuildHeader()
        self.observer = NotificationCenter.default.addObserver(
            forName: .demoStudioDidChange,
            object: self.store,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildHeader()
            self?.tableView.reloadData()
        }
    }

    private func rebuildHeader() {
        guard let profile else {
            return
        }
        let header = UIView(frame: CGRect(x: 0.0, y: 0.0, width: self.view.bounds.width, height: 226.0))
        let avatar = DemoStudioAvatarView(profile: profile, size: 112.0)
        let name = UILabel()
        name.text = "\(profile.displayName)\(profile.isPremium ? " \(profile.premiumEmoji)" : "")"
        name.font = UIFont.systemFont(ofSize: 30.0, weight: .bold)
        name.textColor = self.presentationData.theme.list.itemPrimaryTextColor
        name.textAlignment = .center
        name.translatesAutoresizingMaskIntoConstraints = false
        let username = UILabel()
        username.text = profile.username.isEmpty ? profile.phone : "@\(profile.username)"
        username.font = UIFont.systemFont(ofSize: 16.0, weight: .medium)
        username.textColor = self.presentationData.theme.list.itemSecondaryTextColor
        username.textAlignment = .center
        username.translatesAutoresizingMaskIntoConstraints = false

        header.addSubview(avatar)
        header.addSubview(name)
        header.addSubview(username)
        NSLayoutConstraint.activate([
            avatar.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            avatar.topAnchor.constraint(equalTo: header.topAnchor, constant: 16.0),
            name.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16.0),
            name.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16.0),
            name.topAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 10.0),
            username.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16.0),
            username.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16.0),
            username.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 4.0)
        ])
        self.tableView.tableHeaderView = header
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
            return 5
        case .status:
            return 3
        case .content:
            return 3
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let profile, let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        switch section {
        case .identity:
            switch indexPath.row {
            case 0:
                return self.configuredCell(title: "Телефон", detail: profile.phone, accessory: .none)
            case 1:
                return self.configuredCell(
                    title: "Username",
                    detail: profile.username.isEmpty ? "Не задан" : "@\(profile.username)",
                    accessory: .none
                )
            case 2:
                return self.configuredCell(title: "Страна", detail: profile.country, accessory: .none)
            case 3:
                return self.configuredCell(
                    title: "Регистрация",
                    detail: profile.registrationDate.map(Self.dateFormatter.string) ?? "Не задана",
                    accessory: .none
                )
            default:
                return self.configuredCell(title: "О себе", subtitle: profile.bio, accessory: .none)
            }
        case .status:
            if indexPath.row == 0 {
                return self.configuredCell(
                    title: "Premium",
                    detail: profile.isPremium ? "Да \(profile.premiumEmoji)" : "Нет",
                    accessory: .none
                )
            } else if indexPath.row == 1 {
                return self.configuredCell(
                    title: "Рейтинг",
                    detail: "Уровень \(profile.ratingLevel) / 10",
                    accessory: .none
                )
            } else {
                return self.configuredCell(
                    title: "Контакт",
                    detail: profile.isContact ? "В контактах" : "Не в контактах",
                    accessory: .none
                )
            }
        case .content:
            if indexPath.row == 0 {
                return self.configuredCell(title: "Истории", detail: "\(profile.stories.count)")
            } else if indexPath.row == 1 {
                return self.configuredCell(title: "Публикации", detail: "\(profile.publications.count)")
            } else {
                return self.configuredCell(title: "Подарки", detail: "\(profile.gifts.count)")
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == Section.content.rawValue else {
            return
        }
        if indexPath.row == 0 {
            self.push(DemoStoriesController(context: self.context, profileId: self.profileId))
        } else if indexPath.row == 1 {
            self.push(DemoPublicationsController(context: self.context, profileId: self.profileId))
        } else {
            self.push(DemoProfileGiftsController(context: self.context, profileId: self.profileId))
        }
    }

    @objc private func edit() {
        guard let profile else {
            return
        }
        self.push(DemoProfileEditorController(context: self.context, profile: profile, isNew: false))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        return formatter
    }()
}
