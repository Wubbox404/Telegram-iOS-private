import Foundation
import UIKit
import AccountContext
import DemoStudioCore

class DemoProfileContentController: DemoStudioTableController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let store = DemoStudioStore.shared
    let profileId: UUID
    var observer: NSObjectProtocol?
    private var mediaCompletion: ((String?) -> Void)?

    init(context: AccountContext, profileId: UUID, title: String) {
        self.profileId = profileId
        super.init(context: context, title: title)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Добавить",
            style: .plain,
            target: self,
            action: #selector(self.addItem)
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

    var profile: DemoProfile? {
        return self.store.document.profiles.first(where: { $0.id == self.profileId })
    }

    @objc func addItem() {
    }

    func updateProfile(_ transform: (inout DemoProfile) -> Void) {
        guard var profile = self.profile else {
            return
        }
        transform(&profile)
        self.store.upsertProfile(profile)
    }

    func collectOptionalMedia(completion: @escaping (String?) -> Void) {
        let sheet = UIAlertController(title: "Медиа", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Выбрать фото", style: .default, handler: { [weak self] _ in
            guard let self else {
                return
            }
            self.mediaCompletion = completion
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            self.present(picker, animated: true)
        }))
        sheet.addAction(UIAlertAction(title: "Без фото", style: .default, handler: { _ in
            completion(nil)
        }))
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
        self.present(sheet, animated: true)
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        guard let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage,
              let data = image.jpegData(compressionQuality: 0.88) else {
            self.mediaCompletion?(nil)
            self.mediaCompletion = nil
            return
        }
        let fileName = self.store.writeAsset(
            data: data,
            fileExtension: "jpg",
            ownerId: self.profileId
        )
        self.mediaCompletion?(fileName)
        self.mediaCompletion = nil
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        self.mediaCompletion = nil
    }
}

final class DemoStoriesController: DemoProfileContentController {
    init(context: AccountContext, profileId: UUID) {
        super.init(context: context, profileId: profileId, title: "Истории")
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.profile?.stories.count ?? 0
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "Истории локальны. Можно закреплять их в профиле и задавать произвольное число просмотров."
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let stories = self.profile?.stories, indexPath.row < stories.count else {
            return UITableViewCell()
        }
        let story = stories[indexPath.row]
        let cell = self.configuredCell(
            title: story.caption.isEmpty ? "История без подписи" : story.caption,
            subtitle: "\(story.isPinned ? "Закреплена • " : "")\(story.viewCount) просмотров",
            symbol: "circle.dashed",
            color: .systemPurple
        )
        if let url = self.store.assetURL(fileName: story.mediaFileName),
           let image = UIImage(contentsOfFile: url.path) {
            cell.imageView?.image = image
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let stories = self.profile?.stories, indexPath.row < stories.count else {
            return
        }
        let story = stories[indexPath.row]
        let sheet = UIAlertController(title: story.caption, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Изменить", style: .default, handler: { [weak self] _ in
            self?.editStory(story)
        }))
        sheet.addAction(UIAlertAction(title: story.isPinned ? "Открепить" : "Закрепить", style: .default, handler: { [weak self] _ in
            self?.updateProfile { profile in
                guard let index = profile.stories.firstIndex(where: { $0.id == story.id }) else {
                    return
                }
                profile.stories[index].isPinned.toggle()
            }
        }))
        sheet.addAction(UIAlertAction(title: "Удалить", style: .destructive, handler: { [weak self] _ in
            self?.updateProfile { profile in
                profile.stories.removeAll(where: { $0.id == story.id })
            }
        }))
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        sheet.popoverPresentationController?.sourceView = self.view
        sheet.popoverPresentationController?.sourceRect = tableView.rectForRow(at: indexPath)
        self.present(sheet, animated: true)
    }

    private func editStory(_ story: DemoStory) {
        self.presentTextPrompt(
            title: "Подпись",
            initialValue: story.caption,
            actionTitle: "Дальше"
        ) { [weak self] caption in
            self?.presentTextPrompt(
                title: "Просмотры",
                initialValue: "\(story.viewCount)",
                keyboardType: .numberPad,
                actionTitle: "Сохранить"
            ) { [weak self] views in
                self?.updateProfile { profile in
                    guard let index = profile.stories.firstIndex(where: { $0.id == story.id }) else {
                        return
                    }
                    profile.stories[index].caption = caption
                    profile.stories[index].viewCount = max(0, Int(views) ?? 0)
                }
            }
        }
    }

    override func addItem() {
        self.presentTextPrompt(
            title: "Новая история",
            placeholder: "Подпись",
            actionTitle: "Дальше"
        ) { [weak self] caption in
            self?.presentTextPrompt(
                title: "Просмотры",
                placeholder: "0",
                keyboardType: .numberPad,
                actionTitle: "Добавить"
            ) { [weak self] views in
                self?.collectOptionalMedia { [weak self] mediaFileName in
                    self?.updateProfile { profile in
                        profile.stories.append(DemoStory(
                            caption: caption,
                            mediaFileName: mediaFileName,
                            isPinned: false,
                            viewCount: Int(views) ?? 0
                        ))
                    }
                }
            }
        }
    }
}

