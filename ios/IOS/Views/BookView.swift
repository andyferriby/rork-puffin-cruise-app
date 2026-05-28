import SwiftUI

struct BookView: View {
    @State private var schedule: ScheduleConfig?
    @State private var isLoading = true

    @State private var selectedCruise: Cruise?
    @State private var selectedDate: String?
    @State private var selectedTime: SailingTime?
    @State private var adults = 2
    @State private var children = 0
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var submitting = false
    @State private var errorMessage: String?
    @State private var bookingCounts: [String: Int] = [:]

    private var availableTimes: [SailingTime] {
        guard let date = selectedDate, let day = schedule?.days.first(where: { $0.date == date }) else { return [] }
        if let cruise = selectedCruise {
            return day.times.filter { $0.cruiseId == cruise.id }
        }
        return day.times
    }

    private var totalPounds: Int {
        guard let cruise = selectedCruise else { return 0 }
        return adults * cruise.adultPrice + children * cruise.childPrice
    }

    private var canSubmit: Bool {
        selectedCruise != nil && selectedDate != nil && selectedTime != nil
            && (adults + children) > 0 && name.trimmingCharacters(in: .whitespaces).count > 1
            && email.contains("@") && email.contains(".")
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    stepCruise
                    stepDate
                    stepTime
                    stepPassengers
                    stepContact
                }
                .padding(.bottom, 120)
            }

            footerBar
        }
        .background(Theme.bg)
        .task { await loadSchedule() }
        .alert("Booking error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Book a Cruise")
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(Theme.text)
            Text("Secure payment by Stripe")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Step Helpers

    private func stepLabel(_ num: Int, _ label: String) -> some View {
        HStack(spacing: 10) {
            Text("\(num)")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(Theme.white)
                .frame(width: 22, height: 22)
                .background(Theme.sea)
                .clipShape(Circle())
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Step 1: Cruise

    private var stepCruise: some View {
        VStack(spacing: 0) {
            stepLabel(1, "Choose a cruise")
            VStack(spacing: 10) {
                ForEach(schedule?.cruises ?? ScheduleConfig.default.cruises) { cruise in
                    Button {
                        selectedCruise = cruise
                        selectedTime = nil
                    } label: {
                        HStack(spacing: 14) {
                            Text(cruise.emoji)
                                .font(.system(size: 28))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cruise.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Theme.text)
                                Text("\(cruise.duration) · £\(cruise.adultPrice) adult / £\(cruise.childPrice) child")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textMuted)
                            }
                            Spacer()
                            if cruise.id == selectedCruise?.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Theme.sea)
                            }
                        }
                        .padding(14)
                        .background(cruise.id == selectedCruise?.id ? Theme.foam : Theme.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(cruise.id == selectedCruise?.id ? Theme.sea : Theme.border, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Step 2: Date

    private var stepDate: some View {
        VStack(spacing: 0) {
            stepLabel(2, "Pick a date")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(schedule?.days ?? []) { day in
                        dateChip(day)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func dateChip(_ day: DaySchedule) -> some View {
        let dt = parseDate(day.date)
        let isActive = day.date == selectedDate

        return Button {
            selectedDate = day.date
            selectedTime = nil
        } label: {
            VStack(spacing: 2) {
                Text(weekdayShort(dt).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                Text("\(Calendar.current.component(.day, from: dt))")
                    .font(.system(size: 22, weight: .heavy))
                Text(monthShort(dt))
                    .font(.system(size: 11, weight: .semibold))
            }
            .frame(width: 64)
            .padding(.vertical, 12)
            .foregroundStyle(isActive ? Theme.white : Theme.text)
            .background(isActive ? Theme.sea : Theme.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(isActive ? nil : RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.border))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 3: Time

    private var stepTime: some View {
        VStack(spacing: 0) {
            stepLabel(3, "Choose a sailing time")

            if selectedDate != nil {
                if availableTimes.isEmpty {
                    Text("No sailings match that combination.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textMuted)
                        .padding(.horizontal, 20)
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(availableTimes.enumerated()), id: \.offset) { _, t in
                            timeChip(t)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            } else {
                Text("Pick a date to see times.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Step 4: Passengers

    private var stepPassengers: some View {
        VStack(spacing: 0) {
            stepLabel(4, "Passengers")

            VStack(spacing: 0) {
                passengerRow(label: "Adults", sub: selectedCruise.map { "£\($0.adultPrice) each" } ?? "", value: $adults, min: 0)
                Divider().padding(.horizontal, 14)
                passengerRow(label: "Children", sub: selectedCruise.map { "£\($0.childPrice) each (under 16)" } ?? "", value: $children, min: 0)
            }
            .background(Theme.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.border))
            .padding(.horizontal, 16)
        }
    }

    private func passengerRow(label: String, sub: String, value: Binding<Int>, min: Int) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.text)
                if !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                }
            }
            Spacer()
            Button {
                if value.wrappedValue > min { value.wrappedValue -= 1 }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.sea)
                    .frame(width: 32, height: 32)
                    .background(Theme.foam)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text("\(value.wrappedValue)")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Theme.text)
                .frame(minWidth: 24)

            Button {
                value.wrappedValue += 1
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.sea)
                    .frame(width: 32, height: 32)
                    .background(Theme.foam)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }

    // MARK: - Step 5: Contact

    private var stepContact: some View {
        VStack(spacing: 0) {
            stepLabel(5, "Your details")

            VStack(spacing: 10) {
                textField(icon: "person", placeholder: "Full name", text: $name, capitalize: true)
                textField(icon: "envelope", placeholder: "Email", text: $email, keyboard: .emailAddress)
                textField(icon: "phone", placeholder: "Phone (optional)", text: $phone, keyboard: .phonePad)
            }
            .padding(.horizontal, 16)
        }
    }

    private func textField(icon: String, placeholder: String, text: Binding<String>,
                           keyboard: UIKeyboardType = .default, capitalize: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .autocapitalization(capitalize ? .words : .none)
                .keyboardType(keyboard)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.border))
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("TOTAL")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.textMuted)
                    .tracking(0.5)
                Text("£\(totalPounds).00")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Theme.text)
            }

            Spacer()

            Button {
                submit()
            } label: {
                HStack(spacing: 8) {
                    if submitting {
                        ProgressView()
                            .tint(Theme.white)
                    } else {
                        Image(systemName: "creditcard")
                        Text("Pay & Book")
                            .font(.system(size: 15, weight: .heavy))
                    }
                }
                .foregroundStyle(Theme.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(canSubmit && !submitting ? Theme.sea : Theme.sea.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canSubmit || submitting)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Theme.white)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Theme.border), alignment: .top)
    }

    // MARK: - Actions

    private func submit() {
        guard canSubmit, let cruise = selectedCruise, let date = selectedDate, let time = selectedTime else { return }
        submitting = true
        Task {
            do {
                let result = try await APIService.shared.createCheckout(CreateCheckoutBody(
                    cruiseId: cruise.id,
                    cruiseName: cruise.name,
                    date: date,
                    time: time.time,
                    adults: adults,
                    children: children,
                    customerName: name.trimmingCharacters(in: .whitespaces),
                    customerEmail: email.trimmingCharacters(in: .whitespaces),
                    customerPhone: phone.trimmingCharacters(in: .whitespaces)
                ))
                BookingsStore.shared.add(result.bookingId)
                BookingsStore.shared.savedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
                if let url = URL(string: result.url) {
                    await UIApplication.shared.open(url)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            submitting = false
        }
    }

    private func loadSchedule() async {
        schedule = await SupabaseService.shared.fetchSchedule()
        await refreshBookingCounts()
        isLoading = false
    }

    private func refreshBookingCounts() async {
        guard let sched = schedule else { return }
        var sailings: [(String, String, String)] = []
        for day in sched.days {
            for t in day.times {
                sailings.append((day.date, t.time, t.cruiseId))
            }
        }
        bookingCounts = await SupabaseService.shared.fetchBookingCounts(for: sailings)
    }

    private func timeChip(_ t: SailingTime) -> some View {
        let cruise = schedule?.cruises.first(where: { $0.id == t.cruiseId })
        let date = selectedDate ?? ""
        let key = "\(date)|\(t.time)|\(t.cruiseId)"
        let booked = bookingCounts[key] ?? 0
        let capacity = cruise?.capacity ?? 30
        let spotsLeft = max(0, capacity - booked)
        let isFull = spotsLeft == 0
        let isSelected = selectedTime?.time == t.time && selectedTime?.cruiseId == t.cruiseId

        let barColor: Color = {
            let fraction = CGFloat(booked) / CGFloat(max(1, capacity))
            if fraction > 0.8 { return Theme.coral }
            if fraction > 0.55 { return Theme.puffin }
            return Color(hex: "3A8C6E")
        }()

        return Button {
            guard !isFull else { return }
            selectedTime = t
            if let c = cruise { selectedCruise = c }
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 13))
                    Text(t.time)
                        .font(.system(size: 14, weight: .bold))

                    if isFull {
                        Text("FULL")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Theme.coral)
                            .tracking(0.6)
                    }
                }
                .foregroundStyle(isSelected ? Theme.white : (isFull ? Theme.textMuted : Theme.sea))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSelected ? Theme.sea : (isFull ? Theme.foam : Theme.white))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    isSelected ? nil : RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isFull ? Theme.border : Theme.border, lineWidth: 1.5)
                )

                if !isFull && booked > 0 {
                    VStack(spacing: 3) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Theme.border)
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(barColor)
                                    .frame(width: max(4, geo.size.width * CGFloat(booked) / CGFloat(max(1, capacity))), height: 4)
                            }
                        }
                        .frame(height: 4)

                        Text("\(spotsLeft) of \(capacity) spots left")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(barColor)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(isFull)
    }

    private func parseDate(_ str: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: str) ?? Date()
    }

    private func weekdayShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    private func monthShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date)
    }
}

#Preview {
    BookView()
}
