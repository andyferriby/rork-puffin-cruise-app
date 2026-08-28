import SwiftUI

struct ArrivalGuideView: View {
    @Environment(\.dismiss) private var dismiss

    private let steps: [(icon: String, title: String, body: String)] = [
        ("car.fill", "Parking", "Use Amble Harbour Car Park (NE65 0AP) — a two minute walk from the booking office."),
        ("clock.fill", "Check in 20 minutes early", "Find the Puffin Cruises kiosk at Amble Harbour Village and show your QR boarding pass."),
        ("qrcode.viewfinder", "Boarding", "Crew scan your ticket at the pier. Please arrive at the pier 15 minutes before departure."),
        ("cloud.sun.fill", "What to bring", "Layers, a waterproof jacket and sunscreen. It always feels cooler out on the water."),
        ("camera.fill", "Photography", "Bring binoculars and a camera — the upper deck gives the best views of the colony."),
        ("figure.and.child.holdinghands", "Families", "Lifejackets are provided for children. Buggies can be left safely at the kiosk.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Everything you need before you sail from Amble Harbour.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textMuted)
                        .lineSpacing(4)
                        .padding(.bottom, 4)

                    ForEach(steps, id: \.title) { step in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: step.icon)
                                .font(.system(size: 17))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Theme.sea)
                                .clipShape(.rect(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.title)
                                    .font(.system(size: 16, weight: .black))
                                    .foregroundStyle(Theme.text)
                                Text(step.body)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.textMuted)
                                    .lineSpacing(3)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(16)
                        .puffinCard(radius: 18, fill: .white)
                    }
                }
                .padding(16)
            }
            .background(Theme.bg)
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
