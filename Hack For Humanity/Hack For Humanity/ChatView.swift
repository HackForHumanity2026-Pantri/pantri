import SwiftUI
import CoreLocation

// MARK: - Chat View ("Ask Pantri")
// Conversational UI with typing indicators, quick replies, and SMS sharing.
// Luma-like: smooth message insertion animations, rounded bubbles, haptics.

struct ChatView: View {
    @Bindable var appState: AppState
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isTyping: Bool = false
    @State private var showSMSPreview: Bool = false
    @State private var selectedSource: FoodSource?
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                typingIndicator
                inputBar
            }
            .background(PantriColors.background)
            .navigationTitle("Ask Pantri")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSMSPreview) {
                if let source = selectedSource {
                    SMSPreviewView(source: source, appState: appState)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }
            }
            .onAppear {
                if messages.isEmpty {
                    addBotMessage(
                        "Hi! I'm Pantri, your food-finding assistant. What are you looking for today?",
                        quickReplies: ["I need a cooked meal", "I need groceries", "What's nearby?"]
                    )
                }
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: PantriSpacing.sm) {
                    ForEach(messages) { message in
                        ChatBubble(message: message, onQuickReply: { reply in
                            sendMessage(reply)
                        }, onShareSMS: { source in
                            selectedSource = source
                            showSMSPreview = true
                        }, appState: appState)
                        .id(message.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                .padding(.horizontal, PantriSpacing.md)
                .padding(.vertical, PantriSpacing.sm)
            }
            .onChange(of: messages.count) {
                if let last = messages.last {
                    withAnimation(PantriAnimation.smooth) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Typing Indicator

    @ViewBuilder
    private var typingIndicator: some View {
        if isTyping {
            HStack(spacing: PantriSpacing.sm) {
                TypingDotsView()
                Text("Pantri is thinking...")
                    .font(PantriFonts.caption)
                    .foregroundStyle(PantriColors.secondaryText)
                Spacer()
            }
            .padding(.horizontal, PantriSpacing.lg)
            .padding(.vertical, PantriSpacing.xs)
            .transition(.opacity)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: PantriSpacing.sm) {
            TextField("Ask me anything...", text: $inputText)
                .font(PantriFonts.body)
                .padding(.horizontal, PantriSpacing.md)
                .padding(.vertical, 12)
                .background(PantriColors.card)
                .clipShape(RoundedRectangle(cornerRadius: PantriRadius.full, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PantriRadius.full, style: .continuous)
                        .stroke(PantriColors.border, lineWidth: 1)
                )
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit {
                    sendCurrentMessage()
                }
                .accessibilityLabel("Chat input")

            Button {
                sendCurrentMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(inputText.isEmpty ? PantriColors.border : PantriColors.green)
            }
            .disabled(inputText.isEmpty)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, PantriSpacing.md)
        .padding(.vertical, PantriSpacing.sm)
        .background(.ultraThinMaterial)
    }

    // MARK: - Send

    private func sendCurrentMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        sendMessage(text)
    }

    private func sendMessage(_ text: String) {
        Haptics.tap()
        let userMsg = ChatMessage(content: text, isUser: true)
        withAnimation(PantriAnimation.snappy) {
            messages.append(userMsg)
        }

        withAnimation(PantriAnimation.smooth) {
            isTyping = true
        }

        Task {
            let request = UserRequest(
                id: UUID(),
                needType: appState.selectedNeedType,
                urgency: appState.selectedUrgency,
                latitude: appState.locationManager.effectiveLocation.latitude,
                longitude: appState.locationManager.effectiveLocation.longitude,
                transportMode: appState.selectedTransport,
                city: appState.defaultCity
            )

            do {
                let reply = try await appState.api.sendChatMessage(text, context: request)
                await MainActor.run {
                    withAnimation(PantriAnimation.smooth) {
                        isTyping = false
                    }

                    var quickReplies: [String] = []
                    if reply.contains("direction") || reply.contains("get there") {
                        quickReplies = ["Show me directions", "Share via SMS", "Find more options"]
                    } else if reply.contains("option") || reply.contains("found") {
                        quickReplies = ["Show me directions", "Share via SMS", "Tell me more"]
                    }

                    addBotMessage(reply, quickReplies: quickReplies)
                    Haptics.notification(.success)
                }
            } catch {
                await MainActor.run {
                    withAnimation(PantriAnimation.smooth) {
                        isTyping = false
                    }
                    addBotMessage("Sorry, I had trouble processing that. Could you try again?")
                }
            }
        }
    }

    private func addBotMessage(_ text: String, quickReplies: [String] = []) {
        let msg = ChatMessage(content: text, isUser: false, quickReplies: quickReplies)
        withAnimation(PantriAnimation.snappy) {
            messages.append(msg)
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    var onQuickReply: (String) -> Void
    var onShareSMS: (FoodSource) -> Void
    var appState: AppState

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: PantriSpacing.xs) {
            HStack {
                if message.isUser { Spacer(minLength: 60) }

                VStack(alignment: .leading, spacing: PantriSpacing.xs) {
                    Text(message.content)
                        .font(PantriFonts.body)
                        .foregroundStyle(message.isUser ? .white : PantriColors.black)

                    Text(message.timestamp, style: .time)
                        .font(PantriFonts.caption)
                        .foregroundStyle(message.isUser ? .white.opacity(0.7) : PantriColors.secondaryText)
                }
                .padding(.horizontal, PantriSpacing.md)
                .padding(.vertical, PantriSpacing.sm + 2)
                .background(message.isUser ? PantriColors.green : PantriColors.card)
                .clipShape(RoundedRectangle(cornerRadius: PantriRadius.lg, style: .continuous))
                .shadow(
                    color: message.isUser ? .clear : PantriShadow.sm.color,
                    radius: PantriShadow.sm.radius,
                    y: PantriShadow.sm.y
                )

                if !message.isUser { Spacer(minLength: 60) }
            }

            // Quick replies
            if !message.quickReplies.isEmpty && !message.isUser {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PantriSpacing.xs) {
                        ForEach(message.quickReplies, id: \.self) { reply in
                            Button {
                                if reply == "Share via SMS" {
                                    if let source = appState.store.sources.first(where: { $0.isOpen }) {
                                        onShareSMS(source)
                                    }
                                } else {
                                    onQuickReply(reply)
                                }
                            } label: {
                                Text(reply)
                                    .font(PantriFonts.footnote)
                                    .foregroundStyle(PantriColors.green)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(PantriColors.lightGreen)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
    }
}

// MARK: - Typing Dots

struct TypingDotsView: View {
    @State private var dotIndex = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(PantriColors.green)
                    .frame(width: 8, height: 8)
                    .scaleEffect(dotIndex == index ? 1.3 : 1.0)
                    .opacity(dotIndex == index ? 1.0 : 0.4)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    dotIndex = (dotIndex + 1) % 3
                }
            }
        }
    }
}

#Preview {
    ChatView(appState: AppState.shared)
}
