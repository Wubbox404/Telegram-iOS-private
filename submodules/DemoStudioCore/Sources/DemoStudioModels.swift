import Foundation

public enum DemoMessageAuthor: String, Codable, CaseIterable {
    case owner
    case profile
}

public enum DemoMessageDeliveryState: String, Codable, CaseIterable {
    case sent
    case read
}

public enum DemoMessageKind: String, Codable, CaseIterable {
    case text
    case photo
    case video
    case voice
    case videoMessage
    case music
    case document
    case sticker
    case animation
    case contact
    case location
    case poll
    case premiumGift
    case starsGift
    case starGift
    case phoneCall
    case screenshot
    case autoDelete
    case pinnedMessage
    case historyCleared
    case paidMessagesRefunded
    case paidMessagesPrice
    case service

    public var title: String {
        switch self {
        case .text: return "Текст"
        case .photo: return "Фотография"
        case .video: return "Видео"
        case .voice: return "Голосовое сообщение"
        case .videoMessage: return "Видеосообщение"
        case .music: return "Музыка"
        case .document: return "Файл"
        case .sticker: return "Стикер"
        case .animation: return "GIF"
        case .contact: return "Контакт"
        case .location: return "Геопозиция"
        case .poll: return "Опрос"
        case .premiumGift: return "Подарок Telegram Premium"
        case .starsGift: return "Подарок Stars"
        case .starGift: return "Telegram Gift"
        case .phoneCall: return "Звонок"
        case .screenshot: return "Снимок экрана"
        case .autoDelete: return "Автоудаление"
        case .pinnedMessage: return "Закреплённое сообщение"
        case .historyCleared: return "История очищена"
        case .paidMessagesRefunded: return "Возврат платных сообщений"
        case .paidMessagesPrice: return "Цена платных сообщений"
        case .service: return "Системное сообщение"
        }
    }
}

public struct DemoPublication: Codable, Equatable, Identifiable {
    public var id: UUID
    public var text: String
    public var mediaFileName: String?
    public var timestamp: Date
    public var viewCount: Int

    public init(
        id: UUID = UUID(),
        text: String,
        mediaFileName: String? = nil,
        timestamp: Date = Date(),
        viewCount: Int = 0
    ) {
        self.id = id
        self.text = text
        self.mediaFileName = mediaFileName
        self.timestamp = timestamp
        self.viewCount = max(0, viewCount)
    }
}

public struct DemoStory: Codable, Equatable, Identifiable {
    public var id: UUID
    public var caption: String
    public var mediaFileName: String?
    public var timestamp: Date
    public var expiresAt: Date?
    public var isPinned: Bool
    public var viewCount: Int

    public init(
        id: UUID = UUID(),
        caption: String,
        mediaFileName: String? = nil,
        timestamp: Date = Date(),
        expiresAt: Date? = nil,
        isPinned: Bool = false,
        viewCount: Int = 0
    ) {
        self.id = id
        self.caption = caption
        self.mediaFileName = mediaFileName
        self.timestamp = timestamp
        self.expiresAt = expiresAt
        self.isPinned = isPinned
        self.viewCount = max(0, viewCount)
    }
}

public struct DemoGift: Codable, Equatable, Identifiable {
    public var id: UUID
    public var telegramGiftId: Int64?
    public var slug: String?
    public var title: String
    public var number: Int64?
    public var imageFileName: String?
    public var senderProfileId: UUID?
    public var receivedAt: Date
    public var displayedOnProfile: Bool

    public init(
        id: UUID = UUID(),
        telegramGiftId: Int64? = nil,
        slug: String? = nil,
        title: String,
        number: Int64? = nil,
        imageFileName: String? = nil,
        senderProfileId: UUID? = nil,
        receivedAt: Date = Date(),
        displayedOnProfile: Bool = false
    ) {
        self.id = id
        self.telegramGiftId = telegramGiftId
        self.slug = slug
        self.title = title
        self.number = number
        self.imageFileName = imageFileName
        self.senderProfileId = senderProfileId
        self.receivedAt = receivedAt
        self.displayedOnProfile = displayedOnProfile
    }
}

public struct DemoProfile: Codable, Equatable, Identifiable {
    public var id: UUID
    public var firstName: String
    public var lastName: String
    public var username: String
    public var phone: String
    public var country: String
    public var registrationDate: Date?
    public var bio: String
    public var avatarFileName: String?
    public var isPremium: Bool
    public var premiumEmoji: String
    public var premiumBackgroundHex: String
    public var ratingLevel: Int
    public var ratingStars: Int64?
    public var ratingCurrentLevelStars: Int64?
    public var ratingNextLevelStars: Int64?
    public var isContact: Bool
    public var sourceUsername: String?
    public var savedMusicTitle: String?
    public var savedMusicPerformer: String?
    public var stories: [DemoStory]
    public var publications: [DemoPublication]
    public var gifts: [DemoGift]

