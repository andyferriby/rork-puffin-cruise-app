import SwiftUI

struct AdminView: View {
    private static let adminPin = "1107"

    @State private var authenticated = false
    @State private var pinInput = ""
    @State private var pinError: String?

    var body: some View {
        Group {
            if authenticated {
                AdminEditorView(onLogout: { authenticated = false })
            } else {
                pinEntryView
            }
        }
    }

    private var pinEntryView: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.sea)
                        .frame(width: 56, height: 56)
                        .background(Theme.foam)
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                    Text("Admin Access")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(Theme.text)

                    Text("Enter your admin PIN.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textMuted)
                }
                .padding(.top, 8)

                // PIN dots
                HStack(spacing: 14) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i < pinInput.count ? Theme.sea : Theme.border)
                            .frame(width: 16, height: 16)
                    }
                }
                .padding(.vertical, 4)

                if let error = pinError {
                    Text(error)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                }

                // Custom number pad
                VStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 10) {
                            ForEach(1..<4, id: \.self) { col in
                                let digit = row * 3 + col
                                pinButton("\(digit)")
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        pinButton("", systemImage: "xmark", isClear: true)
                        pinButton("0")
                        pinButton("", systemImage: "delete.left", isDelete: true)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg)
    }

    private func pinButton(_ digit: String, systemImage: String? = nil, isClear: Bool = false, isDelete: Bool = false) -> some View {
        Button {
            handlePinTap(digit: digit, isClear: isClear, isDelete: isDelete)
        } label: {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .semibold))
                } else {
                    Text(digit)
                        .font(.system(size: 26, weight: .bold))
                }
            }
            .foregroundStyle(Theme.text)
            .frame(width: 70, height: 70)
            .background(Theme.card)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func handlePinTap(digit: String, isClear: Bool, isDelete: Bool) {
        if isClear {
            pinInput = ""
            pinError = nil
            return
        }
        if isDelete {
            if !pinInput.isEmpty { pinInput.removeLast() }
            pinError = nil
            return
        }
        guard pinInput.count < 4 else { return }
        pinInput += digit
        pinError = nil
        if pinInput.count == 4 {
            handlePinSubmit()
        }
    }

    private func handlePinSubmit() {
        if pinInput == Self.adminPin {
            authenticated = true
            pinInput = ""
            pinError = nil
        } else {
            pinError = "Wrong PIN. Try again."
            pinInput = ""
        }
    }
}

// MARK: - Editor

struct AdminEditorView: View {
    let onLogout: () -> Void

