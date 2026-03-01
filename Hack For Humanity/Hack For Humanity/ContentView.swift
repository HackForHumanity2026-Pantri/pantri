//
//  ContentView.swift
//  Hack For Humanity
//
//  Created by V Surin on 2/28/26.
//

import SwiftUI

// MARK: - Content View
// Root view: shows onboarding or main tab view based on app state.
// Smooth crossfade transition between states.

struct ContentView: View {
    @State private var appState = AppState.shared

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                MainTabView(appState: appState)
                    .transition(.opacity)
            } else {
                OnboardingView(appState: appState)
                    .transition(.opacity)
            }
        }
        .animation(PantriAnimation.smooth, value: appState.hasCompletedOnboarding)
    }
}

#Preview {
    ContentView()
}
