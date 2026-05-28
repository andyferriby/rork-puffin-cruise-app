import SwiftUI

// MARK: - Loyalty Tier

private enum LoyaltyTier: CaseIterable {
    case bronze, silver, gold, platinum

    var name: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        }
    }

    var emoji: String {
        switch self {
        case .bronze: return "🥉"
        case .silver: return "🥈"
        case .gold: return "🥇"
        case .platinum: return "💎"
        }
    }

    var minTrips: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 3
        case .gold: return 6
        case .platinum: return 12
        }
    }

    var color: Color {
        switch self {
        case .bronze: return Color(hex: "CD7F32")
        case .silver: return Color(hex: "A8B4C2")
        case .gold: return Color(hex: "D4A843")
        case .platinum: return Color(hex: "7B8CDE")
        }
    }

    var gradient: [Color] {
        switch self {
        case .bronze: return [Color(hex: "CD7F32"), Color(hex: "8B5521")]
        case .silver: return [Color(hex: "B8C6D4"), Color(hex: "6B7B8D")]
        case .gold: return [Color(hex: "E8C84A"), Color(hex: "A67C1E")]
        case .platinum: return [Color(hex: "9BAAEA"), Color(hex: "4A5DB0")]
        }
    }

    var benefits: [String] {
        switch self {
        case .bronze:
            return ["Access to loyalty rewards", "Birthday treat on us"]
        case .silver:
            return ["5% off future bookings", "Priority boarding", "Free hot drink on board", "Birthday treat"]
        case .gold:
            return ["10% off future bookings", "Priority boarding + best seats", "Free drink & snack on board", "Exclusive sunset sail invites", "Birthday treat"]
        case .platinum:
            return ["15% off future bookings", "VIP priority boarding", "Complimentary drinks on board", "Free guest pass (2 per year)", "Exclusive sunset sail invites", "Behind-the-scenes island tour", "Birthday treat"]
        }
    }
}

// MARK: - Main View

struct ProfileView: View {
    @State private var bookings: [Booking] = []
    @State private var isLoading = true
    @State private var referralCode: String = ""
    @State private var referralCount: Int = 0
    @State private var showArrivalGuide = false
    @State private var showReferralShare = false

    private let referralCodeKey = "referral_code"
    private let referralCountKey = "referral_count"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard

