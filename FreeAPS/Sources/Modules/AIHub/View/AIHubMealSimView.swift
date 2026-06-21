import SwiftUI

/// Meal Simulator: Eingabemaske für eine geplante Mahlzeit, deterministischer
/// Bolus-Anker (rechnet sofort lokal) und optionale KI-Strategie auf Knopfdruck.
struct AIHubMealSimView: View {
    @Environment(\.colorScheme) private var colorScheme

    /// Übergibt die geplante Mahlzeit (KH/Fett/Eiweiß/Name) an den offiziellen
    /// AddCarbs-/Bolus-Flow. Wird von der RootView gesetzt.
    var onApplyMeal: ((Decimal, Decimal, Decimal, String) -> Void)? = nil

    // Einheit & Profil
    @State private var isMmol = false
    @State private var profile: AIHubMealSim.ProfileContext?

    // Saved Foods
    @State private var showSavedFoods = false
    @State private var savedFoods: [AIHubMealSim.SavedFood] = []
    @State private var mealName = ""
    /// Mehrfachauswahl im Picker: Anzahl pro Speise (id → Portionen).
    @State private var pickCounts: [UUID: Int] = [:]

    // Bolus-Plan aus der KI (now/later/afterMin)
    @State private var bolusPlan: AIHubMealSim.BolusPlan?
    @State private var reminderScheduled = false

    // Eingaben
    @State private var bgText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var proteinText = ""
    @State private var iobText = ""
    @State private var time = Date()
    @State private var useCustomTime = false
    @State private var activity: AIHubMealSim.Activity = .none
    @State private var usePlannedBolus = false
    @State private var plannedBolusText = ""

