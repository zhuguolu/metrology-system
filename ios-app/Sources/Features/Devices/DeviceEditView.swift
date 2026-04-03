import SwiftUI

struct DeviceEditView: View {
    let device: DeviceDto
    let onSave: (DeviceUpdatePayload) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var validationMessage: String?

    @State private var name: String
    @State private var metricNo: String
    @State private var assetNo: String
    @State private var serialNo: String
    @State private var abcClass: String
    @State private var dept: String
    @State private var location: String
    @State private var responsiblePerson: String
    @State private var useStatus: String
    @State private var manufacturer: String
    @State private var model: String
    @State private var purchaseDate: String
    @State private var purchasePriceText: String
    @State private var graduationValue: String
    @State private var testRange: String
    @State private var allowableError: String
    @State private var cycleText: String
    @State private var calDate: String
    @State private var calibrationResult: String
    @State private var remark: String

    init(device: DeviceDto, onSave: @escaping (DeviceUpdatePayload) -> Void) {
        self.device = device
        self.onSave = onSave

        _name = State(initialValue: device.name ?? "")
        _metricNo = State(initialValue: device.metricNo ?? "")
        _assetNo = State(initialValue: device.assetNo ?? "")
        _serialNo = State(initialValue: device.serialNo ?? "")
        _abcClass = State(initialValue: device.abcClass ?? "")
        _dept = State(initialValue: device.dept ?? "")
        _location = State(initialValue: device.location ?? "")
        _responsiblePerson = State(initialValue: device.responsiblePerson ?? "")
        _useStatus = State(initialValue: device.useStatus ?? "")
        _manufacturer = State(initialValue: device.manufacturer ?? "")
        _model = State(initialValue: device.model ?? "")
        _purchaseDate = State(initialValue: device.purchaseDate ?? "")
        _purchasePriceText = State(initialValue: Self.formatPrice(device.purchasePrice))
        _graduationValue = State(initialValue: device.graduationValue ?? "")
        _testRange = State(initialValue: device.testRange ?? "")
        _allowableError = State(initialValue: device.allowableError ?? "")
        _cycleText = State(initialValue: Self.formatCycle(device.cycle))
        _calDate = State(initialValue: device.calDate ?? "")
        _calibrationResult = State(initialValue: device.calibrationResult ?? "")
        _remark = State(initialValue: device.remark ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MetrologyPalette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        if let validationMessage {
                            Text(validationMessage)
                                .font(.footnote)
                                .foregroundStyle(MetrologyPalette.statusExpired)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 2)
                        }

                        sectionCard(title: "\u{5fc5}\u{586b}\u{4fe1}\u{606f}") {
                            field("\u{8bbe}\u{5907}\u{540d}\u{79f0}", text: $name)
                            field("\u{8ba1}\u{91cf}\u{7f16}\u{53f7}", text: $metricNo)
                        }

                        sectionCard(title: "\u{53f0}\u{8d26}\u{4fe1}\u{606f}") {
                            field("\u{8d44}\u{4ea7}\u{7f16}\u{53f7}", text: $assetNo)
                            field("\u{51fa}\u{5382}\u{7f16}\u{53f7}", text: $serialNo)
                            field("\u{41}\u{42}\u{43}\u{5206}\u{7c7b}", text: $abcClass)
                            field("\u{90e8}\u{95e8}", text: $dept)
                            field("\u{8bbe}\u{5907}\u{4f4d}\u{7f6e}", text: $location)
                            field("\u{8d23}\u{4efb}\u{4eba}", text: $responsiblePerson)
                            field("\u{4f7f}\u{7528}\u{72b6}\u{6001}", text: $useStatus)
                        }

                        sectionCard(title: "\u{6821}\u{51c6}\u{4fe1}\u{606f}") {
                            field("\u{68c0}\u{5b9a}\u{5468}\u{671f}\u{ff08}\u{534a}\u{5e74}\u{2f}\u{4e00}\u{5e74}\u{2f}\u{6570}\u{5b57}\u{ff09}", text: $cycleText, keyboard: .numbersAndPunctuation)
                            field("\u{4e0a}\u{6b21}\u{6821}\u{51c6}\u{65e5}\u{671f}\u{ff08}\u{59}\u{59}\u{59}\u{59}\u{2d}\u{4d}\u{4d}\u{2d}\u{44}\u{44}\u{ff09}", text: $calDate)
                            field("\u{6821}\u{51c6}\u{7ed3}\u{679c}", text: $calibrationResult)
                        }

                        sectionCard(title: "\u{6269}\u{5c55}\u{4fe1}\u{606f}") {
                            field("\u{5236}\u{9020}\u{5382}", text: $manufacturer)
                            field("\u{8bbe}\u{5907}\u{578b}\u{53f7}", text: $model)
                            field("\u{91c7}\u{8d2d}\u{65e5}\u{671f}\u{ff08}\u{59}\u{59}\u{59}\u{59}\u{2d}\u{4d}\u{4d}\u{2d}\u{44}\u{44}\u{ff09}", text: $purchaseDate)
                            field("\u{91c7}\u{8d2d}\u{4ef7}\u{683c}", text: $purchasePriceText, keyboard: .decimalPad)
                            field("\u{5206}\u{5ea6}\u{503c}", text: $graduationValue)
                            field("\u{6d4b}\u{8bd5}\u{8303}\u{56f4}", text: $testRange)
                            field("\u{5141}\u{8bb8}\u{8bef}\u{5dee}", text: $allowableError)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("\u{5907}\u{6ce8}")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(MetrologyPalette.textPrimary)
                                TextEditor(text: $remark)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(MetrologyPalette.textPrimary)
                                    .frame(minHeight: 90)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.white)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(MetrologyPalette.stroke, lineWidth: 1)
                                    )
                            }
                        }

                        HStack(spacing: 10) {
                            Button("\u{53d6}\u{6d88}") { dismiss() }
                                .buttonStyle(MetrologySecondaryButtonStyle())
                            Button("\u{4fdd}\u{5b58}") { handleSave() }
                                .buttonStyle(MetrologyPrimaryButtonStyle())
                        }
                    }
                    .padding(12)
                    .padding(.bottom, 18)
                }
            }
            .navigationTitle("\u{7f16}\u{8f91}\u{53f0}\u{8d26}")
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)
            content()
        }
        .padding(10)
        .metrologyCard()
    }

    private func field(_ title: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)
            TextField(title, text: text)
                .keyboardType(keyboard)
                .metrologyInput()
        }
    }

    private func handleSave() {
        validationMessage = nil

        let resolvedName = normalized(name)
        let resolvedMetricNo = normalized(metricNo)
        if resolvedName.isEmpty || resolvedMetricNo.isEmpty {
            validationMessage = "\u{8bbe}\u{5907}\u{540d}\u{79f0}\u{548c}\u{8ba1}\u{91cf}\u{7f16}\u{53f7}\u{4e0d}\u{80fd}\u{4e3a}\u{7a7a}"
            return
        }

        let resolvedPurchasePrice: Double?
        let trimmedPrice = normalized(purchasePriceText)
        if trimmedPrice.isEmpty {
            resolvedPurchasePrice = nil
        } else if let value = Double(trimmedPrice) {
            resolvedPurchasePrice = value
        } else {
            validationMessage = "\u{91c7}\u{8d2d}\u{4ef7}\u{683c}\u{683c}\u{5f0f}\u{4e0d}\u{6b63}\u{786e}"
            return
        }

        let parsedCycle = parseCycle(cycleText)
        if !normalized(cycleText).isEmpty && parsedCycle == nil {
            validationMessage = "\u{68c0}\u{5b9a}\u{5468}\u{671f}\u{4ec5}\u{652f}\u{6301}\u{534a}\u{5e74}\u{3001}\u{4e00}\u{5e74}\u{6216}\u{6570}\u{5b57}\u{6708}\u{4efd}"
            return
        }

        let payload = DeviceUpdatePayload(
            name: resolvedName,
            metricNo: resolvedMetricNo,
            assetNo: normalized(assetNo),
            abcClass: normalized(abcClass),
            dept: normalized(dept),
            location: normalized(location),
            cycle: parsedCycle ?? device.cycle ?? 12,
            calDate: normalized(calDate),
            status: device.status,
            remark: normalized(remark),
            useStatus: normalized(useStatus),
            serialNo: normalized(serialNo),
            purchasePrice: resolvedPurchasePrice,
            purchaseDate: normalized(purchaseDate),
            calibrationResult: normalized(calibrationResult),
            responsiblePerson: normalized(responsiblePerson),
            manufacturer: normalized(manufacturer),
            model: normalized(model),
            graduationValue: normalized(graduationValue),
            testRange: normalized(testRange),
            allowableError: normalized(allowableError)
        )

        onSave(payload)
        dismiss()
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseCycle(_ text: String) -> Int? {
        let value = normalized(text)
        if value.isEmpty { return nil }
        if value == "\u{534a}\u{5e74}" { return 6 }
        if value == "\u{4e00}\u{5e74}" { return 12 }
        return Int(value)
    }

    private static func formatCycle(_ cycle: Int?) -> String {
        guard let cycle else { return "" }
        if cycle == 6 { return "\u{534a}\u{5e74}" }
        if cycle == 12 { return "\u{4e00}\u{5e74}" }
        return String(cycle)
    }

    private static func formatPrice(_ value: Double?) -> String {
        guard let value else { return "" }
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(value)
    }
}
