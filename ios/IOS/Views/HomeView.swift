import SwiftUI

struct HomeView: View {
    @State private var schedule: ScheduleConfig?
    @State private var isLoading = true
    @State private var cruiseRatings: [String: CruiseRating] = [:]
    @State private var recentPhotos: [GalleryPhoto] = []
    @State private var showAllPhotos = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                todaySailings
                cruiseTypes
                guestPhotosSection
                ctaButtons
                noticeSection
            }
        }
        .background(Theme.bg)
        .scrollIndicators(.hidden)
        .task { await loadAll() }
        .sheet(isPresented: $showAllPhotos) {
            GalleryView()
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Theme.deep, Theme.sea, Theme.wave],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Theme.sand.opacity(0.35))
                .frame(width: 140, height: 140)
                .offset(x: 100, y: -60)

            // Wave decorations
            VStack(spacing: 0) {
                Spacer()
                waveShape(opacity: 0.25, offset: 0)
                waveShape(opacity: 0.4, offset: 6)
            }

            VStack(alignment: .leading, spacing: 12) {
                badge
                Text("Dave Gray's\nPuffin Cruises")
                    .font(.system(size: 38, weight: .heavy))
                    .foregroundStyle(Theme.white)
                    .lineSpacing(4)
                Text("Family-run wildlife adventures around Coquet Island for over 40 years.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.white.opacity(0.85))
                    .lineSpacing(6)
                    .frame(maxWidth: 320, alignment: .leading)

                HStack(spacing: 8) {
                    metaPill(icon: "mappin.and.ellipse", text: "Amble Harbour")
                    metaPill(icon: "star.fill", text: "40+ years", color: Theme.sand)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, 32)
        }
        .frame(minHeight: 380)
        .clipped()
    }

    private var badge: some View {
        HStack(spacing: 6) {
            Image(systemName: "tv")
                .font(.system(size: 11))
            Text("As seen on Robson Green's Weekend Escapes")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(Theme.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.white.opacity(0.15))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Theme.white.opacity(0.25)))
    }

    private func waveShape(opacity: Double, offset: CGFloat) -> some View {
        Rectangle()
            .fill(Theme.foam.opacity(opacity))
            .frame(height: 30)
            .clipShape(.rect(topLeadingRadius: 200, topTrailingRadius: 200))
            .scaleEffect(x: 2, y: 1)
            .offset(y: offset)
    }

    private func metaPill(icon: String, text: String, color: Color = Theme.white) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.white.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Today's Sailings

    private var todaySailings: some View {
        Group {
            if let today = schedule?.days.first {
                Button {
                    // navigate handled by tab
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("TODAY'S SAILINGS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.sea)
                                    .tracking(1.2)
                                Text(formatDate(today.date))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Theme.text)
                            }
                            Spacer()
                            Image(systemName: "calendar")
                                .font(.system(size: 22))
                                .foregroundStyle(Theme.sea)
                        }
                        if let weather = today.weather {
                            Text(weather)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textMuted)
                        }

                        LazyVGrid(
                            columns: [.init(.adaptive(minimum: 60), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(today.times.prefix(5), id: \.time) { t in
                                Text(t.time)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Theme.sea)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Theme.foam)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        Text("See full schedule →")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.sea)
                    }
                    .padding(18)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Theme.deep.opacity(0.12), radius: 16, y: 8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.top, -16)
            }
        }
    }

    // MARK: - Cruise Types

    private var cruiseTypes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Our Cruises")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 16)
                .padding(.top, 28)

            VStack(spacing: 12) {
                ForEach(schedule?.cruises ?? ScheduleConfig.default.cruises) { cruise in
                    NavigationLink(value: "book") {
                        cruiseCard(cruise, rating: cruiseRatings[cruise.id])
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func cruiseCard(_ cruise: Cruise, rating: CruiseRating?) -> some View {
        HStack(spacing: 14) {
            Text(cruise.emoji)
                .font(.system(size: 32))
                .frame(width: 60, height: 60)
                .background(Theme.foam)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(cruise.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.text)
                    if let rating, rating.reviewCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                            Text(String(format: "%.1f", rating.averageRating))
                                .font(.system(size: 11, weight: .bold))
                            Text("(\(rating.reviewCount))")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Theme.coral)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.coral.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                Text("\(cruise.duration) · From £\(cruise.childPrice) child / £\(cruise.adultPrice) adult")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.sea)
                Text(cruise.description)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.border))
    }

    // MARK: - CTA

    private var ctaButtons: some View {
        HStack(spacing: 10) {
            NavigationLink(value: "book") {
                HStack(spacing: 8) {
                    Image(systemName: "bird.fill")
                    Text("Book a Cruise")
                        .fontWeight(.bold)
                }
                .font(.system(size: 15))
                .foregroundStyle(Theme.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.sea)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button {
                let phone = schedule?.contactPhone ?? "07752861914"
                let cleaned = phone.replacingOccurrences(of: " ", with: "")
                if let url = URL(string: "tel:\(cleaned)") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "phone")
                    Text("Call")
                        .fontWeight(.bold)
                }
                .font(.system(size: 15))
                .foregroundStyle(Theme.sea)
                .padding(.vertical, 16)
                .padding(.horizontal, 22)
                .background(Theme.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.sea, lineWidth: 1.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
    }

    // MARK: - Notice

    private var noticeSection: some View {
        Group {
            if let notice = schedule?.notice {
                Text("⚓️ \(notice)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.deep)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.foam)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
            } else {
                Spacer().frame(height: 32)
            }
        }
    }

    // MARK: - Helpers

    private func loadAll() async {
        schedule = await SupabaseService.shared.fetchSchedule()
        if let cruises = schedule?.cruises {
            let ids = cruises.map { $0.id }
            cruiseRatings = await SupabaseService.shared.fetchCruiseRatings(for: ids)
        }
        recentPhotos = await SupabaseService.shared.fetchPhotos().prefix(6).map { $0 }
        isLoading = false
    }

    // MARK: - Guest Photos

    private var guestPhotosSection: some View {
        Group {
            if !recentPhotos.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Guest Photos")
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(Theme.text)
                        Spacer()
                        Button {
                            showAllPhotos = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("See all")
                                    .font(.system(size: 14, weight: .semibold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(Theme.sea)
                        }
                    }
                    .padding(.horizontal, 16)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recentPhotos) { photo in
                                Color(Theme.foam)
                                    .frame(width: 120, height: 120)
                                    .overlay {
                                        AsyncImage(url: URL(string: photo.imageURL)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .allowsHitTesting(false)
                                        } placeholder: {
                                            Color(Theme.foam)
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 28)
            }
        }
    }

    private func formatDate(_ dateStr: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateStr) else { return dateStr }
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: date)
    }
}

#Preview {
    HomeView()
}
