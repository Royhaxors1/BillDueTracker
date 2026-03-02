import Foundation
import SwiftData

@MainActor
final class AppBootstrapper {
    private(set) var hasBootstrapped = false

    func runIfNeeded(
        context: ModelContext,
        notificationService: ReminderNotificationService
    ) async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        await BillOperations.bootstrap(
            context: context,
            notificationService: notificationService,
            now: .now,
            timeZone: .current
        )
    }
}
