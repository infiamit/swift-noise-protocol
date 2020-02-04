enum HandshakeStateError: Error {
  case invalidPattern // should not happen in normal use case
  case invalidPremessagePattern
  case invalidMessagePattern
  case missingStaticKey
  case missingRemoteStaticKey
  case staticKeyAlreadyExist
  case missingEphemeralKey
  case missingRemoteEphemeralKey
  case ephemeralKeyAlreadyExist
  case incompleteHandshake
  case completedHandshake
  case messageTooShort
}
