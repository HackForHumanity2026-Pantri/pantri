import SwiftUI

// MARK: - SMS Preview View
// Shows the exact SMS copy that would be sent to the user.
// Front-end only — demonstrates the SMS UX without sending real messages.

struct SMSPreviewView: View {
    let source: FoodSource
    let appState: AppState
    @State private var isSent = false
    @State private var sendFailed = false
    @Environment(\.dismiss) private var dismiss

    var smsBody: String {
        """
        Pantri found a match for you!

        \(source.name)
        \(source.address)
        \(source.hoursOfOperation)

        Food type: \(source.foodTypes.map(\.rawValue).joined(separator: ", "))
        Availability: \(source.availability.rawValue)
        \(source.publicTransitAccessible ? "Accessible by public transit" : "")

        Directions: https://maps.apple.com/?daddr=\(source.latitude),\(source.longitude)

        — Pantri
        """
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: PantriSpacing.lg) {
                // Phone mockup
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(PantriColors.secondaryText)
                        VStack(alignment: .leading) {
                            Text("Pantri SMS")
                                .font(PantriFonts.headline)
                            Text("Preview — not sent")
                                .font(PantriFonts.caption)
                                .foregroundStyle(PantriColors.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(PantriSpacing.md)
                    .background(.ultraThinMaterial)

                    // Message bubble
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text(smsBody)
                                .font(PantriFonts.body)
                                .foregroundStyle(PantriColors.black)
                                .padding(PantriSpacing.md)
                                .background(PantriColors.lightGreen)
                                .clipShape(RoundedRectangle(cornerRadius: PantriRadius.md, style: .continuous))
                                .padding(PantriSpacing.md)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 300)
                }
                .background(PantriColors.card)
                .clipShape(RoundedRectangle(cornerRadius: PantriRadius.lg, style: .continuous))
                .shadow(
                    color: PantriShadow.md.color,
                    radius: PantriShadow.md.radius,
                    y: PantriShadow.md.y
                )
                .padding(.horizontal, PantriSpacing.md)

                // Action
                VStack(spacing: PantriSpacing.sm) {
                    if isSent {
                        HStack(spacing: PantriSpacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(PantriColors.green)
                            Text("SMS sent!")
                                .font(PantriFonts.headline)
                                .foregroundStyle(PantriColors.green)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else if sendFailed {
                        HStack(spacing: PantriSpacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(PantriColors.destructive)
                            Text("Failed to send SMS")
                                .font(PantriFonts.headline)
                                .foregroundStyle(PantriColors.destructive)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Button {
                            Haptics.match()
                            Task {
                                do {
                                    try await appState.api.sendSMS(to: source.phone, body: smsBody)
                                    await MainActor.run {
                                        withAnimation(PantriAnimation.bouncy) {
                                            isSent = true
                                        }
                                    }
                                } catch {
                                    await MainActor.run {
                                        withAnimation(PantriAnimation.bouncy) {
                                            sendFailed = true
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: PantriSpacing.sm) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Send SMS")
                                    .font(PantriFonts.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(PantriColors.green)
                            .clipShape(RoundedRectangle(cornerRadius: PantriRadius.md, style: .continuous))
                        }
                        .padding(.horizontal, PantriSpacing.md)
                    }

                    Text("This sends via the /sms/send endpoint.")
                        .font(PantriFonts.caption)
                        .foregroundStyle(PantriColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, PantriSpacing.lg)
                }

                Spacer()
            }
            .background(PantriColors.background)
            .navigationTitle("SMS Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PantriColors.green)
                }
            }
        }
    }
}

#Preview {
    SMSPreviewView(
        source: MockDataStore.defaultSources[0],
        appState: AppState.shared
    )
}
