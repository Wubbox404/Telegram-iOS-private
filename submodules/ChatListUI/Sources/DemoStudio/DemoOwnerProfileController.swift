import Foundation
import UIKit
import Display
import AccountContext
import DemoStudioCore

final class DemoOwnerProfileController: DemoStudioTableController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private enum Section: Int, CaseIterable {
        case enabled
        case fields
        case gifts
    }

    private let store = DemoStudioStore.shared
    private var value: DemoOwnerProfileOverride
    private var observer: NSObjectProtocol?

    init(context: AccountContext) {
        self.value = DemoStudioStore.shared.document.ownerProfile
        super.init(context: context, title: "Мой визуальный профиль")
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
            guard let self else {
                return
            }
            self.value.gifts = self.store.document.ownerProfile.gifts
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
        case .enabled:
            return 1
        case .fields:
            return 7
        case .gifts:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else {
            return nil
        }
        switch section {
        case .enabled:
            return "Профиль"
        case .fields:
            return "Видимые поля"
        case .gifts:
            return "Профиль"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == Section.enabled.rawValue {
            return "Это только визуальные значения в данной сборке. Настоящие имя, username и номер аккаунта на сервере не меняются."
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        switch section {
        case .enabled:
            let cell = self.configuredCell(title: "Использовать визуальную подмену", accessory: .none)
            let toggle = UISwitch()
            toggle.isOn = self.value.isEnabled
            toggle.addTarget(self, action: #selector(self.toggleEnabled(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            return cell
        case .fields:
            switch indexPath.row {
            case 0:
                return self.configuredCell(title: "Имя", detail: self.value.firstName)
            case 1:
                return self.configuredCell(title: "Фамилия", detail: self.value.lastName)
            case 2:
                return self.configuredCell(
                    title: "Username",
                    detail: self.value.username.isEmpty ? "Не задан" : "@\(self.value.username)"
                )
            case 3:
                return self.configuredCell(title: "Номер телефона", detail: self.value.phone)
            case 4:
                return self.configuredCell(title: "О себе", subtitle: self.value.bio)
            case 5:
                return self.configuredCell(
                    title: "Фотография",
                    detail: self.value.avatarFileName == nil ? "Не выбрана" : "Выбрана",
                    symbol: "photo.fill",
                    color: .systemBlue
                )
            default:
                return self.configuredCell(
                    title: "Очистить локальные поля",
                    symbol: "xmark.circle.fill",
                    color: .systemRed,
                    accessory: .none
                )
            }
        case .gifts:
            return self.configuredCell(
                title: "Подарки в моём профиле",
                detail: "\(self.value.gifts.count)",
                symbol: "gift.fill",
                color: .systemPink
            )
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section) else {
            return
        }
        switch section {
        case .enabled:
            break
        case .fields:
            self.editField(row: indexPath.row)
        case .gifts:
            self.saveValue()
            self.push(DemoGiftsController(context: self.context))
        }
    }

    private func editField(row: Int) {
        switch row {
        case 0:
            self.prompt(title: "Имя", value: self.value.firstName) { [weak self] value in
                self?.value.firstName = value
            }
        case 1:
            self.prompt(title: "Фамилия", value: self.value.lastName) { [weak self] value in
                self?.value.lastName = value
            }
        case 2:
            self.prompt(title: "Username", value: self.value.username, placeholder: "@username") { [weak self] value in
                self?.value.username = DemoProfile.normalizedUsername(value)
            }
        case 3:
            self.prompt(title: "Номер телефона", value: self.value.phone, keyboardType: .phonePad) { [weak self] value in
                self?.value.phone = value
            }
        case 4:
            self.prompt(title: "О себе", value: self.value.bio) { [weak self] value in
                self?.value.bio = value
            }
        case 5:
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.allowsEditing = true
            picker.delegate = self
            self.present(picker, animated: true)
        default:
            self.value = DemoOwnerProfileOverride(isEnabled: self.value.isEnabled, gifts: self.value.gifts)
            self.tableView.reloadData()
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

    @objc private func toggleEnabled(_ sender: UISwitch) {
        self.value.isEnabled = sender.isOn
    }

    @objc private func save() {
        self.saveValue()
        let _ = (self.navigationController as? NavigationController)?.popViewController(animated: true)
    }

    private func saveValue() {
        let value = self.value
        self.store.update { document in
            document.ownerProfile = value
        }
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        guard let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage),
              let data = DemoStudioAvatarPipeline.jpegData(from: image),
              let fileName = self.store.writeAsset(data: data, fileExtension: "jpg") else {
            return
        }
        self.value.avatarFileName = fileName
        self.saveValue()
        self.tableView.reloadData()
    }
}
