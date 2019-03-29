import Foundation

enum InitialMessageHistoryViewLoadingAnchorIndex {
    case groupFeedReadState(PeerGroupId)
}

enum InitialMessageHistoryViewAnchorIndex {
    case index(InternalMessageHistoryAnchorIndex)
    case loading(InitialMessageHistoryViewLoadingAnchorIndex)
}

public enum AdditionalMessageHistoryViewData {
    case cachedPeerData(PeerId)
    case cachedPeerDataMessages(PeerId)
    case peerChatState(PeerId)
    case totalUnreadState
    case peerNotificationSettings(PeerId)
    case cacheEntry(ItemCacheEntryId)
    case preferencesEntry(ValueBoxKey)
    case peer(PeerId)
    case peerIsContact(PeerId)
}

public enum AdditionalMessageHistoryViewDataEntry {
    case cachedPeerData(PeerId, CachedPeerData?)
    case cachedPeerDataMessages(PeerId, [MessageId: Message]?)
    case peerChatState(PeerId, PeerChatState?)
    case totalUnreadState(ChatListTotalUnreadState)
    case peerNotificationSettings(PeerNotificationSettings?)
    case cacheEntry(ItemCacheEntryId, PostboxCoding?)
    case preferencesEntry(ValueBoxKey, PreferencesEntry?)
    case peerIsContact(PeerId, Bool)
    case peer(PeerId, Peer?)
}

public struct MessageHistoryViewId: Equatable {
    let id: Int
    let version: Int
    
    init(id: Int, version: Int = 0) {
        self.id = id
        self.version = version
    }
    
    var nextVersion: MessageHistoryViewId {
        return MessageHistoryViewId(id: self.id, version: self.version + 1)
    }

    public static func ==(lhs: MessageHistoryViewId, rhs: MessageHistoryViewId) -> Bool {
        return lhs.id == rhs.id && lhs.version == rhs.version
    }
}

public struct MutableMessageHistoryEntryAttributes: Equatable {
    public var authorIsContact: Bool
    
    public init(authorIsContact: Bool) {
        self.authorIsContact = authorIsContact
    }
}


public struct MessageHistoryViewPeerHole: Equatable, Hashable {
    public let peerId: PeerId
    public let namespace: MessageId.Namespace
    public let indices: IndexSet
}

public enum MessageHistoryViewHole: Equatable, Hashable {
    case peer(MessageHistoryViewPeerHole)
}

enum MutableMessageHistoryEntry {
    case IntermediateMessageEntry(IntermediateMessage, MessageHistoryEntryLocation?, MessageHistoryEntryMonthLocation?)
    case MessageEntry(Message, MessageHistoryEntryLocation?, MessageHistoryEntryMonthLocation?, MutableMessageHistoryEntryAttributes)
    
    var index: MessageIndex {
        switch self {
            case let .IntermediateMessageEntry(message, _, _):
                return MessageIndex(id: message.id, timestamp: message.timestamp)
            case let .MessageEntry(message, _, _, _):
                return MessageIndex(id: message.id, timestamp: message.timestamp)
        }
    }
    
    var tags: MessageTags {
        switch self {
            case let .IntermediateMessageEntry(message, _, _):
                return message.tags
            case let .MessageEntry(message, _, _, _):
                return message.tags
        }
    }
    
    func updatedLocation(_ location: MessageHistoryEntryLocation?) -> MutableMessageHistoryEntry {
        switch self {
            case let .IntermediateMessageEntry(message, _, monthLocation):
                return .IntermediateMessageEntry(message, location, monthLocation)
            case let .MessageEntry(message, _, monthLocation, attributes):
                return .MessageEntry(message, location, monthLocation, attributes)
        }
    }
    
    func updatedMonthLocation(_ monthLocation: MessageHistoryEntryMonthLocation?) -> MutableMessageHistoryEntry {
        switch self {
            case let .IntermediateMessageEntry(message, location, _):
                return .IntermediateMessageEntry(message, location, monthLocation)
            case let .MessageEntry(message, location, _, attributes):
                return .MessageEntry(message, location, monthLocation, attributes)
        }
    }
    
    func offsetLocationForInsertedIndex(_ index: MessageIndex) -> MutableMessageHistoryEntry {
        switch self {
            case let .IntermediateMessageEntry(message, location, monthLocation):
                if let location = location {
                    if MessageIndex(id: message.id, timestamp: message.timestamp) > index {
                        return .IntermediateMessageEntry(message, MessageHistoryEntryLocation(index: location.index + 1, count: location.count + 1), monthLocation)
                    } else {
                        return .IntermediateMessageEntry(message, MessageHistoryEntryLocation(index: location.index, count: location.count - 1), monthLocation)
                    }
                } else {
                    return self
                }
            case let .MessageEntry(message, location, monthLocation, attributes):
                if let location = location {
                    if MessageIndex(id: message.id, timestamp: message.timestamp) > index {
                        return .MessageEntry(message, MessageHistoryEntryLocation(index: location.index + 1, count: location.count + 1), monthLocation, attributes)
                    } else {
                        return .MessageEntry(message, MessageHistoryEntryLocation(index: location.index, count: location.count + 1), monthLocation, attributes)
                    }
                } else {
                    return self
                }
        }
    }
    
    func offsetLocationForRemovedIndex(_ index: MessageIndex) -> MutableMessageHistoryEntry {
        switch self {
            case let .IntermediateMessageEntry(message, location, monthLocation):
                if let location = location {
                    if MessageIndex(id: message.id, timestamp: message.timestamp) > index {
                        //assert(location.index > 0)
                        //assert(location.count != 0)
                        return .IntermediateMessageEntry(message, MessageHistoryEntryLocation(index: location.index - 1, count: location.count - 1), monthLocation)
                    } else {
                        //assert(location.count != 0)
                        return .IntermediateMessageEntry(message, MessageHistoryEntryLocation(index: location.index, count: location.count - 1), monthLocation)
                    }
                } else {
                    return self
                }
            case let .MessageEntry(message, location, monthLocation, attributes):
                if let location = location {
                    if MessageIndex(id: message.id, timestamp: message.timestamp) > index {
                        //assert(location.index > 0)
                        //assert(location.count != 0)
                        return .MessageEntry(message, MessageHistoryEntryLocation(index: location.index - 1, count: location.count - 1), monthLocation, attributes)
                    } else {
                        //assert(location.count != 0)
                        return .MessageEntry(message, MessageHistoryEntryLocation(index: location.index, count: location.count - 1), monthLocation, attributes)
                    }
                } else {
                    return self
                }
        }
    }
    
    func updatedTimestamp(_ timestamp: Int32) -> MutableMessageHistoryEntry {
        switch self {
            case let .IntermediateMessageEntry(message, location, monthLocation):
                let updatedMessage = IntermediateMessage(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, timestamp: timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributesData: message.attributesData, embeddedMediaData: message.embeddedMediaData, referencedMedia: message.referencedMedia)
                return .IntermediateMessageEntry(updatedMessage, location, monthLocation)
            case let .MessageEntry(message, location, monthLocation, attributes):
                let updatedMessage = Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, timestamp: timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, author: message.author, text: message.text, attributes: message.attributes, media: message.media, peers: message.peers, associatedMessages: message.associatedMessages, associatedMessageIds: message.associatedMessageIds)
                return .MessageEntry(updatedMessage, location, monthLocation, attributes)
        }
    }
}

public struct MessageHistoryEntryLocation: Equatable {
    public let index: Int
    public let count: Int
    
    var predecessor: MessageHistoryEntryLocation? {
        if index == 0 {
            return nil
        } else {
            return MessageHistoryEntryLocation(index: index - 1, count: count)
        }
    }
    
    var successor: MessageHistoryEntryLocation {
        return MessageHistoryEntryLocation(index: index + 1, count: count)
    }
    
    public static func ==(lhs: MessageHistoryEntryLocation, rhs: MessageHistoryEntryLocation) -> Bool {
        return lhs.index == rhs.index && lhs.count == rhs.count
    }
}

public struct MessageHistoryEntryMonthLocation: Equatable {
    public let indexInMonth: Int32
    
    public static func ==(lhs: MessageHistoryEntryMonthLocation, rhs: MessageHistoryEntryMonthLocation) -> Bool {
        return lhs.indexInMonth == rhs.indexInMonth
    }
}

