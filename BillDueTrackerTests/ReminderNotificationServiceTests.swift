import XCTest
@testable import BillDueTracker
import UserNotifications

@MainActor
final class ReminderNotificationServiceTests: XCTestCase {
    func testAuthorizationStatusPassThrough() async {
        let center = FakeNotificationCenter()
        center.stubAuthorizationStatus = .authorized
        let service = ReminderNotificationService(center: center)

        let status = await service.authorizationStatus()
        XCTAssertEqual(status, .authorized)
    }

    func testPendingRequestsPassThrough() async {
        let center = FakeNotificationCenter()
        center.stubPendingRequests = [
            UNNotificationRequest(
                identifier: "test-1",
                content: UNMutableNotificationContent(),
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
            )
        ]
        let service = ReminderNotificationService(center: center)

        let requests = await service.pendingRequests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.identifier, "test-1")
    }

    func testScheduleSelfTestNotificationCreatesExpectedRequest() async throws {
        let center = FakeNotificationCenter()
        let service = ReminderNotificationService(center: center)

        try await service.scheduleSelfTestNotification(after: 5)

        XCTAssertEqual(center.addedRequests.count, 1)
        let request = try XCTUnwrap(center.addedRequests.first)
        XCTAssertTrue(request.identifier.hasPrefix("reminder-self-test-"))
        XCTAssertEqual(request.content.title, "Bill Due Tracker Test")
        XCTAssertEqual(request.content.body, "Notifications are active on this device.")

        let trigger = try XCTUnwrap(request.trigger as? UNTimeIntervalNotificationTrigger)
        XCTAssertEqual(trigger.timeInterval, 5, accuracy: 0.1)
        XCTAssertFalse(trigger.repeats)
    }

    func testNextTriggerDateReturnsNilWhenTriggerHasNoDate() async {
        let service = ReminderNotificationService(center: FakeNotificationCenter())
        let request = UNNotificationRequest(
            identifier: "none",
            content: UNMutableNotificationContent(),
            trigger: nil
        )

        XCTAssertNil(service.nextTriggerDate(from: request))
    }
}

@MainActor
private final class FakeNotificationCenter: UserNotificationCentering {
    var stubAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    var stubPendingRequests: [UNNotificationRequest] = []
    var addedRequests: [UNNotificationRequest] = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        true
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        stubPendingRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func removeAllPendingNotificationRequests() {
        stubPendingRequests.removeAll()
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        stubAuthorizationStatus
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        stubPendingRequests + addedRequests
    }
}
