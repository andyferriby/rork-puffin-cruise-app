import SwiftUI

struct HomeView: View {
    @Environment(ScheduleStore.self) private var schedule
    @Environment(AppSettings.self) private var settings
    @State private var adminTapCount = 0
    @State private var lastTapAt = Date.distantPast
    @State private var showBooking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    todayCard
                        .padding(.horizontal, 16)
                        .offset(y: -16)

                    Text("Our Cruises")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(Theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 12)

                    VStack(spacing: 12) {
                        ForEach(schedule.cruises) { cruise in
                            NavigationLink(value: cruise.id) {
                                cruiseCard(cruise)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)

                    ctaRow.padding(.top, 24)

                    coastSecretsCard.padding(.top, 20)

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
                            .padding(.top, 20)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Theme.bg)
            .ignoresSafeArea(edges: .top)
            .navigationDestination(for: String.self) { value in
                if value == "coast-secrets" {
                    CoastSecretsView()
                } else {
                    BookView()
                }
            }
            .refreshable { await schedule.load(force: true) }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Theme.deep, Theme.sea, Theme.wave],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Theme.sand.opacity(0.35))
                .frame(width: 140, height: 140)
                .offset(x: 150, y: -40)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "tv").font(.system(size: 11, weight: .semibold))
                    Text("As seen on Robson Green's Weekend Escapes")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.15))
                .clipShape(.capsule)
                .overlay { Capsule().stroke(.white.opacity(0.25), lineWidth: 1) }
                .padding(.bottom, 16)

                Text("Dave Gray's\nPuffin Cruises")
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineSpacing(2)
                    .onTapGesture { registerAdminTap() }

                Text("Family-run wildlife adventures around Coquet Island for over 40 years.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineSpacing(4)
                    .frame(maxWidth: 320, alignment: .leading)
                    .padding(.top, 12)

                HStack(spacing: 8) {
                    metaPill(icon: "mappin.and.ellipse", text: "Amble Harbour")
                    metaPill(icon: "star.fill", text: "40+ years", iconColor: Theme.sand)
                }
                .padding(.top, 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 70)
            .padding(.bottom, 48)
        }
        .clipped()
    }

    private func metaPill(icon: String, text: String, iconColor: Color = .white) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(iconColor)
            Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.12))
        .clipShape(.capsule)
    }

    // MARK: - Today

    @ViewBuilder
    private var todayCard: some View {
        if let today = schedule.today {
            NavigationLink(value: "schedule") {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TODAY'S SAILINGS")
                                .font(.system(size: 11, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(Theme.sea)
                            Text(DateFormat.longDay(today.parsedDate))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Theme.text)
                        }
                        Spacer()
                        Image(systemName: "calendar")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.sea)
                    }

                    Text(today.weather ?? "Tide-dependent schedule")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textMuted)
                        .padding(.top, 6)

                    HStack(spacing: 8) {
                        ForEach(today.times.prefix(5)) { slot in
                            Text(slot.time)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.sea)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Theme.foam)
                                .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                    .padding(.top, 14)

                    Text("See full schedule →")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.sea)
                        .padding(.top, 14)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card)
                .clipShape(.rect(cornerRadius: 20))
                .shadow(color: Theme.deep.opacity(0.12), radius: 16, x: 0, y: 8)
            }
            .buttonStyle(.plain)
        }
    }

    private func cruiseCard(_ cruise: Cruise) -> some View {
        HStack(spacing: 14) {
            Text(cruise.emoji)
                .font(.system(size: 32))
                .frame(width: 60, height: 60)
                .background(Theme.foam)
                .clipShape(.rect(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text(cruise.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.text)
                Text("\(cruise.duration) · From £\(cruise.childPrice.priceText) child / £\(cruise.adultPrice.priceText) adult")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.sea)
                Text(cruise.description)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(2)
                    .lineSpacing(2)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .puffinCard(radius: 18, fill: .white)
    }

    private var ctaRow: some View {
        HStack(spacing: 10) {
            NavigationLink(value: "book") {
                HStack(spacing: 8) {
                    Image(systemName: "ferry.fill")
                    Text("Book a Cruise").font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.sea)
                .clipShape(.rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            Button {
                let phone = schedule.config.contactPhone.replacingOccurrences(of: " ", with: "")
                if let url = URL(string: "tel:\(phone)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "phone.fill")
                    Text("Call").font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(Theme.sea)
                .padding(.vertical, 16)
                .padding(.horizontal, 22)
                .background(.white)
                .clipShape(.rect(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).stroke(Theme.sea, lineWidth: 1.5) }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Coast Secrets

    private var coastSecretsCard: some View {
        NavigationLink(value: "coast-secrets") {
            HStack(spacing: 14) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.sandDeep)
                    .frame(width: 52, height: 52)
                    .background(Theme.sand.opacity(0.5))
                    .clipShape(.rect(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 2) {
                    Text("COAST SECRETS")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(Theme.sandDeep)
                    Text("Only in Amble")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text("Tide-aware tips for the shore — and tonight's golden hour photo spot")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .puffinCard(radius: 18, fill: .white)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    /// Three quick taps on the hero title opens the crew admin tools.
    private func registerAdminTap() {
        let now = Date()
        if now.timeIntervalSince(lastTapAt) > 1.2 { adminTapCount = 0 }
        lastTapAt = now
        adminTapCount += 1
        if adminTapCount >= 3 {
            adminTapCount = 0
            settings.showAdmin = true
        }
    }
}

extension Double {
    /// "18" for whole numbers, "17.5" otherwise — matches the RN price formatting.
    var priceText: String {
        self == rounded() ? String(Int(self)) : String(format: "%.2f", self)
    }
}