    @State private var config: ScheduleConfig?
    @State private var isLoading = true
    @State private var hasChanges = false
    @State private var saving = false
    @State private var notifying = false
    @State private var showScanner = false
    @State private var saveError: String?
    @State private var saveSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            if isLoading {
                Spacer()
                ProgressView().tint(Theme.sea)
                Spacer()
            } else if let config {
                editorContent(config)
            }
        }
        .background(Theme.bg)
        .task { await loadConfig() }
        .fullScreenCover(isPresented: $showScanner) {
            AdminScannerView()
        }
        .alert("Save failed", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
        .overlay(alignment: .top) {
            if saveSuccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Schedule saved")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.sea)
                .clipShape(Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: saveSuccess)
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Schedule Editor")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(Theme.text)
                Text("Changes are live on save.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer()
            Button {
                showScanner = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 14, weight: .heavy))
                    Text("Scan")
                        .font(.system(size: 13, weight: .heavy))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.sea)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Button(action: onLogout) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.coral)
                    .padding(10)
                    .background(Theme.foam)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private func editorContent(_ config: ScheduleConfig) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    metaFields
                    cruiseEditor
                    daysEditor
                }
                .padding(.bottom, 100)
            }

            footerBar
        }
    }

    // MARK: - Meta Fields

    private var metaFields: some View {
        VStack(spacing: 10) {
            sectionTitle("Notice")
            TextField("e.g. Sailings subject to weather conditions", text: bindingConfigOpt(\ .notice))
                .fieldStyle()

            sectionTitle("Contact Phone")
            TextField("07752 861914", text: bindingConfigStr(\ .contactPhone))
                .fieldStyle()
                .keyboardType(.phonePad)

            sectionTitle("Booking Office")
            TextField("Amble Harbour Village", text: bindingConfigStr(\ .bookingOffice))
                .fieldStyle()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Cruise Editor

    private var cruiseEditor: some View {
        VStack(spacing: 0) {
            sectionTitle("Cruise Types")
                .padding(.horizontal, 16)

            VStack(spacing: 10) {
                ForEach(Array((config?.cruises ?? []).enumerated()), id: \.offset) { idx, cruise in
                    cruiseCard(idx: idx, cruise: cruise)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func cruiseCard(idx: Int, cruise: Cruise) -> some View {
        VStack(spacing: 8) {
            TextField("Cruise name", text: bindingCruise(idx, \.name))
                .inlineFieldStyle()
            HStack(spacing: 8) {
                TextField("🐧", text: bindingCruise(idx, \.emoji))
                    .inlineFieldStyle()
                    .frame(width: 52)
                    .multilineTextAlignment(.center)
                TextField("Duration", text: bindingCruise(idx, \.duration))
                    .inlineFieldStyle()
            }
            HStack(spacing: 8) {
                VStack(spacing: 4) {
                    Text("Adult £").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.textMuted)
                    TextField("0", text: bindingCruiseInt(idx, \.adultPrice))
                        .inlineFieldStyle()
                        .keyboardType(.numberPad)
                }
                VStack(spacing: 4) {
                    Text("Child £").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.textMuted)
                    TextField("0", text: bindingCruiseInt(idx, \.childPrice))
                        .inlineFieldStyle()
                        .keyboardType(.numberPad)
                }
                VStack(spacing: 4) {
                    Text("Capacity").font(.system(size: 10, weight: .semibold)).foregroundStyle(Theme.textMuted)
                    TextField("0", text: bindingCruiseInt(idx, \.capacity))
                        .inlineFieldStyle()
                        .keyboardType(.numberPad)
                }
            }
            TextField("Short description", text: bindingCruise(idx, \.description), axis: .vertical)
                .inlineFieldStyle()
                .lineLimit(2...4)
        }
        .padding(12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.border))
    }

    // MARK: - Days Editor

    private var daysEditor: some View {
        VStack(spacing: 0) {
            sectionTitle("Sailing Days")
                .padding(.horizontal, 16)

            VStack(spacing: 10) {
                ForEach(Array((config?.days ?? []).enumerated()), id: \.offset) { dayIdx, day in
                    dayCard(dayIdx: dayIdx, day: day)
                }

                Button {
                    addDay()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                        Text("Add day")
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.sea)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Theme.sea, style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    )
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func dayCard(dayIdx: Int, day: DaySchedule) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("YYYY-MM-DD", text: bindingDay(dayIdx, \.date))
                    .inlineFieldStyle()
                TextField("Weather", text: bindingDayOpt(dayIdx, \.weather))
                    .inlineFieldStyle()
                    .frame(width: 140)
                Button {
                    removeDay(dayIdx)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.coral)
                }
            }

            ForEach(Array(day.times.enumerated()), id: \.offset) { timeIdx, t in
                HStack(spacing: 6) {
                    TextField("HH:MM", text: bindingTime(dayIdx, timeIdx, \.time))
                        .inlineFieldStyle()
                        .frame(width: 80)
                    VStack(spacing: 4) {
                        TextField("Cruise ID", text: bindingTime(dayIdx, timeIdx, \.cruiseId))
                            .inlineFieldStyle()
                        let cruiseIDs = config?.cruises ?? []
                        let idsStr = cruiseIDs.map { c in "\(c.emoji)\(c.id)" }.joined(separator: ", ")
                        Text("IDs: \(idsStr)")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textMuted)
                    }
                    TextField("Note", text: bindingTimeOpt(dayIdx, timeIdx, \.note))
                        .inlineFieldStyle()
                        .frame(width: 80)
                    Button {
                        removeTime(dayIdx: dayIdx, timeIdx: timeIdx)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.coral)
                    }
                }
            }

            Button {
                addTime(dayIdx)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13))
                    Text("Add time")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Theme.sea)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Theme.sea, style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                )
            }
        }
        .padding(12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.border))
        .padding(.horizontal, 16)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 10) {
            Button {
                sendNotification()
            } label: {
                HStack(spacing: 8) {
                    if notifying {
                        ProgressView().tint(Theme.sea)
                    } else {
                        Image(systemName: "bell")
                    }
                    Text(notifying ? "Sending..." : "Notify")
                        .fontWeight(.bold)
                }
                .font(.system(size: 14))
                .foregroundStyle(Theme.sea)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Theme.foam)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.sea, lineWidth: 1.5))
            }
            .disabled(notifying)

            Button {
                saveConfig()
            } label: {
                HStack(spacing: 8) {
                    if saving {
                        ProgressView().tint(Theme.white)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text(saving ? "Saving..." : "Save Schedule")
                        .font(.system(size: 15, weight: .heavy))
                }
                .foregroundStyle(Theme.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(hasChanges && !saving ? Theme.sea : Theme.sea.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!hasChanges || saving)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Theme.white)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Theme.border), alignment: .top)
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.sea)
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 0)
    }

    private func loadConfig() async {
        config = await SupabaseService.shared.fetchSchedule()
        isLoading = false
    }

    private func saveConfig() {
        guard let config else { return }
        saving = true
        Task {
            do {
                try await SupabaseService.shared.saveSchedule(config)
                hasChanges = false
                saveSuccess = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    saveSuccess = false
                }
            } catch {
                print("[admin] save error:", error)
                saveError = error.localizedDescription
            }
            saving = false
        }
    }

    private func sendNotification() {
        notifying = true
        Task {
            do {
                try await APIService.shared.sendNotification(
                    title: "New sailing times posted! 🐧",
                    body: "Check the app for the latest Puffin Cruises schedule."
                )
            } catch {
                print("[admin] notify error:", error)
            }
            notifying = false
        }
    }

    // MARK: - Bindings (String)

    private func bindingConfigStr(_ keyPath: WritableKeyPath<ScheduleConfig, String>) -> Binding<String> {
        Binding(
            get: { config?[keyPath: keyPath] ?? "" },
            set: { newVal in
                guard var c = config else { return }
                c[keyPath: keyPath] = newVal
                config = c
                hasChanges = true
            }
        )
    }

    private func bindingConfigOpt(_ keyPath: WritableKeyPath<ScheduleConfig, String?>) -> Binding<String> {
        Binding(
            get: { config?[keyPath: keyPath] ?? "" },
            set: { newVal in
                guard var c = config else { return }
                c[keyPath: keyPath] = newVal.isEmpty ? nil : newVal
                config = c
                hasChanges = true
            }
        )
    }

    private func bindingCruise(_ idx: Int, _ keyPath: WritableKeyPath<Cruise, String>) -> Binding<String> {
        Binding(
            get: { config?.cruises[idx][keyPath: keyPath] ?? "" },
            set: { newVal in
                guard var c = config else { return }
                c.cruises[idx][keyPath: keyPath] = newVal
                config = c
                hasChanges = true
            }
        )
    }

    private func bindingCruiseInt(_ idx: Int, _ keyPath: WritableKeyPath<Cruise, Int>) -> Binding<String> {
        Binding(
            get: { String(config?.cruises[idx][keyPath: keyPath] ?? 0) },
            set: { newVal in
                guard var c = config else { return }
                c.cruises[idx][keyPath: keyPath] = Int(newVal) ?? 0
                config = c
                hasChanges = true
            }
        )
    }

    private func bindingDay(_ idx: Int, _ keyPath: WritableKeyPath<DaySchedule, String>) -> Binding<String> {
        Binding(
            get: { config?.days[idx][keyPath: keyPath] ?? "" },
            set: { newVal in
                guard var c = config else { return }
                c.days[idx][keyPath: keyPath] = newVal
                config = c
                hasChanges = true
            }
        )
    }

    private func bindingDayOpt(_ idx: Int, _ keyPath: WritableKeyPath<DaySchedule, String?>) -> Binding<String> {
        Binding(
            get: { config?.days[idx][keyPath: keyPath] ?? "" },
            set: { newVal in
                guard var c = config else { return }
                c.days[idx][keyPath: keyPath] = newVal.isEmpty ? nil : newVal
                config = c
                hasChanges = true
            }
        )
    }

    private func bindingTime(_ dayIdx: Int, _ timeIdx: Int, _ keyPath: WritableKeyPath<SailingTime, String>) -> Binding<String> {
        Binding(
            get: { config?.days[dayIdx].times[timeIdx][keyPath: keyPath] ?? "" },
            set: { newVal in
                guard var c = config else { return }
                c.days[dayIdx].times[timeIdx][keyPath: keyPath] = newVal
                config = c
                hasChanges = true
            }
        )
    }

    private func bindingTimeOpt(_ dayIdx: Int, _ timeIdx: Int, _ keyPath: WritableKeyPath<SailingTime, String?>) -> Binding<String> {
        Binding(
            get: { config?.days[dayIdx].times[timeIdx][keyPath: keyPath] ?? "" },
            set: { newVal in
                guard var c = config else { return }
                c.days[dayIdx].times[timeIdx][keyPath: keyPath] = newVal.isEmpty ? nil : newVal
                config = c
                hasChanges = true
            }
        )
    }

    private func addDay() {
        guard var c = config else { return }
        let lastDate = c.days.last?.date
        let next: String
        if let last = lastDate {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            if let d = f.date(from: last) {
                next = f.string(from: d.addingTimeInterval(86400))
            } else {
                next = f.string(from: Date())
            }
        } else {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            next = f.string(from: Date())
        }
        c.days.append(DaySchedule(date: next, times: []))
        config = c
        hasChanges = true
    }

    private func removeDay(_ idx: Int) {
        guard var c = config else { return }
        c.days.remove(at: idx)
        config = c
        hasChanges = true
    }

    private func addTime(_ dayIdx: Int) {
        guard var c = config else { return }
        let defaultCruiseId = c.cruises.first?.id ?? ""
        c.days[dayIdx].times.append(SailingTime(time: "10:00", cruiseId: defaultCruiseId))
        config = c
        hasChanges = true
    }

    private func removeTime(dayIdx: Int, timeIdx: Int) {
        guard var c = config else { return }
        c.days[dayIdx].times.remove(at: timeIdx)
        config = c
        hasChanges = true
    }
}

// MARK: - Field Styles

extension View {
    func fieldStyle() -> some View {
        self
            .font(.system(size: 15))
            .padding(12)
            .background(Theme.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.border))
    }

    func inlineFieldStyle() -> some View {
        self
            .font(.system(size: 14))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Theme.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border))
    }
}

#Preview {
    AdminView()
}
