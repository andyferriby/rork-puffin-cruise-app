import SwiftUI

struct ScheduleView: View {
    /// Standalone (tab) mode wraps its own NavigationStack and hides the bar;
    /// embedded (pushed from Home) reuses the host stack so Back stays visible.
    var showsOwnNavigation = true

    @Environment(ScheduleStore.self) private var schedule
    @State private var selectedDate: String?

    private var activeDay: DaySchedule? {
        schedule.days.first { $0.date == selectedDate } ?? schedule.days.first
    }

    var body: some View {
        if showsOwnNavigation {
            NavigationStack {
                content
            }
        } else {
            content
                .navigationTitle("Sailings")
        }
    }

    private var content: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sailings")
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundStyle(Theme.text)
                        Text("Tide-dependent. Tap a time to book.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    if schedule.isLoading && schedule.days.isEmpty {
                        ProgressView().tint(Theme.sea)
                            .frame(maxWidth: .infinity)
                            .padding(40)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(schedule.days) { day in
                                dayChip(day)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .contentMargins(.horizontal, 16, for: .scrollContent)

                    if let day = activeDay {
                        dayCard(day).padding(.horizontal, 16).padding(.top, 12)
                    }

                    if let notice = schedule.config.notice, !notice.isEmpty {
                        Text("⚓️ \(notice)")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.deep)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Theme.foam)
                            .clipShape(.rect(cornerRadius: 12))
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Theme.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(showsOwnNavigation ? .hidden : .visible, for: .navigationBar)
            .refreshable { await schedule.load(force: true) }
    }

    private func dayChip(_ day: DaySchedule) -> some View {
        let isActive = (selectedDate ?? schedule.days.first?.date) == day.date
        let date = day.parsedDate
        return Button {
            selectedDate = day.date
        } label: {
            VStack(spacing: 2) {
                Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(isActive ? .white : Theme.textMuted)
                Text(date.formatted(.dateTime.day()))
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(isActive ? .white : Theme.text)
                Text(date.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isActive ? .white : Theme.textMuted)
            }
            .frame(width: 64)
            .padding(.vertical, 12)
            .background(isActive ? Theme.sea : .white)
            .clipShape(.rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isActive ? Theme.sea : Theme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func dayCard(_ day: DaySchedule) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(DateFormat.longDay(day.parsedDate))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.text)
                Spacer()
                if let weather = day.weather, !weather.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "cloud.sun.fill").font(.system(size: 11))
                        Text(weather).font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.sea)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.foam)
                    .clipShape(.capsule)
                }
            }

            VStack(spacing: 10) {
                if day.times.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "water.waves")
                            .font(.system(size: 26))
                            .foregroundStyle(Theme.textMuted)
                        Text("No sailings this day")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .padding(32)
                } else {
                    ForEach(Array(day.times.enumerated()), id: \.offset) { _, slot in
                        NavigationLink { BookView() } label: {
                            timeRow(slot)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 16)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .puffinCard()
    }

    private func timeRow(_ slot: SailingTime) -> some View {
        let cruise = schedule.cruise(id: slot.cruiseId)
        return HStack(spacing: 12) {
            Text(slot.time)
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 64)
                .padding(.vertical, 10)
                .background(Theme.deep)
                .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(cruise?.emoji ?? "") \(cruise?.name ?? slot.cruiseId)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.text)
                if let duration = cruise?.duration {
                    Text(duration).font(.system(size: 12)).foregroundStyle(Theme.textMuted)
                }
                if let note = slot.note, !note.isEmpty {
                    Text(note).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.coral)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(12)
        .contentShape(.rect)
    }
}
