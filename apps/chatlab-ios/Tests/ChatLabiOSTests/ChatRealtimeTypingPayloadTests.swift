@testable import ChatLabiOS
import XCTest

final class ChatRealtimeTypingPayloadTests: XCTestCase {
    // MARK: - identityKey

    func testIdentityKeyPrefersActorUserUuid() {
        let payload = makePayload(
            user: "a@example.com",
            senderId: 2,
            actorUserId: 1,
            actorUserUuid: "uuid-abc",
        )
        XCTAssertEqual(payload.identityKey, "uuid-abc")
    }

    func testIdentityKeyFallsToActorUserIdWhenNoUuid() {
        let payload = makePayload(user: "a@example.com", senderId: 99, actorUserId: 42)
        XCTAssertEqual(payload.identityKey, "42")
    }

    func testIdentityKeyFallsToSenderIdWhenNoUuidOrActorUserId() {
        let payload = makePayload(user: "a@example.com", senderId: 99)
        XCTAssertEqual(payload.identityKey, "99")
    }

    func testIdentityKeyFallsToUserEmailWhenNoIds() {
        let payload = makePayload(user: "legacy@example.com")
        XCTAssertEqual(payload.identityKey, "legacy@example.com")
    }

    func testIdentityKeyIsUnknownWhenAllNil() {
        let payload = makePayload()
        XCTAssertEqual(payload.identityKey, "unknown")
    }

    // MARK: - normalizedActorType

    func testNormalizedActorTypeReturnsUserWhenAbsent() {
        let payload = makePayload()
        XCTAssertEqual(payload.normalizedActorType, "user")
    }

    func testNormalizedActorTypeReturnsSystemWhenPresent() {
        let payload = makePayload(actorType: "system")
        XCTAssertEqual(payload.normalizedActorType, "system")
    }

    // MARK: - isFromCurrentUser: suppressed by actor_user_id (Case A)

    func testSuppressesSelfByActorUserId() {
        let payload = makePayload(actorType: "user", actorUserId: 10)
        XCTAssertTrue(payload.isFromCurrentUser(currentUserId: 10, currentUserUuid: nil, currentUserEmail: nil))
    }

    func testDoesNotSuppressDifferentActorUserId() {
        let payload = makePayload(actorType: "user", actorUserId: 10)
        XCTAssertFalse(payload.isFromCurrentUser(currentUserId: 99, currentUserUuid: nil, currentUserEmail: nil))
    }

    // MARK: - isFromCurrentUser: suppressed by sender_id (Case B)

    func testSuppressesSelfBySenderId() {
        let payload = makePayload(actorType: "user", senderId: 7)
        XCTAssertTrue(payload.isFromCurrentUser(currentUserId: 7, currentUserUuid: nil, currentUserEmail: nil))
    }

    func testDoesNotSuppressDifferentSenderId() {
        let payload = makePayload(actorType: "user", senderId: 7)
        XCTAssertFalse(payload.isFromCurrentUser(currentUserId: 99, currentUserUuid: nil, currentUserEmail: nil))
    }

    // MARK: - isFromCurrentUser: suppressed by UUID (Case C)

    func testSuppressesSelfByUuid() {
        let uuid = "550e8400-e29b-41d4-a716-446655440000"
        let payload = makePayload(actorType: "user", actorUserUuid: uuid)
        XCTAssertTrue(payload.isFromCurrentUser(currentUserId: nil, currentUserUuid: uuid, currentUserEmail: nil))
    }

    func testUuidComparisonIsCaseInsensitive() {
        let payload = makePayload(actorType: "user", actorUserUuid: "UPPER-UUID")
        XCTAssertTrue(payload.isFromCurrentUser(currentUserId: nil, currentUserUuid: "upper-uuid", currentUserEmail: nil))
    }

    func testDoesNotSuppressDifferentUuid() {
        let payload = makePayload(actorType: "user", actorUserUuid: "uuid-a")
        XCTAssertFalse(payload.isFromCurrentUser(currentUserId: nil, currentUserUuid: "uuid-b", currentUserEmail: nil))
    }

    // MARK: - isFromCurrentUser: suppressed by legacy email (Case D)

    func testSuppressesSelfByLegacyEmail() {
        let payload = makePayload(user: "me@example.com")
        XCTAssertTrue(payload.isFromCurrentUser(currentUserId: nil, currentUserUuid: nil, currentUserEmail: "me@example.com"))
    }

    func testEmailComparisonIsCaseInsensitive() {
        let payload = makePayload(user: "Me@Example.COM")
        XCTAssertTrue(payload.isFromCurrentUser(currentUserId: nil, currentUserUuid: nil, currentUserEmail: "me@example.com"))
    }

