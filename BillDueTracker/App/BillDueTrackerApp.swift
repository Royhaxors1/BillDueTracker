import SwiftData
import SwiftUI

@main
struct BillDueTrackerApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    @AppStorage(AppAppearanceMode.storageKey) private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @State private var bootstrapper = AppBootstrapper()
    @StateObject private var entitlementState = EntitlementState()
    @StateObject private var appNavigation = AppNavigationState()

    private let notificationService = ReminderNotificationService.shared
    private let attachmentStore = AttachmentStore()

    var body: some Scene {
        WindowGroup {
            RootTabView(
                bootstrapper: bootstrapper,
                notificationService: notificationService,
                attachmentStore: attachmentStore
            )
            .preferredColorScheme(appearanceMode.colorScheme)
            .onReceive(NotificationCenter.default.publisher(for: .reminderNotificationTapped)) { notification in
                guard let target = navigationTarget(from: notification.userInfo) else { return }
                appNavigation.routeToBill(target)
            }
            .environmentObject(appNavigation)
            .environmentObject(entitlementState)
        }
        .modelContainer(
            for: [
                UserProfile.self,
                BillItem.self,
                BillCycle.self,
                ReminderEvent.self,
                PaymentProof.self,
                ProviderAction.self
            ]
        )
    }

    private var appearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private func navigationTarget(from userInfo: [AnyHashable: Any]?) -> BillNavigationTarget? {
        guard let userInfo,
              let billRaw = userInfo[ReminderNotificationService.billIDUserInfoKey] as? String,
              let billID = UUID(uuidString: billRaw) else {
            return nil
        }

        let cycleID: UUID?
        if let cycleRaw = userInfo[ReminderNotificationService.cycleIDUserInfoKey] as? String {
            cycleID = UUID(uuidString: cycleRaw)
        } else {
            cycleID = nil
        }

        return BillNavigationTarget(billID: billID, cycleID: cycleID)
    }
}