public struct MessageHistoryEntry: Comparable {
    public let message: Message
    public let isRead: Bool
    public let location: MessageHistoryEntryLocation?
    public let monthLocation: MessageHistoryEntryMonthLocation?
    public let attributes: MutableMessageHistoryEntryAttributes
    
    public var index: MessageIndex {
        return MessageIndex(id: self.message.id, timestamp: self.message.timestamp)
    }
    
    public init(message: Message, isRead: Bool, location: MessageHistoryEntryLocation?, monthLocation: MessageHistoryEntryMonthLocation?, attributes: MutableMessageHistoryEntryAttributes) {
        self.message = message
        self.isRead = isRead
        self.location = location
        self.monthLocation = monthLocation
        self.attributes = attributes
    }

    public static func ==(lhs: MessageHistoryEntry, rhs: MessageHistoryEntry) -> Bool {
        if lhs.message.index == rhs.message.index && lhs.message.flags == rhs.message.flags && lhs.location == rhs.location && lhs.isRead == rhs.isRead && lhs.monthLocation == rhs.monthLocation && lhs.attributes == rhs.attributes {
            return true
        }
        return false
    }
    
    public static func <(lhs: MessageHistoryEntry, rhs: MessageHistoryEntry) -> Bool {
        return lhs.index < rhs.index
    }
}

final class MutableMessageHistoryViewReplayContext {
    var invalidEarlier: Bool = false
    var invalidLater: Bool = false
    var removedEntries: Bool = false
    
    func empty() -> Bool {
        return !self.removedEntries && !invalidEarlier && !invalidLater
    }
}

enum MessageHistoryTopTaggedMessage {
    case message(Message)
    case intermediate(IntermediateMessage)
    
    var id: MessageId {
        switch self {
            case let .message(message):
                return message.id
            case let .intermediate(message):
                return message.id
        }
    }
}

public enum MessageHistoryViewRelativeHoleDirection: Equatable, Hashable {
    case UpperToLower
    case LowerToUpper
    case AroundId(MessageId)
    case AroundIndex(MessageIndex)
}

public struct MessageHistoryViewOrderStatistics: OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let combinedLocation = MessageHistoryViewOrderStatistics(rawValue: 1 << 0)
    public static let locationWithinMonth = MessageHistoryViewOrderStatistics(rawValue: 1 << 1)
}

private struct MessageMonthIndex: Equatable {
    let year: Int32
    let month: Int32
    
    var timestamp: Int32 {
        var timeinfo = tm()
        timeinfo.tm_year = self.year
        timeinfo.tm_mon = self.month
        return Int32(timegm(&timeinfo))
    }
    
    init(year: Int32, month: Int32) {
        self.year = year
        self.month = month
    }
    
    init(timestamp: Int32) {
        var t = Int(timestamp)
        var timeinfo = tm()
        gmtime_r(&t, &timeinfo)
        self.year = timeinfo.tm_year
        self.month = timeinfo.tm_mon
    }
    
    static func ==(lhs: MessageMonthIndex, rhs: MessageMonthIndex) -> Bool {
        return lhs.month == rhs.month && lhs.year == rhs.year
    }
    
    var successor: MessageMonthIndex {
        if self.month == 11 {
            return MessageMonthIndex(year: self.year + 1, month: 0)
        } else {
            return MessageMonthIndex(year: self.year, month: self.month + 1)
        }
    }
    
    var predecessor: MessageMonthIndex {
        if self.month == 0 {
            return MessageMonthIndex(year: self.year - 1, month: 11)
        } else {
            return MessageMonthIndex(year: self.year, month: self.month - 1)
        }
    }
}

private func monthUpperBoundIndex(peerId: PeerId, index: MessageMonthIndex) -> MessageIndex {
    return MessageIndex(id: MessageId(peerId: peerId, namespace: 0, id: 0), timestamp: index.successor.timestamp)
}

public enum MessageHistoryViewPeerIds: Equatable {
    case single(PeerId)
    case associated(PeerId, MessageId?)
    //case group(PeerGroupId)
}

private func clipMessages(peerIds: MessageHistoryViewPeerIds, entries: [MutableMessageHistoryEntry]) -> [MutableMessageHistoryEntry] {
    switch peerIds {
        case .single://, .group:
            return entries
        case let .associated(_, associatedId):
            if let associatedId = associatedId {
                var result: [MutableMessageHistoryEntry] = []
                for entry in entries {
                    switch entry {
                        case let .MessageEntry(message, _, _, _):
                            if message.id.peerId == associatedId.peerId {
                                if message.id.namespace == associatedId.namespace && message.id.id < associatedId.id {
                                    result.append(entry)
                                }
                            } else {
                                result.append(entry)
                            }
                        case let .IntermediateMessageEntry(message, _, _):
                            if message.id.peerId == associatedId.peerId {
                                if message.id.namespace == associatedId.namespace && message.id.id < associatedId.id {
                                    result.append(entry)
                                }
                            } else {
                                result.append(entry)
                            }
                    }
                }
                return result
            } else {
                return entries
            }
    }
}

private func clipAround(peerIds: MessageHistoryViewPeerIds, _ data: (entries: [MutableMessageHistoryEntry], lower: MutableMessageHistoryEntry?, upper: MutableMessageHistoryEntry?)) -> (entries: [MutableMessageHistoryEntry], lower: MutableMessageHistoryEntry?, upper: MutableMessageHistoryEntry?) {
    return (entries: clipMessages(peerIds: peerIds, entries: data.entries), lower: data.lower, upper: data.upper)
}

private func fetchAround(postbox: Postbox, peerIds: MessageHistoryViewPeerIds, index: InternalMessageHistoryAnchorIndex, count: Int, tagMask: MessageTags?) -> (entries: [MutableMessageHistoryEntry], lower: MutableMessageHistoryEntry?, upper: MutableMessageHistoryEntry?) {
    var ids: [PeerId] = []
    switch peerIds {
        case let .single(peerId):
            ids = [peerId]
        case let .associated(mainId, associatedId):
            ids.append(mainId)
            if let associatedId = associatedId {
                ids.append(associatedId.peerId)
            }
        /*case let .group(groupId):
            switch index {
                case let .message(index: index, _):
                    return postbox.fetchAroundGroupFeedEntries(groupId: groupId, index: index, count: count)
                case .upperBound:
                    return postbox.fetchAroundGroupFeedEntries(groupId: groupId, index: MessageIndex.absoluteUpperBound(), count: count)
                case .lowerBound:
                    return postbox.fetchAroundGroupFeedEntries(groupId: groupId, index: MessageIndex.absoluteLowerBound(), count: count)
            }*/
    }
    
    switch index {
        case let .message(index: index, _):
            return clipAround(peerIds: peerIds, postbox.fetchAroundHistoryEntries(peerIds: ids, index: index, count: count, tagMask: tagMask))
        case .upperBound:
            return clipAround(peerIds: peerIds, postbox.fetchAroundHistoryEntries(peerIds: ids, index: MessageIndex.absoluteUpperBound(), count: count, tagMask: tagMask))
        case .lowerBound:
            return clipAround(peerIds: peerIds, postbox.fetchAroundHistoryEntries(peerIds: ids, index: MessageIndex.absoluteLowerBound(), count: count, tagMask: tagMask))
    }
}

private struct HoleKey: Hashable {
    let peerId: PeerId
    let namespace: MessageId.Namespace
}

