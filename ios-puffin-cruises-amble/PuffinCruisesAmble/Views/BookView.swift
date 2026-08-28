import SafariServices
import SwiftUI

struct BookView: View {
    @Environment(ScheduleStore.self) private var schedule

    @State private var cruiseId: String?
    @State private var date: String?
    @State private var time: String?
    @State private var adults = 2
    @State private var children = 0
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var isSubmitting = false
    @State private var checkoutURL: URL?
    @State private var errorMessage: String?

    private var cruise: Cruise? { schedule.cruise(id: cruiseId ?? "") }

    private var availableTimes: [SailingTime] {
        guard let date, let day = schedule.days.first(where: { $0.date == date }) else { return [] }
        guard let cruiseId else { return day.times }
        return day.times.filter { $0.cruiseId == cruiseId }
    }

    private var total: Double {
        guard let cruise else { return 0 }
        return Double(adults) * cruise.adultPrice + Double(children) * cruise.childPrice
    }

    private var canSubmit: Bool {
        cruise != nil && date != nil && time != nil
            && adults + children > 0
            && name.trimmingCharacters(in: .whitespaces).count > 1
            && email.contains("@") && email.contains(".")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Book a Cruise")
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundStyle(Theme.text)
                        Text("Secure payment by Stripe")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)

                    stepHeader(1, "Choose a cruise")
                    VStack(spacing: 10) {
                        ForEach(schedule.cruises) { item in
                            cruiseChoice(item)
                        }
                    }
                    .padding(.horizontal, 16)

                    stepHeader(2, "Pick a date")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(schedule.days) { day in
                                dayChip(day)
                            }
                        }
                    }
                    .contentMargins(.horizontal, 16, for: .scrollContent)

                    stepHeader(3, "Choose a sailing time")
                    timesSection

                    stepHeader(4, "Passengers")
                    VStack(spacing: 0) {
                        paxRow(
                            label: "Adults",
                            sub: cruise.map { "£\($0.adultPrice.priceText) each" } ?? "",
                            value: $adults
                        )
                        Divider().background(Theme.border).padding(.horizontal, 14)
                        paxRow(
                            label: "Children",
                            sub: cruise.map { "£\($0.childPrice.priceText) each (under 16)" } ?? "",
                            value: $children
                        )
                    }
                    .puffinCard(radius: 16, fill: .white)
                    .padding(.horizontal, 16)

                    stepHeader(5, "Your details")
                    VStack(spacing: 10) {
                        field(icon: "person", placeholder: "Full name", text: $name)
                            .textInputAutocapitalization(.words)
                        field(icon: "envelope", placeholder: "Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        field(icon: "phone", placeholder: "Phone (optional)", text: $phone)
                            .keyboardType(.phonePad)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Theme.bg)
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { footer }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $checkoutURL) { url in
                SafariView(url: url)
            }
            .alert("Booking error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Pieces

    private func stepHeader(_ number: Int, _ label: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Theme.sea)
                .clipShape(.circle)
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 10)
    }

    private func cruiseChoice(_ item: Cruise) -> some View {
        let selected = item.id == cruiseId
        return Button {
            cruiseId = item.id
            time = nil
        } label: {
            HStack(spacing: 14) {
                Text(item.emoji).font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.text)
                    Text("\(item.duration) · £\(item.adultPrice.priceText) adult / £\(item.childPrice.priceText) child")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.sea)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Theme.foam : .white)
            .clipShape(.rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Theme.sea : Theme.border, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func dayChip(_ day: DaySchedule) -> some View {
        let isActive = day.date == date
        let parsed = day.parsedDate
        return Button {
            date = day.date
            time = nil
        } label: {
            VStack(spacing: 2) {
                Text(parsed.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isActive ? .white : Theme.textMuted)
                Text(parsed.formatted(.dateTime.day()))
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(isActive ? .white : Theme.text)
                Text(parsed.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isActive ? .white : Theme.textMuted)
            }
            .frame(width: 64)
            .padding(.vertical, 12)
            .background(isActive ? Theme.sea : .white)
            .clipShape(.rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14).stroke(isActive ? Theme.sea : Theme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var timesSection: some View {
        if date == nil {
            Text("Pick a date to see times.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
                .padding(.horizontal, 20)
        } else if availableTimes.isEmpty {
            Text("No sailings match that combination.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
                .padding(.horizontal, 20)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                ForEach(Array(availableTimes.enumerated()), id: \.offset) { _, slot in
                    let selected = time == slot.time && cruiseId == slot.cruiseId
                    Button {
                        time = slot.time
                        cruiseId = slot.cruiseId
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "clock").font(.system(size: 12))
                            Text(slot.time).font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(selected ? .white : Theme.sea)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selected ? Theme.sea : .white)
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected ? Theme.sea : Theme.border, lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func paxRow(label: String, sub: String, value: Binding<Int>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                if !sub.isEmpty {
                    Text(sub).font(.system(size: 12)).foregroundStyle(Theme.textMuted)
                }
            }
            Spacer()
            Button { value.wrappedValue = max(0, value.wrappedValue - 1) } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.sea)
                    .frame(width: 32, height: 32)
                    .background(Theme.foam)
                    .clipShape(.circle)
            }
            Text("\(value.wrappedValue)")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Theme.text)
                .frame(minWidth: 24)
            Button { value.wrappedValue += 1 } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.sea)
                    .frame(width: 32, height: 32)
                    .background(Theme.foam)
                    .clipShape(.circle)
            }
        }
        .padding(14)
    }

    private func field(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Theme.textMuted)
            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(.white)
        .clipShape(.rect(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1) }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("TOTAL")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.textMuted)
                Text("£\(total, specifier: "%.2f")")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Theme.text)
            }
            Spacer()
            Button { Task { await submit() } } label: {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "creditcard.fill")
                        Text("Pay & Book").font(.system(size: 15, weight: .heavy))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .background(Theme.sea)
                .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(!canSubmit || isSubmitting)
            .opacity(canSubmit && !isSubmitting ? 1 : 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white)
        .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    private func submit() async {
        guard canSubmit, let cruise, let date, let time else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        do {
            let response = try await BookingAPI.createCheckout(
                CheckoutRequest(
                    cruiseId: cruise.id,
                    cruiseName: cruise.name,
                    date: date,
                    time: time,
                    adults: adults,
                    children: children,
                    customerName: name.trimmingCharacters(in: .whitespaces),
                    customerEmail: email.trimmingCharacters(in: .whitespaces),
                    customerPhone: phone.trimmingCharacters(in: .whitespaces)
                )
            )
            if let url = URL(string: response.url) {
                checkoutURL = url
            } else {
                errorMessage = "The payment page could not be opened."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

/// In-app Safari used for the Stripe checkout hand-off.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
