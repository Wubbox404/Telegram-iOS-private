import Foundation

public enum DemoMessageAuthor: String, Codable, CaseIterable {
    case owner
    case profile
}

public enum DemoMessageDeliveryState: String, Codable, CaseIterable {
    case sent
    case read
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
    public var isContact: Bool
    public var sourceUsername: String?
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
        isContact: Bool = false,
        sourceUsername: String? = nil,
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
        self.ratingLevel = min(10, max(0, ratingLevel))
        self.isContact = isContact
        self.sourceUsername = sourceUsername
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

    public init(
        id: UUID = UUID(),
        author: DemoMessageAuthor,
        text: String,
        timestamp: Date = Date(),
        deliveryState: DemoMessageDeliveryState = .read,
        replyToMessageId: UUID? = nil,
        mediaFileName: String? = nil,
        gift: DemoGift? = nil
    ) {
        self.id = id
        self.author = author
        self.text = text
        self.timestamp = timestamp
        self.deliveryState = deliveryState
        self.replyToMessageId = replyToMessageId
        self.mediaFileName = mediaFileName
        self.gift = gift
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

    public var id: UUID
    public var direction: Direction
    public var amount: Int64
    public var title: String
    public var peerName: String
    public var date: Date
    public var iconFileName: String?

    public init(
        id: UUID = UUID(),
        direction: Direction,
        amount: Int64,
        title: String,
        peerName: String,
        date: Date = Date(),
        iconFileName: String? = nil
    ) {
        self.id = id
        self.direction = direction
        self.amount = max(0, amount)
        self.title = title
        self.peerName = peerName
        self.date = date
        self.iconFileName = iconFileName
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
        schemaVersion: Int = 2,
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
