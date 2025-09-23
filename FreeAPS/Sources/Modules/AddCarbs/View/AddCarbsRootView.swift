import Combine
import CoreData
import OSLog
import SwiftUI
import Swinject

extension AddCarbs {
    struct RootView: BaseView {
        let resolver: Resolver
        let editMode: Bool
        let override: Bool

        @StateObject var state = StateModel()
        @StateObject var foodSearchState = FoodSearchStateModel()

        @State var dish: String = ""
        @State var isPromptPresented = false
        @State var saved = false
        @State var pushed = false
        @State var button = false
        @State private var showAlert = false
        @State private var presentPresets = false
        @State private var string = ""
        @State private var newPreset: (dish: String, carbs: Decimal, fat: Decimal, protein: Decimal) = ("", 0, 0, 0)

        // Food Search States
        @State private var showingFoodSearch = false
        @State private var foodSearchText = ""
        @State private var searchResults: [FoodItem] = []
        @State private var isLoading = false
        @State private var errorMessage: String?
        @State private var selectedFoodItem: AIFoodItem? = nil
        @State private var showMultiplierEditor: Bool = false
        @State private var portionGrams: Double = 100.0

        init(resolver: Resolver, editMode: Bool, override: Bool) {
            self.resolver = resolver
            self.editMode = editMode
            self.override = override
        }

        private func isAIAnalysisProduct(_ food: AIFoodItem) -> Bool {
            food.brand == "AI Analysis" || food.brand == nil || food.brand?.contains("AI") == true
        }

        @FetchRequest(
            entity: Presets.entity(),
            sortDescriptors: [NSSortDescriptor(key: "dish", ascending: true)], predicate:
            NSCompoundPredicate(
                andPredicateWithSubpredicates: [
                    NSPredicate(format: "dish != %@", " " as String),
                    NSPredicate(format: "dish != %@", "Empty" as String)
                ]
            )
        ) var carbPresets: FetchedResults<Presets>

        @Environment(\.managedObjectContext) var moc
        @Environment(\.colorScheme) var colorScheme

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }

        var body: some View {
            Form {
                foodSearchSection

                if let selectedFood = selectedFoodItem {
                    SelectedFoodView(
                        food: selectedFood,
                        portionGrams: $portionGrams,
                        onChange: {
                            selectedFoodItem = nil
                            showingFoodSearch = true
                        },
                        onTakeOver: { food in
                            if isAIAnalysisProduct(food) {
                                state.carbs = Decimal(food.carbs)
                                state.fat = Decimal(food.fat)
                                state.protein = Decimal(food.protein)
                            } else {
                                state.carbs = Decimal(food.carbs)
                                state.fat = Decimal(food.fat)
                                state.protein = Decimal(food.protein)
                            }
                        }
                    )
                }

                if let carbsReq = state.carbsRequired, state.carbs < carbsReq {
                    Section {
                        HStack {
                            Text("Carbs required")
                            Spacer()
                            Text((formatter.string(from: carbsReq as NSNumber) ?? "") + " g")
                        }
                    }
                }

                Section {
                    // Saved Food presets
                    mealPresets.padding(.vertical, 9)

                    HStack {
                        Text("Carbs").fontWeight(.semibold).foregroundColor(.orange)
                        Spacer()
                        DecimalTextField(
                            "0",
                            value: $state.carbs,
                            formatter: formatter,
                            autofocus: true,
                            liveEditing: true
                        )
                        Text("grams").foregroundColor(.secondary)
                    }

                    if state.useFPUconversion {
                        proteinAndFat()
                    }

                    // Summary when combining presets
                    if state.combinedPresets.isNotEmpty {
                        let summary = state.waitersNotepad()
                        if summary.isNotEmpty {
                            HStack {
                                Text("Total")
                                HStack(spacing: 0) {
                                    ForEach(summary, id: \.self) {
                                        Text($0).foregroundStyle(Color.randomGreen()).font(.footnote)
                                        Text($0 == summary[summary.count - 1] ? "" : ", ")
                                    }
                                }.frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }

                    // Time
                    HStack {
                        Text("Time")
                        Spacer()
                        if !pushed {
                            Button {
                                pushed = true
                            } label: { Text("Now") }.buttonStyle(.borderless).foregroundColor(.secondary).padding(.trailing, 5)
                        } else {
                            Button { state.date = state.date.addingTimeInterval(-15.minutes.timeInterval) }
                            label: { Image(systemName: "minus.circle") }.tint(.blue).buttonStyle(.borderless)
                            DatePicker(
                                "Time",
                                selection: $state.date,
                                displayedComponents: [.hourAndMinute]
                            ).controlSize(.mini)
                                .labelsHidden()
                            Button {
                                state.date = state.date.addingTimeInterval(15.minutes.timeInterval)
                            }
                            label: { Image(systemName: "plus.circle") }.tint(.blue).buttonStyle(.borderless)
                        }
                    }
                }

                // Optional Hypo Treatment
                if state.carbs > 0, let profile = state.id, profile != "None", state.carbsRequired != nil {
                    Section {
                        Button {
                            state.hypoTreatment = true
                            button.toggle()
                            if button { state.add(override, fetch: editMode) }
                        }
                        label: {
                            Text("Hypo Treatment")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }.listRowBackground(Color(.orange).opacity(0.9)).tint(.white)
                }

                Section {
                    Button {
                        button.toggle()
                        if button { state.add(override, fetch: editMode) }
                    }
                    label: {
                        Text(
                            ((state.skipBolus && !override && !editMode) || state.carbs <= 0) ? "Save" :
                                "Continue"
                        ) }
                        .disabled(empty)
                        .frame(maxWidth: .infinity, alignment: .center)
                }.listRowBackground(!empty ? Color(.systemBlue) : Color(.systemGray4))
                    .tint(.white)
            }
            .compactSectionSpacing()
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            .onAppear {
                configureView {
                    state.loadEntries(editMode)
                }
            }
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel", action: {
                    state.hideModal()
                    if editMode { state.apsManager.determineBasalSync() }
                })
            )
            .sheet(isPresented: $presentPresets, content: { presetView })
            .sheet(isPresented: $showingFoodSearch) {
                FoodSearchView(
                    state: foodSearchState,
                    onSelect: { selectedFood in
                        handleSelectedFood(selectedFood)
                    }
                )
            }
        }