    public init(
        id: UUID = UUID(),
        firstName: String,
        lastName: String = "",
        username: String = "",
        phone: String = "",
        country: String = "",
        registrationDate: Date? = nil,
        bio: String = "",
        avatarFileName: String? = nil,
        isPremium: Bool = false,
        premiumEmoji: String = "⭐️",
        premiumBackgroundHex: String = "#6C5CE7",
        ratingLevel: Int = 0,
        ratingStars: Int64? = nil,
        ratingCurrentLevelStars: Int64? = nil,
        ratingNextLevelStars: Int64? = nil,
        isContact: Bool = false,
        sourceUsername: String? = nil,
        savedMusicTitle: String? = nil,
        savedMusicPerformer: String? = nil,
        stories: [DemoStory] = [],
        publications: [DemoPublication] = [],
        gifts: [DemoGift] = []
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.username = DemoProfile.normalizedUsername(username)
        self.phone = phone
        self.country = country
        self.registrationDate = registrationDate
        self.bio = bio
        self.avatarFileName = avatarFileName
        self.isPremium = isPremium
        self.premiumEmoji = premiumEmoji
        self.premiumBackgroundHex = premiumBackgroundHex
        self.ratingLevel = max(0, ratingLevel)
        self.ratingStars = ratingStars.map { max(0, $0) }
        self.ratingCurrentLevelStars = ratingCurrentLevelStars.map { max(0, $0) }
        self.ratingNextLevelStars = ratingNextLevelStars.map { max(0, $0) }
        self.isContact = isContact
        self.sourceUsername = sourceUsername
        self.savedMusicTitle = savedMusicTitle
        self.savedMusicPerformer = savedMusicPerformer
        self.stories = stories
        self.publications = publications
        self.gifts = gifts
    }

    public var displayName: String {
        let value = "\(self.firstName) \(self.lastName)".trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Без имени" : value
    }

    public static func normalizedUsername(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.hasPrefix("@") {
            result.removeFirst()
        }
        return result
    }
}

public struct DemoMessage: Codable, Equatable, Identifiable {
    public var id: UUID
    public var author: DemoMessageAuthor
    public var text: String
    public var timestamp: Date
    public var deliveryState: DemoMessageDeliveryState
    public var replyToMessageId: UUID?
    public var mediaFileName: String?
    public var gift: DemoGift?
    public var kind: DemoMessageKind?
    public var secondaryText: String?
    public var amount: Int64?
    public var duration: Int?
    public var latitude: Double?
    public var longitude: Double?
    public var options: [String]?

    public init(
        id: UUID = UUID(),
        author: DemoMessageAuthor,
        text: String,
        timestamp: Date = Date(),
        deliveryState: DemoMessageDeliveryState = .read,
        replyToMessageId: UUID? = nil,
        mediaFileName: String? = nil,
        gift: DemoGift? = nil,
        kind: DemoMessageKind? = nil,
        secondaryText: String? = nil,
        amount: Int64? = nil,
        duration: Int? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        options: [String]? = nil
    ) {
        self.id = id
        self.author = author
        self.text = text
        self.timestamp = timestamp
        self.deliveryState = deliveryState
        self.replyToMessageId = replyToMessageId
        self.mediaFileName = mediaFileName
        self.gift = gift
        self.kind = kind
        self.secondaryText = secondaryText
        self.amount = amount
        self.duration = duration
        self.latitude = latitude
        self.longitude = longitude
        self.options = options
    }

    public var resolvedKind: DemoMessageKind {
        if let kind {
            return kind
        } else if self.gift != nil {
            return .starGift
        } else if self.mediaFileName != nil {
            return .photo
        } else {
            return .text
        }
    }
}

public struct DemoChat: Codable, Equatable, Identifiable {
    public var id: UUID
    public var profileId: UUID
    public var messages: [DemoMessage]
    public var isPinned: Bool
    public var isArchived: Bool
    public var isMuted: Bool
    public var unreadCount: Int
    public var draft: String
    public var wallpaperFileName: String?
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        profileId: UUID,
        messages: [DemoMessage] = [],
        isPinned: Bool = false,
        isArchived: Bool = false,
        isMuted: Bool = false,
        unreadCount: Int = 0,
        draft: String = "",
        wallpaperFileName: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.profileId = profileId
        self.messages = messages
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.isMuted = isMuted
        self.unreadCount = max(0, unreadCount)
        self.draft = draft
        self.wallpaperFileName = wallpaperFileName
        self.updatedAt = updatedAt
    }
}

