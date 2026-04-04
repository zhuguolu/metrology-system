import SwiftUI

struct DeviceEditView: View {
    let device: DeviceDto
    let screenTitle: String
    let onSave: (DeviceUpdatePayload) -> Void

    @EnvironmentObject private var appState: AppState
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
    @State private var activeDatePicker: DatePickerField?
    @State private var departmentLookupOptions: [String] = []
    @State private var useStatusLookupOptions: [String] = []

    private enum DatePickerField: String, Identifiable {
        case calDate
        case purchaseDate

        var id: String { rawValue }
    }

    init(
        device: DeviceDto,
        title: String = "编辑台账",
        onSave: @escaping (DeviceUpdatePayload) -> Void
    ) {
        self.device = device
        self.screenTitle = title
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

                        sectionCard(title: "必填信息") {
                            field("设备名称", text: $name)
                            field("计量编号", text: $metricNo)
                        }

                        sectionCard(title: "台账信息") {
                            field("资产编号", text: $assetNo)
                            field("出厂编号", text: $serialNo)
                            selectField("ABC分类", text: $abcClass, options: ["A", "B", "C"])
                            selectField("部门", text: $dept, options: departmentOptions)
                            field("设备位置", text: $location)
                            field("责任人", text: $responsiblePerson)
                            selectField("使用状态", text: $useStatus, options: useStatusOptions)
                        }

                        sectionCard(title: "校准信息") {
                            selectField("检定周期", text: $cycleText, options: ["半年", "一年", "两年", "24"])
                            dateField("上次校准日期", value: calDate) {
                                activeDatePicker = .calDate
                            }
                            selectField("校准结果", text: $calibrationResult, options: ["合格", "不合格"])
                        }

                        sectionCard(title: "扩展信息") {
                            field("制造厂", text: $manufacturer)
                            field("设备型号", text: $model)
                            dateField("采购日期", value: purchaseDate) {
                                activeDatePicker = .purchaseDate
                            }
                            field("采购价格", text: $purchasePriceText, keyboard: .decimalPad)
                            field("分度值", text: $graduationValue)
                            field("测试范围", text: $testRange)
                            field("允许误差", text: $allowableError)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("备注")
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
                            Button("取消") { dismiss() }
                                .buttonStyle(MetrologySecondaryButtonStyle())
                            Button("保存") { handleSave() }
                                .buttonStyle(MetrologyPrimaryButtonStyle())
                        }
                    }
                    .padding(12)
                    .padding(.bottom, 18)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(screenTitle)
        }
        .task {
            await refreshLookupOptions()
        }
        .sheet(item: $activeDatePicker) { field in
            DeviceEditDatePickerSheet(
                title: field == .calDate ? "上次校准日期" : "采购日期",
                initialDate: parsedDate(for: field) ?? Date(),
                onClear: {
                    setDateValue(nil, for: field)
                },
                onSelect: { date in
                    setDateValue(date, for: field)
                }
            )
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

    private func dateField(_ title: String, value: String, onTap: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)
            Button(action: onTap) {
                HStack(spacing: 6) {
                    Text(normalized(value).isEmpty ? "请选择日期" : value)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(normalized(value).isEmpty ? MetrologyPalette.textMuted : MetrologyPalette.textPrimary)
                    Spacer(minLength: 0)
                    Image(systemName: "calendar")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MetrologyPalette.textMuted)
                }
                .padding(.horizontal, 10)
                .frame(height: 38)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(MetrologyPalette.stroke, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func selectField(_ title: String, text: Binding<String>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        text.wrappedValue = option
                    }
                }
            } label: {
                MetrologySelectField(
                    title: title,
                    value: normalized(text.wrappedValue).isEmpty ? "请选择" : text.wrappedValue
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func handleSave() {
        validationMessage = nil

        let resolvedName = normalized(name)
        let resolvedMetricNo = normalized(metricNo)
        if resolvedName.isEmpty || resolvedMetricNo.isEmpty {
            validationMessage = "设备名称和计量编号不能为空"
            return
        }

        let resolvedPurchasePrice: Double?
        let trimmedPrice = normalized(purchasePriceText)
        if trimmedPrice.isEmpty {
            resolvedPurchasePrice = nil
        } else if let value = Double(trimmedPrice) {
            resolvedPurchasePrice = value
        } else {
            validationMessage = "采购价格格式不正确"
            return
        }

        let parsedCycle = parseCycle(cycleText)
        if !normalized(cycleText).isEmpty && parsedCycle == nil {
            validationMessage = "检定周期仅支持半年、一年、两年或数字月份"
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

    private func parsedDate(for field: DatePickerField) -> Date? {
        let text: String
        switch field {
        case .calDate:
            text = calDate
        case .purchaseDate:
            text = purchaseDate
        }
        let trimmed = normalized(text)
        guard !trimmed.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: trimmed)
    }

    private func setDateValue(_ date: Date?, for field: DatePickerField) {
        let text = date.map(formatDate) ?? ""
        switch field {
        case .calDate:
            calDate = text
        case .purchaseDate:
            purchaseDate = text
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func parseCycle(_ text: String) -> Int? {
        let value = normalized(text)
        if value.isEmpty { return nil }
        if value == "半年" { return 6 }
        if value == "一年" { return 12 }
        if value == "两年" { return 24 }
        return Int(value)
    }

    private var departmentOptions: [String] {
        let sessionDepartments: [String] = appState.session?.departments ?? []
        return normalizedOptions(departmentLookupOptions + sessionDepartments + [dept])
    }

    private var useStatusOptions: [String] {
        let fallback = ["正常", "故障", "报废", "其他"]
        return normalizedOptions(useStatusLookupOptions + fallback + [useStatus])
    }

    @MainActor
    private func refreshLookupOptions() async {
        do {
            async let departmentsTask = APIClient.shared.departments(search: "")
            async let statusesTask = APIClient.shared.deviceStatuses()
            let departments = try await departmentsTask
            let statuses = try await statusesTask

            let departmentNames = departments
                .sorted { lhs, rhs in
                    let left = lhs.sortOrder ?? Int.max
                    let right = rhs.sortOrder ?? Int.max
                    if left != right { return left < right }
                    return (lhs.id ?? Int64.max) < (rhs.id ?? Int64.max)
                }
                .compactMap { $0.name?.trimmingCharacters(in: .whitespacesAndNewlines) }

            let statusNames = statuses
                .sorted { lhs, rhs in
                    let left = lhs.sortOrder ?? Int.max
                    let right = rhs.sortOrder ?? Int.max
                    if left != right { return left < right }
                    return (lhs.id ?? Int64.max) < (rhs.id ?? Int64.max)
                }
                .compactMap { $0.name?.trimmingCharacters(in: .whitespacesAndNewlines) }

            departmentLookupOptions = normalizedOptions(departmentNames + [dept])
            useStatusLookupOptions = normalizedOptions(statusNames + [useStatus])
        } catch {
            // Keep current values and fallback options when remote lookup fails.
            departmentLookupOptions = normalizedOptions(departmentLookupOptions + [dept])
            useStatusLookupOptions = normalizedOptions(useStatusLookupOptions + [useStatus])
        }
    }

    private func normalizedOptions(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in values {
            let value = normalized(raw)
            guard !value.isEmpty, !seen.contains(value) else { continue }
            seen.insert(value)
            result.append(value)
        }
        return result
    }

    private static func formatCycle(_ cycle: Int?) -> String {
        guard let cycle else { return "" }
        if cycle == 6 { return "半年" }
        if cycle == 12 { return "一年" }
        if cycle == 24 { return "两年" }
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

private struct DeviceEditDatePickerSheet: View {
    let title: String
    let initialDate: Date
    let onClear: () -> Void
    let onSelect: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date

    init(
        title: String,
        initialDate: Date,
        onClear: @escaping () -> Void,
        onSelect: @escaping (Date) -> Void
    ) {
        self.title = title
        self.initialDate = initialDate
        self.onClear = onClear
        self.onSelect = onSelect
        _selectedDate = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()

                HStack(spacing: 10) {
                    Button("清空") {
                        onClear()
                        dismiss()
                    }
                    .buttonStyle(MetrologySecondaryButtonStyle())

                    Button("确定") {
                        onSelect(selectedDate)
                        dismiss()
                    }
                    .buttonStyle(MetrologyPrimaryButtonStyle())
                }
            }
            .padding(14)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
