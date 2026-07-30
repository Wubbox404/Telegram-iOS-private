import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import DemoStudioCore
import AvatarNode

final class DemoProfilesController: DemoStudioTableController {
    private let store = DemoStudioStore.shared
    private let cloneDisposable = MetaDisposable()
    private var observer: NSObjectProtocol?

    init(context: AccountContext) {
        super.init(context: context, title: "Профили")
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Добавить",
            style: .plain,
            target: self,
            action: #selector(self.addProfile)
        )
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.cloneDisposable.dispose()
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
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(1, self.store.document.profiles.count)
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "Можно назначить любой локальный @username, включая уже занятый. Он не регистрируется и не проверяется на сервере Telegram."
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let profiles = self.store.document.profiles
        if profiles.isEmpty {
            let cell = self.configuredCell(
                title: "Профилей пока нет",
                subtitle: "Нажмите «Добавить» сверху",
                symbol: "person.crop.circle.badge.plus",
                color: .systemPurple,
                accessory: .none
            )
            cell.selectionStyle = .none
            return cell
        }
        guard indexPath.row < profiles.count else {
            return UITableViewCell()
        }
        let profile = profiles[indexPath.row]
        let premium = profile.isPremium ? " \(profile.premiumEmoji)" : ""
        let subtitleParts = [
            profile.username.isEmpty ? nil : "@\(profile.username)",
            "рейтинг \(profile.ratingLevel)",
            profile.sourceUsername.map { "копия @\($0)" }
        ].compactMap { $0 }
        let cell = self.configuredCell(
            title: "\(profile.displayName)\(premium)",
            subtitle: subtitleParts.joined(separator: " • "),
            accessory: .disclosureIndicator
        )
        cell.accessoryView = nil
        cell.imageView?.image = DemoStudioColors.image(
            symbol: profile.isPremium ? "star.fill" : "person.fill",
            background: DemoStudioColors.avatarColor(seed: profile.displayName)
        )
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let profiles = self.store.document.profiles
        guard indexPath.row < profiles.count else {
            return
        }
        self.push(DemoProfileEditorController(context: self.context, profile: profiles[indexPath.row], isNew: false))
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let profiles = self.store.document.profiles
        guard indexPath.row < profiles.count else {
            return nil
        }
        let profile = profiles[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] _, _, completion in
            self?.store.removeProfile(id: profile.id)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }

    @objc private func addProfile() {
        let sheet = UIAlertController(title: "Новый профиль", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Создать вручную", style: .default, handler: { [weak self] _ in
            guard let self else {
                return
            }
            let profile = DemoProfile(firstName: "Новый пользователь")
            self.push(DemoProfileEditorController(context: self.context, profile: profile, isNew: true))
        }))
        sheet.addAction(UIAlertAction(title: "Скопировать по @username", style: .default, handler: { [weak self] _ in
            self?.requestCloneUsername()
        }))
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
        self.present(sheet, animated: true)
    }

    private func requestCloneUsername() {
        self.presentTextPrompt(
            title: "Скопировать публичный профиль",
            message: "Будут скопированы только поля, которые ваш аккаунт реально видит.",
            placeholder: "@username",
            actionTitle: "Найти"
        ) { [weak self] value in
            self?.clone(username: value)
        }
    }

    private func clone(username: String) {
        let username = DemoProfile.normalizedUsername(username)
        guard !username.isEmpty else {
            return
        }

        let progress = UIAlertController(title: nil, message: "Загрузка @\(username)…", preferredStyle: .alert)
        self.present(progress, animated: true)

        self.cloneDisposable.set((
            self.context.engine.peers.resolvePeerByName(name: username, referrer: nil)
            |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
                guard case let .result(peer) = result else {
                    return .single(nil)
                }
                return .single(peer)
            }
            |> take(1)
            |> deliverOnMainQueue
        ).startStrict(next: { [weak self, weak progress] peer in
            guard let self, let peer, case let .user(user) = peer else {
                progress?.dismiss(animated: true)
                self?.presentCloneError(username: username)
                return
            }

            let profile = DemoProfile(
                firstName: user.firstName ?? "",
                lastName: user.lastName ?? "",
                username: user.addressName ?? username,
                phone: user.phone ?? "",
                bio: "",
                isPremium: user.isPremium,
                sourceUsername: username
            )

            self.context.account.viewTracker.forceUpdateCachedPeerData(peerId: peer.id)
            let refreshDelay = self.context.account.postbox.transaction { _ -> Void in
            }
            let cachedDataSignal = refreshDelay
            // Give forceUpdateCachedPeerData time to persist getFullUser,
            // then read one coherent cached-data snapshot.
            |> delay(2.0, queue: .mainQueue())
            |> mapToSignal { _ in
                return self.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.CachedData(id: peer.id)
                )
            }
            |> timeout(
                10.0,
                queue: .mainQueue(),
                alternate: self.context.engine.data.get(
                    TelegramEngine.EngineData.Item.Peer.CachedData(id: peer.id)
                )
            )
            |> take(1)
            |> deliverOnMainQueue

            let avatarSignal: Signal<UIImage?, NoError>
            if peer.profileImageRepresentations.isEmpty {
                avatarSignal = .single(nil)
            } else {
                let source = peerAvatarCompleteImage(
                    account: self.context.account,
                    peer: peer,
                    size: CGSize(width: 512.0, height: 512.0),
                    round: false,
                    fullSize: true
                )
                |> filter { $0 != nil }
                avatarSignal = source
                |> timeout(10.0, queue: .mainQueue(), alternate: .single(nil))
                |> take(1)
            }

            let giftsContext = ProfileGiftsContext(
                account: self.context.account,
                peerId: peer.id,
                limit: 100
            )
            let giftsSignal: Signal<[DemoGift], NoError> = giftsContext.state
            |> filter { state in
                if case .ready = state.dataState {
                    return true
                } else {
                    return false
                }
            }
            |> take(1)
            |> map { state in
                let _ = giftsContext
                return state.gifts.map { item in
                    switch item.gift {
                    case let .generic(gift):
                        return DemoGift(
                            telegramGiftId: gift.id,
                            telegramGiftPayload: try? JSONEncoder().encode(item.gift),
                            title: gift.title ?? "Telegram Gift",
                            number: item.number.map { Int64($0) },
                            receivedAt: Date(timeIntervalSince1970: TimeInterval(item.date)),
                            displayedOnProfile: item.savedToProfile
                        )
                    case let .unique(gift):
                        return DemoGift(
                            telegramGiftId: gift.giftId,
                            telegramGiftPayload: try? JSONEncoder().encode(item.gift),
                            slug: gift.slug,
                            title: gift.title,
                            number: Int64(gift.number),
                            receivedAt: Date(timeIntervalSince1970: TimeInterval(item.date)),
                            displayedOnProfile: item.savedToProfile
                        )
                    }
                }
            }
            |> timeout(12.0, queue: .mainQueue(), alternate: .single([]))

            self.cloneDisposable.set(combineLatest(
                cachedDataSignal,
                avatarSignal,
                giftsSignal
            ).startStrict(next: { [weak self, weak progress] cachedData, avatarImage, gifts in
                progress?.dismiss(animated: true)
                guard let self else {
                    return
                }
                var profile = profile
                if let cachedUserData = cachedData as? CachedUserData {
                    profile.bio = cachedUserData.about ?? ""
                    if let starRating = cachedUserData.starRating {
                        profile.ratingLevel = max(0, Int(starRating.level))
                        profile.ratingStars = max(0, starRating.stars)
                        profile.ratingCurrentLevelStars = max(0, starRating.currentLevelStars)
                        profile.ratingNextLevelStars = starRating.nextLevelStars.map { max(0, $0) }
                    }
                    if let savedMusic = cachedUserData.savedMusic {
                        for attribute in savedMusic.attributes {
                            if case let .Audio(_, _, title, performer, _) = attribute {
                                profile.savedMusicTitle = title
                                profile.savedMusicPerformer = performer
                            }
                        }
                    }
                }
                if let avatarImage,
                   let data = DemoStudioAvatarPipeline.jpegData(from: avatarImage) {
                    profile.avatarFileName = self.store.writeAsset(
                        data: data,
                        fileExtension: "jpg",
                        ownerId: profile.id
                    )
                }
                profile.gifts = gifts
                self.push(DemoProfileEditorController(context: self.context, profile: profile, isNew: true))
            }))
        }))
    }

    private func presentCloneError(username: String) {
        let alert = UIAlertController(
            title: "Профиль не найден",
            message: "@\(username) недоступен вашему аккаунту или это не пользователь.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
}
