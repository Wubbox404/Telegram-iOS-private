import Foundation
import UIKit
import AccountContext
import DemoStudioCore

final class DemoStarsController: DemoStudioTableController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let store = DemoStudioStore.shared
    private var observer: NSObjectProtocol?
    private var iconTransactionId: UUID?

    init(context: AccountContext) {
        super.init(context: context, title: "Звёзды Telegram", style: .insetGrouped)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Операция",
            style: .plain,
            target: self,
            action: #selector(self.addTransaction)
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

    private var transactions: [DemoStarsTransaction] {
        return self.store.document.starsTransactions.sorted { $0.date > $1.date }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : max(1, self.transactions.count)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Баланс" : "История операций"
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            return self.configuredCell(
                title: "Изменить баланс",
                detail: "⭐️ \(self.store.document.starsBalance)",
                symbol: "star.fill",
                color: .systemOrange
            )
        }
        let transactions = self.transactions
        if transactions.isEmpty {
            let cell = self.configuredCell(
                title: "История пока пуста",
                subtitle: "Нажмите «Операция» сверху",
                symbol: "clock.arrow.circlepath",
                color: .systemOrange,
                accessory: .none
            )
            cell.selectionStyle = .none
            return cell
        }
        guard indexPath.row < transactions.count else {
            return UITableViewCell()
        }
        let transaction = transactions[indexPath.row]
        let sign = transaction.direction == .incoming ? "+" : "−"
        let kindTitle = transaction.kind?.title
        let statusTitle: String?
        if transaction.isFailed == true {
            statusTitle = "Ошибка"
        } else if transaction.isPending == true {
            statusTitle = "В обработке"
        } else {
            statusTitle = nil
        }
        let cell = self.configuredCell(
            title: transaction.title.isEmpty ? transaction.peerName : transaction.title,
            subtitle: [
                kindTitle,
                transaction.peerName,
                statusTitle,
                Self.dateFormatter.string(from: transaction.date)
            ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " • "),
            accessory: .none
        )
        let amountLabel = UILabel()
        amountLabel.text = "\(sign)\(transaction.amount) ⭐️"
        amountLabel.font = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
        amountLabel.textColor = transaction.direction == .incoming ? .systemGreen : .systemRed
        amountLabel.sizeToFit()
        cell.accessoryView = amountLabel
        if let url = self.store.assetURL(fileName: transaction.iconFileName),
           let image = UIImage(contentsOfFile: url.path) {
            cell.imageView?.image = image
        } else {
            cell.imageView?.image = DemoStudioColors.image(
                symbol: transaction.direction == .incoming ? "arrow.down" : "arrow.up",
                background: transaction.direction == .incoming ? .systemGreen : .systemRed
            )
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            self.presentTextPrompt(
                title: "Баланс Stars",
                placeholder: "0",
                initialValue: "\(self.store.document.starsBalance)",
                keyboardType: .numberPad
            ) { [weak self] value in
                self?.store.update { document in
                    document.starsBalance = max(0, Int64(value) ?? 0)
                }
            }
            return
        }
        let transactions = self.transactions
        guard indexPath.row < transactions.count else {
            return
        }
        self.presentTransactionActions(transactions[indexPath.row], sourceRect: tableView.rectForRow(at: indexPath))
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 1 else {
            return nil
        }
        let transactions = self.transactions
        guard indexPath.row < transactions.count else {
            return nil
        }
        let transaction = transactions[indexPath.row]
        return UISwipeActionsConfiguration(actions: [
            UIContextualAction(style: .destructive, title: "Удалить", handler: { [weak self] _, _, completion in
                self?.store.update { document in
                    document.starsTransactions.removeAll(where: { $0.id == transaction.id })
                }
                completion(true)
            })
        ])
    }

    @objc private func addTransaction() {
        let sheet = UIAlertController(title: "Тип операции", message: nil, preferredStyle: .actionSheet)
        for kind in DemoStarsTransaction.Kind.allCases {
            sheet.addAction(UIAlertAction(title: kind.title, style: .default, handler: { [weak self] _ in
                self?.chooseDirection(kind: kind, existing: nil)
            }))
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = self.navigationItem.rightBarButtonItem
        self.present(sheet, animated: true)
    }

    private func collectTransaction(
        direction: DemoStarsTransaction.Direction,
        kind: DemoStarsTransaction.Kind,
        existing: DemoStarsTransaction?
    ) {
        self.presentTextPrompt(
            title: direction == .incoming ? "Сколько зачислено?" : "Сколько списано?",
            placeholder: "50",
            initialValue: existing.map { "\($0.amount)" } ?? "",
            keyboardType: .numberPad,
            actionTitle: "Дальше"
        ) { [weak self] amountText in
            let amount = max(0, Int64(amountText) ?? 0)
            self?.presentTextPrompt(
                title: "Название операции",
                placeholder: "Подарок Вам",
                initialValue: existing?.title ?? "",
                actionTitle: "Дальше"
            ) { [weak self] title in
                self?.presentTextPrompt(
                    title: "Имя или ник",
                    placeholder: "@username",
                    initialValue: existing?.peerName ?? "",
                    actionTitle: "Дальше"
                ) { [weak self] peerName in
                    self?.presentTextPrompt(
                        title: "Дата и время",
                        placeholder: "2026-07-26 18:50",
                        initialValue: Self.inputDateFormatter.string(from: existing?.date ?? Date()),
                        actionTitle: existing == nil ? "Добавить" : "Сохранить"
                    ) { [weak self] dateText in
                        let transaction = DemoStarsTransaction(
                            id: existing?.id ?? UUID(),
                            direction: direction,
                            amount: amount,
                            title: title,
                            peerName: peerName,
                            date: Self.inputDateFormatter.date(from: dateText) ?? Date(),
                            iconFileName: existing?.iconFileName,
                            kind: kind,
                            isPending: existing?.isPending,
                            isFailed: existing?.isFailed
                        )
                        self?.store.update { document in
                            if let index = document.starsTransactions.firstIndex(where: { $0.id == transaction.id }) {
                                document.starsTransactions[index] = transaction
                            } else {
                                document.starsTransactions.append(transaction)
                            }
                        }
                    }
                }
            }
        }
    }

    private func presentTransactionActions(_ transaction: DemoStarsTransaction, sourceRect: CGRect) {
        let sheet = UIAlertController(title: transaction.title, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Изменить", style: .default, handler: { [weak self] _ in
            self?.chooseDirectionForEditing(transaction)
        }))
        sheet.addAction(UIAlertAction(title: "Статус операции", style: .default, handler: { [weak self] _ in
            self?.chooseStatus(transaction)
        }))
        sheet.addAction(UIAlertAction(title: "Выбрать иконку из Фото", style: .default, handler: { [weak self] _ in
            self?.iconTransactionId = transaction.id
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.allowsEditing = true
            picker.delegate = self
            self?.present(picker, animated: true)
        }))
        sheet.addAction(UIAlertAction(title: "Удалить", style: .destructive, handler: { [weak self] _ in
            self?.store.update { document in
                document.starsTransactions.removeAll(where: { $0.id == transaction.id })
            }
        }))
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        sheet.popoverPresentationController?.sourceView = self.view
        sheet.popoverPresentationController?.sourceRect = sourceRect
        self.present(sheet, animated: true)
    }

    private func chooseStatus(_ transaction: DemoStarsTransaction) {
        let sheet = UIAlertController(title: "Статус операции", message: nil, preferredStyle: .actionSheet)
        let values: [(String, Bool?, Bool?)] = [
            ("Завершена", nil, nil),
            ("В обработке", true, false),
            ("Ошибка", false, true)
        ]
        for (title, isPending, isFailed) in values {
            sheet.addAction(UIAlertAction(title: title, style: .default, handler: { [weak self] _ in
                self?.store.update { document in
                    guard let index = document.starsTransactions.firstIndex(where: { $0.id == transaction.id }) else {
                        return
                    }
                    document.starsTransactions[index].isPending = isPending
                    document.starsTransactions[index].isFailed = isFailed
                }
            }))
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        sheet.popoverPresentationController?.sourceView = self.view
        sheet.popoverPresentationController?.sourceRect = CGRect(
            x: self.view.bounds.midX,
            y: self.view.bounds.maxY,
            width: 1.0,
            height: 1.0
        )
        self.present(sheet, animated: true)
    }

    private func chooseDirectionForEditing(_ transaction: DemoStarsTransaction) {
        self.chooseDirection(kind: transaction.kind ?? .custom, existing: transaction)
    }

    private func chooseDirection(
        kind: DemoStarsTransaction.Kind,
        existing: DemoStarsTransaction?
    ) {
        let sheet = UIAlertController(title: "Тип операции", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Зачисление", style: .default, handler: { [weak self] _ in
            self?.collectTransaction(direction: .incoming, kind: kind, existing: existing)
        }))
        sheet.addAction(UIAlertAction(title: "Списание", style: .default, handler: { [weak self] _ in
            self?.collectTransaction(direction: .outgoing, kind: kind, existing: existing)
        }))
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        sheet.popoverPresentationController?.sourceView = self.view
        sheet.popoverPresentationController?.sourceRect = CGRect(
            x: self.view.bounds.midX,
            y: self.view.bounds.maxY,
            width: 1.0,
            height: 1.0
        )
        self.present(sheet, animated: true)
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true)
        guard let transactionId = self.iconTransactionId,
              let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage),
              let data = DemoStudioAvatarPipeline.jpegData(from: image, side: 256.0),
              let fileName = self.store.writeAsset(data: data, fileExtension: "jpg") else {
            self.iconTransactionId = nil
            return
        }
        self.store.update { document in
            guard let index = document.starsTransactions.firstIndex(where: { $0.id == transactionId }) else {
                return
            }
            document.starsTransactions[index].iconFileName = fileName
        }
        self.iconTransactionId = nil
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        self.iconTransactionId = nil
    }

    private static let inputDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter
    }()
}
