import XCTest
import SwiftNoise

func getKeyPair(secretKey: Data?) -> KeyPair? {
  if secretKey == nil {
    return nil
  }
  return constructKeyPair(secretKey: secretKey!)
}

func getPublicKey(secretKey: Data?) -> PublicKey? {
  let keyPair = getKeyPair(secretKey: secretKey)
  if keyPair == nil {
    return nil
  }
  return keyPair!.publicKey
}

final class SwiftNoiseTests: XCTestCase {
  static var allTests = [
    ("testSnowVectors", testSnowVectors)
  ]

  func testSnowVectors() {
    let supportedCipherSuites = [
      "Noise_N_25519_AESGCM_SHA256",
      "Noise_K_25519_AESGCM_SHA256",
      "Noise_X_25519_AESGCM_SHA256",
      "Noise_NN_25519_AESGCM_SHA256",
      "Noise_NK_25519_AESGCM_SHA256",
      "Noise_NX_25519_AESGCM_SHA256",
      "Noise_KN_25519_AESGCM_SHA256",
      "Noise_KK_25519_AESGCM_SHA256",
      "Noise_KX_25519_AESGCM_SHA256",
      "Noise_XN_25519_AESGCM_SHA256",
      "Noise_XK_25519_AESGCM_SHA256",
      "Noise_XX_25519_AESGCM_SHA256",
      "Noise_IN_25519_AESGCM_SHA256",
      "Noise_IK_25519_AESGCM_SHA256",
      "Noise_IX_25519_AESGCM_SHA256"
    ]
    
    let path = Bundle(path: "Tests/SwiftNoiseTests")!.path(forResource: "SnowTestVectors", ofType: "json")
    let url = URL(fileURLWithPath: path!)
    let data = try! Data(contentsOf: url)
    let json = try! JSONDecoder().decode(SnowTestVectors.self, from: data)
    let testVectors = json.vectors
    testVectors.forEach { testVector in
      if !supportedCipherSuites.contains(testVector.protocolName) {
        return
      }
      let pattern = try! getPatternFromProtocolName(protocolName: testVector.protocolName)
      let initiatorState = try! HandshakeState(
        pattern: pattern,
        initiator: true,
        prologue: testVector.initPrologue,
        s: getKeyPair(secretKey: testVector.initStatic),
        e: getKeyPair(secretKey: testVector.initEphemeral),
        rs: testVector.initRemoteStatic
      )

      let responderState = try! HandshakeState(
        pattern: pattern,
        initiator: false,
        prologue: testVector.respPrologue,
        s: getKeyPair(secretKey: testVector.respStatic),
        e: getKeyPair(secretKey: testVector.respEphemeral),
        rs: testVector.respRemoteStatic
      )

      for index in 0..<testVector.messages.count {
        let message = testVector.messages[index]
        if index & 1 == 0 {
          let tx = try! initiatorState.writeMessage(payload: message.payload)
          assert(try! responderState.readMessage(message: tx) == message.payload)
          assert(tx == message.ciphertext)
        } else {
          let tx = try! responderState.writeMessage(payload: message.payload)
          assert(try! initiatorState.readMessage(message: tx) == message.payload)
          assert(tx == message.ciphertext)
        }
      }
    }
  }
}

enum TestError: Error {
  case invalidProtocolName
}

func getPatternFromProtocolName(protocolName: String) throws -> HandshakePattern {
  let components = protocolName.components(separatedBy: "_")
  if components.count != 5 {
    throw TestError.invalidProtocolName
  }
  return HandshakePattern(rawValue: components[1])!
}

struct SnowTestVectors: Codable {
  var vectors: [SnowTestVector]
}

struct SnowTestVector {
  var protocolName: String
  var initPrologue: Data
  var initPsks: [Data]
  var initStatic: Data?
  var initEphemeral: Data
  var initRemoteStatic: Data?
  var respPrologue: Data
  var respPsks: [Data]
  var respStatic: Data?
  var respEphemeral: Data
  var respRemoteStatic: Data?
  var messages: [Message]

  enum CodingKeys: String, CodingKey {
    case protocolName = "protocol_name"
    case initPrologue = "init_prologue"
    case initPsks = "init_psks"
    case initStatic = "init_static"
    case initEphemeral = "init_ephemeral"
    case initRemoteStatic = "init_remote_static"
    case respPrologue = "resp_prologue"
    case respPsks = "resp_psks"
    case respStatic = "resp_static"
    case respEphemeral = "resp_ephemeral"
    case respRemoteStatic = "resp_remote_static"
    case messages = "messages"
  }
}

extension SnowTestVector: Encodable {}

extension SnowTestVector: Decodable {
  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    self.protocolName = try values.decode(String.self, forKey: .protocolName)
    self.initPrologue = try values.decodeHex(forKey: .initPrologue)!
    self.initPsks = []
    self.initStatic = try values.decodeHex(forKey: .initStatic)
    self.initEphemeral = try values.decodeHex(forKey: .initEphemeral)!
    self.initRemoteStatic = try values.decodeHex(forKey: .initRemoteStatic)
    self.respPrologue = try values.decodeHex(forKey: .respPrologue)!
    self.respPsks = []
    self.respStatic = try values.decodeHex(forKey: .respStatic)
    self.respEphemeral = try values.decodeHex(forKey: .respEphemeral)!
    self.respRemoteStatic = try values.decodeHex(forKey: .respRemoteStatic)
    self.messages = try values.decode([Message].self, forKey: .messages)
  }
}

struct Message {
  var payload: Data
  var ciphertext: Data

  enum CodingKeys: String, CodingKey {
    case payload = "payload"
    case ciphertext = "ciphertext"
  }
}

extension Message: Encodable {}
extension Message: Decodable {
  init(from decoder: Decoder) {
    let values = try! decoder.container(keyedBy: CodingKeys.self)
    self.payload = try! values.decodeHex(forKey: .payload)!
    self.ciphertext = try! values.decodeHex(forKey: .ciphertext)!
  }
}

extension KeyedDecodingContainer {
  func decodeHex(forKey key: Key) -> Data? {
    if !self.contains(key) {
      return nil
    }
    let hexString = try! self.decode(String.self, forKey: key)
    return Data(hex: hexString)
  }
}