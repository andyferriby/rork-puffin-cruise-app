import SwiftUI

/// Crew editor for the sailing schedule — notice, contact details, cruise
/// types and each day's sailing times. Saves to Supabase `app_config` under
/// `schedule`, the same key the Expo app reads.
struct ScheduleAdminSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ScheduleStore.self) private var schedule

    @State private var config: ScheduleConfig = .fallback
    @State private var isSaving = false
    @State private var error: String?
    @State private var editingCruise: Cruise?
    @State private var showNewCruise = false
    @State private var newDayDate = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    @State private var timeDrafts: [String: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                noticeSection
                cruisesSection
                daysSection

                Section {
                    Button { Task { await persist() } } label: {
                        HStack {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text("Save Schedule").font(.system(size: 16, weight: .black))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Theme.sea)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .disabled(isSaving)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    if let error {
                        Text(error)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.coral)
                    }
                }
            }
            .navigationTitle("Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                if !schedule.hasLoaded { await schedule.load() }
                config = schedule.config
            }
            .sheet(item: $editingCruise) { cruise in
                CruiseFormSheet(cruise: cruise) { updated in
                    replace(cruise: updated)
                }
            }
            .sheet(isPresented: $showNewCruise) {
                CruiseFormSheet(cruise: nil) { cruise in
                    config.cruises.append(cruise)
                }
            }
        }
    }

    // MARK: - Sections

    private var noticeSection: some View {
        Section("Notice & Contact") {
            TextField("Notice shown on Home (e.g. tide warning)", text: Binding(
                get: { config.notice ?? "" },
                set: { config.notice = $0.isEmpty ? nil : $0 }
            ), axis: .vertical)
            .lineLimit(2...4)

            TextField("Contact phone", text: $config.contactPhone)
                .keyboardType(.phonePad)
            TextField("Booking office", text: $config.bookingOffice)
        }
    }

    private var cruisesSection: some View {
        Section {
            ForEach(config.cruises) { cruise in
                Button { editingCruise = cruise } label: {
                    HStack(spacing: 10) {
                        Text(cruise.emoji).font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(cruise.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.text)
                            Text("£\(cruise.adultPrice.priceText) adult · £\(cruise.childPrice.priceText) child · \(cruise.capacity) max")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }
            Button {
                showNewCruise = true
            } label: {
                Label("Add Cruise Type", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.sea)
            }
        } header: {
            Text("Cruise Types")
        } footer: {
            Text("Cruises appear in the app, the booking flow and the sailing time pickers below.")
        }
    }

    private var daysSection: some View {
        Section {
            ForEach(config.days) { day in
                DisclosureGroup {
                    TextField("Weather note (e.g. Sunny, light breeze)", text: Binding(
                        get: { day.weather ?? "" },
                        set: { newValue in
                            setDay(day) { updated in
                                updated.weather = newValue.isEmpty ? nil : newValue
                            }
                        }
                    ))

                    ForEach(Array(day.times.enumerated()), id: \.offset) { index, slot in
                        sailingTimeRow(day: day, index: index, slot: slot)
                    }

                    addTimeRow(day)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(DateFormat.longDay(day.parsedDate))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.text)
                            Text(day.times.isEmpty ? "No sailings" : "\(day.times.count) sailing\(day.times.count == 1 ? "" : "s")")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textMuted)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            config.days.removeAll { $0.date == day.date }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.coral)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            HStack {
                DatePicker("Add day", selection: $newDayDate, displayedComponents: .date)
                    .font(.system(size: 14))
                Button("Add") { addDay() }
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Theme.sea)
            }
        } header: {
            Text("Sailing Days")
        } footer: {
            Text("Days appear in the app in the order listed — put today first. Times use 24-hour format, e.g. 14:30.")
        }
    }

    private func sailingTimeRow(day: DaySchedule, index: Int, slot: SailingTime) -> some View {
        HStack(spacing: 8) {
            TextField("14:30", text: Binding(
                get: { timeDrafts["\(day.date)#\(slot.id)"] ?? slot.time },
                set: { timeDrafts["\(day.date)#\(slot.id)"] = $0 }
            ))
            .keyboardType(.numbersAndPunctuation)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .frame(width: 74)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Theme.bg)
            .clipShape(.rect(cornerRadius: 8))

            Menu {
                ForEach(config.cruises) { cruise in
                    Button("\(cruise.emoji) \(cruise.name)") {
                        setDay(day) { days in
                            days.times[index].cruiseId = cruise.id
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(schedule.cruise(id: slot.cruiseId)?.name ?? slot.cruiseId)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.sea)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textMuted)
                }
            }

            Spacer()

            Button(role: .destructive) {
                setDay(day) { updated in
                    updated.times.remove(at: index)
                }
                timeDrafts["\(day.date)#\(slot.id)"] = nil
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.coral)
            }
            .buttonStyle(.borderless)
        }
    }

    private func addTimeRow(_ day: DaySchedule) -> some View {
        HStack(spacing: 8) {
            TextField("14:30", text: Binding(
                get: { timeDrafts["new-\(day.date)"] ?? "" },
                set: { timeDrafts["new-\(day.date)"] = $0 }
            ))
            .keyboardType(.numbersAndPunctuation)
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .frame(width: 74)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Theme.bg)
            .clipShape(.rect(cornerRadius: 8))

            Button {
                addTime(to: day)
            } label: {
                Label("Add sailing", systemImage: "plus.circle.fill")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Theme.sea)
            }
            Spacer()
        }
    }

    // MARK: - Mutations

    private func setDay(_ day: DaySchedule, mutate: (inout DaySchedule) -> Void) {
        guard let index = config.days.firstIndex(where: { $0.date == day.date }) else { return }
        mutate(&config.days[index])
    }

    private func addDay() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.string(from: newDayDate)
        guard !config.days.contains(where: { $0.date == date }) else { return }
        config.days.append(DaySchedule(date: date, weather: nil, times: []))
    }

    private func addTime(to day: DaySchedule) {
        let draft = (timeDrafts["new-\(day.date)"] ?? "")
            .trimmingCharacters(in: .whitespaces)
        guard Self.isValidTime(draft), let cruise = config.cruises.first else {
            error = "Enter a time in 24-hour format, e.g. 14:30."
            return
        }
        error = nil
        timeDrafts["new-\(day.date)"] = nil
        setDay(day) { updated in
            updated.times.append(SailingTime(time: draft, cruiseId: cruise.id, note: nil))
        }
    }

    private func replace(cruise: Cruise) {
        if let index = config.cruises.firstIndex(where: { $0.id == cruise.id }) {
            config.cruises[index] = cruise
        }
    }

    private static func isValidTime(_ value: String) -> Bool {
        let parts = value.split(separator: ":")
        guard parts.count == 2, let hours = Int(parts[0]), let minutes = Int(parts[1]),
              (1...24).contains(hours), (0...59).contains(minutes) else { return false }
        return true
    }

    // MARK: - Persistence

    private func persist() async {
        // Apply any pending time-draft edits before saving.
        for day in config.days {
            for slot in day.times {
                let key = "\(day.date)#\(slot.id)"
                if let draft = timeDrafts[key]?.trimmingCharacters(in: .whitespaces),
                   draft != slot.time, Self.isValidTime(draft) {
                    setDay(day) { updated in
                        if let index = updated.times.firstIndex(where: { $0.id == slot.id }) {
                            updated.times[index].time = draft
                        }
                    }
                }
            }
        }

        guard !config.days.isEmpty, !config.cruises.isEmpty else {
            error = "Add at least one cruise type and one sailing day."
            return
        }

        isSaving = true
        error = nil
        defer { isSaving = false }
        config.version += 1
        do {
            try await SupabaseService.saveSchedule(config)
            schedule.config = config
            schedule.hasLoaded = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            self.error = "Couldn't save the schedule. Check your connection and try again."
        }
    }
}

