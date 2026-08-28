import SwiftUI

struct TicketsView: View {
    @State private var email = ""
    @State private var bookings: [Booking] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var walletURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tickets")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(Theme.text)
                    Text("Find your QR boarding passes by email.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textMuted)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

                searchCard

                if bookings.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 14) {
                        ForEach(bookings) { booking in
                            ticketCard(booking)
                        }
                    }
                    .padding(16)
                }
            }
            .padding(.bottom, 36)
        }
        .background(Theme.bg)
        .navigationTitle("Tickets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $walletURL) { url in SafariView(url: url) }
    }

    private var searchCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.textMuted)
                TextField("Email used for booking", text: $email)
                    .font(.system(size: 15))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(Theme.bg)
            .clipShape(.rect(cornerRadius: 14))

            Button { Task { await search() } } label: {
                Group {
                    if isSearching {
                        ProgressView().tint(.white)
                    } else {
                        Text("Find tickets").font(.system(size: 15, weight: .black))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Theme.sea)
                .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(isSearching)
        }
        .padding(16)
        .puffinCard(fill: .white)
        .padding(16)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "ticket")
                .font(.system(size: 38))
                .foregroundStyle(Theme.textMuted)
                .padding(.bottom, 8)
            Text(hasSearched ? "No tickets found" : "No tickets loaded")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Theme.text)
            Text(hasSearched
                 ? "We couldn't find paid bookings for that email."
                 : "Enter your booking email to show your boarding passes.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
        .padding(36)
        .puffinCard(radius: 22, fill: .white)
        .padding(.horizontal, 16)
    }

    private func ticketCard(_ booking: Booking) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(booking.cruise_name)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Theme.text)
                    Text("\(booking.displayDate) · \(booking.cruise_time)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textMuted)
                    Text("\(booking.adults) adult\(booking.adults == 1 ? "" : "s") · \(booking.children) child\(booking.children == 1 ? "" : "ren")")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textMuted)
                }
                Spacer()
                if booking.isBoarded {
                    VStack(spacing: 3) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)
                        Text("BOARDED")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 78, height: 78)
                    .background(Theme.sea)
                    .clipShape(.rect(cornerRadius: 16))
                } else {
                    QRCodeView(value: booking.id, size: 58)
                }
            }

            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)
                .padding(.vertical, 14)

            HStack {
                Text(booking.isBoarded ? "✓ BOARDED" : booking.status.uppercased())
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(booking.isBoarded ? Theme.sea : Theme.coral)
                Spacer()
                if booking.isBoarded {
                    HStack(spacing: 4) {
                        Image(systemName: "ferry.fill").font(.system(size: 11))
                        Text("Already boarded").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.sea)
                } else {
                    Button {
                        walletURL = BookingAPI.walletPassURL(bookingId: booking.id)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "wallet.bifold.fill").font(.system(size: 12))
                            Text("Add to Wallet").font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Theme.ink)
                        .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(16)
        .puffinCard(radius: 22, fill: booking.isBoarded ? Color(hex: 0xF0F5FA) : .white)
    }

    private func search() async {
        isSearching = true
        defer { isSearching = false }
        bookings = await SupabaseService.fetchBookings(email: email)
        hasSearched = true
    }
}
