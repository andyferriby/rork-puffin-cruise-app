import SwiftUI

// MARK: - Guide Section Model

private struct GuideSection: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let items: [GuideItem]
}

private struct GuideItem: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let detail: String
}

// MARK: - Hardcoded Guide Content

private let sections: [GuideSection] = [
    GuideSection(icon: "mappin.and.ellipse", title: "Getting Here & Parking", items: [
        GuideItem(emoji: "🗺️", title: "Our Location",
                  detail: "Dave Gray's Puffin Cruises sails from Amble Harbour, Northumberland. The booking office is on Harbour Road, a 2-minute walk from the pier. Look for the blue and white Puffin Cruises sign."),
        GuideItem(emoji: "🅿️", title: "Parking",
                  detail: "Amble has several public car parks. The closest is Harbour Car Park (NE65 0AP) — £2.50 all day. Leazes Street Car Park is a 5-minute walk and less busy on peak days. Both take card and contactless."),
        GuideItem(emoji: "🚉", title: "By Public Transport",
                  detail: "The nearest railway station is Alnmouth (5 miles away). Arriva bus 518 runs hourly from Alnmouth to Amble. Taxis are available at the station — approx £12 to the harbour."),
    ]),
    GuideSection(icon: "suitcase.fill", title: "What to Bring", items: [
        GuideItem(emoji: "🧥", title: "Warm Layers",
                  detail: "Even on sunny days it's cooler at sea. Bring a jumper or fleece. Waterproof jacket recommended — the North Sea spray is real!"),
        GuideItem(emoji: "🧢", title: "Sun Protection",
                  detail: "Sunscreen, sunglasses, and a hat — you're exposed on the boat. There's limited shade on deck."),
        GuideItem(emoji: "📸", title: "Camera or Phone",
                  detail: "You'll want photos of puffins, seals, and the lighthouse. Phones are fine but a camera with zoom lens is even better for wildlife close-ups."),
        GuideItem(emoji: "👟", title: "Flat Shoes",
                  detail: "Non-slip, flat-soled shoes. No heels — the deck can be wet. Trainers or deck shoes are perfect."),
        GuideItem(emoji: "💊", title: "Seasickness",
                  detail: "If you're prone to motion sickness, take tablets 30 minutes before departure. Our boats are stable catamarans, but swell around the island can be choppy."),
    ]),
    GuideSection(icon: "clock.fill", title: "On the Day", items: [
        GuideItem(emoji: "⏰", title: "Arrive 20 Minutes Early",
                  detail: "Check in at the booking office at least 20 minutes before departure. Late arrivals may lose their place — we sail on schedule."),
        GuideItem(emoji: "🛂", title: "Check-in Process",
                  detail: "Show your booking confirmation (the QR code in the Tickets tab of this app works perfectly). Our crew will scan your pass and direct you to the boarding point."),
        GuideItem(emoji: "🧑‍✈️", title: "Safety Briefing",
                  detail: "Before departure the skipper gives a short safety talk — lifejacket locations, staying seated while moving, and keeping hands inside the rails. Lifejackets are provided for all passengers."),
        GuideItem(emoji: "🚻", title: "Facilities",
                  detail: "Toilets are available at the harbour near the booking office. There are no toilets on the boat (trips are 60–90 minutes)."),
    ]),
    GuideSection(icon: "accessibility", title: "Accessibility", items: [
        GuideItem(emoji: "♿", title: "Wheelchair Access",
                  detail: "Our catamaran has a flat boarding ramp and wide deck space for wheelchairs. Please call us at least 24 hours before your trip so we can reserve the best spot and have crew ready to assist."),
        GuideItem(emoji: "🦻", title: "Hearing & Visual",
                  detail: "Skipper commentary is delivered over a PA system. If you have hearing difficulties, let the crew know and they'll seat you near the speaker. Assistance dogs are welcome aboard."),
        GuideItem(emoji: "👶", title: "Children & Families",
                  detail: "Children of all ages are welcome. Under-3s sail free. Pushchairs can be left at the booking office — space is limited on board. Child-sized lifejackets are provided."),
    ]),
    GuideSection(icon: "info.circle.fill", title: "Need to Know", items: [
        GuideItem(emoji: "🌦️", title: "Weather & Cancellations",
                  detail: "We monitor conditions constantly. If a trip is cancelled due to weather, you'll be offered a full refund or free rebooking. We'll notify you by text/email and push notification by 8am on the day."),
        GuideItem(emoji: "🦺", title: "Safety Record",
                  detail: "Dave Gray's Puffin Cruises is fully licensed and insured. Both catamarans are MCA-certified. Our skippers have 20+ years of local experience. Safety is our top priority."),
        GuideItem(emoji: "📞", title: "Contact",
                  detail: "Call us on 01665 711444 (9am–6pm daily). Email: info@puffincruises.co.uk. The booking office at Amble Harbour is open daily from 8:30am until the last sailing returns."),
    ]),
]

// MARK: - Main View

struct ArrivalGuideView: View {
    @Environment(\.dismiss) private var dismiss
    var embedded: Bool = false

    var body: some View {
        if embedded {
            content
        } else {
            NavigationStack {
                content
                    .navigationTitle("Arrival Guide")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { dismiss() }
                        }
                    }
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroSection
                guideContent
            }
        }
        .background(Theme.bg)
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Theme.deep, Theme.sea, Theme.wave.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 200)

            WaveShape()
                .fill(Theme.foam.opacity(0.15))
                .frame(height: 40)
                .offset(y: -20)

            VStack(alignment: .leading, spacing: 6) {
                Text("⚓")
                    .font(.system(size: 36))
                Text("Your Arrival Guide")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.white)
                Text("Everything you need to know before your cruise")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.foam.opacity(0.8))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Content Sections

    private var guideContent: some View {
        VStack(spacing: 16) {
            ForEach(sections) { section in
                sectionCard(section)
            }
        }
        .padding(16)
    }

    private func sectionCard(_ section: GuideSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.coral)
                    .frame(width: 32, height: 32)
                    .background(Theme.coral.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 8))

                Text(section.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.text)
            }

            VStack(spacing: 0) {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                    guideItemRow(item, isLast: index == section.items.count - 1)
                }
            }
        }
        .padding(20)
        .background(Theme.card)
        .clipShape(.rect(cornerRadius: 16))
        .shadow(color: Theme.border, radius: 4, y: 2)
    }

    private func guideItemRow(_ item: GuideItem, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(item.emoji)
                .font(.system(size: 24))
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)

                Text(item.detail)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Theme.textMuted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .overlay(alignment: .bottom) {
            if !isLast {
                Divider()
                    .padding(.leading, 54)
            }
        }
    }
}

// MARK: - Wave Shape (reused)

private struct WaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: 0, y: h * 0.6))
        path.addCurve(to: CGPoint(x: w * 0.33, y: h * 0.2),
                      control1: CGPoint(x: w * 0.15, y: h * 0.9),
                      control2: CGPoint(x: w * 0.2, y: h * 0.2))
        path.addCurve(to: CGPoint(x: w * 0.66, y: h * 0.6),
                      control1: CGPoint(x: w * 0.46, y: h * 0.2),
                      control2: CGPoint(x: w * 0.5, y: h * 0.9))
        path.addCurve(to: CGPoint(x: w, y: h * 0.3),
                      control1: CGPoint(x: w * 0.8, y: h * 0.35),
                      control2: CGPoint(x: w * 0.9, y: h * 0.9))
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.closeSubpath()
        return path
    }
}

#Preview {
    ArrivalGuideView()
}
