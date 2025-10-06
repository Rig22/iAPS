import SwiftUI

public struct DanaBarView: View {
    @ObservedObject var viewModel: DanaBarViewModel

    public init(viewModel: DanaBarViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                ReservoirView(viewModel: viewModel).frame(width: 60)
                CannulaAgeView(viewModel: viewModel).frame(width: 60)
                InsulinAgeView(viewModel: viewModel).frame(width: 60)
                BatteryAgeView(viewModel: viewModel).frame(width: 60)
                BluetoothConnectionView(viewModel: viewModel).frame(width: 60)
            }
        }
    }
}