private func fetchHoles(postbox: Postbox, peerIds: MessageHistoryViewPeerIds, tagMask: MessageTags?, entries: [MutableMessageHistoryEntry], hasEarlier: Bool, hasLater: Bool) -> [HoleKey: IndexSet] {
    var peerIdsSet: [PeerId] = []
    switch peerIds {
        case let .single(peerId):
            peerIdsSet.append(peerId)
        case let .associated(peerId, associatedId):
            peerIdsSet.append(peerId)
            if let associatedId = associatedId {
                peerIdsSet.append(associatedId.peerId)
            }
    }
    var namespaceBounds: [(PeerId, MessageId.Namespace, ClosedRange<MessageId.Id>?)] = []
    for peerId in peerIdsSet {
        if let namespaces = postbox.seedConfiguration.messageHoles[peerId.namespace] {
            for namespace in namespaces.keys {
                var earlierId: MessageId.Id?
                earlier: for entry in entries {
                    if entry.index.id.peerId == peerId && entry.index.id.namespace == namespace {
                        earlierId = entry.index.id.id
                        break earlier
                    }
                }
                var laterId: MessageId.Id?
                later: for entry in entries.reversed() {
                    if entry.index.id.peerId == peerId && entry.index.id.namespace == namespace {
                        laterId = entry.index.id.id
                        break later
                    }
                }
                if let earlierId = earlierId, let laterId = laterId {
                    namespaceBounds.append((peerId, namespace, earlierId ... laterId))
                } else {
                    namespaceBounds.append((peerId, namespace, nil))
                }
            }
        }
    }
    let space: MessageHistoryHoleSpace = tagMask.flatMap(MessageHistoryHoleSpace.tag) ?? .everywhere
    var result: [HoleKey: IndexSet] = [:]
    for (peerId, namespace, bounds) in namespaceBounds {
        var indices = postbox.messageHistoryHoleIndexTable.closest(peerId: peerId, namespace: namespace, space: space, range: bounds ?? 1 ... Int32.max)
        if let bounds = bounds {
            if hasEarlier {
                indices.remove(integersIn: 1 ... Int(bounds.lowerBound))
            }
            if hasLater {
                indices.remove(integersIn: Int(bounds.upperBound) ... Int(Int32.max))
            }
        }
        if !indices.isEmpty {
            result[HoleKey(peerId: peerId, namespace: namespace)] = indices
        }
    }
    return result
}

public enum MessageHistoryViewReadState {
    case peer([PeerId: CombinedPeerReadState])
    //case group(PeerGroupId, GroupFeedReadState)
}

final class MutableMessageHistoryView {
    private(set) var id: MessageHistoryViewId
    private(set) var peerIds: MessageHistoryViewPeerIds
    let tagMask: MessageTags?
    private let orderStatistics: MessageHistoryViewOrderStatistics
    
    fileprivate var loadingInitialIndex: InitialMessageHistoryViewLoadingAnchorIndex?
    
    fileprivate var anchorIndex: InternalMessageHistoryAnchorIndex
    fileprivate var combinedReadStates: MessageHistoryViewReadState?
    fileprivate var transientReadStates: MessageHistoryViewReadState?
    fileprivate var earlier: MutableMessageHistoryEntry?
    fileprivate var later: MutableMessageHistoryEntry?
    fileprivate var entries: [MutableMessageHistoryEntry]
    fileprivate var holes: [HoleKey: IndexSet]
    fileprivate let fillCount: Int
    fileprivate let clipHoles: Bool
    
    fileprivate var topTaggedMessages: [MessageId.Namespace: MessageHistoryTopTaggedMessage?]
    fileprivate var additionalDatas: [AdditionalMessageHistoryViewDataEntry]
    
    init(id: MessageHistoryViewId, postbox: Postbox, orderStatistics: MessageHistoryViewOrderStatistics, peerIds: MessageHistoryViewPeerIds, index: InitialMessageHistoryViewAnchorIndex, anchorIndex: InternalMessageHistoryAnchorIndex?, combinedReadStates: MessageHistoryViewReadState?, transientReadStates: MessageHistoryViewReadState?, tagMask: MessageTags?, count: Int, clipHoles: Bool, topTaggedMessages: [MessageId.Namespace: MessageHistoryTopTaggedMessage?], additionalDatas: [AdditionalMessageHistoryViewDataEntry], getMessageCountInRange: (MessageIndex, MessageIndex) -> Int32) {
        switch index {
            case let .index(realIndex):
                let (entries, earlier, later) = fetchAround(postbox: postbox, peerIds: peerIds, index: realIndex, count: count, tagMask: tagMask)
                self.earlier = earlier
                self.entries = entries
                self.later = later
                self.loadingInitialIndex = nil
            case let .loading(loadingIndex):
                self.earlier = nil
                self.entries = []
                self.later = nil
                self.loadingInitialIndex = loadingIndex
        }
        self.holes = fetchHoles(postbox: postbox, peerIds: peerIds, tagMask: tagMask, entries: self.entries, hasEarlier: self.earlier != nil, hasLater: self.later != nil)
        
        self.id = id
        self.orderStatistics = orderStatistics
        self.peerIds = peerIds
        self.anchorIndex = anchorIndex ?? .upperBound
        self.combinedReadStates = combinedReadStates
        self.transientReadStates = transientReadStates
        self.tagMask = tagMask
        self.fillCount = count
        self.clipHoles = clipHoles
        self.topTaggedMessages = topTaggedMessages
        self.additionalDatas = additionalDatas
        
        if let tagMask = self.tagMask, !orderStatistics.isEmpty && !self.entries.isEmpty {
            if orderStatistics.contains(.combinedLocation) {
                if let location = postbox.messageHistoryTagsTable.entryLocation(at: self.entries[0].index, tagMask: tagMask) {
                    self.entries[0] = self.entries[0].updatedLocation(location)
                    
                    var previousLocation = location
                    for i in 1 ..< self.entries.count {
                        previousLocation = previousLocation.successor
                        self.entries[i] = self.entries[i].updatedLocation(previousLocation)
                    }
                } else {
                    assertionFailure()
                }
            }
            
            if orderStatistics.contains(.locationWithinMonth) {
                var peerId: PeerId?
                switch self.peerIds {
                    case let .single(id):
                        peerId = id
                    case let .associated(id, _):
                        peerId = id
                    /*case .group:
                        break*/
                }
                
                if let peerId = peerId {
                    var topMessageEntryIndex: Int?
                    var index = self.entries.count - 1
                    loop: for entry in self.entries.reversed() {
                        switch entry {
                            case .IntermediateMessageEntry, .MessageEntry:
                                topMessageEntryIndex = index
                                break loop
                            default:
                                break
                        }
                        index -= 1
                    }
                    if let topMessageEntryIndex = topMessageEntryIndex {
                        let topMessageIndex = self.entries[topMessageEntryIndex].index
                        
                        let monthIndex = MessageMonthIndex(timestamp: topMessageIndex.timestamp)
                        
                        let laterCount: Int32
                        if self.later == nil {
                            laterCount = 0
                        } else {
                            laterCount = postbox.messageHistoryTagsTable.getMessageCountInRange(tagMask: tagMask, peerId: peerId, lowerBound: topMessageIndex.successor(), upperBound: monthUpperBoundIndex(peerId: peerId, index: monthIndex))
                        }
                        self.entries[topMessageEntryIndex] = self.entries[topMessageEntryIndex].updatedMonthLocation(MessageHistoryEntryMonthLocation(indexInMonth: laterCount))
                    }
                }
            }
        }
    }
    
    func incrementVersion() {
        self.id = self.id.nextVersion
    }
    
    func updateVisibleRange(earliestVisibleIndex: MessageIndex, latestVisibleIndex: MessageIndex, context: MutableMessageHistoryViewReplayContext) -> Bool {
        var minIndex: Int?
        var maxIndex: Int?
        
        for i in 0 ..< self.entries.count {
            if self.entries[i].index >= earliestVisibleIndex {
                minIndex = i
                break
            }
        }
        
        for i in (0 ..< self.entries.count).reversed() {
            if self.entries[i].index <= latestVisibleIndex {
                maxIndex = i
                break
            }
        }
        
        if let minIndex = minIndex, let maxIndex = maxIndex {
            var minClipIndex = minIndex
            var maxClipIndex = maxIndex
            
            while maxClipIndex - minClipIndex <= self.fillCount {
                if maxClipIndex != self.entries.count - 1 {
                    maxClipIndex += 1
                }
                
                if minClipIndex != 0 {
                    minClipIndex -= 1
                } else if maxClipIndex == self.entries.count - 1 {
                    break
                }
            }
            
            if minClipIndex != 0 || maxClipIndex != self.entries.count - 1 {
                if minClipIndex != 0 {
                    self.earlier = self.entries[minClipIndex - 1]
                }
                
                if maxClipIndex != self.entries.count - 1 {
                    self.later = self.entries[maxClipIndex + 1]
                }
                
                for _ in 0 ..< self.entries.count - 1 - maxClipIndex {
                    self.entries.removeLast()
                }
                
                for _ in 0 ..< minClipIndex {
                    self.entries.removeFirst()
                }
                
                return true
            }
        }
        
        return false
    }
    
