import SwiftUI

struct AdminScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scannedId: String?
    @State private var booking: Booking?
    @State private var loading = false
    @State private var notFound = false
    @State private var checkingIn = false
    @State private var checkInDone = false
    @State private var error: String?

    var body: some View {
        ZStack {
            QRScannerView { code in
                handleScan(code)
            }
            .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
            }
        }
        .sheet(item: Binding(
            get: { booking },
            set: { newVal in
                booking = newVal
                if newVal == nil { resetScan() }
            }
        )) { b in
            resultSheet(b)
                .presentationDetents([.medium, .large])
        }
        .alert("Ticket not found", isPresented: $notFound) {
            Button("Scan again") { resetScan() }
        } message: {
            Text("That QR code didn't match any booking in the system.")
        }
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil; resetScan() }
        } message: {
            Text(error ?? "")
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.55))
                    .clipShape(Circle())
            }

            Spacer()

            Text("Scan Ticket")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.55))
                .clipShape(Capsule())

            Spacer()

            // Symmetric spacer
            Color.clear.frame(width: 38, height: 38)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    @ViewBuilder
    private func resultSheet(_ booking: Booking) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                statusHeader(booking)

                infoRows(booking)
                    .padding(.horizontal, 18)

                if booking.isCheckedIn {
                    alreadyCheckedInNote
                } else if booking.isPaid {
                    checkInButton
                } else {
                    notPaidWarning
                }

                Button {
                    self.booking = nil
                } label: {
                    Text("Scan another")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.sea)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.foam)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
        .background(Theme.bg)
        .presentationDragIndicator(.visible)
    }

    private func statusHeader(_ booking: Booking) -> some View {
        let (color, icon, title): (Color, String, String) = {
            if checkInDone {
                return (.green, "checkmark.seal.fill", "Checked In!")
            }
            if booking.isCheckedIn {
                return (.orange, "exclamationmark.triangle.fill", "Already Checked In")
            }
            if booking.isPaid {
                return (Theme.sea, "checkmark.circle.fill", "Valid Ticket")
            }
            return (.red, "xmark.octagon.fill", "Not Paid")
        }()
        return VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(color)
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(Theme.text)
        }
        .padding(.top, 26)
    }

    private func infoRows(_ booking: Booking) -> some View {
        VStack(spacing: 0) {
            row(label: "Cruise", value: booking.cruiseName)
            Divider().padding(.horizontal, 14)
            row(label: "Date", value: booking.cruiseDate)
            Divider().padding(.horizontal, 14)
            row(label: "Time", value: booking.cruiseTime)
            Divider().padding(.horizontal, 14)
            row(label: "Passengers", value: booking.passengerSummary)
            Divider().padding(.horizontal, 14)
            row(label: "Name", value: booking.customerName)
            Divider().padding(.horizontal, 14)
            row(label: "Email", value: booking.customerEmail)
            Divider().padding(.horizontal, 14)
            row(label: "Ref", value: String(booking.id.prefix(8)).uppercased())
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.border))
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var checkInButton: some View {
        Button {
            Task { await checkIn() }
        } label: {
            HStack(spacing: 8) {
                if checkingIn {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "person.fill.checkmark")
                }
                Text(checkingIn ? "Checking in…" : "Confirm Check-In")
                    .font(.system(size: 15, weight: .heavy))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(checkingIn ? Color.green.opacity(0.6) : Color.green)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(checkingIn)
        .padding(.horizontal, 18)
    }

    private var alreadyCheckedInNote: some View {
        Text("This ticket was already used. Please verify with the customer before re-admitting.")
            .font(.system(size: 13))
            .foregroundStyle(.orange)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
    }

    private var notPaidWarning: some View {
        Text("This booking has not been paid. Do not allow boarding.")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.red)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
    }

    // MARK: - Actions

    private func handleScan(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        scannedId = trimmed
        loading = true
        Task {
            if let result = await SupabaseService.shared.fetchBooking(id: trimmed) {
                booking = result
            } else {
                notFound = true
            }
            loading = false
        }
    }

    private func checkIn() async {
        guard let b = booking else { return }
        checkingIn = true
        do {
            try await SupabaseService.shared.checkInBooking(id: b.id)
            checkInDone = true
            // refresh booking
            if let updated = await SupabaseService.shared.fetchBooking(id: b.id) {
                booking = updated
            }
        } catch {
            self.error = error.localizedDescription
        }
        checkingIn = false
    }

    private func resetScan() {
        scannedId = nil
        booking = nil
        checkInDone = false
    }
}

#Preview {
    AdminScannerView()
}
