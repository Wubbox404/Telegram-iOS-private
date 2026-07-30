import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import DemoStudioCore

/// Materializes the editable Demo Studio document as normal Postbox records.
/// Telegram UI then consumes the same Peer / CachedUserData / StoreMessage
/// objects that it consumes for an ordinary personal chat.
final class DemoStudioPostboxBridge {
    static let shared = DemoStudioPostboxBridge()

    private var context: AccountContext?
    private var observer: NSObjectProtocol?
    private let syncDisposable = MetaDisposable()
    private var lastSynchronizedDocument: DemoStudioDocument?

    private init() {
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        self.syncDisposable.dispose()
    }

    func activate(context: AccountContext) {
        self.context = context
        self.lastSynchronizedDocument = nil
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        self.observer = NotificationCenter.default.addObserver(
            forName: .demoStudioDidChange,
            object: DemoStudioStore.shared,
            queue: .main
        ) { [weak self] _ in
            self?.synchronize()
        }
        self.synchronize()
    }

    func peerId(profileId: UUID) -> PeerId {
        return PeerId(
            namespace: Namespaces.Peer.CloudUser,
            id: PeerId.Id._internalFromInt64Value(Self.negativeStableId(profileId))
        )
    }

    private func synchronize() {
        guard let context else {
            return
        }
        let document = DemoStudioStore.shared.document
        if self.lastSynchronizedDocument == document {
            return
        }
        self.lastSynchronizedDocument = document
        let store = DemoStudioStore.shared
        let accountPeerId = context.account.peerId

        self.syncDisposable.set((context.account.postbox.transaction { transaction -> Void in
            var profilePeerIds: [UUID: PeerId] = [:]
            for profile in document.profiles {
                profilePeerIds[profile.id] = self.peerId(profileId: profile.id)
            }
            let intendedPeerIds = Set(profilePeerIds.values)
            let pinnedChats = document.chats
                .filter(\.isPinned)
                .sorted { lhs, rhs in
                    if lhs.updatedAt != rhs.updatedAt {
                        return lhs.updatedAt > rhs.updatedAt
                    }
                    return lhs.id.uuidString < rhs.id.uuidString
                }
            var pinningIndices: [UUID: UInt16] = [:]
            for (index, chat) in pinnedChats.enumerated() {
                pinningIndices[chat.id] = UInt16(clamping: index)
            }

            for peerId in transaction.chatListGetAllPeerIds() where Namespaces.Peer.isDemoStudioUser(peerId) {
                if !intendedPeerIds.contains(peerId) {
                    updateLocalProfileGifts(peerId: peerId, gifts: [])
                    transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
                    transaction.clearHistory(
                        peerId,
                        threadId: nil,
                        minTimestamp: nil,
                        maxTimestamp: nil,
                        namespaces: .all,
                        forEachMedia: nil
                    )
                }
            }

            for profile in document.profiles {
                guard let peerId = profilePeerIds[profile.id] else {
                    continue
                }
                let peer = Self.makePeer(profile: profile, peerId: peerId, store: store)
                transaction.updatePeersInternal([peer], update: { _, updated in
                    return updated
                })

                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                    var data = (current as? CachedUserData) ?? CachedUserData()
                    data = data.withUpdatedAbout(profile.bio.isEmpty ? nil : profile.bio)
                    data = data.withUpdatedStarGiftsCount(
                        profile.gifts.isEmpty ? nil : Int32(clamping: profile.gifts.count)
                    )
                    data = data.withUpdatedStarRating(Self.makeRating(profile: profile))
                    if !profile.gifts.isEmpty {
                        data = data.withUpdatedMainProfileTab(.gifts)
                    } else if profile.savedMusicTitle != nil {
                        data = data.withUpdatedMainProfileTab(.music)
                    } else {
                        data = data.withUpdatedMainProfileTab(nil)
                    }
                    data = data.withUpdatedSavedMusic(Self.makeSavedMusic(profile: profile))
                    return data
                })

                let presence = TelegramUserPresence(
                    status: .recently(isHidden: false),
                    lastActivity: Int32(Date().timeIntervalSince1970)
                )
                transaction.updatePeerPresencesInternal(
                    presences: [peerId: presence],
                    merge: { _, updated in updated }
                )
            }

            for profile in document.profiles {
                guard let peerId = profilePeerIds[profile.id] else {
                    continue
                }
                updateLocalProfileGifts(
                    peerId: peerId,
                    gifts: Self.makeProfileGifts(
                        profile.gifts,
                        profilePeerIds: profilePeerIds,
                        transaction: transaction,
                        store: store
                    )
                )
            }
            updateLocalProfileGifts(
                peerId: accountPeerId,
                gifts: Self.makeProfileGifts(
                    document.ownerProfile.gifts,
                    profilePeerIds: profilePeerIds,
                    transaction: transaction,
                    store: store,
                    forceHidden: true
                )
            )
            if !document.ownerProfile.gifts.isEmpty {
                transaction.updatePeerCachedData(peerIds: Set([accountPeerId]), update: { _, current in
                    var data = (current as? CachedUserData) ?? CachedUserData()
                    let visibleGiftCount = max(
                        data.starGiftsCount ?? 0,
                        Int32(clamping: document.ownerProfile.gifts.count)
                    )
                    data = data.withUpdatedStarGiftsCount(visibleGiftCount)
                    return data.withUpdatedMainProfileTab(.gifts)
                })
            }

            for profile in document.profiles {
                guard let peerId = profilePeerIds[profile.id] else {
                    continue
                }
                guard let chat = document.chats.first(where: { $0.profileId == profile.id }) else {
                    transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
                    continue
                }

                var desiredMessages: [MessageId: DemoMessage] = [:]
                for message in chat.messages {
                    let id = MessageId(
                        peerId: peerId,
                        namespace: Namespaces.Message.Local,
                        id: Self.messageId(message.id)
                    )
                    desiredMessages[id] = message
                }
                // Older Demo Studio builds materialized these records in the
                // cloud namespace. That makes ChatController wait for a server
                // history which can never exist for a synthetic peer.
                var legacyCloudMessageIds: [MessageId] = []
                transaction.withAllMessages(peerId: peerId, namespace: Namespaces.Message.Cloud) { message in
                    legacyCloudMessageIds.append(message.id)
                    return true
                }
                if !legacyCloudMessageIds.isEmpty {
                    transaction.deleteMessages(legacyCloudMessageIds, forEachMedia: nil)
                }

                var obsoleteMessageIds: [MessageId] = []
                transaction.withAllMessages(peerId: peerId, namespace: Namespaces.Message.Local) { message in
                    // Demo-authored records use negative ids. Telegram's own
                    // outgoing local messages use its normal positive id
                    // allocator and must survive subsequent Studio edits.
                    if message.id.id < 0 && desiredMessages[message.id] == nil {
                        obsoleteMessageIds.append(message.id)
                    }
                    return true
                }
                if !obsoleteMessageIds.isEmpty {
                    transaction.deleteMessages(obsoleteMessageIds, forEachMedia: nil)
                }

                var messagesToAdd: [StoreMessage] = []
                for (messageId, message) in desiredMessages {
                    let storeMessage = Self.makeMessage(
                        value: message,
                        id: messageId,
                        peerId: peerId,
                        accountPeerId: accountPeerId,
                        profile: profile,
                        store: store
                    )
                    if transaction.messageExists(id: messageId) {
                        transaction.updateMessage(messageId, update: { _ in
                            return .update(storeMessage)
                        })
                    } else {
                        messagesToAdd.append(storeMessage)
                    }
                }
                if !messagesToAdd.isEmpty {
                    let _ = transaction.addMessages(messagesToAdd, location: .Random)
                }

                transaction.updateCurrentPeerNotificationSettings([
                    peerId: TelegramPeerNotificationSettings(
                        muteState: chat.isMuted
                            ? .muted(until: Int32.max)
                            : .unmuted,
                        messageSound: .default,
                        displayPreviews: .default,
                        storySettings: .default
                    )
                ])

                let groupId: PeerGroupId = chat.isArchived
                    ? Namespaces.PeerGroup.archive
                    : .root
                transaction.updatePeerChatListInclusion(
                    peerId,
                    inclusion: .ifHasMessagesOrOneOf(
                        groupId: groupId,
                        pinningIndex: pinningIndices[chat.id],
                        minTimestamp: Int32(clamping: Int64(chat.updatedAt.timeIntervalSince1970))
                    )
                )
            }
        }).start())
    }

    private static func makePeer(
        profile: DemoProfile,
        peerId: PeerId,
        store: DemoStudioStore
    ) -> TelegramUser {
        var flags = UserInfoFlags()
        if profile.isPremium {
            flags.insert(.isPremium)
        }
        if profile.isContact {
            flags.insert(.mutualContact)
        }

        var representations: [TelegramMediaImageRepresentation] = []
        if let url = store.assetURL(fileName: profile.avatarFileName),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            representations.append(TelegramMediaImageRepresentation(
                dimensions: PixelDimensions(
                    width: Int32(clamping: Int(image.size.width * image.scale)),
                    height: Int32(clamping: Int(image.size.height * image.scale))
                ),
                resource: LocalFileReferenceMediaResource(
                    localFilePath: url.path,
                    randomId: Self.positiveStableId(
                        profile.id,
                        salt: profile.avatarFileName
                    )
                ),
                progressiveSizes: [],
                immediateThumbnailData: data,
                hasVideo: false,
                isPersonal: true
            ))
        }
        let usernames: [TelegramPeerUsername]
        if profile.username.isEmpty {
            usernames = []
        } else {
            usernames = [
                TelegramPeerUsername(flags: [.isActive], username: profile.username)
            ]
        }
        return TelegramUser(
            id: peerId,
            accessHash: nil,
            firstName: profile.firstName,
            lastName: profile.lastName.isEmpty ? nil : profile.lastName,
            username: profile.username.isEmpty ? nil : profile.username,
            phone: profile.phone.isEmpty ? nil : profile.phone,
            photo: representations,
            botInfo: nil,
            restrictionInfo: nil,
            flags: flags,
            emojiStatus: nil,
            usernames: usernames,
            storiesHidden: false,
            nameColor: nil,
            backgroundEmojiId: nil,
            profileColor: nil,
            profileBackgroundEmojiId: nil,
            subscriberCount: nil,
            verificationIconFileId: nil
        )
    }

    private static func makeRating(profile: DemoProfile) -> TelegramStarRating? {
        let level = max(0, profile.ratingLevel)
        let stars = profile.ratingStars ?? Int64(level) * 1_000
        let current = profile.ratingCurrentLevelStars ?? max(0, stars - Int64(level) * 1_000)
        let next = profile.ratingNextLevelStars ?? (Int64(level + 1) * 1_000)
        if level == 0 && stars == 0 {
            return nil
        }
        return TelegramStarRating(
            level: Int32(clamping: level),
            currentLevelStars: max(0, current),
            stars: max(0, stars),
            nextLevelStars: max(0, next)
        )
    }

    private static func makeSavedMusic(profile: DemoProfile) -> TelegramMediaFile? {
        guard let title = profile.savedMusicTitle, !title.isEmpty else {
            return nil
        }
        return TelegramMediaFile(
            fileId: MediaId(
                namespace: Namespaces.Media.LocalFile,
                id: Self.positiveStableId(profile.id)
            ),
            partialReference: nil,
            resource: EmptyMediaResource(),
            previewRepresentations: [],
            videoThumbnails: [],
            immediateThumbnailData: nil,
            mimeType: "audio/mpeg",
            size: nil,
            attributes: [
                .FileName(fileName: "\(title).mp3"),
                .Audio(
                    isVoice: false,
                    duration: 180,
                    title: title,
                    performer: profile.savedMusicPerformer,
                    waveform: nil
                )
            ],
            alternativeRepresentations: []
        )
    }

    private static func makeProfileGifts(
        _ gifts: [DemoGift],
        profilePeerIds: [UUID: PeerId],
        transaction: Transaction,
        store: DemoStudioStore,
        forceHidden: Bool = false
    ) -> [ProfileGiftsContext.State.StarGift] {
        return gifts.map { gift in
            let fromPeer: EnginePeer?
            if let senderProfileId = gift.senderProfileId,
               let senderPeerId = profilePeerIds[senderProfileId],
               let senderPeer = transaction.getPeer(senderPeerId) {
                fromPeer = EnginePeer(senderPeer)
            } else {
                fromPeer = nil
            }

            return ProfileGiftsContext.State.StarGift(
                gift: Self.makeStarGift(gift, store: store),
                reference: nil,
                fromPeer: fromPeer,
                date: Int32(clamping: Int64(gift.receivedAt.timeIntervalSince1970)),
                text: nil,
                entities: nil,
                nameHidden: fromPeer == nil,
                savedToProfile: forceHidden ? false : gift.displayedOnProfile,
                pinnedToTop: false,
                convertStars: nil,
                canUpgrade: false,
                canExportDate: nil,
                upgradeStars: nil,
                transferStars: nil,
                canTransferDate: nil,
                canResaleDate: nil,
                collectionIds: nil,
                prepaidUpgradeHash: nil,
                upgradeSeparate: false,
                dropOriginalDetailsStars: nil,
                number: gift.number.map { Int32(clamping: $0) },
                isRefunded: false,
                canCraftAt: nil
            )
        }
    }

    /// Builds the exact StarGift payload consumed by both the native profile
    /// gifts grid and ChatMessageGiftBubbleContentNode. Keeping one payload
    /// prevents the chat card and profile card from drifting apart.
    private static func makeStarGift(
        _ gift: DemoGift,
        store: DemoStudioStore
    ) -> StarGift {
        if let nativeUniqueGiftData = gift.nativeUniqueGiftData,
           let nativeGift = try? JSONDecoder().decode(
               StarGift.UniqueGift.self,
               from: nativeUniqueGiftData
           ) {
            return .unique(nativeGift)
        }

        let previewURL = store.assetURL(fileName: gift.imageFileName)
        let previewData = previewURL.flatMap { try? Data(contentsOf: $0) }
        let dimensions: PixelDimensions?
        if let previewData, let image = UIImage(data: previewData) {
            dimensions = PixelDimensions(
                width: Int32(clamping: Int(image.size.width * image.scale)),
                height: Int32(clamping: Int(image.size.height * image.scale))
            )
        } else {
            dimensions = nil
        }

        let resource: TelegramMediaResource
        let mimeType: String
        let fileName: String
        if let previewURL {
            resource = LocalFileReferenceMediaResource(
                localFilePath: previewURL.path,
                randomId: Self.positiveStableId(
                    gift.id,
                    salt: gift.imageFileName
                )
            )
            let fileExtension = previewURL.pathExtension.lowercased()
            switch fileExtension {
            case "jpg", "jpeg":
                mimeType = "image/jpeg"
            case "webp":
                mimeType = "image/webp"
            default:
                mimeType = "image/png"
            }
            fileName = previewURL.lastPathComponent
        } else {
            resource = EmptyMediaResource()
            mimeType = "application/x-tgsticker"
            fileName = "gift.tgs"
        }

        var attributes: [TelegramMediaFileAttribute] = [
            .FileName(fileName: fileName),
            .Sticker(displayText: "🎁", packReference: nil, maskData: nil)
        ]
        if let dimensions {
            attributes.append(.ImageSize(size: dimensions))
        }

        let previewRepresentations: [TelegramMediaImageRepresentation]
        if let previewURL, let previewData, let dimensions {
            previewRepresentations = [
                TelegramMediaImageRepresentation(
                    dimensions: dimensions,
                    resource: LocalFileReferenceMediaResource(
                        localFilePath: previewURL.path,
                        randomId: Self.positiveStableId(
                            gift.id,
                            salt: "preview:\(gift.imageFileName ?? "")"
                        )
                    ),
                    progressiveSizes: [],
                    immediateThumbnailData: previewData,
                    hasVideo: false,
                    isPersonal: false
                )
            ]
        } else {
            previewRepresentations = []
        }

        let file = TelegramMediaFile(
            fileId: MediaId(
                namespace: Namespaces.Media.LocalFile,
                id: Self.positiveStableId(gift.id)
            ),
            partialReference: nil,
            resource: resource,
            previewRepresentations: previewRepresentations,
            videoThumbnails: [],
            immediateThumbnailData: previewData,
            mimeType: mimeType,
            size: previewData.map { Int64($0.count) },
            attributes: attributes,
            alternativeRepresentations: []
        )
        return .generic(StarGift.Gift(
            id: gift.telegramGiftId ?? Self.positiveStableId(gift.id),
            title: gift.title.isEmpty ? "Telegram Gift" : gift.title,
            file: file,
            price: 0,
            convertStars: 0,
            availability: nil,
            soldOut: nil,
            flags: [],
            upgradeStars: nil,
            releasedBy: nil,
            perUserLimit: nil,
            lockedUntilDate: nil,
            auctionSlug: nil,
            auctionGiftsPerRound: nil,
            auctionStartDate: nil,
            upgradeVariantsCount: nil,
            background: nil
        ))
    }

    private static func makeMessage(
        value: DemoMessage,
        id: MessageId,
        peerId: PeerId,
        accountPeerId: PeerId,
        profile: DemoProfile,
        store: DemoStudioStore
    ) -> StoreMessage {
        let incoming = value.author == .profile
        var flags = StoreMessageFlags()
        flags.insert(.TopIndexable)
        if incoming {
            flags.insert(.Incoming)
            flags.insert(.CountedAsIncoming)
        }

        let content = Self.messageContent(
            value: value,
            peerId: peerId,
            accountPeerId: accountPeerId,
            profile: profile,
            store: store
        )
        return StoreMessage(
            id: id,
            customStableId: Self.stableUInt32(value.id),
            globallyUniqueId: nil,
            groupingKey: nil,
            threadId: nil,
            timestamp: Int32(clamping: Int64(value.timestamp.timeIntervalSince1970)),
            flags: flags,
            tags: [],
            globalTags: [],
            localTags: [],
            forwardInfo: nil,
            authorId: incoming ? peerId : accountPeerId,
            text: content.text,
            attributes: [],
            media: content.media
        )
    }

    private static func messageContent(
        value: DemoMessage,
        peerId: PeerId,
        accountPeerId: PeerId,
        profile: DemoProfile,
        store: DemoStudioStore
    ) -> (text: String, media: [Media]) {
        switch value.resolvedKind {
        case .text:
            return (value.text, [])
        case .photo:
            if let image = Self.makeImage(value: value, store: store) {
                return (value.text, [image])
            }
            return (value.text, [])
        case .video, .voice, .videoMessage, .music, .document, .sticker, .animation:
            return (value.text, [Self.makeFile(value: value)])
        case .contact:
            let contact = TelegramMediaContact(
                firstName: value.text.isEmpty ? profile.firstName : value.text,
                lastName: value.secondaryText ?? profile.lastName,
                phoneNumber: profile.phone,
                peerId: nil,
                vCardData: nil
            )
            return ("", [contact])
        case .location:
            return ("", [TelegramMediaMap(
                latitude: value.latitude ?? 59.437,
                longitude: value.longitude ?? 24.7536,
                heading: nil,
                accuracyRadius: nil,
                venue: nil
            )])
        case .poll:
            let optionTitles = value.options.flatMap { $0.isEmpty ? nil : $0 } ?? ["Да", "Нет"]
            let options = optionTitles.enumerated().map { index, text in
                TelegramMediaPollOption(
                    text: text,
                    entities: [],
                    opaqueIdentifier: Data([UInt8(clamping: index)]),
                    date: nil,
                    addedBy: nil
                )
            }
            let results = TelegramMediaPollResults(
                voters: options.map {
                    TelegramMediaPollOptionVoters(
                        selected: false,
                        opaqueIdentifier: $0.opaqueIdentifier,
                        count: 0,
                        isCorrect: false
                    )
                },
                totalVoters: 0,
                recentVoters: [],
                solution: nil,
                hasUnseenVotes: false,
                canViewStats: false
            )
            return ("", [TelegramMediaPoll(
                pollId: MediaId(
                    namespace: Namespaces.Media.LocalPoll,
                    id: positiveStableId(value.id)
                ),
                publicity: .anonymous,
                kind: .poll(multipleAnswers: false),
                text: value.text.isEmpty ? "Опрос" : value.text,
                textEntities: [],
                options: options,
                correctAnswers: nil,
                results: results,
                isClosed: false,
                deadlineTimeout: nil,
                deadlineDate: nil,
                pollHash: positiveStableId(value.id)
            )])
        case .premiumGift:
            return ("", [TelegramMediaAction(action: .giftPremium(
                currency: "USD",
                amount: max(0, value.amount ?? 499),
                days: Int32(clamping: max(1, value.duration ?? 30)),
                cryptoCurrency: nil,
                cryptoAmount: nil,
                text: value.text.isEmpty ? nil : value.text,
                entities: nil
            ))])
        case .starsGift:
            return ("", [TelegramMediaAction(action: .giftStars(
                currency: "XTR",
                amount: max(0, value.amount ?? 50),
                count: max(0, value.amount ?? 50),
                cryptoCurrency: nil,
                cryptoAmount: nil,
                transactionId: nil
            ))])
        case .phoneCall:
            return ("", [TelegramMediaAction(action: .phoneCall(
                callId: positiveStableId(value.id),
                discardReason: nil,
                duration: Int32(clamping: max(0, value.duration ?? 0)),
                isVideo: false
            ))])
        case .screenshot:
            return ("", [TelegramMediaAction(action: .historyScreenshot)])
        case .autoDelete:
            return ("", [TelegramMediaAction(action: .messageAutoremoveTimeoutUpdated(
                period: Int32(clamping: max(0, value.duration ?? 86400)),
                autoSettingSource: nil
            ))])
        case .pinnedMessage:
            return ("", [TelegramMediaAction(action: .pinnedMessageUpdated)])
        case .historyCleared:
            return ("", [TelegramMediaAction(action: .historyCleared)])
        case .paidMessagesRefunded:
            return ("", [TelegramMediaAction(action: .paidMessagesRefunded(
                count: Int32(clamping: max(1, value.duration ?? 1)),
                stars: max(0, value.amount ?? 1)
            ))])
        case .paidMessagesPrice:
            return ("", [TelegramMediaAction(action: .paidMessagesPriceEdited(
                stars: max(0, value.amount ?? 1),
                broadcastMessagesAllowed: false
            ))])
        case .starGift:
            let gift = value.gift ?? DemoGift(
                id: value.id,
                title: value.text.isEmpty ? "Telegram Gift" : value.text,
                senderProfileId: value.author == .profile ? profile.id : nil,
                receivedAt: value.timestamp,
                displayedOnProfile: false
            )
            let note: String?
            if value.gift != nil && !value.text.isEmpty
                && value.text != "Подарил(а) вам подарок" {
                note = value.text
            } else {
                note = nil
            }
            let renderedGift = Self.makeStarGift(gift, store: store)
            let senderId = value.author == .profile ? peerId : accountPeerId
            let action: TelegramMediaActionType
            switch renderedGift {
            case .generic:
                action = .starGift(
                    gift: renderedGift,
                    convertStars: nil,
                    text: note,
                    entities: nil,
                    nameHidden: false,
                    savedToProfile: gift.displayedOnProfile,
                    converted: false,
                    upgraded: false,
                    canUpgrade: false,
                    upgradeStars: nil,
                    isRefunded: false,
                    isPrepaidUpgrade: false,
                    upgradeMessageId: nil,
                    peerId: nil,
                    senderId: senderId,
                    savedId: nil,
                    prepaidUpgradeHash: nil,
                    giftMessageId: nil,
                    upgradeSeparate: false,
                    isAuctionAcquired: false,
                    toPeerId: nil,
                    number: gift.number.map { Int32(clamping: $0) }
                )
            case .unique:
                action = .starGiftUnique(
                    gift: renderedGift,
                    isUpgrade: false,
                    isTransferred: false,
                    savedToProfile: gift.displayedOnProfile,
                    canExportDate: nil,
                    transferStars: nil,
                    isRefunded: false,
                    isPrepaidUpgrade: false,
                    peerId: nil,
                    senderId: senderId,
                    savedId: nil,
                    resaleAmount: nil,
                    canTransferDate: nil,
                    canResaleDate: nil,
                    dropOriginalDetailsStars: nil,
                    assigned: false,
                    fromOffer: false,
                    canCraftAt: nil,
                    isCrafted: false
                )
            }
            return ("", [TelegramMediaAction(action: action)])
        case .service:
            let fallbackText = value.text.isEmpty
                ? value.resolvedKind.title
                : value.text
            return ("", [TelegramMediaAction(action: .customText(
                text: fallbackText,
                entities: [],
                additionalAttributes: nil
            ))])
        }
    }

    private static func makeImage(value: DemoMessage, store: DemoStudioStore) -> TelegramMediaImage? {
        guard let url = store.assetURL(fileName: value.mediaFileName),
              let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        let representation = TelegramMediaImageRepresentation(
            dimensions: PixelDimensions(
                width: Int32(clamping: Int(image.size.width * image.scale)),
                height: Int32(clamping: Int(image.size.height * image.scale))
            ),
            resource: LocalFileReferenceMediaResource(
                localFilePath: url.path,
                randomId: positiveStableId(
                    value.id,
                    salt: value.mediaFileName
                )
            ),
            progressiveSizes: [],
            immediateThumbnailData: data
        )
        return TelegramMediaImage(
            imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: positiveStableId(value.id)),
            representations: [representation],
            immediateThumbnailData: data,
            reference: nil,
            partialReference: nil,
            flags: []
        )
    }

    private static func makeFile(value: DemoMessage) -> TelegramMediaFile {
        let duration = max(1, value.duration ?? 10)
        var attributes: [TelegramMediaFileAttribute] = []
        var mimeType = "application/octet-stream"
        switch value.resolvedKind {
        case .video:
            mimeType = "video/mp4"
            attributes = [
                .FileName(fileName: value.secondaryText ?? "video.mp4"),
                .Video(
                    duration: Double(duration),
                    size: PixelDimensions(width: 1280, height: 720),
                    flags: [.supportsStreaming],
                    preloadSize: nil,
                    coverTime: nil,
                    videoCodec: nil
                )
            ]
        case .videoMessage:
            mimeType = "video/mp4"
            attributes = [
                .Video(
                    duration: Double(duration),
                    size: PixelDimensions(width: 384, height: 384),
                    flags: [.instantRoundVideo],
                    preloadSize: nil,
                    coverTime: nil,
                    videoCodec: nil
                )
            ]
        case .voice:
            mimeType = "audio/ogg"
            attributes = [
                .Audio(isVoice: true, duration: duration, title: nil, performer: nil, waveform: nil)
            ]
        case .music:
            mimeType = "audio/mpeg"
            attributes = [
                .FileName(fileName: "\(value.text.isEmpty ? "Audio" : value.text).mp3"),
                .Audio(
                    isVoice: false,
                    duration: duration,
                    title: value.text.isEmpty ? nil : value.text,
                    performer: value.secondaryText,
                    waveform: nil
                )
            ]
        case .sticker:
            mimeType = "image/webp"
            attributes = [
                .Sticker(displayText: value.text, packReference: nil, maskData: nil),
                .ImageSize(size: PixelDimensions(width: 512, height: 512))
            ]
        case .animation:
            mimeType = "video/mp4"
            attributes = [
                .Animated,
                .Video(
                    duration: Double(duration),
                    size: PixelDimensions(width: 480, height: 480),
                    flags: [.supportsStreaming],
                    preloadSize: nil,
                    coverTime: nil,
                    videoCodec: nil
                )
            ]
        default:
            attributes = [.FileName(fileName: value.secondaryText ?? "document")]
        }
        return TelegramMediaFile(
            fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: positiveStableId(value.id)),
            partialReference: nil,
            resource: EmptyMediaResource(),
            previewRepresentations: [],
            videoThumbnails: [],
            immediateThumbnailData: nil,
            mimeType: mimeType,
            size: nil,
            attributes: attributes,
            alternativeRepresentations: []
        )
    }

    private static func negativeStableId(_ uuid: UUID) -> Int64 {
        return -(1_000_000_000 + positiveStableId(uuid) % 1_000_000_000)
    }

    private static func positiveStableId(_ uuid: UUID) -> Int64 {
        return positiveStableId(uuid, salt: nil)
    }

    private static func positiveStableId(_ uuid: UUID, salt: String?) -> Int64 {
        var bytes = uuid.uuid
        return withUnsafeBytes(of: &bytes) { buffer in
            var hash: UInt64 = 14_695_981_039_346_656_037
            for byte in buffer {
                hash ^= UInt64(byte)
                hash &*= 1_099_511_628_211
            }
            if let salt {
                for byte in salt.utf8 {
                    hash ^= UInt64(byte)
                    hash &*= 1_099_511_628_211
                }
            }
            return Int64(hash & 0x007f_ffff_ffff_ffff)
        }
    }

    private static func messageId(_ uuid: UUID) -> Int32 {
        return -Int32(1 + positiveStableId(uuid) % Int64(Int32.max - 1))
    }

    private static func stableUInt32(_ uuid: UUID) -> UInt32 {
        return UInt32(truncatingIfNeeded: positiveStableId(uuid))
    }
}
