import SwiftUI

// MARK: - Main Tab View
// Switches between User and Provider tab layouts based on appState.userMode.
// Luma-like: clean tab bar with custom tint.

struct MainTabView: View {
    @Bindable var appState: AppState

    var body: some View {
        Group {
            switch appState.userMode {
            case .user:
                userTabs
            case .provider:
                providerTabs
            }
        }
    }

    private var userTabs: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                UserHomeView(appState: appState)
            }
            .accessibilityLabel("Home tab")

            Tab("Ask Pantri", systemImage: "message") {
                ChatView(appState: appState)
            }
            .accessibilityLabel("Chat tab")

            Tab("Settings", systemImage: "gearshape") {
                SettingsView(appState: appState)
            }
            .accessibilityLabel("Settings tab")
        }
        .tint(PantriColors.green)
    }

    private var providerTabs: some View {
        TabView {
            Tab("Register", systemImage: "plus.circle") {
                ProviderRegisterView(appState: appState)
            }
            .accessibilityLabel("Register tab")

            Tab("Dashboard", systemImage: "list.bullet.rectangle") {
                ProviderDashboardView(appState: appState)
            }
            .accessibilityLabel("Dashboard tab")

            Tab("Settings", systemImage: "gearshape") {
                SettingsView(appState: appState)
            }
            .accessibilityLabel("Settings tab")
        }
        .tint(PantriColors.green)
    }
}

#Preview("User Mode") {
    MainTabView(appState: {
        let state = AppState.shared
        state.userMode = .user
        return state
    }())
}

#Preview("Provider Mode") {
    MainTabView(appState: {
        let state = AppState.shared
        state.userMode = .provider
        return state
    }())
}
