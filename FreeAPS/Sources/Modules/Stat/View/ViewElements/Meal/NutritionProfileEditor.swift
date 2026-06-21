import SwiftUI

/// Editor for the Meal tab's body data (weight, height, age, sex, activity) and
/// macro goals. Independent from the Sharing settings — changes here only affect
/// the Meal tab's nutrient targets.
struct NutritionProfileEditor: View {
    @Binding var profile: NutritionProfile
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    private func decimalProxy(_ keyPath: WritableKeyPath<NutritionProfile, Decimal>) -> Binding<Double> {
        Binding(
            get: { NSDecimalNumber(decimal: profile[keyPath: keyPath]).doubleValue },
            set: { profile[keyPath: keyPath] = Decimal($0) }
        )
    }

    /// Only biological sexes relevant for the EFSA reference values are offered.
    private let selectableSexes: [Sex] = [.woman, .man]

    private var sexProxy: Binding<Sex> {
        Binding(
            get: { selectableSexes.contains(profile.sex) ? profile.sex : .woman },
            set: { profile.sex = $0 }
        )
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Stepper(value: decimalProxy(\.weightKg), in: 0 ... 250, step: 1) {
                        labeledValue(
                            statT("stat.np.bodyWeight"),
                            profile.weightKg > 0 ? "\(Int(profile.doubleWeight)) kg" : statT("stat.np.notSet")
                        )
                    }
                    Stepper(value: decimalProxy(\.heightCm), in: 0 ... 230, step: 1) {
                        labeledValue(
                            statT("stat.np.height"),
                            profile.heightCm > 0 ? "\(Int(profile.doubleHeight)) cm" : statT("stat.np.notSet")
                        )
                    }
                    Stepper(value: $profile.age, in: 1 ... 120) {
                        labeledValue(statT("stat.np.age"), "\(profile.age)")
                    }
                    Picker("Sex", selection: sexProxy) {
                        ForEach(selectableSexes) { sex in
                            Text(NSLocalizedString(sex.rawValue, comment: "")).tag(sex)
                        }
                    }
                } header: {
                    Text(statT("stat.np.bodyData"))
                } footer: {
                    Text(statT("stat.np.bodyData.footer"))
                }

                Section {
                    Picker(selection: $profile.activityLevel) {
                        ForEach(ActivityLevel.allCases) { level in
                            Text(verbatim: "\(level.title) · \(level.detail)").tag(level)
                        }
                    } label: {
                        Text(statT("stat.np.activity"))
                    }

                    if profile.hasBodyData {
                        labeledValue(statT("stat.np.dailyEnergy"), kcal(profile.tdee), valueColor: .primary)
                        labeledValue(statT("stat.np.bmr"), kcal(profile.bmr))
                    }
                } header: {
                    Text(statT("stat.np.activityEnergy"))
                } footer: {
                    Text(statT("stat.np.activityEnergy.footer"))
                }

                Section {
                    Stepper(value: decimalProxy(\.proteinPerKg), in: 0.5 ... 3.0, step: 0.1) {
                        macroLabel(
                            "Protein",
                            macro: .protein,
                            trailing: profile.doubleProteinPerKg.formatted(.number.precision(.fractionLength(1))) + " g/kg"
                        )
                    }
                    Stepper(value: decimalProxy(\.fatPercent), in: 15 ... 45, step: 1) {
                        macroLabel("Fat", macro: .fat, trailing: "\(Int(profile.doubleFatPercent)) %")
                    }
                    macroLabel("Carbs", macro: .carbs, trailing: carbsPercentText)
                } header: {
                    Text(statT("stat.np.macroTargets"))
                } footer: {
                    Text(statT("stat.np.macroTargets.footer"))
                }
            }
            .navigationTitle(Text(statT("stat.np.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDone()
                        dismiss()
                    }
                }
            }
        }
    }

    private var carbsPercentText: String {
        guard profile.hasBodyData, profile.tdee > 0 else { return statT("stat.np.rest") }
        let pct = profile.targetGrams(for: .carbs) * 4 / profile.tdee * 100
        return "\(Int(pct.rounded())) %"
    }

    private func kcal(_ value: Double) -> String {
        value.formatted(.number.grouping(.automatic).rounded().precision(.fractionLength(0))) + " kcal"
    }

    private func labeledValue(_ label: String, _ value: String, valueColor: Color = .secondary) -> some View {
        HStack {
            Text(verbatim: label)
            Spacer()
            Text(verbatim: value).foregroundStyle(valueColor)
        }
    }

    /// Macro name (shared, localized) + resolved grams + a trailing detail.
    private func macroLabel(_ name: String, macro: MacroNutrient, trailing: String) -> some View {
        HStack(spacing: 8) {
            Text(NSLocalizedString(name, comment: ""))
            Spacer(minLength: 8)
            if profile.hasBodyData {
                Text(verbatim: "\(Int(profile.targetGrams(for: macro).rounded())) g")
                    .foregroundStyle(.primary)
                Text(verbatim: "·").foregroundStyle(.secondary)
            }
            Text(verbatim: trailing).foregroundStyle(.secondary)
        }
    }
}

private extension NutritionProfile {
    var doubleWeight: Double { NSDecimalNumber(decimal: weightKg).doubleValue }
    var doubleHeight: Double { NSDecimalNumber(decimal: heightCm).doubleValue }
    var doubleProteinPerKg: Double { NSDecimalNumber(decimal: proteinPerKg).doubleValue }
    var doubleFatPercent: Double { NSDecimalNumber(decimal: fatPercent).doubleValue }
}
