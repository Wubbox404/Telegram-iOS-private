import Foundation

extension Notification.Name {
    static let demoModeStoreDidChange = Notification.Name("org.telegram.demoMode.storeDidChange")
}

final class DemoModeStore {
    static let shared = DemoModeStore()

    private let queue = DispatchQueue(label: "org.telegram.demoMode.store")
    private let fileURL: URL
    private var value: DemoAccountSnapshot

    var snapshot: DemoAccountSnapshot {
        return self.queue.sync {
            return self.value
        }
    }

    private init() {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TelegramDemoMode", isDirectory: true)
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        self.fileURL = baseURL.appendingPathComponent("account.json")

        if
            let data = try? Data(contentsOf: self.fileURL),
            let snapshot = try? JSONDecoder().decode(DemoAccountSnapshot.self, from: data)
        {
            self.value = snapshot
        } else {
            self.value = DemoAccountSnapshot.starter()
        }
    }

    private func mutate(_ body: (inout DemoAccountSnapshot) -> Void) {
        let updated: DemoAccountSnapshot = self.queue.sync {
            body(&self.value)
            if let data = try? JSONEncoder().encode(self.value) {
                try? data.write(to: self.fileURL, options: [.atomic])
            }
            return self.value
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .demoModeStoreDidChange, object: self, userInfo: ["snapshot": updated])
        }
    }

    func reset() {
        self.mutate { snapshot in
            snapshot = DemoAccountSnapshot.starter()
        }
    }

    func updateOwner(_ owner: DemoProfile) {
        self.mutate { snapshot in
            snapshot.owner = owner
        }
    }

    func setStarBalance(_ value: Int) {
        self.mutate { snapshot in
            snapshot.starBalance = max(0, value)
        }
    }

    func addStarsTransaction(title: String, subtitle: String, amount: Int) {
        self.mutate { snapshot in
            snapshot.starTransactions.insert(
                DemoStarsTransaction(title: title, subtitle: subtitle, amount: amount),
                at: 0
            )
            snapshot.starBalance = max(0, snapshot.starBalance + amount)
        }
    }

    func addChat(profile: DemoProfile) {
        self.mutate { snapshot in
            snapshot.chats.insert(DemoChat(profile: profile), at: 0)
        }
    }

    func updateChat(_ chat: DemoChat) {
        self.mutate { snapshot in
            guard let index = snapshot.chats.firstIndex(where: { $0.id == chat.id }) else {
                return
            }
            snapshot.chats[index] = chat
        }
    }

    func deleteChat(id: UUID) {
        self.mutate { snapshot in
            snapshot.chats.removeAll(where: { $0.id == id })
        }
    }

    func addMessage(chatId: UUID, text: String, isOutgoing: Bool) {
        self.mutate { snapshot in
            guard let index = snapshot.chats.firstIndex(where: { $0.id == chatId }) else {
                return
            }
            snapshot.chats[index].messages.append(DemoMessage(text: text, isOutgoing: isOutgoing))
            snapshot.chats[index].unreadCount = 0
        }
    }

    func addStory(_ story: DemoStory) {
        self.mutate { snapshot in
            snapshot.stories.insert(story, at: 0)
        }
    }

    func markStoryViewed(id: UUID) {
        self.mutate { snapshot in
            guard let index = snapshot.stories.firstIndex(where: { $0.id == id }) else {
                return
            }
            snapshot.stories[index].isViewed = true
        }
    }
}
