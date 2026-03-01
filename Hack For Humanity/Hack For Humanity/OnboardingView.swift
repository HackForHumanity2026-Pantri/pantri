import SwiftUI

// MARK: - Onboarding View
// Logo + tagline + mode selection. First screen the user sees.
// Luma-like: large logo, generous spacing, spring animations on appear.

struct OnboardingView: View {
    @Bindable var appState: AppState

    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var buttonsOffset: CGFloat = 40
    @State private var buttonsOpacity: Double = 0

    var body: some View {
        ZStack {
            PantriColors.background
                .ignoresSafeArea()

            VStack(spacing: PantriSpacing.xxl) {
                Spacer()

                // Logo
                VStack(spacing: PantriSpacing.md) {
                    Image("PantriLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200)
                        .accessibilityLabel("Pantri logo")
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)

                    Text("Find food, not a maze.")
                        .font(PantriFonts.title3)
                        .foregroundStyle(PantriColors.secondaryText)
                        .opacity(taglineOpacity)
                }

                Spacer()

                // Mode buttons
                VStack(spacing: PantriSpacing.md) {
                    Button {
                        Haptics.tap()
                        withAnimation(PantriAnimation.snappy) {
                            appState.userMode = .user
                            appState.hasCompletedOnboarding = true
                        }
                    } label: {
                        HStack(spacing: PantriSpacing.sm) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .semibold))
                            Text("I'm looking for food")
                                .font(PantriFonts.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(PantriColors.green)
                        .clipShape(RoundedRectangle(cornerRadius: PantriRadius.md, style: .continuous))
                    }
                    .accessibilityHint("Opens the user view to find food sources near you")

                    Button {
                        Haptics.tap()
                        withAnimation(PantriAnimation.snappy) {
                            appState.userMode = .provider
                            appState.hasCompletedOnboarding = true
                        }
                    } label: {
                        HStack(spacing: PantriSpacing.sm) {
                            Image(systemName: "storefront")
                                .font(.system(size: 18, weight: .semibold))
                            Text("I'm a provider")
                                .font(PantriFonts.headline)
                        }
                        .foregroundStyle(PantriColors.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(PantriColors.card)
                        .clipShape(RoundedRectangle(cornerRadius: PantriRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PantriRadius.md, style: .continuous)
                                .stroke(PantriColors.border, lineWidth: 1.5)
                        )
                    }
                    .accessibilityHint("Opens the provider view to register and manage food sources")

                    Button {
                        Haptics.selection()
                        withAnimation(PantriAnimation.snappy) {
                            appState.userMode = .user
                            appState.hasCompletedOnboarding = true
                        }
                    } label: {
                        Text("Skip for now")
                            .font(PantriFonts.subheadline)
                            .foregroundStyle(PantriColors.secondaryText)
                    }
                    .padding(.top, PantriSpacing.xs)
                }
                .offset(y: buttonsOffset)
                .opacity(buttonsOpacity)
                .padding(.horizontal, PantriSpacing.lg)
                .padding(.bottom, PantriSpacing.xxl)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                taglineOpacity = 1.0
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6)) {
                buttonsOffset = 0
                buttonsOpacity = 1.0
            }
        }
    }
}

#Preview {
    OnboardingView(appState: AppState.shared)
}
