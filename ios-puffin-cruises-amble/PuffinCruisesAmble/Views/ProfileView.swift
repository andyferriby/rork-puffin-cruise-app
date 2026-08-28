import SwiftUI

private struct Tier {
    let name: String
    let emoji: String
    let minTrips: Int
    let colors: [Color]
    let benefits: [String]
}

struct ProfileView: View {
    @State private var email = ""
    @State private var bookings: [Booking] = []
    @State private var isLoading = false
    @State private var referralCode = ""
    @State private var showArrivalGuide = false

    private let referralKey = "puffin_referral_code"

    private let tiers: [Tier] = [
        Tier(name: "Bronze", emoji: "🥉", minTrips: 0, colors: [Color(hex: 0xCD7F32), Color(hex: 0x8B5521)],
             benefits: ["Access to Puffin Club", "Birthday treat on us"]),
        Tier(name: "Silver", emoji: "🥈", minTrips: 3, colors: [Color(hex: 0xB8C6D4), Color(hex: 0x6B7B8D)],
             benefits: ["5% off future bookings", "Priority boarding", "Free hot drink"]),
        Tier(name: "Gold", emoji: "🥇", minTrips: 6, colors: [Color(hex: 0xE8C84A), Color(hex: 0xA67C1E)],
             benefits: ["10% off future bookings", "Best seats", "Sunset sail invites"]),
        Tier(name: "Platinum", emoji: "💎", minTrips: 12, colors: [Color(hex: 0x9BAAEA), Color(hex: 0x4A5DB0)],
             benefits: ["15% off bookings", "VIP boarding", "Free guest pass twice a year"])
    ]

    private var completedTrips: Int {
        bookings.filter { booking in
            booking.status == "paid" || booking.status == "boarded"
                || (DateFormat.parseISODate(booking.cruise_date).map { $0 < Date() } ?? false)
        }.count
    }

    private var tier: Tier {
        tiers.reversed().first { completedTrips >= $0.minTrips } ?? tiers[0]
    }

    private var nextTier: Tier? {
        tiers.first { $0.minTrips > completedTrips }
    }

    private var progress: Double {
        guard let nextTier, nextTier.minTrips > 0 else { return 1 }
        return min(1, Double(completedTrips) / Double(nextTier.minTrips))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(Theme.text)
                    Text("Puffin Club rewards, referrals and arrival info.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textMuted)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

                lookupCard
                loyaltyCard
                benefitsCard
                actionsSection
                historyCard
            }
            .padding(.bottom, 36)
        }
        .background(Theme.bg)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .onAppear(perform: loadReferralCode)
        .sheet(isPresented: $showArrivalGuide) { ArrivalGuideView() }
    }

    private var lookupCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Load your rewards")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Theme.text)
            TextField("Email used for bookings", text: $email)
                .font(.system(size: 15))
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Theme.bg)
                .clipShape(.rect(cornerRadius: 14))
            Button {
                Task {
                    isLoading = true
                    bookings = await SupabaseService.fetchAllBookings(email: email)
                    isLoading = false
                }
            } label: {
                Group {
                    if isLoading { ProgressView().tint(.white) } else { Text("Load trips").font(.system(size: 15, weight: .black)) }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Theme.sea)
                .clipShape(.rect(cornerRadius: 14))
            }
        }
        .padding(16)
        .puffinCard(fill: .white)
        .padding(16)
    }

    private var loyaltyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(tier.emoji).font(.system(size: 42))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Puffin Club · \(tier.name)")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.white)
                    Text("\(completedTrips) trips · \(completedTrips * 100) points")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule().fill(.white)
                        .frame(width: max(20, geo.size.width * progress))
                }
            }
            .frame(height: 8)
            .padding(.top, 18)

            Text(nextTier.map { "\($0.minTrips - completedTrips) more trip\($0.minTrips - completedTrips == 1 ? "" : "s") to \($0.name)" } ?? "Top tier unlocked")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white.opacity(0.82))
                .padding(.top, 9)
        }
        .padding(20)
        .background(LinearGradient(colors: tier.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(.rect(cornerRadius: 22))
        .padding(.horizontal, 16)
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill").font(.system(size: 15)).foregroundStyle(Theme.puffin)
                Text("Your Benefits").font(.system(size: 18, weight: .black)).foregroundStyle(Theme.text)
            }
            .padding(.bottom, 10)

            ForEach(tier.benefits, id: \.self) { benefit in
                HStack(spacing: 10) {
                    Text("✓").font(.system(size: 17, weight: .black)).foregroundStyle(Theme.sea)
                    Text(benefit).font(.system(size: 15)).foregroundStyle(Theme.text)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .puffinCard(fill: .white)
        .padding(16)
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            ShareLink(item: "Book a Puffin Cruise from Amble and use my referral code \(referralCode) for rewards: https://puffincruisesamble.co.uk") {
                actionTile(icon: "square.and.arrow.up", title: "Refer a friend", sub: referralCode.isEmpty ? "Loading code…" : referralCode)
            }
            .buttonStyle(.plain)

            Button { showArrivalGuide = true } label: {
                actionTile(icon: "mappin.and.ellipse", title: "Arrival guide", sub: "Parking, check-in, what to bring")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    private func actionTile(icon: String, title: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(Theme.sea)
            Text(title).font(.system(size: 17, weight: .black)).foregroundStyle(Theme.text).padding(.top, 6)
            Text(sub).font(.system(size: 13)).foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.foam)
        .clipShape(.rect(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1) }
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill").font(.system(size: 15)).foregroundStyle(Theme.puffin)
                Text("Trip History").font(.system(size: 18, weight: .black)).foregroundStyle(Theme.text)
            }
            .padding(.bottom, 10)

            if bookings.isEmpty {
                Text("Load your email to see past and upcoming cruises.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textMuted)
                    .lineSpacing(4)
            } else {
                ForEach(bookings.prefix(6)) { booking in
                    HStack(spacing: 10) {
                        Image(systemName: "gift.fill").font(.system(size: 14)).foregroundStyle(Theme.sea)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(booking.cruise_name).font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.text)
                            Text(DateFormat.parseISODate(booking.cruise_date).map { DateFormat.numeric($0) } ?? booking.cruise_date)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textMuted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .puffinCard(fill: .white)
        .padding(16)
    }

    private func loadReferralCode() {
        if let saved = UserDefaults.standard.string(forKey: referralKey) {
            referralCode = saved
            return
        }
        let code = "PUFFIN-\(UUID().uuidString.prefix(6).uppercased())"
        UserDefaults.standard.set(code, forKey: referralKey)
        referralCode = code
    }
}