final class DemoPublicationsController: DemoProfileContentController {
    init(context: AccountContext, profileId: UUID) {
        super.init(context: context, profileId: profileId, title: "Публикации")
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.profile?.publications.count ?? 0
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "Публикации отображаются только в локальном профиле."
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let publications = self.profile?.publications, indexPath.row < publications.count else {
            return UITableViewCell()
        }
        let publication = publications[indexPath.row]
        let cell = self.configuredCell(
            title: publication.text.isEmpty ? "Публикация" : publication.text,
            subtitle: "\(publication.viewCount) просмотров",
            symbol: "square.grid.2x2.fill",
            color: .systemBlue
        )
        if let url = self.store.assetURL(fileName: publication.mediaFileName),
           let image = UIImage(contentsOfFile: url.path) {
            cell.imageView?.image = image
        }
        return cell
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let publications = self.profile?.publications, indexPath.row < publications.count else {
            return nil
        }
        let publication = publications[indexPath.row]
        return UISwipeActionsConfiguration(actions: [
            UIContextualAction(style: .destructive, title: "Удалить", handler: { [weak self] _, _, completion in
                self?.updateProfile { profile in
                    profile.publications.removeAll(where: { $0.id == publication.id })
                }
                completion(true)
            })
        ])
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let publications = self.profile?.publications, indexPath.row < publications.count else {
            return
        }
        let publication = publications[indexPath.row]
        self.presentTextPrompt(
            title: "Текст публикации",
            initialValue: publication.text,
            actionTitle: "Дальше"
        ) { [weak self] text in
            self?.presentTextPrompt(
                title: "Просмотры",
                initialValue: "\(publication.viewCount)",
                keyboardType: .numberPad,
                actionTitle: "Сохранить"
            ) { [weak self] views in
                self?.updateProfile { profile in
                    guard let index = profile.publications.firstIndex(where: { $0.id == publication.id }) else {
                        return
                    }
                    profile.publications[index].text = text
                    profile.publications[index].viewCount = max(0, Int(views) ?? 0)
                }
            }
        }
    }

    override func addItem() {
        self.presentTextPrompt(
            title: "Новая публикация",
            placeholder: "Текст",
            actionTitle: "Дальше"
        ) { [weak self] text in
            self?.presentTextPrompt(
                title: "Просмотры",
                placeholder: "0",
                keyboardType: .numberPad,
                actionTitle: "Добавить"
            ) { [weak self] views in
                self?.collectOptionalMedia { [weak self] mediaFileName in
                    self?.updateProfile { profile in
                        profile.publications.append(DemoPublication(
                            text: text,
                            mediaFileName: mediaFileName,
                            viewCount: Int(views) ?? 0
                        ))
                    }
                }
            }
        }
    }
}

final class DemoProfileGiftsController: DemoProfileContentController {
    init(context: AccountContext, profileId: UUID) {
        super.init(context: context, profileId: profileId, title: "Подарки профиля")
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.profile?.gifts.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let gifts = self.profile?.gifts, indexPath.row < gifts.count else {
            return UITableViewCell()
        }
        let gift = gifts[indexPath.row]
        return self.configuredCell(
            title: gift.title,
            subtitle: gift.slug.map { "t.me/nft/\($0)" } ?? "Локальный подарок",
            symbol: "gift.fill",
            color: .systemPink,
            accessory: .none
        )
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard let gifts = self.profile?.gifts, indexPath.row < gifts.count else {
            return nil
        }
        let gift = gifts[indexPath.row]
        return UISwipeActionsConfiguration(actions: [
            UIContextualAction(style: .destructive, title: "Удалить", handler: { [weak self] _, _, completion in
                self?.updateProfile { profile in
                    profile.gifts.removeAll(where: { $0.id == gift.id })
                }
                completion(true)
            })
        ])
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let gifts = self.profile?.gifts, indexPath.row < gifts.count else {
            return
        }
        let gift = gifts[indexPath.row]
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
                self?.updateProfile { profile in
                    guard let index = profile.gifts.firstIndex(where: { $0.id == gift.id }) else {
                        return
                    }
                    profile.gifts[index].title = title
                    profile.gifts[index].slug = slug.isEmpty ? nil : slug
                }
            }
        }
    }

    override func addItem() {
        self.presentTextPrompt(
            title: "Название подарка",
            placeholder: "Plush Pepe",
            actionTitle: "Дальше"
        ) { [weak self] title in
            self?.presentTextPrompt(
                title: "Slug или номер",
                placeholder: "PlushPepe-1234",
                actionTitle: "Добавить"
            ) { [weak self] slug in
                self?.updateProfile { profile in
                    profile.gifts.append(DemoGift(
                        slug: slug.isEmpty ? nil : slug,
                        title: title.isEmpty ? "Telegram Gift" : title
                    ))
                }
            }
        }
    }
}
