//
//  PumpBaseSettingsViewModel.swift
//  MedtrumKit
//
//  Created by Bastiaan Verhaar on 05/04/2025.
//

class PumpBaseSettingsViewModel: ObservableObject {
    @Published var is300u = false
    @Published var serialNumber: String = ""
    @Published var errorMessage: String = ""
    
    private let pumpManager: MedtrumPumpManager?
    private let nextStep: () -> Void
    init(_ pumpManager: MedtrumPumpManager?, _ nextStep: @escaping () -> Void) {
        self.pumpManager = pumpManager
        self.nextStep = nextStep
        
        guard let pumpManager = pumpManager else {
            return
        }
        
        self.serialNumber = pumpManager.state.pumpSN.hexEncodedString().uppercased()
        if !pumpManager.state.pumpSN.isEmpty {
            // Only try to decrypt pumpSN if it is valid
            self.is300u = pumpManager.state.pumpName.contains("300U")
        }
    }
    
    func saveAndContinue() {
        guard serialNumber.count == 8 else {
            errorMessage = "Serial Number is too short"
            return
        }
        
        guard let snData = Data(hex: serialNumber), snData.count == 4 else {
            errorMessage = "Serial Number is invalid hex format"
            return
        }

        guard let pumpManager = pumpManager else {
            errorMessage = "Failed to connect to pump"
            return
        }
        
        pumpManager.state.pumpSN = snData
        guard pumpManager.state.model != "INVALID" else {
            errorMessage = "Incorrect serial number received"
            return
        }
        
        errorMessage = ""
        
        pumpManager.state.isOnboarded = true
        pumpManager.notifyStateDidChange()
        nextStep()
    }
}