/// Add / edit form for a cruise type. Calls back with the saved cruise;
/// the parent sheet owns persistence.
private struct CruiseFormSheet: View {
    @Environment(\.dismiss) private var dismiss

    let cruise: Cruise?
    let onSave: (Cruise) -> Void

    @State private var name = ""
    @State private var emoji = "🐧"
    @State private var duration = "1 hour"
    @State private var descriptionText = ""
    @State private var adultPriceText = ""
    @State private var childPriceText = ""
    @State private var capacityText = ""
    @State private var validationError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Name (e.g. 1 Hour Puffin Cruise)", text: $name)
                    TextField("Emoji (e.g. 🐧)", text: $emoji)
                    TextField("Duration (e.g. 1 hour)", text: $duration)
                    TextField("Description", text: $descriptionText, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Pricing & Capacity") {
                    TextField("Adult price (£)", text: $adultPriceText)
                        .keyboardType(.decimalPad)
                    TextField("Child price (£)", text: $childPriceText)
                        .keyboardType(.decimalPad)
                    TextField("Max passengers", text: $capacityText)
                        .keyboardType(.numberPad)
                }

                if let validationError {
                    Text(validationError)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                }
            }
            .navigationTitle(cruise == nil ? "New Cruise" : "Edit Cruise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(.system(size: 16, weight: .bold))
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: populate)
        }
    }

    private func populate() {
        guard let cruise else { return }
        name = cruise.name
        emoji = cruise.emoji
        duration = cruise.duration
        descriptionText = cruise.description
        adultPriceText = cruise.adultPrice == cruise.adultPrice.rounded()
            ? String(Int(cruise.adultPrice)) : String(cruise.adultPrice)
        childPriceText = cruise.childPrice == cruise.childPrice.rounded()
            ? String(Int(cruise.childPrice)) : String(cruise.childPrice)
        capacityText = String(cruise.capacity)
    }

    private func save() {
        guard let adultPrice = Double(adultPriceText), adultPrice >= 0,
              let childPrice = Double(childPriceText), childPrice >= 0 else {
            validationError = "Adult and child prices must be numbers, e.g. 18 or 17.50."
            return
        }
        guard let capacity = Int(capacityText), capacity > 0 else {
            validationError = "Max passengers must be a whole number above 0."
            return
        }
        let saved = Cruise(
            id: cruise?.id ?? "cruise-\(UUID().uuidString.lowercased().prefix(8))",
            name: name.trimmingCharacters(in: .whitespaces),
            duration: duration.trimmingCharacters(in: .whitespaces),
            description: descriptionText.trimmingCharacters(in: .whitespaces),
            adultPrice: adultPrice,
            childPrice: childPrice,
            capacity: capacity,
            emoji: emoji.trimmingCharacters(in: .whitespaces).isEmpty ? "⛵️" : emoji.trimmingCharacters(in: .whitespaces)
        )
        onSave(saved)
        dismiss()
    }
}
