import SwiftUI
import PassKit

struct TicketsView: View {
    @State private var bookings: [Booking] = []
    @State private var isLoading = true
    @State private var emailInput: String = ""
    @State private var showEmailLookup: Bool = false
    @State private var showNotifications: Bool = false
    @State private var selected: Booking?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header

                if isLoading {
                    ProgressView()
                        .tint(Theme.sea)
                        .padding(.top, 60)
                } else if bookings.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(bookings) { booking in
                            Button {
                                selected = booking
                            } label: {
                                ticketRow(booking)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                HStack(spacing: 10) {
                    notificationButton
                    emailLookupButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Theme.bg)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $selected) { booking in
            TicketDetailView(booking: booking)
        }
        .sheet(isPresented: $showEmailLookup) {
            emailLookupSheet
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("My Tickets")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(Theme.text)
                Spacer()
                notificationBellButton
            }
            Text("Show your QR code at the harbour to board.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 18)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "ticket")
                .font(.system(size: 44))
                .foregroundStyle(Theme.sea)
                .frame(width: 88, height: 88)
                .background(Theme.foam)
                .clipShape(Circle())

            Text("No tickets yet")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Theme.text)
            Text("After you book, your tickets appear here with a QR code for boarding.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 40)
    }

    // MARK: - Row

    private func ticketRow(_ booking: Booking) -> some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Text(dayNumber(booking.cruiseDate))
                    .font(.system(size: 26, weight: .heavy))
                Text(monthShort(booking.cruiseDate).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
            }
            .foregroundStyle(Theme.white)
            .frame(width: 64, height: 64)
            .background(LinearGradient(colors: [Theme.sea, Theme.wave], startPoint: .top, endPoint: .bottom))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                Text(booking.cruiseName)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(booking.cruiseTime)
                        .font(.system(size: 12, weight: .semibold))
                    Text("·")
                    Text(booking.passengerSummary)
                        .font(.system(size: 12))
                }
                .foregroundStyle(Theme.textMuted)
                statusPill(booking)
            }

            Spacer()

            Image(systemName: "qrcode")
                .font(.system(size: 26))
                .foregroundStyle(Theme.sea)
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.border))
        .shadow(color: Theme.deep.opacity(0.06), radius: 10, y: 4)
    }

    private func statusPill(_ booking: Booking) -> some View {
        let (label, color): (String, Color) = {
            switch booking.status {
            case "paid": return ("CONFIRMED", Theme.sea)
            case "checked_in": return ("CHECKED IN", Color.green)
            case "pending": return ("PAYMENT PENDING", Theme.puffin)
            default: return (booking.status.uppercased(), Theme.textMuted)
            }
        }()
        return Text(label)
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.8)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
            .padding(.top, 4)
    }

    // MARK: - Notifications

    private var notificationBellButton: some View {
        Button {
            showNotifications = true
        } label: {
            Image(systemName: "bell.fill")
                .font(.system(size: 16))
                .foregroundStyle(Theme.sea)
                .frame(width: 40, height: 40)
                .background(Theme.foam)
                .clipShape(Circle())
        }
    }

    private var notificationButton: some View {
        Button {
            showNotifications = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 18))
                    .symbolRenderingMode(.hierarchical)
                Text("Crew Updates")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(Theme.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(Theme.sea)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Email Lookup

    private var emailLookupButton: some View {
        Button {
            emailInput = BookingsStore.shared.savedEmail ?? ""
            showEmailLookup = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "envelope.badge.fill")
                Text("Find tickets by email")
                    .fontWeight(.bold)
            }
            .font(.system(size: 14))
            .foregroundStyle(Theme.sea)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.foam)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.sea.opacity(0.3), lineWidth: 1))
        }
    }

    private var emailLookupSheet: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Find your tickets")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(Theme.text)
                Text("Enter the email you used at booking.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)

            TextField("you@example.com", text: $emailInput)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textInputAutocapitalization(.never)
                .padding(14)
                .background(Theme.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.border))
                .padding(.horizontal, 24)

            Button {
                Task { await lookupByEmail() }
            } label: {
                Text("Find tickets")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.sea)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!emailInput.contains("@"))
            .opacity(emailInput.contains("@") ? 1 : 0.5)
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        let ids = BookingsStore.shared.savedIds()
        var fetched = await SupabaseService.shared.fetchBookings(ids: ids)
        if fetched.isEmpty, let email = BookingsStore.shared.savedEmail, !email.isEmpty {
            fetched = await SupabaseService.shared.fetchBookings(byEmail: email)
            for b in fetched { BookingsStore.shared.add(b.id) }
        }
        bookings = fetched.filter { $0.isPaid }
        isLoading = false
    }

    private func lookupByEmail() async {
        let email = emailInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard email.contains("@") else { return }
        BookingsStore.shared.savedEmail = email
        showEmailLookup = false
        isLoading = true
        let fetched = await SupabaseService.shared.fetchBookings(byEmail: email)
        for b in fetched { BookingsStore.shared.add(b.id) }
        bookings = fetched.filter { $0.isPaid }
        isLoading = false
    }

    private func dayNumber(_ str: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: str) else { return "—" }
        f.dateFormat = "d"
        return f.string(from: d)
    }
    private func monthShort(_ str: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: str) else { return "" }
        f.dateFormat = "MMM"
        return f.string(from: d)
    }
}

#Preview {
    TicketsView()
}
