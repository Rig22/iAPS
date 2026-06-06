import SwiftUI

/// Editor for the Meal tab's body data (age, sex, weight) and protein goal.
/// Independent from the Sharing settings — changes here only affect the Meal
/// tab's nutrient RDI calculations.
struct NutritionProfileEditor: View {
    @Binding var profile: NutritionProfile
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var weightProxy: Binding<Double> {
        Binding(
            get: { NSDecimalNumber(decimal: profile.weightKg).doubleValue },
            set: { profile.weightKg = Decimal($0) }
        )
    }

    private func factorProxy(_ keyPath: WritableKeyPath<NutritionProfile, Decimal>) -> Binding<Double> {
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
                    Stepper(value: weightProxy, in: 0 ... 250, step: 1) {
                        HStack {
                            Text(verbatim: "Body weight")
                            Spacer()
                            Text(
                                profile.weightKg > 0
                                    ? "\(Int(weightProxy.wrappedValue)) kg"
                                    : "Not set"
                            )
                            .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: $profile.age, in: 1 ... 120) {
                        HStack {
                            Text(verbatim: "Age")
                            Spacer()
                            Text("\(profile.age)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Picker("Sex", selection: sexProxy) {
                        ForEach(selectableSexes) { sex in
                            Text(NSLocalizedString(sex.rawValue, comment: "")).tag(sex)
                        }
                    }
                } header: {
                    Text(verbatim: "Body Data")
                } footer: {
                    Text(verbatim: "Used only for the nutrient targets in the Meal statistics. Independent from Share & Backup.")
                }

                Section {
                    factorRow(
                        title: "Protein",
                        macro: .protein,
                        binding: factorProxy(\.proteinPerKg),
                        range: 0.5 ... 3.0
                    )
                    factorRow(
                        title: "Carbs",
                        macro: .carbs,
                        binding: factorProxy(\.carbsPerKg),
                        range: 1.0 ... 8.0
                    )
                    factorRow(
                        title: "Fat",
                        macro: .fat,
                        binding: factorProxy(\.fatPerKg),
                        range: 0.3 ... 2.5
                    )
                } header: {
                    Text(verbatim: "Macro Targets (g/kg/day)")
                } footer: {
                    Text(
                        verbatim: "When a body weight is set, each macro target = weight × factor. Protein: EFSA min ~0.83, health/sport 1.2–2.0 g/kg. Without a body weight, the fixed EFSA / EU reference values are used."
                    )
                }
            }
            .navigationTitle(Text(verbatim: "Nutrition Profile"))
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

    @ViewBuilder private func factorRow(
        title: String,
        macro: MacroNutrient,
        binding: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        Stepper(value: binding, in: range, step: 0.1) {
            HStack {
                Text(NSLocalizedString(title, comment: ""))
                Spacer()
                if profile.weightKg > 0 {
                    Text("\(Int(profile.targetGrams(for: macro).rounded())) g")
                        .foregroundStyle(.primary)
                    Text("·")
                        .foregroundStyle(.secondary)
                }
                Text(binding.wrappedValue.formatted(.number.precision(.fractionLength(1))) + " g/kg")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
