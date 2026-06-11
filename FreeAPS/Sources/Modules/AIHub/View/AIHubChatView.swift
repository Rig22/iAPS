import SwiftUI

// MARK: - View model

final class AIHubChatViewModel: ObservableObject {
    @Published var messages: [AIHubChat.Message] = []
    @Published var input = ""
    @Published var isSending = false
    @Published var errorText: String?
    // Starter: datengetrieben (AIHubChatContext), bis geladen die Defaults.
    @Published var starters: [String] = AIHubChatContext.fallbackStarters
    // Follow-ups: vom Modell mitgelieferte Anschlussfragen zur letzten Antwort.
    @Published var followUps: [String] = []

    private let service = AIHubChatService()
    private var startersLoaded = false
    // Einmal pro Chat-Session gebaut — die Daten ändern sich innerhalb
    // weniger Minuten nicht relevant, und der Build fetcht CoreData.
    private var cachedContext: String?

    func loadStartersIfNeeded() {
        guard !startersLoaded else { return }
        startersLoaded = true
        Task { @MainActor in
            starters = await Task.detached(priority: .userInitiated) {
                AIHubChatContext.starterSuggestions()
            }.value
        }
    }

    var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        input = ""
        errorText = nil
        followUps = []
        messages.append(AIHubChat.Message(role: .user, text: text))
        isSending = true

        Task { @MainActor in
            do {
                let context = try await dataContext()
                let reply = try await service.send(messages: messages, dataContext: context)
                let parsed = AIHubChatService.parseReply(reply)
                messages.append(AIHubChat.Message(role: .assistant, text: parsed.text))
                followUps = parsed.followUps
            } catch {
                errorText = error.localizedDescription
            }
            isSending = false
        }
    }

    private func dataContext() async throws -> String {
        if let cached = cachedContext { return cached }
        let built = await Task.detached(priority: .userInitiated) {
            AIHubChatContext.build()
        }.value
        cachedContext = built
        return built
    }
}

// MARK: - View

struct AIHubChatView: View {
    @StateObject private var model = AIHubChatViewModel()
    @Environment(\.colorScheme) private var colorScheme
    // In .onAppear aktualisiert statt direkt im Body gelesen — die View wird
    // als NavigationLink-Destination eager erzeugt und würde sonst beim
    // Wiederöffnen einen veralteten Key-Status zeigen.
    @State private var isConfigured = AIHubChatService.isConfigured
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if isConfigured {
                conversation
                followUpBar
                inputBar
            } else {
                missingKeyNotice
            }
        }
        .onAppear {
            isConfigured = AIHubChatService.isConfigured
            model.loadStartersIfNeeded()
        }
        .background(
            Color(colorScheme == .dark ? .systemBackground : .secondarySystemBackground)
                .ignoresSafeArea()
        )
        .navigationTitle("AI Chat")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if model.messages.isEmpty {
                        emptyState
                    }
                    ForEach(model.messages) { message in
                        bubble(for: message)
                            .id(message.id)
                    }
                    if model.isSending {
                        HStack {
                            ProgressView()
                            Text(hubT("chat.thinking"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .id("typing")
                    }
                    if let error = model.errorText {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
            // Tastatur schließbar machen: Wisch nach unten im Verlauf
            // (interaktiv, wie in Messages) oder Tipp auf den Verlauf.
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { inputFocused = false }
            .onChange(of: model.messages) { _ in
                withAnimation {
                    proxy.scrollTo(model.messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: model.isSending) { sending in
                if sending {
                    withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(hubT("chat.empty.title"))
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.starters, id: \.self) { question in
                    suggestionButton(question)
                }
            }
            Text(hubT("chat.note"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    private func suggestionButton(_ text: String) -> some View {
        Button {
            model.input = text
            model.send()
        } label: {
            Text(text)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(Color.purple.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .disabled(model.isSending)
    }

    private func bubble(for message: AIHubChat.Message) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            message.role == .user
                                ? Color.purple.opacity(colorScheme == .dark ? 0.35 : 0.15)
                                : Color(colorScheme == .dark ? .secondarySystemBackground : .systemBackground)
                        )
                )
                .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    /// Anschlussfragen unter der letzten Antwort, horizontal scrollbar.
    @ViewBuilder private var followUpBar: some View {
        if !model.followUps.isEmpty, !model.isSending {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.followUps, id: \.self) { question in
                        suggestionButton(question)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 2)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField(hubT("chat.input.placeholder"), text: $model.input, axis: .vertical)
                .lineLimit(1 ... 4)
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(Color(colorScheme == .dark ? .secondarySystemBackground : .systemBackground))
                )
                .onSubmit { model.send() }
            Button {
                model.send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(model.canSend ? Color.purple : Color.secondary.opacity(0.4))
            }
            .disabled(!model.canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var missingKeyNotice: some View {
        VStack(spacing: 14) {
            Image(systemName: "key.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(hubT("chat.nokey.title"))
                .font(.title3.bold())
            Text(hubT("chat.nokey.text"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            NavigationLink(destination: AIHubSettingsView()) {
                Text(hubT("chat.nokey.button"))
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.purple.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