public struct DemoStarsTransaction: Codable, Equatable, Identifiable {
    public enum Direction: String, Codable, CaseIterable {
        case incoming
        case outgoing
    }

    public enum Kind: String, Codable, CaseIterable {
        case purchase
        case gift
        case transfer
        case refund
        case reaction
        case subscription
        case paidMessage
        case starGift
        case starGiftUpgrade
        case starGiftResale
        case businessTransfer
        case giveaway
        case ads
        case apiExtension
        case postsSearch
        case auctionBid
        case liveStreamPaidMessage
        case custom

        public var title: String {
            switch self {
            case .purchase: return "Покупка Stars"
            case .gift: return "Подарок"
            case .transfer: return "Перевод"
            case .refund: return "Возврат"
            case .reaction: return "Платная реакция"
            case .subscription: return "Подписка"
            case .paidMessage: return "Платное сообщение"
            case .starGift: return "Telegram Gift"
            case .starGiftUpgrade: return "Улучшение подарка"
            case .starGiftResale: return "Перепродажа подарка"
            case .businessTransfer: return "Бизнес-перевод"
            case .giveaway: return "Розыгрыш"
            case .ads: return "Telegram Ads"
            case .apiExtension: return "Расширение API"
            case .postsSearch: return "Поиск публикаций"
            case .auctionBid: return "Ставка на аукционе"
            case .liveStreamPaidMessage: return "Сообщение в трансляции"
            case .custom: return "Другая операция"
            }
        }
    }

    public var id: UUID
    public var direction: Direction
    public var amount: Int64
    public var title: String
    public var peerName: String
    public var date: Date
    public var iconFileName: String?
    public var kind: Kind?
    public var isPending: Bool?
    public var isFailed: Bool?

    public init(
        id: UUID = UUID(),
        direction: Direction,
        amount: Int64,
        title: String,
        peerName: String,
        date: Date = Date(),
        iconFileName: String? = nil,
        kind: Kind? = nil,
        isPending: Bool? = nil,
        isFailed: Bool? = nil
    ) {
        self.id = id
        self.direction = direction
        self.amount = max(0, amount)
        self.title = title
        self.peerName = peerName
        self.date = date
        self.iconFileName = iconFileName
        self.kind = kind
        self.isPending = isPending
        self.isFailed = isFailed
    }

    public var signedAmount: Int64 {
        switch self.direction {
        case .incoming:
            return self.amount
        case .outgoing:
            return -self.amount
        }
    }
}

public struct DemoOwnerProfileOverride: Codable, Equatable {
    public var isEnabled: Bool
    public var firstName: String
    public var lastName: String
    public var username: String
    public var phone: String
    public var bio: String
    public var avatarFileName: String?
    public var gifts: [DemoGift]

    public init(
        isEnabled: Bool = false,
        firstName: String = "",
        lastName: String = "",
        username: String = "",
        phone: String = "",
        bio: String = "",
        avatarFileName: String? = nil,
        gifts: [DemoGift] = []
    ) {
        self.isEnabled = isEnabled
        self.firstName = firstName
        self.lastName = lastName
        self.username = DemoProfile.normalizedUsername(username)
        self.phone = phone
        self.bio = bio
        self.avatarFileName = avatarFileName
        self.gifts = gifts
    }
}

public struct DemoStudioDocument: Codable, Equatable {
    public var schemaVersion: Int
    public var profiles: [DemoProfile]
    public var chats: [DemoChat]
    public var starsBalance: Int64
    public var starsTransactions: [DemoStarsTransaction]
    public var ownerProfile: DemoOwnerProfileOverride

    public init(
        schemaVersion: Int = 3,
        profiles: [DemoProfile] = [],
        chats: [DemoChat] = [],
        starsBalance: Int64 = 0,
        starsTransactions: [DemoStarsTransaction] = [],
        ownerProfile: DemoOwnerProfileOverride = DemoOwnerProfileOverride()
    ) {
        self.schemaVersion = schemaVersion
        self.profiles = profiles
        self.chats = chats
        self.starsBalance = max(0, starsBalance)
        self.starsTransactions = starsTransactions
        self.ownerProfile = ownerProfile
    }
}