    func updateAnchorIndex(_ getIndex: (MessageId) -> InternalMessageHistoryAnchorIndex?) -> Bool {
        switch self.anchorIndex {
            case let .message(index, exact):
                if !exact {
                    if let index = getIndex(index.id) {
                        self.anchorIndex = index
                        return true
                    }
                }
            default:
                break
        }
        return false
    }
    
    func refreshDueToExternalTransaction(postbox: Postbox) -> Bool {
        if self.loadingInitialIndex != nil {
            return false
        }
        
        var index: InternalMessageHistoryAnchorIndex = .upperBound
        if !self.entries.isEmpty {
            if let _ = self.later {
                index = .message(index: self.entries[self.entries.count / 2].index, exact: true)
            }
        }
        
        let (entries, earlier, later) = fetchAround(postbox: postbox, peerIds: self.peerIds, index: index, count: max(self.fillCount, self.entries.count), tagMask: tagMask)
        
        self.entries = entries
        self.earlier = earlier
        self.later = later
        
        return true
    }
    
    func updatePeerIds(transaction: PostboxTransaction) {
        switch self.peerIds {
            /*case .group:
                break*/
            case let .single(peerId):
                if self.tagMask == nil, let updatedData = transaction.currentUpdatedCachedPeerData[peerId] {
                    if updatedData.associatedHistoryMessageId != nil {
                        self.peerIds = .associated(peerId, updatedData.associatedHistoryMessageId)
                    }
                }
            case let .associated(peerId, associatedId):
                if let updatedData = transaction.currentUpdatedCachedPeerData[peerId] {
                    if updatedData.associatedHistoryMessageId != associatedId {
                        self.peerIds = .associated(peerId, updatedData.associatedHistoryMessageId)
                    }
                }
        }
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction, updatedMedia: [MediaId: Media?], updatedCachedPeerData: [PeerId: CachedPeerData], context: MutableMessageHistoryViewReplayContext, renderIntermediateMessage: (IntermediateMessage) -> Message) -> Bool {
        var operations: [[MessageHistoryOperation]] = []
        /*var groupOperations: [GroupFeedIndexOperation] = []
        var holeFillDirections: [MessageIndex: HoleFillDirection] = [:]*/
        
        switch self.peerIds {
            case let .single(peerId):
                if let value = transaction.currentOperationsByPeerId[peerId] {
                    operations.append(value)
                }
                /*if let value = transaction.peerIdsWithFilledHoles[peerId] {
                    holeFillDirections = value
                }*/
            case .associated://, .group:
                var ids = Set<PeerId>()
                switch self.peerIds {
                    case .single:
                        assertionFailure()
                    case let .associated(mainPeerId, associatedPeerId):
                        ids.insert(mainPeerId)
                        if let associatedPeerId = associatedPeerId {
                            ids.insert(associatedPeerId.peerId)
                        }
                    /*case let .group(groupId):
                        if let operations = transaction.currentGroupFeedOperations[groupId] {
                            groupOperations = operations
                        }
                        if let value = transaction.groupFeedIdsWithFilledHoles[groupId] {
                            holeFillDirections = value
                        }*/
                }
                
                if !ids.isEmpty {
                    for (peerId, value) in transaction.currentOperationsByPeerId {
                        if ids.contains(peerId) {
                            operations.append(value)
                        }
                    }
                    
                    /*for (peerId, value) in transaction.peerIdsWithFilledHoles {
                        if ids.contains(peerId) {
                            for (k, v) in value {
                                holeFillDirections[k] = v
                            }
                        }
                    }*/
                }
        }
        
        let tagMask = self.tagMask
        let unwrappedTagMask: UInt32 = tagMask?.rawValue ?? 0
        
        var hasChanges = false
        
        if let loadingInitialIndex = self.loadingInitialIndex {
            switch loadingInitialIndex {
                case let .groupFeedReadState(groupId):
                    break
                    /*if case .group(groupId) = self.peerIds, let updatedState = transaction.currentGroupFeedReadStateContext.updatedStates[groupId], let state = updatedState.state {
                        
                        self.combinedReadStates = .group(groupId, state)
                        self.transientReadStates = .group(groupId, state)
                        
                        self.anchorIndex = .message(index: state.maxReadIndex, exact: true)
                        
                        let (entries, earlier, later) = fetchAround(postbox: postbox, peerIds: peerIds, index: .message(index: state.maxReadIndex, exact: true), count: self.fillCount, tagMask: self.tagMask)
                        self.earlier = earlier
                        self.entries = entries
                        self.later = later
                        self.loadingInitialIndex = nil
                        
                        hasChanges = true
                    }*/
            }
        } else {
            for operationSet in operations {
                for operation in operationSet {
                    switch operation {
                        case let .InsertMessage(intermediateMessage):
                            if tagMask == nil || (intermediateMessage.tags.rawValue & unwrappedTagMask) != 0 {
                                if self.add(.IntermediateMessageEntry(intermediateMessage, nil, nil)) {
                                    hasChanges = true
                                }
                            }
                        case let .Remove(indices):
                            if self.remove(indices, context: context) {
                                hasChanges = true
                            }
                        case let .UpdateReadState(peerId, combinedReadState):
                            hasChanges = true
                            if let transientReadStates = self.transientReadStates {
                                switch transientReadStates {
                                    case let .peer(states):
                                        var updatedStates = states
                                        updatedStates[peerId] = combinedReadState
                                        self.transientReadStates = .peer(updatedStates)
                                    /*case .group:
                                        break*/
                                }
                            }
                        case let .UpdateEmbeddedMedia(index, embeddedMediaData):
                            for i in 0 ..< self.entries.count {
                                if case let .IntermediateMessageEntry(message, location, monthLocation) = self.entries[i] , message.index == index {
                                    self.entries[i] = .IntermediateMessageEntry(IntermediateMessage(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, authorId: message.authorId, text: message.text, attributesData: message.attributesData, embeddedMediaData: embeddedMediaData, referencedMedia: message.referencedMedia), location, monthLocation)
                                    hasChanges = true
                                    break
                                }
                            }
                        case let .UpdateTimestamp(index, timestamp):
                            for i in 0 ..< self.entries.count {
                                let entry = self.entries[i]
                                if entry.index == index {
                                    let _ = self.remove([(index, entry.tags)], context: context)
                                    let _ = self.add(entry.updatedTimestamp(timestamp))
                                    hasChanges = true
                                    break
                                }
                            }
                        case let .UpdateGroupInfos(mapping):
                            for i in 0 ..< self.entries.count {
                                if let groupInfo = mapping[self.entries[i].index.id] {
                                    switch self.entries[i] {
                                        case let .IntermediateMessageEntry(message, location, monthLocation):
                                            self.entries[i] = .IntermediateMessageEntry(message.withUpdatedGroupInfo(groupInfo), location, monthLocation)
                                            hasChanges = true
                                        case let .MessageEntry(message, location, monthLocation, attributes):
                                            self.entries[i] = .MessageEntry(message.withUpdatedGroupInfo(groupInfo), location, monthLocation, attributes)
                                            hasChanges = true
                                    }
                                }
                        }
                    }
                }
            }
            /*for operation in groupOperations {
                switch operation {
                    case let .insertMessage(message):
                        if self.add(.IntermediateMessageEntry(message, nil, nil), holeFillDirections: holeFillDirections) {
                            hasChanges = true
                        }
                    case let .removeMessage(index):
                        if self.remove([(index, true, [])], context: context) {
                            hasChanges = true
                        }
                    case let .insertHole(hole, lowerIndex):
                        if self.add(MutableMessageHistoryEntry.HoleEntry(hole, nil, lowerIndex: lowerIndex), holeFillDirections: holeFillDirections) {
                            hasChanges = true
                        }
                    case let .removeHole(index):
                        if self.remove([(index, false, [])], context: context) {
                            hasChanges = true
                        }
                }
            }*/
            
            if !updatedMedia.isEmpty {
                for i in 0 ..< self.entries.count {
                    switch self.entries[i] {
                        case let .MessageEntry(message, location, monthLocation, attributes):
                            var rebuild = false
                            for media in message.media {
                                if let mediaId = media.id, let _ = updatedMedia[mediaId] {
                                    rebuild = true
                                    break
                                }
                            }
                            
                            if rebuild {
                                var messageMedia: [Media] = []
                                for media in message.media {
                                    if let mediaId = media.id, let updated = updatedMedia[mediaId] {
                                        if let updated = updated {
                                            messageMedia.append(updated)
                                        }
                                    } else {
                                        messageMedia.append(media)
                                    }
                                }
                                let updatedMessage = Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, author: message.author, text: message.text, attributes: message.attributes, media: messageMedia, peers: message.peers, associatedMessages: message.associatedMessages, associatedMessageIds: message.associatedMessageIds)
                                self.entries[i] = .MessageEntry(updatedMessage, location, monthLocation, attributes)
                                hasChanges = true
                            }
                        case let .IntermediateMessageEntry(message, location, monthLocation):
                            var rebuild = false
                            for mediaId in message.referencedMedia {
                                if let media = updatedMedia[mediaId] , media?.id != mediaId {
                                    rebuild = true
                                    break
                                }
                            }
                            if rebuild {
                                var referencedMedia: [MediaId] = []
                                for mediaId in message.referencedMedia {
                                    if let media = updatedMedia[mediaId] , media?.id != mediaId {
                                        if let id = media?.id {
                                            referencedMedia.append(id)
                                        }
                                    } else {
                                        referencedMedia.append(mediaId)
                                    }
                                }
                                hasChanges = true
                            }
                        default:
                            break
                    }
                }
            }
            
            for operationSet in operations {
                for operation in operationSet {
                    switch operation {
                        case let .InsertMessage(intermediateMessage):
                            for i in 0 ..< self.entries.count {
                                switch self.entries[i] {
                                    case let .MessageEntry(message, location, monthLocation, attributes):
                                        if message.associatedMessageIds.count != message.associatedMessages.count {
                                            if message.associatedMessageIds.contains(intermediateMessage.id) && message.associatedMessages[intermediateMessage.id] == nil {
                                                var updatedAssociatedMessages = message.associatedMessages
                                                let renderedMessage = renderIntermediateMessage(intermediateMessage)
                                                updatedAssociatedMessages[intermediateMessage.id] = renderedMessage
                                                let updatedMessage = Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, author: message.author, text: message.text, attributes: message.attributes, media: message.media, peers: message.peers, associatedMessages: updatedAssociatedMessages, associatedMessageIds: message.associatedMessageIds)
                                                self.entries[i] = .MessageEntry(updatedMessage, location, monthLocation, attributes)
                                                hasChanges = true
                                            }
                                        }
                                        break
                                    default:
                                        break
                                }
                            }
                            break
                        default:
                            break
                    }
                }
            }
            
