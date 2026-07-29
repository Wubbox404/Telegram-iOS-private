import Foundation

public extension Notification.Name {
    static let demoStudioDidChange = Notification.Name("org.telegram.DemoStudio.didChange")
}

public final class DemoStudioStore {
    public static let shared = DemoStudioStore()

    private let lock = NSRecursiveLock()
    private var scope = "default"
    private var documentValue = DemoStudioDocument()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private init() {
        self.loadLocked()
    }

    public func activate(scope: String) {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        let normalized = self.normalizedScope(scope)
        guard normalized != self.scope else {
            return
        }
        self.scope = normalized
        self.loadLocked()
    }

    public var document: DemoStudioDocument {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.documentValue
    }

    public func update(_ transform: (inout DemoStudioDocument) -> Void) {
        self.lock.lock()
        transform(&self.documentValue)
        self.normalizeLocked()
        self.saveLocked()
        self.lock.unlock()

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .demoStudioDidChange, object: self)
        }
    }

    @discardableResult
    public func upsertProfile(_ profile: DemoProfile, createChat: Bool = false) -> UUID {
        self.update { document in
            if let index = document.profiles.firstIndex(where: { $0.id == profile.id }) {
                document.profiles[index] = profile
            } else {
                document.profiles.append(profile)
            }
            if createChat && !document.chats.contains(where: { $0.profileId == profile.id }) {
                document.chats.append(DemoChat(profileId: profile.id))
            }
        }
        return profile.id
    }

    public func removeProfile(id: UUID) {
        self.update { document in
            document.profiles.removeAll(where: { $0.id == id })
            document.chats.removeAll(where: { $0.profileId == id })
        }
        self.removeAssetDirectory(id: id)
    }

    @discardableResult
    public func createChat(profileId: UUID) -> UUID {
        if let existing = self.document.chats.first(where: { $0.profileId == profileId }) {
            return existing.id
        }
        let chat = DemoChat(profileId: profileId)
        self.update { document in
            document.chats.append(chat)
        }
        return chat.id
    }

    public func updateChat(id: UUID, _ transform: (inout DemoChat) -> Void) {
        self.update { document in
            guard let index = document.chats.firstIndex(where: { $0.id == id }) else {
                return
            }
            transform(&document.chats[index])
            document.chats[index].updatedAt = Date()
        }
    }

    public func removeChat(id: UUID) {
        self.update { document in
            document.chats.removeAll(where: { $0.id == id })
        }
        self.removeAssetDirectory(id: id)
    }

    public func appendMessage(chatId: UUID, message: DemoMessage) {
        self.updateChat(id: chatId) { chat in
            chat.messages.append(message)
            chat.draft = ""
            if message.author == .profile {
                chat.unreadCount += 1
            }
        }
    }

    public func markChatRead(id: UUID) {
        self.updateChat(id: id) { chat in
            chat.unreadCount = 0
        }
    }

    public func reset() {
        self.lock.lock()
        self.documentValue = DemoStudioDocument()
        self.saveLocked()
        let directory = self.assetsDirectory
        self.lock.unlock()

        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .demoStudioDidChange, object: self)
        }
    }

    public func writeAsset(data: Data, fileExtension: String, ownerId: UUID? = nil) -> String? {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        let extensionValue = fileExtension
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            .lowercased()
        let fileName = "\(UUID().uuidString).\(extensionValue.isEmpty ? "dat" : extensionValue)"
        let relativePath: String
        let directory: URL
        if let ownerId {
            relativePath = "\(ownerId.uuidString)/\(fileName)"
            directory = self.assetsDirectory.appendingPathComponent(ownerId.uuidString, isDirectory: true)
        } else {
            relativePath = fileName
            directory = self.assetsDirectory
        }
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try data.write(to: self.assetsDirectory.appendingPathComponent(relativePath), options: [.atomic])
            return relativePath
        } catch {
            return nil
        }
    }

    public func assetURL(fileName: String?) -> URL? {
        guard let fileName, !fileName.isEmpty else {
            return nil
        }
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        let url = self.assetsDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    private var baseDirectory: URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return applicationSupport
            .appendingPathComponent("TelegramDemoStudio", isDirectory: true)
            .appendingPathComponent(self.scope, isDirectory: true)
    }

    private var documentURL: URL {
        return self.baseDirectory.appendingPathComponent("demo-studio-v2.json")
    }

    private var assetsDirectory: URL {
        return self.baseDirectory.appendingPathComponent("assets", isDirectory: true)
    }

    private func normalizedScope(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let result = value.unicodeScalars
            .map { allowed.contains($0) ? String($0) : "_" }
            .joined()
        return result.isEmpty ? "default" : result
    }

    private func loadLocked() {
        do {
            try FileManager.default.createDirectory(
                at: self.baseDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            try FileManager.default.createDirectory(
                at: self.assetsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try Data(contentsOf: self.documentURL)
            self.documentValue = try self.decoder.decode(DemoStudioDocument.self, from: data)
            self.normalizeLocked()
        } catch {
            self.documentValue = DemoStudioDocument()
            self.saveLocked()
        }
    }

    private func normalizeLocked() {
        self.documentValue.schemaVersion = 3
        self.documentValue.starsBalance = max(0, self.documentValue.starsBalance)

        var profileIds = Set<UUID>()
        self.documentValue.profiles = self.documentValue.profiles.map { value in
            var profile = value
            profile.username = DemoProfile.normalizedUsername(profile.username)
            profile.ratingLevel = max(0, profile.ratingLevel)
            profile.ratingStars = profile.ratingStars.map { max(0, $0) }
            profile.ratingCurrentLevelStars = profile.ratingCurrentLevelStars.map { max(0, $0) }
            profile.ratingNextLevelStars = profile.ratingNextLevelStars.map { max(0, $0) }
            profileIds.insert(profile.id)
            return profile
        }

        var chatIds = Set<UUID>()
        self.documentValue.chats = self.documentValue.chats.filter { chat in
            guard profileIds.contains(chat.profileId), !chatIds.contains(chat.id) else {
                return false
            }
            chatIds.insert(chat.id)
            return true
        }.map { value in
            var chat = value
            chat.unreadCount = max(0, chat.unreadCount)
            return chat
        }
    }

    private func saveLocked() {
        do {
            try FileManager.default.createDirectory(
                at: self.baseDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try self.encoder.encode(self.documentValue)
            try data.write(to: self.documentURL, options: [.atomic])
        } catch {
        }
    }

    private func removeAssetDirectory(id: UUID) {
        self.lock.lock()
        let directory = self.assetsDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
        self.lock.unlock()
        try? FileManager.default.removeItem(at: directory)
    }
}
