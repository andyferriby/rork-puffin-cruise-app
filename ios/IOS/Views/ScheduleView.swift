import SwiftUI

struct ScheduleView: View {
    @State private var schedule: ScheduleConfig?
    @State private var selectedDate: String?
    @State private var isLoading = true
    @State private var bookingCounts: [String: Int] = [:]

    private var days: [DaySchedule] { schedule?.days ?? [] }
    private var active: DaySchedule? {
        days.first { $0.date == (selectedDate ?? days.first?.date) }
    }

    private var cruisesById: [String: Cruise] {
        guard let cruises = schedule?.cruises else { return [:] }
        return Dictionary(uniqueKeysWithValues: cruises.map { ($0.id, $0) })
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            datePickerRow

            if isLoading {
                Spacer()
                ProgressView()
                    .tint(Theme.sea)
                Spacer()
            } else {
                scheduleContent
            }
        }
        .background(Theme.bg)
        .task { await loadSchedule() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sailings")
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(Theme.text)
            Text("Tide-dependent. Tap a time to book.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var datePickerRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(days) { day in
                    dateChip(day)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func dateChip(_ day: DaySchedule) -> some View {
        let isActive = (selectedDate ?? days.first?.date) == day.date
        let dt = parseDate(day.date)

        return Button {
            selectedDate = day.date
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
            .overlay(
                isActive ? nil : RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.border)
            )
        }
        .buttonStyle(.plain)
    }

    private var scheduleContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let active {
                    dayCard(active)
                }

                if let notice = schedule?.notice {
                    Text("⚓️ \(notice)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.deep)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.foam)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 32)
        }
    }

    private func dayCard(_ day: DaySchedule) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text(formatFullDate(day.date))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.text)
                Spacer()
                if let weather = day.weather {
                    HStack(spacing: 4) {
                        Image(systemName: "cloud")
                            .font(.system(size: 12))
                        Text(weather)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.sea)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.foam)
                    .clipShape(Capsule())
                }
            }

            VStack(spacing: 10) {
                ForEach(Array(day.times.enumerated()), id: \.offset) { idx, t in
                    NavigationLink(value: "book") {
                        timeRow(t, cruisesById[t.cruiseId], date: day.date)
                    }
                    .buttonStyle(.plain)
                }

                if day.times.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "water.waves")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.textMuted)
                        Text("No sailings this day")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .padding(.vertical, 32)
                }
            }
        }
        .padding(18)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.border))
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func timeRow(_ t: SailingTime, _ cruise: Cruise?, date: String) -> some View {
        let key = "\(date)|\(t.time)|\(t.cruiseId)"
        let booked = bookingCounts[key] ?? 0
        let capacity = cruise?.capacity ?? 30
        let spotsLeft = max(0, capacity - booked)
        let isFull = spotsLeft == 0

        return VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text(t.time)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(isFull ? Theme.textMuted : Theme.white)
                    .frame(width: 64)
                    .padding(.vertical, 10)
                    .background(isFull ? Theme.border : Theme.deep)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(cruise?.emoji ?? "") \(cruise?.name ?? t.cruiseId)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isFull ? Theme.textMuted : Theme.text)
                    if let duration = cruise?.duration {
                        Text(duration)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)
                    }
                    if let note = t.note {
                        Text(note)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.coral)
                    }
                }

                Spacer()

                if isFull {
                    Text("Full")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.coral)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.coral.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textMuted)
                }
            }

            if !isFull {
                spotsBar(booked: booked, capacity: capacity, spotsLeft: spotsLeft)
            }
        }
        .padding(12)
        .background(isFull ? Theme.white.opacity(0.5) : Theme.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func spotsBar(booked: Int, capacity: Int, spotsLeft: Int) -> some View {
        let fraction = CGFloat(booked) / CGFloat(max(1, capacity))
        let clamped = min(max(fraction, 0), 1)
        let barColor: Color = {
            if clamped > 0.8 { return Theme.coral }
            if clamped > 0.55 { return Theme.puffin }
            return Color(hex: "3A8C6E")
        }()

        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.border)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: max(6, geo.size.width * clamped), height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(spotsLeft) of \(capacity) spots left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(barColor)
                Spacer()
            }
        }
    }

    // MARK: - Helpers

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

    private func formatFullDate(_ dateStr: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: dateStr) else { return dateStr }
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: d)
    }
}

#Preview {
    ScheduleView()
}