    // Ausgaben
    @State private var calc: AIHubMealSim.Calc?
    @State private var strategy: String?
    @State private var isGenerating = false
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if profile == nil {
                    noProfileCard
                } else {
                    inputCard
                    calcCard
                    strategyCard
                    treatmentCard
                }
                disclaimer
            }
            .padding(16)
        }
        .background(
            Color(colorScheme == .dark ? .systemBackground : .secondarySystemBackground)
                .ignoresSafeArea()
        )
        .navigationTitle(hubT("sim.title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSavedFoods) { savedFoodsSheet }
        .onAppear(perform: load)
        .onChange(of: bgText) { _ in recompute() }
        .onChange(of: carbsText) { _ in recompute() }
        .onChange(of: iobText) { _ in recompute() }
        .onChange(of: useCustomTime) { _ in reloadProfile() }
        .onChange(of: time) { _ in if useCustomTime { reloadProfile() } }
    }

    // MARK: - Laden / Rechnen

    private func load() {
        isMmol = (BaseFileStorage().retrieveRaw(OpenAPS.Settings.bgTargets) ?? "")
            .lowercased().contains("mmol")
        let effectiveTime = useCustomTime ? time : Date()
        profile = AIHubMealSim.profileContext(at: effectiveTime)

        Task { @MainActor in
            let prefill = await Task.detached(priority: .userInitiated) {
                AIHubMealSim.livePrefill()
            }.value
            if bgText.isEmpty, let bg = prefill.bgMgdl {
                bgText = formatInput(displayGlucose(bg))
            }
            if iobText.isEmpty, let iob = prefill.iob {
                iobText = formatInsulin(iob)
            }
            recompute()
        }
        Task { @MainActor in
            savedFoods = await Task.detached(priority: .userInitiated) {
                AIHubMealSim.savedFoods()
            }.value
        }
    }

    /// Summe der aktuellen Picker-Auswahl über alle Portionen.
    private var selectionTotals: (carbs: Double, fat: Double, protein: Double, names: [String]) {
        var carbs = 0.0, fat = 0.0, protein = 0.0
        var names: [String] = []
        for food in savedFoods {
            let count = pickCounts[food.id] ?? 0
            guard count > 0 else { continue }
            carbs += food.carbs * Double(count)
            fat += food.fat * Double(count)
            protein += food.protein * Double(count)
            names.append(count > 1 ? "\(count)× \(food.name)" : food.name)
        }
        return (carbs, fat, protein, names)
    }

    private var selectionCount: Int { pickCounts.values.reduce(0, +) }

    /// Übernimmt die summierte Picker-Auswahl in die Eingabefelder.
    private func applySelection() {
        let totals = selectionTotals
        guard totals.carbs > 0 || totals.fat > 0 || totals.protein > 0 else { return }
        carbsText = formatGram(totals.carbs)
        fatText = totals.fat > 0 ? formatGram(totals.fat) : ""
        proteinText = totals.protein > 0 ? formatGram(totals.protein) : ""
        mealName = totals.names.joined(separator: " + ")
        // Mahlzeit geändert → alte Strategie/Plan passen nicht mehr.
        strategy = nil
        bolusPlan = nil
        showSavedFoods = false
        recompute()
    }

    private func reloadProfile() {
        let effectiveTime = useCustomTime ? time : Date()
        profile = AIHubMealSim.profileContext(at: effectiveTime)
        // Tageszeit ändert ISF/CR/Ziel → Strategie passt nicht mehr.
        strategy = nil
        recompute()
    }

    private func recompute() {
        guard let profile = profile, let inputs = currentInputs() else {
            calc = nil
            return
        }
        calc = AIHubMealSim.calculate(inputs, profile: profile)
        // Eingaben geändert → KI-Bolusplan gilt nicht mehr für die Aktionen.
        if bolusPlan != nil {
            bolusPlan = nil
            reminderScheduled = false
        }
    }

    private func currentInputs() -> AIHubMealSim.Inputs? {
        guard let profile = profile else { return nil }
        let carbs = parse(carbsText) ?? 0
        let bgDisplay = parse(bgText)
        // Ohne BG keine sinnvolle Korrektur — dann Ziel annehmen.
        let bgMgdl = bgDisplay.map { isMmol ? $0 * 18 : $0 } ?? profile.targetMgdl
        return AIHubMealSim.Inputs(
            bgMgdl: bgMgdl,
            carbs: carbs,
            fat: parse(fatText) ?? 0,
            protein: parse(proteinText) ?? 0,
            iob: parse(iobText) ?? 0,
            timeOfDay: useCustomTime ? time : Date(),
            activity: activity,
            plannedBolus: usePlannedBolus ? parse(plannedBolusText) : nil
        )
    }

    private func generateStrategy() {
        guard let calc = calc, let inputs = currentInputs(), !isGenerating else { return }
        isGenerating = true
        errorText = nil
        reminderScheduled = false
        Task { @MainActor in
            do {
                let prompt = AIHubMealSim.strategyPrompt(inputs: inputs, calc: calc)
                let raw = try await AIHubChatService.executePrompt(prompt)
                let parsed = AIHubMealSim.parseStrategy(raw)
                strategy = parsed.text
                bolusPlan = parsed.plan
            } catch {
                errorText = error.localizedDescription
            }
            isGenerating = false
        }
    }

    // MARK: - Eingabe-Card

    private var inputCard: some View {
        card {
            VStack(spacing: 14) {
                if !savedFoods.isEmpty {
                    Button {
                        showSavedFoods = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bookmark.fill")
                            Text(mealName.isEmpty ? hubT("sim.savedfoods.button") : mealName)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(accent)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(accent.opacity(colorScheme == .dark ? 0.18 : 0.10))
                        )
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
                numberRow(
                    icon: "drop.fill",
                    tint: .red,
                    title: hubT("sim.field.bg"),
                    text: $bgText,
                    suffix: isMmol ? "mmol/L" : "mg/dL"
                )
                Divider()
                numberRow(
                    icon: "fork.knife",
                    tint: .green,
                    title: hubT("sim.field.carbs"),
                    text: $carbsText,
                    suffix: "g"
                )
                numberRow(
                    icon: "circle.lefthalf.filled",
                    tint: .orange,
                    title: hubT("sim.field.fat"),
                    text: $fatText,
                    suffix: "g"
                )
                numberRow(
                    icon: "circle.righthalf.filled",
                    tint: .brown,
                    title: hubT("sim.field.protein"),
                    text: $proteinText,
                    suffix: "g"
                )
                Divider()
                numberRow(
                    icon: "syringe",
                    tint: .blue,
                    title: hubT("sim.field.iob"),
                    text: $iobText,
                    suffix: insulinUnit
                )
                Divider()
                timeRow
                activityRow
                Divider()
                plannedBolusRow
            }
        }
    }

    private func numberRow(
        icon: String,
        tint: Color,
        title: String,
        text: Binding<String>,
        suffix: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(title)
                .font(.subheadline)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.subheadline.bold())
                .frame(maxWidth: 80)
            Text(suffix)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
        }
    }

    private var timeRow: some View {
        VStack(spacing: 8) {
            Toggle(isOn: $useCustomTime) {
                HStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.indigo)
                        .frame(width: 22)
                    Text(hubT("sim.field.time"))
                        .font(.subheadline)
                }
            }
            if useCustomTime {
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var activityRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.subheadline)
                .foregroundStyle(.teal)
                .frame(width: 22)
            Text(hubT("sim.field.activity"))
                .font(.subheadline)
            Spacer()
            Picker("", selection: $activity) {
                ForEach(AIHubMealSim.Activity.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }

    private var plannedBolusRow: some View {
        VStack(spacing: 8) {
            Toggle(isOn: $usePlannedBolus) {
                HStack(spacing: 12) {
                    Image(systemName: "pencil")
                        .font(.subheadline)
                        .foregroundStyle(.purple)
                        .frame(width: 22)
                    Text(hubT("sim.field.planned"))
                        .font(.subheadline)
                }
            }
            if usePlannedBolus {
                HStack {
                    Spacer()
                    TextField("0", text: $plannedBolusText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.subheadline.bold())
                        .frame(maxWidth: 80)
                    Text(insulinUnit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Rechnungs-Card

    @ViewBuilder private var calcCard: some View {
        if let calc = calc {
            card {
                VStack(alignment: .leading, spacing: 12) {
                    Text(hubT("sim.calc.title"))
                        .font(.headline)

                    calcRow(hubT("sim.calc.carb"), value: calc.carbInsulin, sign: false)
                    calcRow(hubT("sim.calc.correction"), value: calc.correctionInsulin, sign: true)
                    calcRow(hubT("sim.calc.iob"), value: -calc.iob, sign: true)

                    Divider()
                    HStack(alignment: .firstTextBaseline) {
                        Text(hubT("sim.calc.total"))
                            .font(.subheadline.bold())
                        Spacer()
                        Text("\(formatInsulin(calc.recommendedBolus)) \(insulinUnit)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.purple)
                    }

                    Text(hubT(
                        "sim.calc.basis",
                        String(format: "%.0f", calc.profile.crGramsPerU),
                        AIHubTherapyAnalysis.formatGlucose(calc.profile.isfMgdlPerU, isMmol: isMmol)
                            .replacingOccurrences(of: " mmol/L", with: "")
                            .replacingOccurrences(of: " mg/dL", with: ""),
                        AIHubTherapyAnalysis.formatGlucose(calc.profile.targetMgdl, isMmol: isMmol)
                    ))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func calcRow(_ title: String, value: Double, sign: Bool) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(sign && value >= 0 ? "+" : "")\(formatInsulin(value)) \(insulinUnit)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(value < 0 ? .blue : .primary)
        }
    }

    // MARK: - KI-Strategie-Card

    private var strategyCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    Text(hubT("sim.ai.title"))
                        .font(.headline)
                    Spacer()
                    if strategy != nil, !isGenerating {
                        Button {
                            generateStrategy()
                        } label: {
                            Image(systemName: "arrow.clockwise").font(.subheadline)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let strategy = strategy {
                    Text(strategy)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                } else if isGenerating {
                    HStack {
                        ProgressView()
                        Text(hubT("sim.ai.generating"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if !AIHubChatService.isConfigured {
                    Text(hubT("sim.nokey"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        generateStrategy()
                    } label: {
                        Text(hubT("sim.ai.generate"))
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.purple.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .disabled(calc == nil || (parse(carbsText) ?? 0) <= 0)
                }

                if let error = errorText {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Behandlungs-Card (Übernahme in den offiziellen Flow)

    @ViewBuilder private var treatmentCard: some View {
        let carbs = parse(carbsText) ?? 0
        if carbs > 0 || bolusPlan != nil {
            card {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "cross.case.fill")
                            .foregroundStyle(accent)
                        Text(hubT("sim.treat.title"))
                            .font(.headline)
                    }

                    // 1) Mahlzeit (+ Bolus) in den offiziellen Flow übergeben.
                    Button {
                        onApplyMeal?(
                            Decimal(carbs),
                            Decimal(parse(fatText) ?? 0),
                            Decimal(parse(proteinText) ?? 0),
                            mealName
                        )
                    } label: {
                        Label(hubT("sim.treat.apply"), systemImage: "arrow.right.circle.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(accent))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(onApplyMeal == nil || carbs <= 0)

                    Text(hubT("sim.treat.applyhint"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    // 2) Split-Bolus: späteren Anteil als Erinnerung vormerken.
                    if let plan = bolusPlan, plan.isSplit {
                        Divider()
                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: "clock.badge.checkmark")
                                .foregroundStyle(.indigo)
                            Text(hubT(
                                "sim.treat.split",
                                "\(formatInsulin(plan.now)) \(insulinUnit)",
                                "\(formatInsulin(plan.later)) \(insulinUnit)",
                                "\(plan.afterMinutes)"
                            ))
                                .font(.footnote)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if reminderScheduled {
                            Label(hubT("sim.treat.reminderset"), systemImage: "checkmark.circle.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.green)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        } else {
                            Button {
                                AIHubMealSim.scheduleLaterBolusReminder(
                                    units: plan.later,
                                    afterMinutes: plan.afterMinutes,
                                    isMmol: isMmol
                                )
                                reminderScheduled = true
                            } label: {
                                Label(
                                    hubT("sim.treat.remind", "\(formatInsulin(plan.later)) \(insulinUnit)"),
                                    systemImage: "bell.badge"
                                )
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color.indigo.opacity(0.15)))
                                .foregroundStyle(.indigo)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Saved Foods

    private var savedFoodsSheet: some View {
        NavigationStack {
            List(savedFoods) { food in
                savedFoodRow(food)
            }
            .navigationTitle(hubT("sim.savedfoods.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(hubT("sim.savedfoods.cancel")) {
                        pickCounts = [:]
                        showSavedFoods = false
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { applyBar }
        }
        .onAppear { pickCounts = [:] }
    }

    private func savedFoodRow(_ food: AIHubMealSim.SavedFood) -> some View {
        let count = pickCounts[food.id] ?? 0
        let selected = count > 0
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(food.name)
                    .font(.subheadline.weight(.medium))
                Text(
                    "\(formatGram(food.carbs)) g · \(hubT("sim.field.fat")) \(formatGram(food.fat)) g · \(hubT("sim.field.protein")) \(formatGram(food.protein)) g"
                )
                .font(.caption)
            }
            // Ausgegraut, bis per Plus hinzugefügt.
            .foregroundStyle(selected ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            Spacer()
            if selected {
                Button {
                    if count <= 1 { pickCounts[food.id] = nil } else { pickCounts[food.id] = count - 1 }
                } label: {
                    Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                Text("\(count)")
                    .font(.subheadline.bold().monospacedDigit())
                    .frame(minWidth: 18)
            }
            Button {
                pickCounts[food.id] = count + 1
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
        }
    }

    private var applyBar: some View {
        let totals = selectionTotals
        return VStack(spacing: 0) {
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(hubT("sim.savedfoods.selected", "\(selectionCount)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(formatGram(totals.carbs)) g")
                        .font(.headline)
                }
                Spacer()
                Button {
                    applySelection()
                } label: {
                    Text(hubT("sim.savedfoods.apply"))
                        .font(.subheadline.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(selectionCount > 0 ? accent : Color(.systemGray3)))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(selectionCount == 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
    }

    // MARK: - Bausteine

    private var noProfileCard: some View {
        card {
            VStack(alignment: .leading, spacing: 8) {
                Text(hubT("sim.noprofile.title"))
                    .font(.headline)
                Text(hubT("sim.noprofile.text"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var disclaimer: some View {
        Text(hubT("sim.disclaimer"))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    private func card(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(colorScheme == .dark ? .secondarySystemBackground : .systemBackground))
        )
    }

    // MARK: - Zahlen-Helfer

    private func parse(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private func displayGlucose(_ mgdl: Double) -> Double {
        isMmol ? mgdl / 18.0 : mgdl
    }

    private func formatInput(_ value: Double) -> String {
        isMmol ? String(format: "%.1f", value) : String(Int(value.rounded()))
    }

    /// Gramm-Werte: ganze Zahl ohne Nachkomma, sonst bis zu 2 Stellen.
    private func formatGram(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : (Self.insulinFormatter.string(from: value as NSNumber) ?? String(format: "%.1f", value))
    }

    /// Insulin braucht Nachkommastellen (0,5 E) — der Glukose-Formatter würde
    /// für mg/dL-Nutzer auf eine ganze Zahl runden.
    private func formatInsulin(_ value: Double) -> String {
        Self.insulinFormatter.string(from: value as NSNumber) ?? String(format: "%.2f", value)
    }

    /// Lokalisierte Insulin-Einheit ("U" / de "E"), wie im Rest der App.
    private var insulinUnit: String { hubT("sim.unit.insulin") }

    /// Ruhiger, gut lesbarer Akzent (statt des aggressiven Pink/Rot).
    private var accent: Color { .teal }

    private static let insulinFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter
    }()
}