        // MARK: - Helper Functions

        @ViewBuilder private func proteinAndFat() -> some View {
            HStack {
                Text("Fat").foregroundColor(.blue)
                Spacer()
                DecimalTextField(
                    "0",
                    value: $state.fat,
                    formatter: formatter,
                    autofocus: false,
                    liveEditing: true
                )
                Text("grams").foregroundColor(.secondary)
            }
            HStack {
                Text("Protein").foregroundColor(.green)
                Spacer()
                DecimalTextField(
                    "0",
                    value: $state.protein,
                    formatter: formatter,
                    autofocus: false,
                    liveEditing: true
                )
                Text("grams").foregroundColor(.secondary)
            }
        }

        // MARK: - Food Search Section

        private var foodSearchSection: some View {
            Section(header: Text("AI Food Search")) {
                NavigationLink(destination: AISettingsView()) {
                    HStack {
                        Image(systemName: "gearshape")
                        Text("AI Settings")
                        Spacer()
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())

                // Suche in der Food-Datenbank
                Button {
                    showingFoodSearch = true
                } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search Food Database")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.popUpGray)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }

        /*   private func handleSelectedFood(_ food: FoodItem) {
             state.carbs = food.carbs
             state.fat = food.fat
             state.protein = food.protein
         }*/

        private func handleSelectedFood(_ foodItem: FoodItem) {
            let calculatedCalories = Double(truncating: foodItem.carbs as NSNumber) * 4 +
                Double(truncating: foodItem.protein as NSNumber) * 4 +
                Double(truncating: foodItem.fat as NSNumber) * 9

            let aiFoodItem = AIFoodItem(
                name: foodItem.name,
                brand: foodItem.source,
                calories: calculatedCalories,
                carbs: Double(truncating: foodItem.carbs as NSNumber),
                protein: Double(truncating: foodItem.protein as NSNumber),
                fat: Double(truncating: foodItem.fat as NSNumber),
                imageURL: foodItem.imageURL
            )
            selectedFoodItem = aiFoodItem

            // Gramm zurücksetzen (100g für normale Produkte)
            portionGrams = 100.0

            showingFoodSearch = false
        }

        private var empty: Bool {
            state.carbs <= 0 && state.fat <= 0 && state.protein <= 0
        }

        private var mealPresets: some View {
            Section {
                HStack {
                    if state.selection == nil {
                        Button { presentPresets.toggle() }
                        label: {
                            HStack {
                                Text(state.selection?.dish ?? NSLocalizedString("Saved Food", comment: ""))
                                Text(">")
                            }
                        }.foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    } else {
                        minusButton
                        Spacer()

                        Button { presentPresets.toggle() }
                        label: {
                            HStack {
                                Text(state.selection?.dish ?? NSLocalizedString("Saved Food", comment: ""))
                                Text(">")
                            }
                        }.foregroundStyle(.secondary)
                        Spacer()
                        plusButton
                    }
                }
            }.dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }

        private var minusButton: some View {
            Button {
                state.subtract()
                if empty {
                    state.selection = nil
                    state.combinedPresets = []
                }
            }
            label: { Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .disabled(state.selection == nil)
        }

        private var plusButton: some View {
            Button {
                state.plus()
            }
            label: { Image(systemName: "plus.circle.fill")
            }
            .buttonStyle(.borderless)
            .disabled(state.selection == nil)
        }

        private var presetView: some View {
            Form {
                Section {} header: {
                    Text("Back").textCase(nil).foregroundStyle(.blue).font(.system(size: 16))
                        .onTapGesture { reset() } }

                if !empty {
                    Section {
                        Button {
                            addfromCarbsView()
                        }
                        label: {
                            HStack {
                                Text("Save as Preset")
                                Spacer()
                                Text("[\(state.carbs), \(state.fat), \(state.protein)]")
                            }
                        }.frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color(.systemBlue)).tint(.white)
                    }
                    header: { Text("Save") }
                }

                let filtered = carbPresets.filter { ($0.dish ?? "").count > 1 }.removeDublicates()
                if filtered.count > 4 {
                    Section {
                        TextField("Search", text: $string)
                    } header: { Text("Search") }
                }
                let data = string.isEmpty ? filtered : carbPresets
                    .filter { ($0.dish ?? "").localizedCaseInsensitiveContains(string) }

                Section {
                    ForEach(data, id: \.self) { preset in
                        presetsList(for: preset)
                    }.onDelete(perform: delete)
                } header: {
                    HStack {
                        Text("Saved Food")
                        Button {
                            state.presetToEdit = Presets(context: moc)
                            newPreset = (NSLocalizedString("New", comment: ""), 0, 0, 0)
                            state.edit = true
                        } label: { Image(systemName: "plus").font(.system(size: 22)) }
                            .buttonStyle(.borderless).frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .sheet(isPresented: $state.edit, content: { editView })
            .environment(\.colorScheme, colorScheme)
        }

        @ViewBuilder private func presetsList(for preset: Presets) -> some View {
            let dish = preset.dish ?? ""

            if !preset.hasChanges {
                HStack {
                    VStack(alignment: .leading) {
                        Text(dish)
                        HStack {
                            Text("Carbs")
                            Text("\(preset.carbs ?? 0)")
                            Spacer()
                            Text("Fat")
                            Text("\(preset.fat ?? 0)")
                            Spacer()
                            Text("Protein")
                            Text("\(preset.protein ?? 0)")
                        }.foregroundStyle(.secondary).font(.caption).padding(.top, 2)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        state.selection = preset
                        state.addU(state.selection)
                        reset()
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            state.edit = true
                            state.presetToEdit = preset
                            update()
                        } label: {
                            Label("Edit", systemImage: "pencil.line")
                        }
                    }
                }
            }
        }

        private func delete(at offsets: IndexSet) {
            for index in offsets {
                let preset = carbPresets[index]
                moc.delete(preset)
            }
            do {
                try moc.save()
            } catch {
                // Error handling
            }
        }

        private func save() {
            if let preset = state.presetToEdit {
                preset.dish = newPreset.dish
                preset.carbs = newPreset.carbs as NSDecimalNumber
                preset.fat = newPreset.fat as NSDecimalNumber
                preset.protein = newPreset.protein as NSDecimalNumber
            } else if !disabled {
                let preset = Presets(context: moc)
                preset.carbs = newPreset.carbs as NSDecimalNumber
                preset.fat = newPreset.fat as NSDecimalNumber
                preset.protein = newPreset.protein as NSDecimalNumber
                preset.dish = newPreset.dish
            }

            if moc.hasChanges {
                do {
                    try moc.save()
                } catch {}
            }
            state.edit = false
        }

        private func update() {
            newPreset.dish = state.presetToEdit?.dish ?? ""
            newPreset.carbs = (state.presetToEdit?.carbs ?? 0) as Decimal
            newPreset.fat = (state.presetToEdit?.fat ?? 0) as Decimal
            newPreset.protein = (state.presetToEdit?.protein ?? 0) as Decimal
        }

        private func addfromCarbsView() {
            newPreset = (NSLocalizedString("New", comment: ""), state.carbs, state.fat, state.protein)
            state.edit = true
        }

        private func reset() {
            presentPresets = false
            string = ""
        }

        private var disabled: Bool {
            (newPreset == (NSLocalizedString("New", comment: ""), 0, 0, 0)) || (newPreset.dish == "") ||
                (newPreset.carbs + newPreset.fat + newPreset.protein <= 0)
        }

        private var editView: some View {
            Form {
                Section {
                    HStack {
                        TextField("", text: $newPreset.dish)
                    }
                    HStack {
                        Text("Carbs").foregroundStyle(.secondary)
                        Spacer()
                        DecimalTextField("0", value: $newPreset.carbs, formatter: formatter, liveEditing: true)
                    }
                    HStack {
                        Text("Fat").foregroundStyle(.secondary)
                        Spacer()
                        DecimalTextField("0", value: $newPreset.fat, formatter: formatter, liveEditing: true)
                    }
                    HStack {
                        Text("Protein").foregroundStyle(.secondary)
                        Spacer()
                        DecimalTextField("0", value: $newPreset.protein, formatter: formatter, liveEditing: true)
                    }
                } header: { Text("Saved Food") }

                Section {
                    Button { save() }
                    label: { Text("Save") }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(!disabled ? Color(.systemBlue) : Color(.systemGray4))
                        .tint(.white)
                        .disabled(disabled)
                }
            }.environment(\.colorScheme, colorScheme)
        }
    }
}

/// FOOD SEARCH

class FoodSearchStateModel: ObservableObject {
    @Published var foodSearchText = ""
    @Published var searchResults: [OpenFoodFactsProduct] = []
    @Published var aiSearchResults: [AIFoodItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    init() {
        print("🔍 FoodSearchStateModel initialized")

        // Debounced search
        $foodSearchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }

    deinit {
        print("🔍 FoodSearchStateModel deinitialized")
        searchTask?.cancel()
    }

    func performSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            aiSearchResults = []
            return
        }

        searchTask?.cancel()
        isLoading = true
        errorMessage = nil

        searchTask = Task { @MainActor in
            do {
                let openFoodProducts = try await FoodSearchRouter.shared.searchFoodsByText(query)

                if !Task.isCancelled {
                    // ✅ KEINE map MEHR - direkt die originalen Produkte verwenden
                    self.searchResults = openFoodProducts
                    self.isLoading = false
                    print("✅ Search completed: \(self.searchResults.count) results")
                }
            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    self.searchResults = []
                    print("❌ Search failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func searchWithOpenFoodFacts(barcode: String) {
        isLoading = true
        errorMessage = nil
        foodSearchText = barcode

        Task {
            do {
                print("🔍 Searching OpenFoodFacts for barcode: \(barcode)")

                // ✅ DIREKT den Shared Router verwenden
                if let product = try await FoodSearchRouter.shared.searchFoodByBarcode(barcode) {
                    await MainActor.run {
                        self.searchResults = [product] // ← Das ist jetzt [OpenFoodFactsProduct]
                        print("✅ OpenFoodFacts found product: \(product.displayName)")
                        self.isLoading = false

                        // ✅ DEBUG: Prüfe ob URLs vorhanden sind
                        print("🖼️ Barcode Product URLs: \(product.imageURL ?? "nil"), \(product.imageFrontURL ?? "nil")")
                    }
                } else {
                    // Kein Produkt gefunden → Fallback zu normaler Suche
                    await MainActor.run {
                        print("⚠️ No OpenFoodFacts results, using normal search")
                        self.performSearch(query: barcode)
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ OpenFoodFacts search failed: \(error), using normal search")
                    self.errorMessage = "OpenFoodFacts search failed: \(error.localizedDescription)"
                    self.performSearch(query: barcode)
                }
            }
        }
    }

    func addAISearchResults(_ results: [AIFoodItem]) {
        aiSearchResults = results
    }

    func clearAISearchResults() {
        aiSearchResults = []
    }
}

private func searchFoodProducts(query: String) async throws -> [FoodItem] {
    print("🔍 Starting search for: '\(query)'")
    let openFoodProducts = try await FoodSearchRouter.shared.searchFoodsByText(query)

    return openFoodProducts.map { openFoodProduct in
        FoodItem(
            name: openFoodProduct.productName ?? "Unknown",
            carbs: Decimal(openFoodProduct.nutriments.carbohydrates),
            fat: Decimal(openFoodProduct.nutriments.fat ?? 0),
            protein: Decimal(openFoodProduct.nutriments.proteins ?? 0),
            source: openFoodProduct.brands ?? "OpenFoodFacts",
            imageURL: openFoodProduct.imageURL ?? openFoodProduct.imageFrontURL
        )
    }
}

private func searchOpenFoodFactsByBarcode(_ barcode: String) async throws -> [FoodItem] {
    let urlString = "https://world.openfoodfacts.org/api/v2/product/\(barcode).json"
    print("🌐 OpenFoodFacts API Call: \(urlString)")

    guard let url = URL(string: urlString) else {
        throw NSError(domain: "OpenFoodFactsError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
    }

    let (data, response) = try await URLSession.shared.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse else {
        throw NSError(domain: "OpenFoodFactsError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
    }

    guard httpResponse.statusCode == 200 else {
        print("❌ OpenFoodFacts API Error: Status \(httpResponse.statusCode)")
        return [] // Leeres Array für "nicht gefunden"
    }

    // Parse die Response
    let productResponse = try JSONDecoder().decode(OpenFoodFactsProductResponse.self, from: data)

    if productResponse.status == 1, let product = productResponse.product {
        // Produkt gefunden
        let foodItem = FoodItem(
            name: product.productName ?? "Unknown",
            carbs: Decimal(product.nutriments.carbohydrates),
            fat: Decimal(product.nutriments.fat ?? 0),
            protein: Decimal(product.nutriments.proteins ?? 0),
            source: product.brands ?? "OpenFoodFacts",
            imageURL: product.imageURL ?? product.imageFrontURL
        )
        return [foodItem]
        // }
    } else {
        // Kein Produkt gefunden
        print("ℹ️ OpenFoodFacts: No product found for barcode \(barcode)")
        return []
    }
}

private func searchFoodProducts(query: String, completion: @escaping ([AIFoodItem]) -> Void) async throws -> [FoodItem] {
    do {
        print("🔍 Starting AI search for: '\(query)'")

        // Use the FoodSearchRouter to handle the search
        let openFoodProducts = try await FoodSearchRouter.shared.searchFoodsByText(query)

        print("✅ AI search completed, found \(openFoodProducts.count) products")

        // Konvertiert OpenFoodFactsProduct zu AIFoodItem
        let aiProducts = openFoodProducts.map { openFoodProduct in
            AIFoodItem(
                name: openFoodProduct.productName ?? "Unknown",
                brand: openFoodProduct.brands,
                calories: 0,
                carbs: openFoodProduct.nutriments.carbohydrates,
                protein: openFoodProduct.nutriments.proteins ?? 0,
                fat: openFoodProduct.nutriments.fat ?? 0,
                imageURL: openFoodProduct.imageURL ?? openFoodProduct.imageFrontURL
            )
        }

        // Rückgabe der AI-Ergebnisse via Completion Handler
        completion(aiProducts)

        // Konvertiere zu FoodItem für Rückgabe
        return openFoodProducts.map { openFoodProduct in
            FoodItem(
                name: openFoodProduct.productName ?? "Unknown",
                carbs: Decimal(openFoodProduct.nutriments.carbohydrates),
                fat: Decimal(openFoodProduct.nutriments.fat ?? 0),
                protein: Decimal(openFoodProduct.nutriments.proteins ?? 0),
                source: openFoodProduct.brands ?? "OpenFoodFacts",
                imageURL: openFoodProduct.imageURL ?? openFoodProduct.imageFrontURL
            )
        }
    } catch {
        print("❌ AI Search failed: \(error.localizedDescription)")
        completion([])
        return []
    }
}

/* struct FoodSearchView: View {
     @ObservedObject var state: FoodSearchStateModel
     var onSelect: (FoodItem) -> Void
     @Environment(\.dismiss) var dismiss

     // Navigation States
     @State private var navigateToBarcode = false
     @State private var navigateToAICamera = false
     @State private var showingAIAnalysisResults = false
     @State private var aiAnalysisResult: AIFoodAnalysisResult?

     var body: some View {
         NavigationView {
             VStack {
                 // Suchfeld + Buttons
                 HStack(spacing: 8) {
                     TextField("Food Search...", text: $state.foodSearchText)
                         .textFieldStyle(RoundedBorderTextFieldStyle())
                         .autocapitalization(.none)
                         .disableAutocorrection(true)
                         .submitLabel(.search)
                         .onSubmit {
                             state.performSearch(query: state.foodSearchText)
                         }
                     // Barcode Button
                     Button {
                         navigateToBarcode = true
                     } label: {
                         Image(systemName: "barcode.viewfinder")
                             .font(.title2)
                             .foregroundColor(.blue)
                             .padding(8)
                             .background(Color.blue.opacity(0.1))
                             .cornerRadius(8)
                     }

                     // AI Kamera Button
                     Button {
                         navigateToAICamera = true
                     } label: {
                         AICameraIcon()
                             .frame(width: 24, height: 24)
                             .padding(8)
                             .background(Color.purple.opacity(0.1))
                             .cornerRadius(8)
                     }
                 }
                 .padding(.horizontal)
                 .padding(.top, 8)

                 ScrollView {
                     // Zeige entweder normale Suchergebnisse oder AI-Analyse-Ergebnisse an
                     if showingAIAnalysisResults, let result = aiAnalysisResult {
                         AIAnalysisResultsView(
                             analysisResult: result,
                             onFoodItemSelected: { foodItem in
                                 onSelect(foodItem)
                                 dismiss()
                             },
                             onCompleteMealSelected: { totalMeal in
                                 onSelect(totalMeal)
                                 dismiss()
                             }
                         ) // <-- Hier endete der View-Initialisierer
                     } else {
                         FoodSearchResultsView(
                             searchResults: state.searchResults,
                             aiSearchResults: state.aiSearchResults,
                             isSearching: state.isLoading,
                             errorMessage: state.errorMessage,
                             onProductSelected: { selectedProduct in
                                 let foodItem = selectedProduct.toFoodItem()
                                 onSelect(foodItem)
                                 dismiss()
                             },
                             onAIProductSelected: { aiProduct in
                                 let foodItem = FoodItem(
                                     name: aiProduct.name,
                                     carbs: Decimal(aiProduct.carbs),
                                     fat: Decimal(aiProduct.fat),
                                     protein: Decimal(aiProduct.protein),
                                     source: "AI Analyse",
                                     imageURL: aiProduct.imageURL
                                 )
                                 onSelect(foodItem)
                                 dismiss()
                             }
                         )
                     }
                 }
                 .padding(.top, 8)
                 // Navigation-Ziele
                 NavigationLink(
                     destination: BarcodeScannerView(
                         onBarcodeScanned: { barcode in
                             handleBarcodeScan(barcode)
                             navigateToBarcode = false
                         },
                         onCancel: { navigateToBarcode = false }
                     ),
                     isActive: $navigateToBarcode,
                     label: { EmptyView() }
                 )

                 NavigationLink(
                     destination: AICameraView(
                         onFoodAnalyzed: { analysisResult, image in
                             handleAIAnalysis(analysisResult, image: image)
                             navigateToAICamera = false
                         },
                         onCancel: { navigateToAICamera = false }
                     ),
                     isActive: $navigateToAICamera,
                     label: { EmptyView() }
                 )
             }
             .navigationTitle("Food Search")
             .navigationBarItems(trailing: Button("Fertig") { dismiss() })
         }
     }

     private func handleBarcodeScan(_ barcode: String) {
         print("📦 Barcode gescannt: \(barcode)")
         navigateToBarcode = false
         state.foodSearchText = barcode
         state.performSearch(query: barcode)
         print("🔍 Suche nach Barcode: \(barcode)")
     }

     private func handleAIAnalysis(_ analysisResult: AIFoodAnalysisResult, image _: UIImage?) {
         aiAnalysisResult = analysisResult
         showingAIAnalysisResults = true

         let aiFoodItems = analysisResult.foodItemsDetailed.map { foodItem in
             AIFoodItem(
                 name: foodItem.name,
                 brand: nil,
                 calories: foodItem.calories ?? 0,
                 carbs: foodItem.carbohydrates,
                 protein: foodItem.protein ?? analysisResult.totalProtein ?? 0,
                 fat: foodItem.fat ?? analysisResult.totalFat ?? 0,
                 imageURL: nil
             )
         }
         state.aiSearchResults = aiFoodItems
     }
 } */

struct FoodSearchView: View {
    @ObservedObject var state: FoodSearchStateModel
    var onSelect: (FoodItem) -> Void
    @Environment(\.dismiss) var dismiss

    // Navigation States
    @State private var navigateToBarcode = false
    @State private var navigateToAICamera = false
    @State private var showingAIAnalysisResults = false
    @State private var aiAnalysisResult: AIFoodAnalysisResult?

    var body: some View {
        NavigationStack {
            VStack {
                // Suchfeld + Buttons
                HStack(spacing: 8) {
                    TextField("Food Search...", text: $state.foodSearchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .submitLabel(.search)
                        .onSubmit {
                            state.performSearch(query: state.foodSearchText)
                        }

                    // Barcode Button
                    Button {
                        navigateToBarcode = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }

                    // AI Kamera Button
                    Button {
                        navigateToAICamera = true
                    } label: {
                        Image(systemName: "camera")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .padding(8)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundColor(.purple)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                ScrollView {
                    // Zeige entweder normale Suchergebnisse oder AI-Analyse-Ergebnisse an
                    if showingAIAnalysisResults, let result = aiAnalysisResult {
                        AIAnalysisResultsView(
                            analysisResult: result,
                            onFoodItemSelected: { foodItem in
                                onSelect(foodItem)
                                dismiss()
                            },
                            onCompleteMealSelected: { totalMeal in
                                onSelect(totalMeal)
                                dismiss()
                            }
                        )
                    } else {
                        FoodSearchResultsView(
                            searchResults: state.searchResults,
                            aiSearchResults: state.aiSearchResults,
                            isSearching: state.isLoading,
                            errorMessage: state.errorMessage,
                            onProductSelected: { selectedProduct in
                                let foodItem = selectedProduct.toFoodItem()
                                onSelect(foodItem)
                                dismiss()
                            },
                            onAIProductSelected: { aiProduct in
                                let foodItem = FoodItem(
                                    name: aiProduct.name,
                                    carbs: Decimal(aiProduct.carbs),
                                    fat: Decimal(aiProduct.fat),
                                    protein: Decimal(aiProduct.protein),
                                    source: "AI Analyse",
                                    imageURL: aiProduct.imageURL
                                )
                                onSelect(foodItem)
                                dismiss()
                            }
                        )
                    }
                }
                .padding(.top, 8)
            }
            .navigationTitle("Food Search")
            .navigationBarItems(trailing: Button("Fertig") { dismiss() })
            .navigationDestination(isPresented: $navigateToBarcode) {
                BarcodeScannerView(
                    onBarcodeScanned: { barcode in
                        handleBarcodeScan(barcode)
                        navigateToBarcode = false
                    },
                    onCancel: { navigateToBarcode = false }
                )
            }
            .navigationDestination(isPresented: $navigateToAICamera) {
                AICameraView(
                    onFoodAnalyzed: { analysisResult, image in
                        // ✅ STABILER: Verzögerung vor Rücknavigation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            handleAIAnalysis(analysisResult, image: image)
                            navigateToAICamera = false
                        }
                    },
                    onCancel: { navigateToAICamera = false }
                )
            }
        }
    }

    private func handleBarcodeScan(_ barcode: String) {
        print("📦 Barcode gescannt: \(barcode)")
        navigateToBarcode = false
        state.foodSearchText = barcode
        state.performSearch(query: barcode)
        print("🔍 Suche nach Barcode: \(barcode)")
    }

    private func handleAIAnalysis(_ analysisResult: AIFoodAnalysisResult, image _: UIImage?) {
        aiAnalysisResult = analysisResult
        showingAIAnalysisResults = true

        let aiFoodItems = analysisResult.foodItemsDetailed.map { foodItem in
            AIFoodItem(
                name: foodItem.name,
                brand: nil,
                calories: foodItem.calories ?? 0,
                carbs: foodItem.carbohydrates,
                protein: foodItem.protein ?? analysisResult.totalProtein ?? 0,
                fat: foodItem.fat ?? analysisResult.totalFat ?? 0,
                imageURL: nil
            )
        }
        state.aiSearchResults = aiFoodItems
    }
}

struct FoodItemCard: View {
    let foodItem: FoodItemAnalysis
    let onSelect: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Kopfbereich mit Tap-Gesture für Auswahl
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(foodItem.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    // Expand/Collapse Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(6)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Auswahl-Button
                Button(action: onSelect) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                        Text("Add")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())

                // Portionsinformationen (immer sichtbar)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Portion: \(foodItem.portionEstimate)")
                        .font(.subheadline)

                    if let usdaSize = foodItem.usdaServingSize {
                        Text("USDA Standard: \(usdaSize)")
                            .font(.caption)
                    }

                    if foodItem.servingMultiplier != 1.0 {
                        Text("Multiplikator: \(foodItem.servingMultiplier, specifier: "%.1f")x")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    NutritionBadge(value: foodItem.carbohydrates, unit: "g", label: "KH", color: .orange)

                    if let protein = foodItem.protein, protein > 0 {
                        NutritionBadge(value: protein, unit: "g", label: "P", color: .green)
                    }

                    if let fat = foodItem.fat, fat > 0 {
                        NutritionBadge(value: fat, unit: "g", label: "F", color: .blue)
                    }
                }
            }

            // Erweiterter Bereich (expandable)
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Detaillierte Nährwerte
                    if let calories = foodItem.calories, calories > 0 {
                        HStack {
                            NutritionBadge(value: calories, unit: "kcal", label: "Calories", color: .red)

                            if let fiber = foodItem.fiber, fiber > 0 {
                                NutritionBadge(value: fiber, unit: "g", label: "Faser", color: .purple)
                            }
                        }
                    }

                    // Zusätzliche Informationen
                    VStack(alignment: .leading, spacing: 4) {
                        if let preparation = foodItem.preparationMethod, !preparation.isEmpty {
                            HStack(alignment: .top) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Zubereitung: \(preparation)")
                                    .font(.caption)
                            }
                        }

                        if let visualCues = foodItem.visualCues, !visualCues.isEmpty {
                            HStack(alignment: .top) {
                                Image(systemName: "eye.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text("Visuelle Hinweise: \(visualCues)")
                                    .font(.caption)
                            }
                        }

                        if let notes = foodItem.assessmentNotes, !notes.isEmpty {
                            HStack(alignment: .top) {
                                Image(systemName: "note.text")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                                Text("Bewertung: \(notes)")
                                    .font(.caption)
                            }
                        }
                    }
                    .foregroundColor(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

private func isAIAnalysisProduct(_ foodItem: AIFoodItem) -> Bool {
    if let brand = foodItem.brand, brand.contains("AI") || brand.contains("Analysis") {
        return true
    }
    return foodItem.brand == nil || foodItem.brand == "AI Analysis"
}

struct AIAnalysisResultsView: View {
    let analysisResult: AIFoodAnalysisResult
    let onFoodItemSelected: (FoodItem) -> Void
    let onCompleteMealSelected: (FoodItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header mit Gesamtübersicht
            VStack(alignment: .leading, spacing: 12) {
                Text("🧠 AI Food analysis")
                    .font(.title2)
                    .fontWeight(.bold)

                if let description = analysisResult.overallDescription {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Konfidenz-Level
                HStack {
                    Text("Confidence level:")
                    ConfidenceBadge(level: analysisResult.confidence)
                    Spacer()
                    if let portions = analysisResult.totalFoodPortions {
                        Text("\(portions) Portions")
                            .font(.caption)
                    }
                }
                .font(.subheadline)
            }
            .padding(.horizontal)

            // Gesamt-Nährwerte der Mahlzeit
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("📊 Total nutritional values of the meal")
                        .font(.headline)

                    Spacer()

                    Button(action: {
                        let mealName = analysisResult.foodItemsDetailed.count == 1 ?
                            analysisResult.foodItemsDetailed.first?.name ?? "Meal" :
                            "Complete Meal"

                        let totalMeal = FoodItem(
                            name: mealName,
                            carbs: Decimal(analysisResult.totalCarbohydrates),
                            fat: Decimal(analysisResult.totalFat ?? 0),
                            protein: Decimal(analysisResult.totalProtein ?? 0),
                            source: "AI overall analysis • \(analysisResult.foodItemsDetailed.count) Food",
                            imageURL: nil
                        )
                        onCompleteMealSelected(totalMeal)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Add all")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("\(analysisResult.foodItemsDetailed.count) Food")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                    NutritionSummaryBadge(
                        value: analysisResult.totalCarbohydrates,
                        unit: "g",
                        label: "Carbs",
                        color: .orange
                    )

                    if let protein = analysisResult.totalProtein {
                        NutritionSummaryBadge(value: protein, unit: "g", label: "Protein", color: .green)
                    }

                    if let fat = analysisResult.totalFat {
                        NutritionSummaryBadge(value: fat, unit: "g", label: "Fat", color: .loopRed)
                    }

                    /*  if let fiber = analysisResult.totalFiber {
                         NutritionSummaryBadge(value: fiber, unit: "g", label: "Fiber", color: .purple)
                     }

                     if let calories = analysisResult.totalCalories {
                         NutritionSummaryBadge(value: calories, unit: "kcal", label: "Calories", color: .red)
                     }

                     if let servings = analysisResult.totalUsdaServings {
                         NutritionSummaryBadge(value: servings, unit: "", label: "USDA Portions", color: .indigo)
                     }*/
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)

            // Einzelne Lebensmittel
            Text("🍽️ Seperat Foods")
                .font(.headline)
                .padding(.horizontal)

            ForEach(analysisResult.foodItemsDetailed, id: \.name) { foodItem in
                FoodItemCard(
                    foodItem: foodItem,
                    onSelect: {
                        let selectedFood = FoodItem(
                            name: foodItem.name,
                            carbs: Decimal(foodItem.carbohydrates),
                            fat: Decimal(foodItem.fat ?? 0),
                            protein: Decimal(foodItem.protein ?? 0),
                            source: "AI Analysis",
                            imageURL: nil
                        )
                        onFoodItemSelected(selectedFood)
                    }
                )
            }

            // Diabetes-spezifische Empfehlungen
            if let diabetesInfo = analysisResult.diabetesConsiderations {
                VStack(alignment: .leading, spacing: 8) {
                    Label("💉 Diabetes recommendations", systemImage: "cross.case.fill")
                        .font(.headline)
                    Text(diabetesInfo)
                        .font(.subheadline)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            // Zusätzliche Hinweise
            if let notes = analysisResult.notes {
                VStack(alignment: .leading, spacing: 8) {
                    Label("📝 Notes", systemImage: "note.text")
                        .font(.headline)
                    Text(notes)
                        .font(.subheadline)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

struct ConfidenceBadge: View {
    let level: AIConfidenceLevel

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(level.color)
                .frame(width: 8, height: 8)
            Text(level.description)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(level.color.opacity(0.2))
        .foregroundColor(level.color)
        .cornerRadius(6)
    }
}

struct NutritionSummaryBadge: View {
    let value: Double
    let unit: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value, specifier: "%.0f")")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            Text(unit)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// Erweiterung für AIConfidenceLevel
extension AIConfidenceLevel {
    var color: Color {
        switch self {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }

    var description: String {
        switch self {
        case .high: return "Hoch"
        case .medium: return "Mittel"
        case .low: return "Niedrig"
        }
    }
}

extension OpenFoodFactsProduct {
    func toFoodItem() -> FoodItem {
        FoodItem(
            name: productName ?? "Unknown",
            carbs: Decimal(nutriments.carbohydrates),
            fat: Decimal(nutriments.fat ?? 0),
            protein: Decimal(nutriments.proteins ?? 0),
            source: brands ?? "OpenFoodFacts",
            imageURL: imageURL ?? imageFrontURL
        )
    }
}

struct FoodItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let carbs: Decimal
    let fat: Decimal
    let protein: Decimal
    let source: String
    let imageURL: String?

    static func == (lhs: FoodItem, rhs: FoodItem) -> Bool {
        lhs.id == rhs.id
    }
}

extension FoodItem {
    func toAIFoodItem() -> AIFoodItem {
        AIFoodItem(
            name: name,
            brand: source,
            calories: Double(truncating: carbs as NSNumber) * 4 + Double(truncating: protein as NSNumber) * 4 +
                Double(truncating: fat as NSNumber) * 9,
            carbs: Double(truncating: carbs as NSNumber),
            protein: Double(truncating: protein as NSNumber),
            fat: Double(truncating: fat as NSNumber),
            imageURL: imageURL
        )
    }
}

// Rechner
struct MultiplierEditorView: View {
    @Binding var grams: Double
    @Environment(\.dismiss) var dismiss
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Amount")
                        .font(.headline)
                        .fontWeight(.bold)

                    Spacer()

                    Button("Exit") {
                        saveAndDismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color(.systemGray6))

                // Hauptinhalt
                VStack(spacing: 20) {
                    // Eingabefeld
                    VStack(spacing: 8) {
                        Text("Enter desired quantity")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            TextField("0", text: $inputText)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(PlainTextFieldStyle())
                                .focused($isInputFocused)
                                .font(.system(size: 40, weight: .bold))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 150)

                            Text("g")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)

                    // Schnellauswahl
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach([50, 100, 150, 200, 250, 300, 400, 500], id: \.self) { value in
                            Button {
                                inputText = "\(value)"
                            } label: {
                                Text("\(value)")
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(width: 70, height: 50)
                                    .background(grams == Double(value) ? Color.blue : Color.gray.opacity(0.1))
                                    .foregroundColor(grams == Double(value) ? .white : .primary)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Übernehmen-Button
                    Button(action: {
                        saveAndDismiss()
                    }) {
                        Text("Accept quantity")
                            .font(.headline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(15)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                }
            }
            .onAppear {
                inputText = String(format: "%.0f", grams)
                isInputFocused = true
            }
        }
    }

    private func saveAndDismiss() {
        if let value = Double(inputText.replacingOccurrences(of: ",", with: ".")) {
            grams = value
        }
        dismiss()
    }
}

extension AIFoodItem {
    func toCarbsEntry(servingSize: Double = 100.0) -> CarbsEntry {
        let scalingFactor = servingSize / 100.0

        return CarbsEntry(
            id: UUID().uuidString,
            createdAt: Date(),
            actualDate: Date(),
            carbs: Decimal(carbs * scalingFactor),
            fat: Decimal(fat * scalingFactor),
            protein: Decimal(protein * scalingFactor),
            note: "\(name)\(brand != nil ? " (\(brand!))" : "") - AI detected",
            enteredBy: CarbsEntry.manual,
            isFPU: false
        )
    }
}

struct SelectedFoodView: View {
    let food: AIFoodItem
    @Binding var portionGrams: Double
    var onChange: () -> Void
    var onTakeOver: (AIFoodItem) -> Void

    @State private var showMultiplierEditor = false

    /* private var isAIProduct: Bool {
         (food.brand ?? "")
             .lowercased()
             .contains("ai")
     }*/

    private var isAIProduct: Bool {
        (food.brand ?? "")
            .lowercased()
            .contains("ai overall analysis")
    }

    private var displayCarbs: Double {
        isAIProduct ? food.carbs : food.carbs * (portionGrams / 100.0)
    }

    private var displayFat: Double {
        isAIProduct ? food.fat : food.fat * (portionGrams / 100.0)
    }

    private var displayProtein: Double {
        isAIProduct ? food.protein : food.protein * (portionGrams / 100.0)
    }

    private var displayCalories: Double {
        isAIProduct ? food.calories : food.calories * (portionGrams / 100.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header mit Bild und Produktinfo
            HStack(alignment: .top, spacing: 12) {
                // Produktbild
                if let imageURLString = food.imageURL, let imageURL = URL(string: imageURLString) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 50, height: 50)
                        case let .success(image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            Image(systemName: "photo")
                                .frame(width: 50, height: 50)
                                .background(Color.gray.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    /*   Image(systemName: "photo")
                     .frame(width: 50, height: 50)
                     .background(Color.gray.opacity(0.2))
                     .clipShape(RoundedRectangle(cornerRadius: 8))*/
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Produktname
                    Text(food.name)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    // AI-Badge
                    HStack(spacing: 4) {
                        Image(systemName: isAIAnalysisProduct(food) ? "brain" : "scalemass")
                            .font(.caption)

                        if isAIAnalysisProduct(food) {
                            Text("AI Analysis")
                                .font(.caption)
                        } else if portionGrams == 100.0 {
                            Text("100g")
                                .font(.caption)
                        }
                    }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        isAIAnalysisProduct(food) ? Color.purple.opacity(0.2) :
                            (portionGrams == 100.0 ? Color.blue.opacity(0.2) : Color.clear)
                    )
                    .foregroundColor(
                        isAIAnalysisProduct(food) ? .purple :
                            (portionGrams == 100.0 ? .blue : .clear)
                    )
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                isAIAnalysisProduct(food) ? Color.purple.opacity(0.3) :
                                    (portionGrams == 100.0 ? Color.blue.opacity(0.3) : Color.clear),
                                lineWidth: 1
                            )
                    )
                }
            }

            // Amount-Sektion (nur für nicht-AI-Produkte)
            if !isAIAnalysisProduct(food) {
                HStack {
                    Text("Amount:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button {
                        showMultiplierEditor = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(portionGrams, specifier: "%.0f")g")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Image(systemName: "pencil")
                                .font(.system(size: 18, weight: .bold))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()
                }
            }

            // Nährwert-Badges
            HStack(spacing: 8) {
                NutritionBadge(
                    value: displayCarbs,
                    unit: "g",
                    label: "Carbs",
                    color: .dynamicColorOrange
                )
                NutritionBadge(
                    value: displayFat,
                    unit: "g",
                    label: "Fat",
                    color: .loopRed
                )
                NutritionBadge(
                    value: displayProtein,
                    unit: "g",
                    label: "Protein",
                    color: .green
                )
                if food.calories > 0 {
                    NutritionBadge(
                        value: displayCalories,
                        unit: "kcal",
                        label: "Calories",
                        color: .red
                    )
                }
            }

            // Button-Row
            HStack(spacing: 12) {
                Button(action: onChange) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Food")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                Button {
                    let adjustedFood = AIFoodItem(
                        name: food.name,
                        brand: food.brand,
                        calories: displayCalories,
                        carbs: displayCarbs,
                        protein: displayProtein,
                        fat: displayFat,
                        imageURL: food.imageURL
                    )
                    onTakeOver(adjustedFood)

                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Take over")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding()
        .padding(.vertical, 8)
        .sheet(isPresented: $showMultiplierEditor) {
            MultiplierEditorView(grams: $portionGrams)
        }
    }
}

private struct NutritionBadge: View {
    let value: Double
    let unit: String
    let label: String
    let color: Color
    let icon: String

    init(value: Double, unit: String, label: String, color: Color, icon: String? = nil) {
        self.value = value
        self.unit = unit
        self.label = label
        self.color = color
        self.icon = icon ?? ""
    }

    var body: some View {
        HStack(spacing: 4) {
            if !icon.isEmpty {
                Image(systemName: icon)
                    .font(.system(size: 10))
            }
            VStack(spacing: 2) {
                Text("\(value, specifier: "%.1f")\(unit)")
                    .font(.system(size: 12, weight: .bold))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }
}

public extension Color {
    static func randomGreen(randomOpacity: Bool = false) -> Color {
        Color(
            red: .random(in: 0 ... 1),
            green: .random(in: 0.4 ... 0.7),
            blue: .random(in: 0.2 ... 1),
            opacity: randomOpacity ? .random(in: 0.8 ... 1) : 1
        )
    }
}
