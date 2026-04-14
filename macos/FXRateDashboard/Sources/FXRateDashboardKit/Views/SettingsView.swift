import SwiftUI

public struct SettingsView: View {
    private static let windowSize = CGSize(width: 392, height: 474)

    @ObservedObject private var viewModel: SettingsViewModel
    private let onSave: () async -> String?
    private let onClose: () -> Void
    @FocusState private var focusedField: Field?

    @State private var validationMessage = ""
    @State private var isSaving = false
    @State private var isCloseHovered = false

    private enum Field {
        case token
    }

    private let windowCornerRadius: CGFloat = 30

    public init(
        viewModel: SettingsViewModel,
        onSave: @escaping () async -> String?,
        onClose: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onSave = onSave
        self.onClose = onClose
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                ColorPalette.settingsWindowBackground
                    .ignoresSafeArea()

                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(ColorPalette.settingsWindowBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(ColorPalette.settingsWindowBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 24, x: 0, y: 10)

                VStack(spacing: 14) {
                    ZStack {
                        Text("Settings")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(ColorPalette.settingsPrimaryText)

                        HStack {
                            Button {
                                onClose()
                            } label: {
                                Circle()
                                    .fill(Color(hex: 0xFF5F57))
                                    .frame(width: 14, height: 14)
                                    .overlay {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundStyle(Color.black.opacity(0.45))
                                            .opacity(isCloseHovered ? 0.78 : 0)
                                    }
                            }
                            .buttonStyle(.plain)
                            .onHover { isHovering in
                                isCloseHovered = isHovering
                            }

                            Spacer()
                        }
                    }
                    .padding(.top, 2)

                    VStack(spacing: 8) {
                        settingsCard(title: "Currency Pair", subtitle: "Choose the Wise source and target currencies.") {
                            HStack(spacing: 10) {
                                settingsTextField("Base", text: $viewModel.baseCurrency)
                                settingsTextField("Quote", text: $viewModel.quoteCurrency)
                            }
                        }

                        settingsCard(title: "Base Amount", subtitle: "Scales the headline value and chart.") {
                            settingsTextField("Amount", text: $viewModel.baseAmountText)
                        }

                        settingsCard(title: "Refresh Interval", subtitle: "Current rate polling interval in seconds.") {
                            settingsTextField("Seconds", text: $viewModel.refreshSecondsText)
                        }

                        settingsCard(title: "Wise API Token", subtitle: viewModel.tokenHelpText) {
                            HStack(spacing: 8) {
                                settingsTextField("Paste token", text: $viewModel.apiTokenText)
                                    .focused($focusedField, equals: .token)

                                if focusedField == .token && !viewModel.apiTokenText.isEmpty {
                                    Button {
                                        viewModel.apiTokenText = ""
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .frame(width: 18, height: 18)
                                            .background(Color(hex: 0xE6EBF1), in: Circle())
                                            .foregroundStyle(Color(hex: 0x6F7D8E))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if !validationMessage.isEmpty {
                        Text(validationMessage)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(ColorPalette.validationText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(ColorPalette.validationBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(ColorPalette.validationBorder, lineWidth: 1)
                                    )
                            )
                    }

                    HStack(spacing: 10) {
                        Spacer()

                        Button("Cancel") {
                            onClose()
                        }
                        .buttonStyle(SettingsSecondaryButtonStyle())

                        Button(isSaving ? "Saving..." : "Save") {
                            validationMessage = ""
                            isSaving = true

                            Task {
                                let result = await onSave()
                                await MainActor.run {
                                    isSaving = false
                                    if let result {
                                        validationMessage = result
                                    } else {
                                        onClose()
                                    }
                                }
                            }
                        }
                        .buttonStyle(SettingsPrimaryButtonStyle())
                        .disabled(isSaving)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 6)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .clipShape(RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous))
        }
        .frame(width: Self.windowSize.width, height: Self.windowSize.height)
        .ignoresSafeArea(.container)
    }

    private func settingsCard<Content: View>(title: String, subtitle: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(ColorPalette.settingsPrimaryText)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(ColorPalette.settingsMutedText)
                }
            }

            content()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ColorPalette.settingsCardTop, ColorPalette.settingsCardBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(ColorPalette.settingsCardBorder, lineWidth: 1)
                )
        )
    }

    private func settingsTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(ColorPalette.settingsPrimaryText)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ColorPalette.settingsInputBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(ColorPalette.settingsInputBorder, lineWidth: 1)
                    )
            )
    }
}

private struct SettingsSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(ColorPalette.settingsPrimaryText)
            .frame(width: 102, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: 0xF7FAFC).opacity(configuration.isPressed ? 0.82 : 1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(hex: 0xD8E1EA), lineWidth: 1)
                    )
            )
    }
}

private struct SettingsPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 102, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x62D255), Color(hex: 0x49B73F)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(configuration.isPressed ? 0.84 : 1)
            )
    }
}
