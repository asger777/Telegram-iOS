import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

private enum MessagePreParsingError: Error {
    case invalidChatState
    case malformedData
    case protocolViolation
}

func processSecretChatIncomingEncryptedOperations(modifier: Modifier, peerId: PeerId) -> Bool {
    if let state = modifier.getPeerChatState(peerId) as? SecretChatState {
        var removeTagLocalIndices: [Int32] = []
        var addedDecryptedOperations = false
        modifier.operationLogEnumerateEntries(peerId: peerId, tag: OperationLogTags.SecretIncomingEncrypted, { entry in
            if let operation = entry.contents as? SecretChatIncomingEncryptedOperation {
                if let key = state.keychain.key(fingerprint: operation.keyFingerprint) {
                    withDecryptedMessageContents(key: key, data: operation.contents, { decryptedContents in
                        if let decryptedContents = decryptedContents {
                            withExtendedLifetime(decryptedContents, {
                                let buffer = BufferReader(Buffer(bufferNoCopy: decryptedContents))
                                
                                do {
                                    guard let topLevelSignature = buffer.readInt32() else {
                                        throw MessagePreParsingError.malformedData
                                    }
                                    let parsedLayer: Int32
                                    let sequenceInfo: SecretChatOperationSequenceInfo?
                                    
                                    if topLevelSignature == 0x1be31789 {
                                        guard let _ = parseBytes(buffer) else {
                                            throw MessagePreParsingError.malformedData
                                        }
                                        
                                        guard let layerValue = buffer.readInt32() else {
                                            throw MessagePreParsingError.malformedData
                                        }
                                        
                                        guard let seqInValue = buffer.readInt32() else {
                                            throw MessagePreParsingError.malformedData
                                        }
                                        
                                        guard let seqOutValue = buffer.readInt32() else {
                                            throw MessagePreParsingError.malformedData
                                        }
                                        
                                        switch state.role {
                                            case .creator:
                                                if seqInValue < 0 || seqOutValue < 0 || (seqInValue & 1) == 0 || (seqOutValue & 1) != 0 {
                                                    throw MessagePreParsingError.protocolViolation
                                                }
                                            case .participant:
                                                if seqInValue < 0 || seqOutValue < 0 || (seqInValue & 1) != 0 || (seqOutValue & 1) == 0 {
                                                    throw MessagePreParsingError.protocolViolation
                                                }
                                        }
                                        
                                        sequenceInfo = SecretChatOperationSequenceInfo(topReceivedOperationIndex: seqInValue / 2, operationIndex: seqOutValue / 2)
                                        
                                        parsedLayer = layerValue
                                    } else {
                                        parsedLayer = 8
                                        sequenceInfo = nil
                                        buffer.reset()
                                    }
                                    
                                    guard let messageContents = buffer.readBuffer(decryptedContents.length - Int(buffer.offset)) else {
                                        throw MessagePreParsingError.malformedData
                                    }
                                    
                                    let entryTagLocalIndex: StorePeerOperationLogEntryTagLocalIndex
                                    
                                    switch state.embeddedState {
                                        case .terminated:
                                            throw MessagePreParsingError.invalidChatState
                                        case .handshake:
                                            throw MessagePreParsingError.invalidChatState
                                        case .basicLayer:
                                            if parsedLayer >= 46 {
                                                guard let sequenceInfo = sequenceInfo else {
                                                    throw MessagePreParsingError.protocolViolation
                                                }
                                                let sequenceBasedLayerState = SecretChatSequenceBasedLayerState(layerNegotiationState: SecretChatLayerNegotiationState(activeLayer: parsedLayer, locallyRequestedLayer: parsedLayer, remotelyRequestedLayer: parsedLayer), rekeyState: nil, baseIncomingOperationIndex: entry.tagLocalIndex, baseOutgoingOperationIndex: modifier.operationLogGetNextEntryLocalIndex(peerId: peerId, tag: OperationLogTags.SecretOutgoing), topProcessedCanonicalIncomingOperationIndex: sequenceInfo.operationIndex)
                                                let updatedState = state.withUpdatedEmbeddedState(.sequenceBasedLayer(sequenceBasedLayerState))
                                                modifier.setPeerChatState(peerId, state: updatedState)
                                                entryTagLocalIndex = .manual(sequenceBasedLayerState.baseIncomingOperationIndex + sequenceInfo.operationIndex)
                                            } else {
                                                if parsedLayer != 8 {
                                                    throw MessagePreParsingError.protocolViolation
                                                }
                                                entryTagLocalIndex = .automatic
                                            }
                                        case let .sequenceBasedLayer(sequenceState):
                                            if parsedLayer < 46 {
                                                throw MessagePreParsingError.protocolViolation
                                            }
                                        
                                            entryTagLocalIndex = .manual(sequenceState.baseIncomingOperationIndex + sequenceInfo!.operationIndex)
                                    }
                                    
                                    modifier.operationLogAddEntry(peerId: peerId, tag: OperationLogTags.SecretIncomingDecrypted, tagLocalIndex: entryTagLocalIndex, tagMergedIndex: .none, contents: SecretChatIncomingDecryptedOperation(timestamp: operation.timestamp, layer: parsedLayer, sequenceInfo: sequenceInfo, contents: MemoryBuffer(messageContents), file: operation.mediaFileReference))
                                    addedDecryptedOperations = true
                                } catch let error {
                                    if let error = error as? MessagePreParsingError {
                                        switch error {
                                            case .invalidChatState:
                                                break
                                            case .malformedData, .protocolViolation:
                                                break
                                        }
                                    }
                                    trace("SecretChat", what: "peerId \(peerId) malformed data after decryption")
                                }
                                
                                removeTagLocalIndices.append(entry.tagLocalIndex)
                            })
                        } else {
                            trace("SecretChat", what: "peerId \(peerId) couldn't decrypt message content")
                            removeTagLocalIndices.append(entry.tagLocalIndex)
                        }
                    })
                } else {
                    trace("SecretChat", what: "peerId \(peerId) key \(operation.keyFingerprint) doesn't exist")
                }
            } else {
                assertionFailure()
            }
            return true
        })
        for index in removeTagLocalIndices {
            let removed = modifier.operationLogRemoveEntry(peerId: peerId, tag: OperationLogTags.SecretIncomingEncrypted, tagLocalIndex: index)
            assert(removed)
        }
        return addedDecryptedOperations
    } else {
        assertionFailure()
        return false
    }
}
