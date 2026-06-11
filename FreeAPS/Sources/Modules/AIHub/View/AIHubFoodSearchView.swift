import SwiftUI

/// Hub-Einstieg für die KI-Mahlzeitenerfassung: Texteingabe oben (KI-Suche),
/// darunter der Kamera-Aufruf. Beide Wege springen in das bestehende
/// AddCarbs-Modal — diese View ist nur die Weiche, keine eigene Suche.
struct AIHubFoodSearchView: View {
    /// Öffnet AddCarbs mit KI-Textsuche und startet die Query sofort.
    let onSearch: (String) -> Void
    /// Öffnet AddCarbs direkt im Kamera-Modus.
    let onCamera: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var inputFocused: Bool
    @State private var query = ""

    private var canSearch: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(hubT("fs.intro"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    TextField(hubT("fs.placeholder"), text: $query, axis: .vertical)
                        .lineLimit(1 ... 3)
                        .textFieldStyle(.plain)
                        .focused($inputFocused)
                        .onSubmit(startSearch)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(colorScheme == .dark ? .secondarySystemBackground : .systemBackground))
                        )
                    Button(action: startSearch) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text(hubT("fs.search"))
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(canSearch ? Color.green.opacity(0.85) : Color.secondary.opacity(0.2))
                        )
                        .foregroundStyle(canSearch ? .white : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSearch)
                }

                HStack {
                    VStack { Divider() }
                    Text(hubT("fs.or"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VStack { Divider() }
                }

                Button {
                    onCamera()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.green.gradient)
                            )
                        VStack(alignment: .leading, spacing: 3) {
                            Text(hubT("fs.camera"))
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(hubT("fs.camera.sub"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(colorScheme == .dark ? .secondarySystemBackground : .systemBackground))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(
            Color(colorScheme == .dark ? .systemBackground : .secondarySystemBackground)
                .ignoresSafeArea()
        )
        .navigationTitle("FoodSearch")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputFocused = false
        onSearch(trimmed)
    }
}