                    if isLoading {
                        loadingState
                    } else {
                        loyaltyCard
                        perksCard
                        quickLinks
                        bookingsHistory
                    }
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadData() }
            .sheet(isPresented: $showArrivalGuide) {
                ArrivalGuideView()
            }
            .sheet(isPresented: $showReferralShare) {
                referralShareSheet
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.sea, Theme.wave],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)

                Text("🐧")
                    .font(.system(size: 28))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome aboard!")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)

                if let email = BookingsStore.shared.savedEmail {
                    Text(email)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Theme.textMuted)
                } else {
                    Text("Sign in to unlock rewards")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Theme.textMuted)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Theme.card)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: Theme.border, radius: 4, y: 2)
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Theme.sea)
            Text("Loading your profile...")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Loyalty Card

    private var loyaltyCard: some View {
        let tier = computedTier
        let trips = completedTrips
        let points = totalPoints
        let nextTier = nextTierInfo

        return VStack(spacing: 0) {
            // Tier badge
            HStack(spacing: 12) {
                Text(tier.emoji)
                    .font(.system(size: 40))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Puffin Club · \(tier.name)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.white)
                    Text("\(trips) trip\(trips == 1 ? "" : "s") · \(points) points")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.white.opacity(0.8))
                }

                Spacer()
            }

            // Progress bar
            if let next = nextTier {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(next.remaining) more trip\(next.remaining == 1 ? "" : "s") to reach \(next.tier.name)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.white.opacity(0.7))
                        Spacer()
                        Text("\(Int(next.progress * 100))%")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.white.opacity(0.9))
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.white.opacity(0.2))
                                .frame(height: 6)

                            Capsule()
                                .fill(Theme.white)
                                .frame(width: max(6, geo.size.width * next.progress), height: 6)
                                .animation(.spring(duration: 0.8), value: next.progress)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: tier.gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: tier.color.opacity(0.35), radius: 8, y: 4)
    }

    // MARK: - Perks

    private var perksCard: some View {
        let tier = computedTier
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.puffin)
                Text("Your \(tier.name) Benefits")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
            }

            VStack(spacing: 0) {
                ForEach(Array(tier.benefits.enumerated()), id: \.offset) { index, benefit in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.sea)

                        Text(benefit)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(Theme.text)

                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)

                    if index < tier.benefits.count - 1 {
                        Divider().padding(.leading, 32)
                    }
                }
            }
        }
        .padding(20)
        .background(Theme.card)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: Theme.border, radius: 4, y: 2)
    }

    // MARK: - Quick Links

    private var quickLinks: some View {
        VStack(spacing: 10) {
            quickLinkRow(
                icon: "gift.fill",
                color: Theme.coral,
                title: "Refer a Friend",
                subtitle: "Share Puffin Cruises and earn £5 credit each",
                badge: referralCount > 0 ? "\(referralCount) sent" : nil,
                action: { showReferralShare = true }
            )

            quickLinkRow(
                icon: "suitcase.fill",
                color: Theme.puffin,
                title: "Arrival Guide",
                subtitle: "Parking, what to bring, and what to expect",
                action: { showArrivalGuide = true }
            )
        }
        .padding(20)
        .background(Theme.card)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: Theme.border, radius: 4, y: 2)
    }

    private func quickLinkRow(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        badge: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(color)
                    .frame(width: 40, height: 40)
                    .background(color.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Theme.textMuted)
                }

                Spacer()

                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.coral.opacity(0.1))
                        .clipShape(.capsule)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textMuted.opacity(0.5))
            }
        }
    }

    // MARK: - Bookings History

    private var bookingsHistory: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.sea)
                Text("Past Bookings")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
            }

            if completedBookings.isEmpty {
                Text("No past bookings yet. Book your first cruise to start earning rewards!")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(completedBookings.enumerated()), id: \.element.id) { index, booking in
                        pastBookingRow(booking, isLast: index == completedBookings.count - 1)
                    }
                }
            }
        }
        .padding(20)
        .background(Theme.card)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: Theme.border, radius: 4, y: 2)
    }

    private func pastBookingRow(_ booking: Booking, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(formattedDay(booking.cruiseDate))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.sea)
                Text(formattedMonth(booking.cruiseDate))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            .frame(width: 44, height: 44)
            .background(Theme.sea.opacity(0.08))
            .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(booking.cruiseName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text("\(booking.cruiseTime) · \(booking.passengerSummary)")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Theme.textMuted)
            }

            Spacer()

            Text("£\(String(format: "%.2f", booking.totalPounds))")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.text)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .overlay(alignment: .bottom) {
            if !isLast {
                Divider().padding(.leading, 60)
            }
        }
    }

    // MARK: - Referral Share Sheet

    private var referralShareSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 32)

                Text("🎁")
                    .font(.system(size: 64))
                    .padding(.bottom, 16)

                Text("Refer a Friend")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)

                Text("Share your unique code. When a friend books using it, you both get £5 off your next cruise.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                // Referral code card
                HStack(spacing: 12) {
                    Text(referralCode)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.white)

                    Button {
                        UIPasteboard.general.string = referralCode
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Theme.sea, Theme.wave],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(.rect(cornerRadius: 14))
                .padding(.top, 24)
                .padding(.horizontal, 24)

                Text(referralCount > 0 ? "\(referralCount) friend\(referralCount == 1 ? "" : "s") joined with your code" : "Share your code to start earning")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, 10)

                // Share button
                Button {
                    let message = "🚤 Join me on a Puffin Cruise from Amble Harbour! Use my referral code \(referralCode) and we both get £5 off. Book at puffincruises.co.uk"
                    let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let root = windowScene.windows.first?.rootViewController {
                        root.present(activityVC, animated: true)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Your Code")
                    }
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.coral)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer()
            }
            .background(Theme.bg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showReferralShare = false }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        // Load bookings
        if let email = BookingsStore.shared.savedEmail {
            bookings = await SupabaseService.shared.fetchBookings(byEmail: email)
        }

        // Load referral code
        if let existing = UserDefaults.standard.string(forKey: referralCodeKey) {
            referralCode = existing
        } else {
            let prefix = (BookingsStore.shared.savedEmail ?? "PUFFIN")
                .components(separatedBy: "@").first?
                .prefix(6)
                .uppercased() ?? "PUFFIN"
            let suffix = String((0..<4).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! })
            referralCode = "\(prefix)-\(suffix)"
            UserDefaults.standard.set(referralCode, forKey: referralCodeKey)
        }

        referralCount = UserDefaults.standard.integer(forKey: referralCountKey)
    }

    // MARK: - Computed Properties

    private var completedBookings: [Booking] {
        bookings.filter { $0.isPaid }
    }

    private var completedTrips: Int {
        completedBookings.count
    }

    private var totalPoints: Int {
        Int(completedBookings.reduce(0) { $0 + $1.totalPounds * 10 })
    }

    private var computedTier: LoyaltyTier {
        let trips = completedTrips
        for tier in LoyaltyTier.allCases.reversed() {
            if trips >= tier.minTrips { return tier }
        }
        return .bronze
    }

    private var nextTierInfo: (tier: LoyaltyTier, remaining: Int, progress: Double)? {
        let trips = completedTrips
        let allTiers = LoyaltyTier.allCases
        for i in 0..<(allTiers.count - 1) {
            if trips < allTiers[i + 1].minTrips {
                let needed = allTiers[i + 1].minTrips
                let currentMin = allTiers[i].minTrips
                let progress = Double(trips - currentMin) / Double(needed - currentMin)
                return (allTiers[i + 1], needed - trips, max(0, min(1, progress)))
            }
        }
        return nil
    }

    // MARK: - Helpers

    private func formattedDay(_ dateStr: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: dateStr) else { return "??" }
        fmt.dateFormat = "d"
        return fmt.string(from: date)
    }

    private func formattedMonth(_ dateStr: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: dateStr) else { return "???" }
        fmt.dateFormat = "MMM"
        return fmt.string(from: date)
    }
}

#Preview {
    ProfileView()
}
