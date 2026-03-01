import SwiftUI

// MARK: - Provider Dashboard View
// Mini admin panel: list of sources, toggle open/closed and verified,
// plus a "Trigger Verification" button that simulates phone-bot.

struct ProviderDashboardView: View {
    @Bindable var appState: AppState
    @State private var verifyingSourceId: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if appState.store.sources.isEmpty {
                    emptyState
                } else {
                    sourceList
                }
            }
            .background(PantriColors.background)
            .navigationTitle("Your Sources")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var sourceList: some View {
        ScrollView {
            LazyVStack(spacing: PantriSpacing.md) {
                ForEach(appState.store.sources) { source in
                    ProviderSourceCard(
                        source: source,
                        isVerifying: verifyingSourceId == source.id,
                        onToggleOpen: {
                            Haptics.toggle()
                            withAnimation(PantriAnimation.snappy) {
                                appState.store.toggleOpen(id: source.id)
                            }
                        },
                        onToggleVerified: {
                            Haptics.toggle()
                            withAnimation(PantriAnimation.snappy) {
                                appState.store.toggleVerified(id: source.id)
                            }
                        },
                        onTriggerVerification: {
                            triggerVerification(for: source)
                        }
                    )
                }
            }
            .padding(.horizontal, PantriSpacing.md)
            .padding(.bottom, PantriSpacing.xxl)
        }
    }

    private var emptyState: some View {
        VStack(spacing: PantriSpacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(PantriColors.secondaryText)
            Text("No sources yet")
                .font(PantriFonts.title3)
            Text("Register a food source from the Register tab to see it here.")
                .font(PantriFonts.body)
                .foregroundStyle(PantriColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PantriSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func triggerVerification(for source: FoodSource) {
        Haptics.tap()
        verifyingSourceId = source.id

        Task {
            do {
                try await appState.api.verifySource(id: source.id)
                await MainActor.run {
                    withAnimation(PantriAnimation.bouncy) {
                        verifyingSourceId = nil
                    }
                    Haptics.notification(.success)
                }
            } catch {
                await MainActor.run {
                    verifyingSourceId = nil
                    Haptics.error()
                }
            }
        }
    }
}

// MARK: - Provider Source Card

struct ProviderSourceCard: View {
    let source: FoodSource
    let isVerifying: Bool
    let onToggleOpen: () -> Void
    let onToggleVerified: () -> Void
    let onTriggerVerification: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PantriSpacing.sm) {
            // Header
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: PantriRadius.sm, style: .continuous)
                        .fill(PantriColors.lightGreen)
                        .frame(width: 44, height: 44)
                    Image(systemName: source.sourceType.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(PantriColors.green)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(source.name)
                        .font(PantriFonts.headline)
                        .foregroundStyle(PantriColors.black)
                    Text(source.sourceType.rawValue)
                        .font(PantriFonts.caption)
                        .foregroundStyle(PantriColors.secondaryText)
                }

                Spacer()

                // Status badges
                VStack(alignment: .trailing, spacing: 4) {
                    StatusBadge(isOpen: source.isOpen)
                    if source.isVerified {
                        BadgeView(text: "Verified", icon: "checkmark.seal.fill", color: PantriColors.green)
                    } else {
                        BadgeView(text: "Unverified", icon: "exclamationmark.triangle", color: PantriColors.warning)
                    }
                }
            }

            Divider()

            // Controls
            HStack(spacing: PantriSpacing.md) {
                // Open/Closed toggle
                Button(action: onToggleOpen) {
                    HStack(spacing: 6) {
                        Image(systemName: source.isOpen ? "door.left.hand.open" : "door.left.hand.closed")
                            .font(.system(size: 14))
                        Text(source.isOpen ? "Open" : "Closed")
                            .font(PantriFonts.footnote)
                    }
                    .foregroundStyle(source.isOpen ? PantriColors.green : PantriColors.destructive)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        (source.isOpen ? PantriColors.green : PantriColors.destructive).opacity(0.1)
                    )
                    .clipShape(Capsule())
                }

                // Verified toggle
                Button(action: onToggleVerified) {
                    HStack(spacing: 6) {
                        Image(systemName: source.isVerified ? "checkmark.seal.fill" : "xmark.seal")
                            .font(.system(size: 14))
                        Text(source.isVerified ? "Verified" : "Unverified")
                            .font(PantriFonts.footnote)
                    }
                    .foregroundStyle(source.isVerified ? PantriColors.green : PantriColors.warning)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        (source.isVerified ? PantriColors.green : PantriColors.warning).opacity(0.1)
                    )
                    .clipShape(Capsule())
                }

                Spacer()

                // Trigger verification
                Button(action: onTriggerVerification) {
                    HStack(spacing: 6) {
                        if isVerifying {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(PantriColors.green)
                        } else {
                            Image(systemName: "phone.badge.checkmark")
                                .font(.system(size: 14))
                        }
                        Text(isVerifying ? "Verifying..." : "Verify")
                            .font(PantriFonts.footnote)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(PantriColors.green)
                    .clipShape(Capsule())
                }
                .disabled(isVerifying)
            }

            if let lastVerified = source.lastVerified {
                Text("Last verified: \(lastVerified, style: .relative) ago")
                    .font(PantriFonts.caption)
                    .foregroundStyle(PantriColors.secondaryText)
            }
        }
        .pantriCard(padding: PantriSpacing.md)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ProviderDashboardView(appState: AppState.shared)
}
