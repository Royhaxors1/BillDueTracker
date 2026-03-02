import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlementState: EntitlementState
    @EnvironmentObject private var appNavigation: AppNavigationState

    let bootstrapper: AppBootstrapper
    let notificationService: ReminderNotificationService
    let attachmentStore: AttachmentStore

    var body: some View {
        TabView(selection: $appNavigation.selectedTab) {
            DashboardView(
                notificationService: notificationService,
                attachmentStore: attachmentStore
            )
            .tabItem {
                Label("Dashboard", systemImage: "house.fill")
            }
            .tag(AppTab.dashboard)

            TimelineView(
                notificationService: notificationService,
                attachmentStore: attachmentStore
            )
            .tabItem {
                Label("Timeline", systemImage: "calendar")
            }
            .tag(AppTab.timeline)

            SettingsView(
                notificationService: notificationService
            )
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
        }
        .tint(AppTheme.Colors.accent)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(AppTheme.Colors.surface, for: .tabBar)
        .task {
            await bootstrapper.runIfNeeded(
                context: modelContext,
                notificationService: notificationService
            )
            await entitlementState.refresh()
        }
    }
}