    func testLegacyEmailWithMissingActorTypeTreatedAsUser() {
        // actor_type absent → treated as "user" → legacy check applies
        let payload = makePayload(user: "me@example.com")
        XCTAssertNil(payload.actorType)
        XCTAssertTrue(payload.isFromCurrentUser(currentUserId: nil, currentUserUuid: nil, currentUserEmail: "me@example.com"))
    }

    // MARK: - isFromCurrentUser: allows system typing (Case E)

    func testSystemActorTypeIsNeverSelf() {
        let payload = makePayload(
            user: "system@medsim.local",
            displayInitials: "TP",
            actorType: "system",
        )
        XCTAssertFalse(payload.isFromCurrentUser(
            currentUserId: nil,
            currentUserUuid: nil,
            currentUserEmail: "system@medsim.local",
        ))
        XCTAssertFalse(payload.isFromCurrentUser(
            currentUserId: 0,
            currentUserUuid: nil,
            currentUserEmail: nil,
        ))
    }

    // MARK: - isFromCurrentUser: allows another user (Case F)

    func testAnotherUserIsNotSelf() {
        let payload = makePayload(
            user: "other@example.com",
            actorType: "user",
            senderId: 55,
        )
        XCTAssertFalse(payload.isFromCurrentUser(
            currentUserId: 7,
            currentUserUuid: nil,
            currentUserEmail: "me@example.com",
        ))
    }

    // MARK: - identity does not use initials (Case G)

    func testTwoUsersWithSameInitialsGetDistinctKeys() {
        let p1 = makePayload(displayInitials: "JD", actorUserId: 10)
        let p2 = makePayload(displayInitials: "JD", actorUserId: 20)
        XCTAssertNotEqual(p1.identityKey, p2.identityKey)
    }

    // MARK: - Codable: new fields absent in old payloads

    func testDecodesLegacyPayloadWithoutNewFields() throws {
        let json = """
        {
            "conversation_id": 3,
            "user": "legacy@example.com",
            "display_initials": "LE"
        }
        """
        let payload = try JSONDecoder().decode(ChatRealtimeTypingPayload.self, from: Data(json.utf8))
        XCTAssertEqual(payload.conversationID, 3)
        XCTAssertEqual(payload.user, "legacy@example.com")
        XCTAssertEqual(payload.displayInitials, "LE")
        XCTAssertNil(payload.actorType)
        XCTAssertNil(payload.senderId)
        XCTAssertNil(payload.actorUserId)
        XCTAssertNil(payload.actorUserUuid)
        XCTAssertEqual(payload.identityKey, "legacy@example.com")
    }

    func testDecodesEnrichedPayload() throws {
        let json = """
        {
            "conversation_id": 5,
            "user": "doc@example.com",
            "display_initials": "DC",
            "actor_type": "user",
            "sender_id": 7,
            "actor_user_id": 7,
            "actor_user_uuid": "abc-def-123"
        }
        """
        let payload = try JSONDecoder().decode(ChatRealtimeTypingPayload.self, from: Data(json.utf8))
        XCTAssertEqual(payload.actorType, "user")
        XCTAssertEqual(payload.senderId, 7)
        XCTAssertEqual(payload.actorUserId, 7)
        XCTAssertEqual(payload.actorUserUuid, "abc-def-123")
        XCTAssertEqual(payload.identityKey, "abc-def-123")
    }

    func testDecodesSystemPayloadWithNullIds() throws {
        let json = """
        {
            "conversation_id": 1,
            "user": "system@medsim.local",
            "display_initials": "TP",
            "actor_type": "system",
            "sender_id": null,
            "actor_user_id": null,
            "actor_user_uuid": null
        }
        """
        let payload = try JSONDecoder().decode(ChatRealtimeTypingPayload.self, from: Data(json.utf8))
        XCTAssertEqual(payload.actorType, "system")
        XCTAssertNil(payload.senderId)
        XCTAssertNil(payload.actorUserId)
        XCTAssertNil(payload.actorUserUuid)
        XCTAssertEqual(payload.identityKey, "system@medsim.local")
        XCTAssertFalse(payload.isFromCurrentUser(
            currentUserId: nil,
            currentUserUuid: nil,
            currentUserEmail: "system@medsim.local",
        ))
    }

    // MARK: - Helpers

    private func makePayload(
        conversationID: Int? = nil,
        user: String? = nil,
        displayInitials: String? = nil,
        actorType: String? = nil,
        senderId: Int? = nil,
        actorUserId: Int? = nil,
        actorUserUuid: String? = nil,
    ) -> ChatRealtimeTypingPayload {
        ChatRealtimeTypingPayload(
            conversationID: conversationID,
            user: user,
            displayInitials: displayInitials,
            actorType: actorType,
            senderId: senderId,
            actorUserId: actorUserId,
            actorUserUuid: actorUserUuid,
        )
    }
}
