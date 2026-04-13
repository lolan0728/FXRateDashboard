import SwiftUI

public struct CompactWidgetView: View {
    @ObservedObject private var viewModel: MainWidgetViewModel

    public init(viewModel: MainWidgetViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            WidgetTopBarView(viewModel: viewModel)
            WidgetValueSectionView(viewModel: viewModel)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
