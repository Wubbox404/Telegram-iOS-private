import Foundation

enum DemoModeCredentials {
    static let displayedPhoneNumber = "+1 111 111 111"
    static let code = "000000"

    static func normalizedDigits(_ value: String) -> String {
        return value.filter(\.isNumber)
    }

    static func matchesPhoneNumber(_ value: String) -> Bool {
        let value = self.normalizedDigits(value)
        // Accept both the exact demo number and the common extra-digit variant
        // produced by some country-code formatters.
        return value == "1111111111" || value == "11111111111"
    }

    static func matchesCode(_ value: String) -> Bool {
        return self.normalizedDigits(value) == self.code
    }
}

struct DemoProfile: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var username: String
    var phone: String
    var about: String
    var country: String
    var registration: String
    var accentHex: String
    var avatarData: Data?
    var isContact: Bool

    init(
        id: UUID = UUID(),
        name: String,
        username: String = "",
        phone: String = "",
        about: String = "",
        country: String = "Россия",
        registration: String = "Июль 2026",
        accentHex: String = "#3390EC",
        avatarData: Data? = nil,
        isContact: Bool = true
    ) {
        self.id = id
        self.name = name
        self.username = username
        self.phone = phone
        self.about = about
        self.country = country
        self.registration = registration
        self.accentHex = accentHex
        self.avatarData = avatarData
        self.isContact = isContact
    }
}

struct DemoMessage: Codable, Equatable, Identifiable {
    var id: UUID
    var text: String
    var timestamp: Date
    var isOutgoing: Bool
    var replyToMessageId: UUID?

    init(
        id: UUID = UUID(),
        text: String,
        timestamp: Date = Date(),
        isOutgoing: Bool,
        replyToMessageId: UUID? = nil
    ) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.isOutgoing = isOutgoing
        self.replyToMessageId = replyToMessageId
    }
}

struct DemoChat: Codable, Equatable, Identifiable {
    var id: UUID
    var profile: DemoProfile
    var messages: [DemoMessage]
    var unreadCount: Int
    var isPinned: Bool
    var isMuted: Bool

    init(
        id: UUID = UUID(),
        profile: DemoProfile,
        messages: [DemoMessage] = [],
        unreadCount: Int = 0,
        isPinned: Bool = false,
        isMuted: Bool = false
    ) {
        self.id = id
        self.profile = profile
        self.messages = messages
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.isMuted = isMuted
    }

    var lastMessage: DemoMessage? {
        return self.messages.max(by: { $0.timestamp < $1.timestamp })
    }
}

struct DemoStory: Codable, Equatable, Identifiable {
    var id: UUID
    var authorName: String
    var caption: String
    var timestamp: Date
    var imageData: Data?
    var accentHex: String
    var isViewed: Bool

    init(
        id: UUID = UUID(),
        authorName: String,
        caption: String,
        timestamp: Date = Date(),
        imageData: Data? = nil,
        accentHex: String = "#8D5CF6",
        isViewed: Bool = false
    ) {
        self.id = id
        self.authorName = authorName
        self.caption = caption
        self.timestamp = timestamp
        self.imageData = imageData
        self.accentHex = accentHex
        self.isViewed = isViewed
    }
}

struct DemoStarsTransaction: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var subtitle: String
    var amount: Int
    var timestamp: Date

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        amount: Int,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.amount = amount
        self.timestamp = timestamp
    }
}

struct DemoAccountSnapshot: Codable, Equatable {
    var owner: DemoProfile
    var starBalance: Int
    var chats: [DemoChat]
    var stories: [DemoStory]
    var starTransactions: [DemoStarsTransaction]

    static func starter() -> DemoAccountSnapshot {
        let owner = DemoProfile(
            name: "Demo User",
            username: "demo",
            phone: DemoModeCredentials.displayedPhoneNumber,
            about: "Локальный демонстрационный аккаунт",
            country: "США",
            registration: "Июль 2026",
            accentHex: "#8D5CF6"
        )

        let alex = DemoProfile(
            name: "Алекс",
            username: "alex_demo",
            about: "Демонстрационный профиль",
            country: "Россия",
            registration: "Апрель 2020",
            accentHex: "#3390EC",
            isContact: false
        )
        let mira = DemoProfile(
            name: "Мира",
            username: "mira_demo",
            about: "Демонстрационный профиль",
            country: "Бразилия",
            registration: "Декабрь 2018",
            accentHex: "#B66AF0",
            isContact: false
        )

        let now = Date()
        let alexChat = DemoChat(
            profile: alex,
            messages: [
                DemoMessage(text: "Здравствуйте", timestamp: now.addingTimeInterval(-3400), isOutgoing: false),
                DemoMessage(text: "Есть минутка обсудить проект?", timestamp: now.addingTimeInterval(-3320), isOutgoing: false),
                DemoMessage(text: "Да, конечно", timestamp: now.addingTimeInterval(-3200), isOutgoing: true),
                DemoMessage(text: "Отлично, буду ждать", timestamp: now.addingTimeInterval(-180), isOutgoing: false)
            ],
            unreadCount: 1,
            isPinned: true
        )
        let miraChat = DemoChat(
            profile: mira,
            messages: [
                DemoMessage(text: "Привет! Это локальная демонстрация.", timestamp: now.addingTimeInterval(-7800), isOutgoing: false),
                DemoMessage(text: "Выглядит отлично", timestamp: now.addingTimeInterval(-7500), isOutgoing: true)
            ],
            unreadCount: 0
        )

        return DemoAccountSnapshot(
            owner: owner,
            starBalance: 27,
            chats: [alexChat, miraChat],
            stories: [
                DemoStory(authorName: "Demo User", caption: "Первая демонстрационная история", timestamp: now.addingTimeInterval(-900)),
                DemoStory(authorName: "Алекс", caption: "Добро пожаловать в Demo Mode", timestamp: now.addingTimeInterval(-1800), accentHex: "#3390EC")
            ],
            starTransactions: [
                DemoStarsTransaction(title: "Подарок", subtitle: "Начисление", amount: 50, timestamp: now.addingTimeInterval(-86000)),
                DemoStarsTransaction(title: "Передача подарка", subtitle: "Списание", amount: -25, timestamp: now.addingTimeInterval(-92000))
            ]
        )
    }
}