            for operationSet in operations {
                for operation in operationSet {
                    switch operation {
                        case let .InsertMessage(message):
                            if message.flags.contains(.TopIndexable) {
                                if let currentTopMessage = self.topTaggedMessages[message.id.namespace] {
                                    if currentTopMessage == nil || currentTopMessage!.id < message.id {
                                        self.topTaggedMessages[message.id.namespace] = MessageHistoryTopTaggedMessage.intermediate(message)
                                        hasChanges = true
                                    }
                                }
                            }
                        case let .Remove(indices):
                            if !self.topTaggedMessages.isEmpty {
                                for (index, _) in indices {
                                    if let maybeCurrentTopMessage = self.topTaggedMessages[index.id.namespace], let currentTopMessage = maybeCurrentTopMessage, index.id == currentTopMessage.id {
                                        let item: MessageHistoryTopTaggedMessage? = nil
                                        self.topTaggedMessages[index.id.namespace] = item
                                    }
                                }
                            }
                        default:
                            break
                    }
                }
            }
            
            /*if case let .group(groupId) = self.peerIds, let updatedState = transaction.currentGroupFeedReadStateContext.updatedStates[groupId], let state = updatedState.state {
                if let transientReadStates = transientReadStates, case .group(groupId, _) = transientReadStates {
                    self.transientReadStates = .group(groupId, state)
                    hasChanges = true
                }
            }*/
        }
        
        var updatedCachedPeerDataMessages = false
        var currentCachedPeerData: CachedPeerData?
        for i in 0 ..< self.additionalDatas.count {
            switch self.additionalDatas[i] {
                case let .cachedPeerData(peerId, currentData):
                    currentCachedPeerData = currentData
                    if let updatedData = updatedCachedPeerData[peerId] {
                        if currentData?.messageIds != updatedData.messageIds {
                            updatedCachedPeerDataMessages = true
                        }
                        currentCachedPeerData = updatedData
                        self.additionalDatas[i] = .cachedPeerData(peerId, updatedData)
                        hasChanges = true
                    }
                case .cachedPeerDataMessages:
                    break
                case let .peerChatState(peerId, _):
                    if transaction.currentUpdatedPeerChatStates.contains(peerId) {
                        self.additionalDatas[i] = .peerChatState(peerId, postbox.peerChatStateTable.get(peerId) as? PeerChatState)
                        hasChanges = true
                    }
                /*case let .peerGroupState(groupId, _):
                    if transaction.currentUpdatedPeerGroupStates.contains(groupId) {
                        self.additionalDatas[i] = .peerGroupState(groupId, postbox.peerGroupStateTable.get(groupId))
                        hasChanges = true
                    }*/
                case .totalUnreadState:
                    break
                case .peerNotificationSettings:
                    break
                case let .cacheEntry(entryId, _):
                    if transaction.updatedCacheEntryKeys.contains(entryId) {
                        self.additionalDatas[i] = .cacheEntry(entryId, postbox.retrieveItemCacheEntry(id: entryId))
                        hasChanges = true
                    }
                case .preferencesEntry:
                    break
                case let .peerIsContact(peerId, value):
                    if let replacedPeerIds = transaction.replaceContactPeerIds {
                        let updatedValue: Bool
                        if let contactPeer = postbox.peerTable.get(peerId), let associatedPeerId = contactPeer.associatedPeerId {
                            updatedValue = replacedPeerIds.contains(associatedPeerId)
                        } else {
                            updatedValue = replacedPeerIds.contains(peerId)
                        }
                        
                        if value != updatedValue {
                            self.additionalDatas[i] = .peerIsContact(peerId, value)
                            hasChanges = true
                        }
                    }
                case let .peer(peerId, _):
                    if let peer = transaction.currentUpdatedPeers[peerId] {
                        self.additionalDatas[i] = .peer(peerId, peer)
                        hasChanges = true
                    }
            }
        }
        if let cachedData = currentCachedPeerData, !cachedData.messageIds.isEmpty {
            for i in 0 ..< self.additionalDatas.count {
                switch self.additionalDatas[i] {
                    case .cachedPeerDataMessages(_, _):
                        outer: for operationSet in operations {
                            for operation in operationSet {
                                switch operation {
                                    case let .InsertMessage(message):
                                        if cachedData.messageIds.contains(message.id) {
                                            updatedCachedPeerDataMessages = true
                                            break outer
                                        }
                                    case let .Remove(indicesWithTags):
                                        for (index, _) in indicesWithTags {
                                            if cachedData.messageIds.contains(index.id) {
                                                updatedCachedPeerDataMessages = true
                                                break outer
                                            }
                                        }
                                    default:
                                        break
                                }
                            }
                        }
                    default:
                        break
                }
            }
        }
        
        if updatedCachedPeerDataMessages {
            hasChanges = true
            for i in 0 ..< self.additionalDatas.count {
                switch self.additionalDatas[i] {
                    case let .cachedPeerDataMessages(peerId, _):
                        var messages: [MessageId: Message] = [:]
                        if let cachedData = currentCachedPeerData {
                            for id in cachedData.messageIds {
                                if let message = postbox.getMessage(id) {
                                    messages[id] = message
                                }
                            }
                        }
                        self.additionalDatas[i] = .cachedPeerDataMessages(peerId, messages)
                    default:
                        break
                }
            }
        }
        
        if !transaction.currentPeerHoleOperations.isEmpty {
            var peerIdsSet: [PeerId] = []
            switch peerIds {
                case let .single(peerId):
                    peerIdsSet.append(peerId)
                case let .associated(peerId, associatedId):
                    peerIdsSet.append(peerId)
                    if let associatedId = associatedId {
                        peerIdsSet.append(associatedId.peerId)
                    }
            }
            let space: MessageHistoryHoleSpace = self.tagMask.flatMap(MessageHistoryHoleSpace.tag) ?? .everywhere
            for key in transaction.currentPeerHoleOperations.keys {
                if peerIdsSet.contains(key.peerId) && key.space == space {
                    hasChanges = true
                }
            }
        }
        
        if hasChanges {
            self.holes = fetchHoles(postbox: postbox, peerIds: self.peerIds, tagMask: self.tagMask, entries: self.entries, hasEarlier: self.earlier != nil, hasLater: self.later != nil)
        }
        
        return hasChanges
    }
    
    private func add(_ entry: MutableMessageHistoryEntry) -> Bool {
        let updated: Bool
        
        if self.entries.count == 0 {
            self.entries.append(entry)
            updated = true
        } else {
            let latestIndex = self.entries[self.entries.count - 1].index
            let earliestIndex = self.entries[0].index
            
            let index = entry.index
            
            if index < earliestIndex {
                if self.earlier == nil || self.earlier!.index < index {
                    self.entries.insert(entry, at: 0)
                    updated = true
                } else {
                    updated = false
                }
            } else if index > latestIndex {
                if let later = self.later {
                    if index < later.index {
                        self.entries.append(entry)
                        updated = true
                    } else {
                        updated = false
                    }
                } else {
                    self.entries.append(entry)
                    updated = true
                }
            } else if index != earliestIndex && index != latestIndex {
                var i = self.entries.count
                while i >= 1 {
                    if self.entries[i - 1].index < index {
                        break
                    }
                    i -= 1
                }
                self.entries.insert(entry, at: i)
                updated = true
            } else {
                updated = false
            }
        }
        
        if !self.orderStatistics.isEmpty {
            let entryIndex = entry.index
            
            if self.orderStatistics.contains(.combinedLocation) {
                for i in 0 ..< self.entries.count {
                    if self.entries[i].index != entryIndex {
                        self.entries[i] = self.entries[i].offsetLocationForInsertedIndex(entryIndex)
                    }
                }
            }
            if self.orderStatistics.contains(.locationWithinMonth) {
                
            }
        }
        
        return updated
    }
    
    private func remove(_ indicesAndFlags: [(MessageIndex, MessageTags)], context: MutableMessageHistoryViewReplayContext) -> Bool {
        let indices = Set(indicesAndFlags.map { $0.0 })
        var hasChanges = false
        if let earlier = self.earlier , indices.contains(earlier.index) {
            context.invalidEarlier = true
            hasChanges = true
        }
        
        if let later = self.later, indices.contains(later.index) {
            context.invalidLater = true
            hasChanges = true
        }
        
        var ids = Set<MessageId>()
        for index in indices {
            ids.insert(index.id)
        }
        
        if self.entries.count != 0 {
            var i = self.entries.count - 1
            while i >= 0 {
                let entry = self.entries[i]
                if indices.contains(entry.index) {
                    self.entries.remove(at: i)
                    
                    context.removedEntries = true
                    hasChanges = true
                } else {
                    switch entry {
                        case let .MessageEntry(message, location, monthLocation, attributes):
                            if let updatedAssociatedMessages = message.associatedMessages.filteredOut(keysIn: ids) {
                                let updatedMessage = Message(stableId: message.stableId, stableVersion: message.stableVersion, id: message.id, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, groupInfo: message.groupInfo, timestamp: message.timestamp, flags: message.flags, tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: message.forwardInfo, author: message.author, text: message.text, attributes: message.attributes, media: message.media, peers: message.peers, associatedMessages: updatedAssociatedMessages, associatedMessageIds: message.associatedMessageIds)
                                self.entries[i] = .MessageEntry(updatedMessage, location, monthLocation, attributes)
                            }
                        default:
                            break
                    }
                }
                i -= 1
            }
        }
        
        if let tagMask = self.tagMask {
            for (index, tags) in indicesAndFlags {
                if (tagMask.rawValue & tags.rawValue) != 0 {
                    for i in 0 ..< self.entries.count {
                        self.entries[i] = self.entries[i].offsetLocationForRemovedIndex(index)
                    }
                }
            }
        }
        
        return hasChanges
    }
    
    func updatePeers(_ peers: [PeerId: Peer]) -> Bool {
        return false
    }
    
    private func fetchEarlier(postbox: Postbox, index: MessageIndex?, count: Int) -> [MutableMessageHistoryEntry] {
        var ids: [PeerId] = []
        switch peerIds {
            case let .single(peerId):
                ids = [peerId]
            case let .associated(mainId, associatedId):
                ids.append(mainId)
                if let associatedId = associatedId {
                    ids.append(associatedId.peerId)
                }
            /*case let .group(groupId):
                return postbox.fetchEarlierGroupFeedEntries(groupId: groupId, index: index, count: count)*/
        }
        
        return clipMessages(peerIds: peerIds, entries: postbox.fetchEarlierHistoryEntries(peerIds: ids, index: index, count: count, tagMask: self.tagMask))
    }
    
    private func fetchLater(postbox: Postbox, index: MessageIndex?, count: Int) -> [MutableMessageHistoryEntry] {
        var ids: [PeerId] = []
        switch peerIds {
            case let .single(peerId):
                ids = [peerId]
            case let .associated(mainId, associatedId):
                ids.append(mainId)
                if let associatedId = associatedId {
                    ids.append(associatedId.peerId)
                }
            /*case let .group(groupId):
                return postbox.fetchLaterGroupFeedEntries(groupId: groupId, index: index, count: count)*/
        }
        
        return clipMessages(peerIds: peerIds, entries: postbox.fetchLaterHistoryEntries(ids, index: index, count: count, tagMask: self.tagMask))
    }
    
    func complete(postbox: Postbox, context: MutableMessageHistoryViewReplayContext) {
        if context.removedEntries && self.entries.count < self.fillCount {
            if self.entries.count == 0 {
                var anchorIndex: MessageIndex?
                
                if context.invalidLater {
                    var laterId: MessageIndex?
                    let i = self.entries.count - 1
                    if i >= 0 {
                        laterId = self.entries[i].index
                    }
                    
                    let laterEntries = self.fetchLater(postbox: postbox, index: laterId, count: 1)
                    anchorIndex = laterEntries.first?.index
                } else {
                    anchorIndex = self.later?.index
                }
                
                if anchorIndex == nil {
                    if context.invalidEarlier {
                        var earlyId: MessageIndex?
                        let i = 0
                        if i < self.entries.count {
                            earlyId = self.entries[i].index
                        }
                        
                        let earlierEntries = self.fetchEarlier(postbox: postbox, index: earlyId, count: 1)
                        anchorIndex = earlierEntries.first?.index
                    } else {
                        anchorIndex = self.earlier?.index
                    }
                }
                
                let fetchedEntries = self.fetchEarlier(postbox: postbox, index: anchorIndex, count: self.fillCount + 2)
                if fetchedEntries.count >= self.fillCount + 2 {
                    self.earlier = fetchedEntries.last
                    for i in (1 ..< fetchedEntries.count - 1).reversed() {
                        self.entries.append(fetchedEntries[i])
                    }
                    self.later = fetchedEntries.first
                } else if fetchedEntries.count >= self.fillCount + 1 {
                    self.earlier = fetchedEntries.last
                    for i in (1 ..< fetchedEntries.count).reversed() {
                        self.entries.append(fetchedEntries[i])
                    }
                    self.later = nil
                } else {
                    for i in (0 ..< fetchedEntries.count).reversed() {
                        self.entries.append(fetchedEntries[i])
                    }
                    self.earlier = nil
                    self.later = nil
                }
            } else {
                let fetchedEntries = self.fetchEarlier(postbox: postbox, index: self.entries[0].index, count: self.fillCount - self.entries.count)
                for entry in fetchedEntries {
                    self.entries.insert(entry, at: 0)
                }
                
                if context.invalidEarlier {
                    var earlyId: MessageIndex?
                    let i = 0
                    if i < self.entries.count {
                        earlyId = self.entries[i].index
                    }
                    
                    let earlierEntries = self.fetchEarlier(postbox: postbox, index: earlyId, count: 1)
                    self.earlier = earlierEntries.first
                }
                
                if context.invalidLater {
                    var laterId: MessageIndex?
                    let i = self.entries.count - 1
                    if i >= 0 {
                        laterId = self.entries[i].index
                    }
                    
                    let laterEntries = self.fetchLater(postbox: postbox, index: laterId, count: 1)
                    self.later = laterEntries.first
                }
            }
        } else {
            if context.invalidEarlier {
                var earlyId: MessageIndex?
                let i = 0
                if i < self.entries.count {
                    earlyId = self.entries[i].index
                }
                
                let earlierEntries = self.fetchEarlier(postbox: postbox, index: earlyId, count: 1)
                self.earlier = earlierEntries.first
            }
            
            if context.invalidLater {
                var laterId: MessageIndex?
                let i = self.entries.count - 1
                if i >= 0 {
                    laterId = self.entries[i].index
                }
                
                let laterEntries = fetchLater(postbox: postbox, index: laterId, count: 1)
                self.later = laterEntries.first
            }
        }
    }
    
    func render(_ renderIntermediateMessage: (IntermediateMessage) -> Message, postbox: Postbox) {
        if let earlier = self.earlier, case let .IntermediateMessageEntry(intermediateMessage, location, monthLocation) = earlier {
            self.earlier = .MessageEntry(renderIntermediateMessage(intermediateMessage), location, monthLocation, MutableMessageHistoryEntryAttributes(authorIsContact: false))
        }
        if let later = self.later, case let .IntermediateMessageEntry(intermediateMessage, location, monthLocation) = later {
            self.later = .MessageEntry(renderIntermediateMessage(intermediateMessage), location, monthLocation, MutableMessageHistoryEntryAttributes(authorIsContact: false))
        }
        
        for i in 0 ..< self.entries.count {
            if case let .IntermediateMessageEntry(intermediateMessage, location, monthLocation) = self.entries[i] {
                let message = renderIntermediateMessage(intermediateMessage)
                var authorIsContact = false
                if let author = message.author {
                    authorIsContact = postbox.contactsTable.isContact(peerId: author.id)
                }
                self.entries[i] = .MessageEntry(message, location, monthLocation, MutableMessageHistoryEntryAttributes(authorIsContact: authorIsContact))
            }
        }
        
        for namespace in self.topTaggedMessages.keys {
            if let entry = self.topTaggedMessages[namespace]!, case let .intermediate(message) = entry {
                let item: MessageHistoryTopTaggedMessage? = .message(renderIntermediateMessage(message))
                self.topTaggedMessages[namespace] = item
            }
        }
    }
    
    func firstHole() -> (MessageHistoryViewHole, MessageHistoryViewRelativeHoleDirection)? {
        if self.entries.isEmpty {
            if let (key, holeIndices) = self.holes.first {
                let hole = MessageHistoryViewPeerHole(peerId: key.peerId, namespace: key.namespace, indices: holeIndices)
                switch self.anchorIndex {
                    case let .message(index, _) where index.id.peerId == key.peerId && index.id.namespace == key.namespace:
                        /*if case let .group(groupId) = self.peerIds {
                         if let lowerIndex = lowerIndex {
                         if index >= lowerIndex && index <= hole.maxIndex {
                         return (.groupFeed(groupId, lowerIndex: lowerIndex, upperIndex: hole.maxIndex), .AroundIndex(index))
                         }
                         } else {
                         assertionFailure()
                         }
                         } else {*/
                        return (.peer(hole), .AroundId(index.id))
                    //}
                    default:
                        return (.peer(hole), .UpperToLower)
                }
            }
            return nil
        }
        
        var referenceIndex = self.entries.count - 1
        for i in 0 ..< self.entries.count {
            if self.anchorIndex.isLessOrEqual(to: self.entries[i].index) {
                referenceIndex = i
                break
            }
        }
        
        var i = referenceIndex
        var j = referenceIndex + 1
        
        func processId(_ id: MessageId, toLower: Bool) -> (MessageHistoryViewHole, MessageHistoryViewRelativeHoleDirection)? {
            if let holeIndices = self.holes[HoleKey(peerId: id.peerId, namespace: id.namespace)] {
                if holeIndices.contains(Int(id.id)) {
                    let hole = MessageHistoryViewPeerHole(peerId: id.peerId, namespace: id.namespace, indices: holeIndices)
                    switch self.anchorIndex {
                        case let .message(index, _) where index.id.peerId == id.peerId && index.id.namespace == id.namespace && holeIndices.contains(Int(index.id.id)):
                            return (.peer(hole), .AroundId(index.id))
                        default:
                            if toLower {
                                return (.peer(hole), .UpperToLower)
                            } else {
                                return (.peer(hole), .LowerToUpper)
                            }
                    }
                }
            }
            return nil
        }
        
        while i >= -1 || j <= self.entries.count {
            if j < self.entries.count {
                if let result = processId(entries[j].index.id, toLower: false) {
                    return result
                }
            }
            
            if i >= 0 {
                if let result = processId(entries[i].index.id, toLower: true) {
                    return result
                }
            }
            
            if i == -1 || j == self.entries.count {
                let toLower = i == -1
                
                var peerIdsSet: [PeerId] = []
                switch self.peerIds {
                    case let .single(peerId):
                        peerIdsSet.append(peerId)
                    case let .associated(peerId, associatedId):
                        peerIdsSet.append(peerId)
                        if let associatedId = associatedId {
                            peerIdsSet.append(associatedId.peerId)
                        }
                }
                var namespaceBounds: [(PeerId, MessageId.Namespace, ClosedRange<MessageId.Id>?)] = []
                for (key, hole) in self.holes {
                    var earlierId: MessageId.Id?
                    earlier: for entry in self.entries {
                        if entry.index.id.peerId == key.peerId && entry.index.id.namespace == key.namespace {
                            earlierId = entry.index.id.id
                            break earlier
                        }
                    }
                    var laterId: MessageId.Id?
                    later: for entry in self.entries.reversed() {
                        if entry.index.id.peerId == key.peerId && entry.index.id.namespace == key.namespace {
                            laterId = entry.index.id.id
                            break later
                        }
                    }
                    if let earlierId = earlierId, let laterId = laterId {
                        let validHole: Bool
                        if toLower {
                            validHole = hole.intersects(integersIn: 1 ... Int(earlierId))
                        } else {
                            validHole = hole.intersects(integersIn: Int(laterId) ... Int(Int32.max))
                        }
                        if validHole {
                            namespaceBounds.append((key.peerId, key.namespace, earlierId ... laterId))
                        }
                    } else {
                        namespaceBounds.append((key.peerId, key.namespace, nil))
                    }
                }
                
                for (peerId, namespace, bounds) in namespaceBounds {
                    if let indices = self.holes[HoleKey(peerId: peerId, namespace: namespace)] {
                        assert(!indices.isEmpty)
                        if let bounds = bounds {
                            var updatedIndices = indices
                            if toLower {
                                updatedIndices.remove(integersIn: Int(bounds.lowerBound) ... Int(Int32.max))
                            } else {
                                updatedIndices.remove(integersIn: 0 ... Int(bounds.upperBound))
                            }
                            if !updatedIndices.isEmpty {
                                let hole = MessageHistoryViewPeerHole(peerId: peerId, namespace: namespace, indices: updatedIndices)
                                if toLower {
                                    return (.peer(hole), .UpperToLower)
                                } else {
                                    return (.peer(hole), .LowerToUpper)
                                }
                            }
                        } else {
                            let hole = MessageHistoryViewPeerHole(peerId: peerId, namespace: namespace, indices: indices)
                            if toLower {
                                return (.peer(hole), .UpperToLower)
                            } else {
                                return (.peer(hole), .LowerToUpper)
                            }
                        }
                    }
                }
            }
            
            i -= 1
            j += 1
        }
        
        return nil
    }
}

public final class MessageHistoryView {
    public let id: MessageHistoryViewId
    public let tagMask: MessageTags?
    public let anchorIndex: MessageHistoryAnchorIndex
    public let earlierId: MessageIndex?
    public let laterId: MessageIndex?
    public let holeEarlier: Bool
    public let holeLater: Bool
    public let entries: [MessageHistoryEntry]
    public let maxReadIndex: MessageIndex?
    public let fixedReadStates: MessageHistoryViewReadState?
    public let topTaggedMessages: [Message]
    public let additionalData: [AdditionalMessageHistoryViewDataEntry]
    public let isLoading: Bool
    
    init(_ mutableView: MutableMessageHistoryView) {
        self.id = mutableView.id
        self.tagMask = mutableView.tagMask
        self.anchorIndex = MessageHistoryAnchorIndex(mutableView.anchorIndex)
        self.isLoading = mutableView.loadingInitialIndex != nil
        
        var earlierId = mutableView.earlier?.index
        var laterId = mutableView.later?.index
        
        var entries: [MessageHistoryEntry] = []
        var removeUpperHolePeerId: PeerId?
        if case let .associated(_, associatedId) = mutableView.peerIds {
            removeUpperHolePeerId = associatedId?.peerId
        }
        if let transientReadStates = mutableView.transientReadStates, case let .peer(states) = transientReadStates {
            for entry in mutableView.entries {
                switch entry {
                    case let .MessageEntry(message, location, monthLocation, attributes):
                        let read: Bool
                        if message.flags.contains(.Incoming) {
                            read = false
                        } else if let readState = states[message.id.peerId] {
                            read = readState.isOutgoingMessageIndexRead(message.index)
                        } else {
                            read = false
                        }
                        entries.append(MessageHistoryEntry(message: message, isRead: read, location: location, monthLocation: monthLocation, attributes: attributes))
                    case .IntermediateMessageEntry:
                        assertionFailure("unexpected IntermediateMessageEntry in MessageHistoryView.init()")
                }
            }
        } else {
            for entry in mutableView.entries {
                switch entry {
                    case let .MessageEntry(message, location, monthLocation, attributes):
                        entries.append(MessageHistoryEntry(message: message, isRead: false, location: location, monthLocation: monthLocation, attributes: attributes))
                    case .IntermediateMessageEntry:
                        assertionFailure("unexpected IntermediateMessageEntry in MessageHistoryView.init()")
                }
            }
        }
        var holeEarlier = false
        var holeLater = false
        if mutableView.clipHoles {
            if entries.isEmpty {
                if !mutableView.holes.isEmpty {
                    holeEarlier = true
                    holeLater = true
                }
            } else {
                var referenceIndex = entries.count - 1
                for i in 0 ..< entries.count {
                    if self.anchorIndex.isLessOrEqual(to: entries[i].index) {
                        referenceIndex = i
                        break
                    }
                }
                var groupStart: (Int, MessageGroupInfo)?
                for i in referenceIndex ..< entries.count {
                    let id = entries[i].message.id
                    if let holeIndices = mutableView.holes[HoleKey(peerId: id.peerId, namespace: id.namespace)] {
                        if holeIndices.contains(Int(id.id)) {
                            if let groupStart = groupStart {
                                entries.removeSubrange(groupStart.0 ..< entries.count)
                            } else {
                                entries.removeSubrange(i ..< entries.count)
                            }
                            laterId = nil
                            holeLater = true
                            break
                        }
                    }
                    /*if let groupStart = groupStart {
                        entries.removeSubrange(groupStart.0 ..< entries.count)
                        laterId = nil
                    } else {
                        if i != entries.count - 1 {
                            entries.removeSubrange(i + 1 ..< entries.count)
                            laterId = nil
                        }
                    }*/
                    if let groupInfo = entries[i].message.groupInfo {
                        if let groupStart = groupStart, groupStart.1 == groupInfo {
                        } else {
                            groupStart = (i, groupInfo)
                        }
                    } else {
                        groupStart = nil
                    }
                }
                if let groupStart = groupStart, laterId != nil {
                    entries.removeSubrange(groupStart.0 ..< entries.count)
                }
                
                groupStart = nil
                if !entries.isEmpty {
                    for i in (0 ... min(referenceIndex, entries.count - 1)).reversed() {
                        let id = entries[i].message.id
                        if let holeIndices = mutableView.holes[HoleKey(peerId: id.peerId, namespace: id.namespace)] {
                            if holeIndices.contains(Int(id.id)) {
                                if let groupStart = groupStart {
                                    entries.removeSubrange(0 ..< groupStart.0 + 1)
                                } else {
                                    entries.removeSubrange(0 ... i)
                                }
                                earlierId = nil
                                holeEarlier = true
                                break
                            }
                        }
                        /*if let groupStart = groupStart {
                            entries.removeSubrange(0 ..< groupStart.0 + 1)
                            earlierId = nil
                        } else {
                            if i != 0 {
                                entries.removeSubrange(0 ..< i)
                                earlierId = nil
                            }
                        }
                        break
                        */
                        if let groupInfo = entries[i].message.groupInfo {
                            if let groupStart = groupStart, groupStart.1 == groupInfo {
                            } else {
                                groupStart = (i, groupInfo)
                            }
                        } else {
                            groupStart = nil
                        }
                    }
                    if let groupStart = groupStart, earlierId != nil {
                        entries.removeSubrange(0 ..< groupStart.0 + 1)
                    }
                }
            }
        }
        self.holeEarlier = holeEarlier
        self.holeLater = holeLater
        self.entries = entries
        
        var topTaggedMessages: [Message] = []
        for (_, message) in mutableView.topTaggedMessages {
            if let message = message {
                switch message {
                    case let .message(message):
                        topTaggedMessages.append(message)
                    default:
                        assertionFailure("unexpected intermediate tagged message entry in MessageHistoryView.init()")
                }
            }
        }
        self.topTaggedMessages = topTaggedMessages
        self.additionalData = mutableView.additionalDatas
        
        self.earlierId = earlierId
        self.laterId = laterId
        
        self.fixedReadStates = mutableView.combinedReadStates
        
        if let combinedReadStates = mutableView.combinedReadStates {
            switch combinedReadStates {
                case let .peer(states):
                    var hasUnread = false
                    for (_, readState) in states {
                        if readState.count > 0 {
                            hasUnread = true
                            break
                        }
                    }
                    
                    var maxIndex: MessageIndex?
                    
                    if hasUnread {
                        var peerIds = Set<PeerId>()
                        for entry in entries {
                            peerIds.insert(entry.index.id.peerId)
                        }
                        for peerId in peerIds {
                            if let combinedReadState = states[peerId] {
                                for (namespace, state) in combinedReadState.states {
                                    var maxNamespaceIndex: MessageIndex?
                                    var index = entries.count - 1
                                    for entry in entries.reversed() {
                                        if entry.index.id.peerId == peerId && entry.index.id.namespace == namespace && state.isIncomingMessageIndexRead(entry.index) {
                                            maxNamespaceIndex = entry.index
                                            break
                                        }
                                        index -= 1
                                    }
                                    if maxNamespaceIndex == nil && index == -1 && entries.count != 0 {
                                        index = 0
                                        for entry in entries {
                                            if entry.index.id.peerId == peerId && entry.index.id.namespace == namespace {
                                                maxNamespaceIndex = entry.index.predecessor()
                                                break
                                            }
                                            index += 1
                                        }
                                    }
                                    if let _ = maxNamespaceIndex , index + 1 < entries.count {
                                        for i in index + 1 ..< entries.count {
                                            if !entries[i].message.flags.contains(.Incoming) {
                                                maxNamespaceIndex = entries[i].message.index
                                            } else {
                                                break
                                            }
                                        }
                                    }
                                    if let maxNamespaceIndex = maxNamespaceIndex , maxIndex == nil || maxIndex! < maxNamespaceIndex {
                                        maxIndex = maxNamespaceIndex
                                    }
                                }
                            }
                        }
                    }
                    self.maxReadIndex = maxIndex
                /*case let .group(_, state):
                    var maxIndex: MessageIndex?
                    var index = entries.count - 1
                    for entry in entries.reversed() {
                        if state.isIncomingMessageIndexRead(entry.index) {
                            maxIndex = entry.index
                            break
                        }
                        index -= 1
                    }
                    if maxIndex == nil && index == -1 && entries.count != 0 {
                        index = 0
                        for entry in entries {
                            maxIndex = entry.index.predecessor()
                            break
                        }
                    }
                    if let _ = maxIndex, index + 1 < entries.count {
                        for i in index + 1 ..< entries.count {
                            if case let .MessageEntry(message, _, _, _, _) = entries[i], !message.flags.contains(.Incoming) {
                                maxIndex = MessageIndex(message)
                            } else {
                                break
                            }
                        }
                    }
                    self.maxReadIndex = maxIndex*/
            }
        } else {
            self.maxReadIndex = nil
        }
    }
}
