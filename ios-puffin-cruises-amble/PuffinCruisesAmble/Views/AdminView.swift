import SwiftUI

private enum ScanResult: Equatable {
    case booking(Booking)
    case membership(MembershipPass)
    case preprinted(Int)
}

struct AdminView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ScheduleStore.self) private var schedule

    @State private var pin = ""
    @State private var isUnlocked = false
    @State private var pinError: String?

    @State private var isScanning = false
    @State private var scanResult: ScanResult?
    @State private var scanError: String?
    @State private var isProcessing = false
    @State private var scanLocked = false

    @State private var boarded: [Booking] = []
    @State private var preprinted = PreprintedBoarding(count: 0, lastScanAt: nil)

    @State private var pushTitle = ""
    @State private var pushBody = ""
    @State private var isSendingPush = false
    @State private var alertMessage: String?

    private let storedPinKey = "puffin_admin_pin"
    private let paperTicketValue = "PUFFIN_SHOP_TICKET_BOARDING"

    private var appAdults: Int { boarded.reduce(0) { $0 + $1.adults } }
    private var appChildren: Int { boarded.reduce(0) { $0 + $1.children } }
    private var totalOnBoard: Int { appAdults + appChildren + preprinted.count }

    var body: some View {
        NavigationStack {
            Group {
                if isUnlocked {
                    adminContent
                } else {
                    lockScreen
                }
            }
            .background(Theme.bg)
            .navigationTitle(isUnlocked ? "Crew Admin" : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { settings.showAdmin = false }
                }
            }
            .alert("Admin", isPresented: .init(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) { alertMessage = nil }
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    // MARK: - Lock

    private var lockScreen: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Theme.sea)
                .clipShape(.rect(cornerRadius: 24))

            VStack(spacing: 6) {
                Text("Crew Access")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(Theme.text)
                Text("Enter the admin PIN to open the scanner and sailing tools.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            SecureField("PIN", text: $pin)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 22, weight: .heavy))
                .padding(.vertical, 14)
                .background(.white)
                .clipShape(.rect(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1) }

            if let pinError {
                Text(pinError).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.coral)
            }

            Button { unlock() } label: {
                Text("Unlock")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.sea)
                    .clipShape(.rect(cornerRadius: 16))
            }

            Text("First time? The PIN you enter now becomes the crew PIN for this device.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: 420)
    }

    private func unlock() {
        let entered = pin.trimmingCharacters(in: .whitespaces)
        guard entered.count >= 4 else {
            pinError = "Use at least 4 digits."
            return
        }
        let stored = UserDefaults.standard.string(forKey: storedPinKey)
        if stored == nil {
            UserDefaults.standard.set(entered, forKey: storedPinKey)
            isUnlocked = true
        } else if stored == entered {
            isUnlocked = true
        } else {
            pinError = "Incorrect PIN."
        }
        pin = ""
    }

    // MARK: - Admin

    private var adminContent: some View {
        ScrollView {
            VStack(spacing: 22) {
                scannerSection
                paperQRSection
                onBoardSection
                pushSection
                scheduleSummary
            }
            .padding(16)
            .padding(.bottom, 30)
        }
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private var scannerSection: some View {
        section("Ticket Scanner") {
            VStack(spacing: 12) {
                if isScanning {
                    ZStack {
                        QRScannerView { value in
                            guard !scanLocked else { return }
                            scanLocked = true
                            Task { await handleScan(value) }
                        }
                        .frame(height: 300)
                        .clipShape(.rect(cornerRadius: 18))

                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.85), lineWidth: 3)
                            .frame(width: 190, height: 190)
                    }

                    Button {
                        isScanning = false
                        scanLocked = false
                    } label: {
                        Text("Stop Scanning")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Theme.sea)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Theme.foam)
                            .clipShape(.rect(cornerRadius: 14))
                    }
                } else {
                    Button {
                        scanResult = nil
                        scanError = nil
                        scanLocked = false
                        isScanning = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Start Scanning").font(.system(size: 16, weight: .black))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.sea)
                        .clipShape(.rect(cornerRadius: 16))
                    }

                    Text("Scans boarding passes, membership passes and preprinted shop tickets.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.center)
                }

                if isProcessing { ProgressView().tint(Theme.sea) }

                if let scanError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.coral)
                        Text(scanError).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.coral)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Theme.coral.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 12))
                }

                if let scanResult { resultCard(scanResult) }
            }
            .padding(16)
            .puffinCard(fill: .white)
        }
    }

    @ViewBuilder
    private func resultCard(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch result {
            case let .booking(booking):
                statusHeader("Booking Found")
                Text(booking.customer_name ?? "Guest")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(Theme.text)
                Text(booking.cruise_name).font(.system(size: 14)).foregroundStyle(Theme.textMuted)
                Text("\(booking.displayDate) · \(booking.cruise_time)")
                    .font(.system(size: 13)).foregroundStyle(Theme.textMuted)
                Text("\(booking.adults) adult\(booking.adults == 1 ? "" : "s") · \(booking.children) child\(booking.children == 1 ? "" : "ren")")
                    .font(.system(size: 13)).foregroundStyle(Theme.textMuted)
                badge(booking.status.uppercased())

                if booking.status == "paid" {
                    Button { Task { await markBoarded(booking) } } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Mark as Boarded").font(.system(size: 15, weight: .black))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Theme.sea)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                    .padding(.top, 4)
                } else if booking.isBoarded {
                    Label("Already boarded", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.sea)
                }

            case let .membership(pass):
                statusHeader("Membership Trip Redeemed")
                Text(pass.email).font(.system(size: 18, weight: .black)).foregroundStyle(Theme.text)
                Text("Annual Puffin Membership").font(.system(size: 14)).foregroundStyle(Theme.textMuted)
                Text("10% shop discount included").font(.system(size: 13)).foregroundStyle(Theme.textMuted)
                badge("\(pass.creditsRemaining) / \(pass.creditsTotal) TRIPS LEFT")
                Text("Valid until \(pass.expiryDisplay)").font(.system(size: 13)).foregroundStyle(Theme.textMuted)

            case let .preprinted(count):
                statusHeader("Shop Ticket Counted")
                Text("+1 person on board").font(.system(size: 18, weight: .black)).foregroundStyle(Theme.text)
                Text("Preprinted shop ticket").font(.system(size: 14)).foregroundStyle(Theme.textMuted)
                badge("\(count) SHOP TICKET\(count == 1 ? "" : "S") ON BOARD")
            }

            Button {
                scanResult = nil
                scanError = nil
                scanLocked = false
            } label: {
                Text("Scan Another")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Theme.sea)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Theme.foam)
                    .clipShape(.rect(cornerRadius: 12))
            }
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bg)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func statusHeader(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.sea)
            Text(text).font(.system(size: 15, weight: .black)).foregroundStyle(Theme.sea)
        }
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(Theme.coral)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.coral.opacity(0.12))
            .clipShape(.capsule)
    }

    private var paperQRSection: some View {
        section("Shop Paper Ticket QR") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Use this one QR on every preprinted ticket")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(Theme.text)
                        Text("Each scan adds 1 person to the on-board counter. It does not check whether the ticket is real.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textMuted)
                            .lineSpacing(3)
                    }
                    QRCodeView(value: paperTicketValue, size: 86)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("QR VALUE")
                        .font(.system(size: 10, weight: .black))
                        .tracking(0.8)
                        .foregroundStyle(Theme.textMuted)
                    Text(paperTicketValue)
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.sea)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Theme.bg)
                .clipShape(.rect(cornerRadius: 12))
            }
            .padding(14)
            .puffinCard(radius: 18, fill: .white)
        }
    }

    private var onBoardSection: some View {
        section("Currently On Board") {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    chip("\(appAdults) adults", color: Theme.foam, text: Theme.sea)
                    chip("\(appChildren) children", color: Color(hex: 0xFFF3F0), text: Theme.coral)
                    chip("\(preprinted.count) shop", color: Color(hex: 0xF7F2E7), text: Theme.sandDeep)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TOTAL ON BOARD")
                            .font(.system(size: 11, weight: .black))
                            .tracking(0.8)
                            .foregroundStyle(Theme.textMuted)
                        Text("\(totalOnBoard) people")
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(Theme.text)
                    }
                    Spacer()
                    Image(systemName: "person.3.fill").font(.system(size: 22)).foregroundStyle(Theme.sea)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Shop paper tickets")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Theme.text)
                        Text("Adjust if someone boards without a scan")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textMuted)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        stepButton("minus") { Task { await adjustPreprinted(-1) } }
                        Text("\(preprinted.count)")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(Theme.text)
                            .frame(minWidth: 26)
                        stepButton("plus") { Task { await adjustPreprinted(1) } }
                    }
                }
                .padding(10)
                .background(Color(hex: 0xF7F2E7))
                .clipShape(.rect(cornerRadius: 14))

                if boarded.isEmpty {
                    Text("No app tickets scanned yet for this trip.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 8) {
                        ForEach(boarded) { booking in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(booking.customer_name ?? "Guest")
                                        .font(.system(size: 14, weight: .heavy))
                                        .foregroundStyle(Theme.text)
                                    Text("\(booking.cruise_name) · \(booking.cruise_time)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textMuted)
                                }
                                Spacer()
                                Text("\(booking.adults + booking.children)")
                                    .font(.system(size: 15, weight: .black))
                                    .foregroundStyle(Theme.sea)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }

                Button { Task { await resetTrip() } } label: {
                    Text("Reset for Next Trip")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Theme.coral)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Theme.coral.opacity(0.1))
                        .clipShape(.rect(cornerRadius: 14))
                }
            }
            .padding(16)
            .puffinCard(fill: .white)
        }
    }

    private func chip(_ text: String, color: Color, text textColor: Color) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .heavy))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color)
            .clipShape(.rect(cornerRadius: 12))
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.sea)
                .frame(width: 34, height: 34)
                .background(.white)
                .clipShape(.rect(cornerRadius: 11))
                .overlay { RoundedRectangle(cornerRadius: 11).stroke(Theme.border, lineWidth: 1) }
        }
    }

    private var pushSection: some View {
        section("Send Push") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "paperplane.fill").foregroundStyle(Theme.sea)
                    Text("Broadcast to all app users")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Theme.text)
                }

                TextField("Title (e.g. Sailing update)", text: $pushTitle)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.bg)
                    .clipShape(.rect(cornerRadius: 12))

                TextField("Message (e.g. The 2pm sailing is running as normal)", text: $pushBody, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(3...5)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Theme.bg)
                    .clipShape(.rect(cornerRadius: 12))

                Button { Task { await sendPush() } } label: {
                    HStack(spacing: 8) {
                        if isSendingPush {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Send to All Devices").font(.system(size: 15, weight: .black))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Theme.sea)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .disabled(isSendingPush)
            }
            .padding(16)
            .puffinCard(fill: .white)
        }
    }

    private var scheduleSummary: some View {
        section("Today's Sailings") {
            VStack(alignment: .leading, spacing: 10) {
                if let today = schedule.today {
                    Text(DateFormat.longDay(today.parsedDate))
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(Theme.text)
                    ForEach(today.times) { slot in
                        HStack(spacing: 10) {
                            Text(slot.time)
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(.white)
                                .frame(width: 56)
                                .padding(.vertical, 7)
                                .background(Theme.deep)
                                .clipShape(.rect(cornerRadius: 9))
                            Text(schedule.cruise(id: slot.cruiseId)?.name ?? slot.cruiseId)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.text)
                            Spacer()
                        }
                    }
                } else {
                    Text("No sailings scheduled.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textMuted)
                }

                Text("Sailing times and cruise types are edited in the main app's admin tools.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .puffinCard(fill: .white)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .black))
                .tracking(1)
                .foregroundStyle(Theme.textMuted)
                .padding(.leading, 4)
            content()
        }
    }

    // MARK: - Actions

    private func refresh() async {
        boarded = await SupabaseService.fetchBoardedBookings()
        preprinted = await SupabaseService.fetchPreprintedBoarding()
    }

    private func handleScan(_ value: String) async {
        isProcessing = true
        defer { isProcessing = false }
        scanError = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        if value == paperTicketValue {
            let latest = await SupabaseService.fetchPreprintedBoarding()
            let next = PreprintedBoarding(
                count: latest.count + 1,
                lastScanAt: ISO8601DateFormatter().string(from: Date())
            )
            do {
                try await SupabaseService.savePreprintedBoarding(next)
                preprinted = next
                scanResult = .preprinted(next.count)
            } catch {
                scanError = "Could not update the paper ticket count."
            }
            return
        }

        if value.hasPrefix("PUFFIN_MEMBER:") {
            let memberId = String(value.dropFirst("PUFFIN_MEMBER:".count))
            do {
                let pass = try await BookingAPI.redeemMembership(memberId: memberId)
                scanResult = .membership(pass)
            } catch {
                scanError = "Membership could not be redeemed. It may have no credits left."
            }
            return
        }

        do {
            if let booking = try await SupabaseService.fetchBooking(id: value) {
                scanResult = .booking(booking)
            } else {
                scanError = "No booking found for that QR code."
            }
        } catch {
            scanError = "Could not look up that ticket. Check your connection."
        }
    }

    private func markBoarded(_ booking: Booking) async {
        do {
            try await SupabaseService.updateBookingStatus(id: booking.id, status: "boarded")
            var updated = booking
            updated.status = "boarded"
            scanResult = .booking(updated)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await refresh()
        } catch {
            alertMessage = "Could not mark as boarded. Please try again."
        }
    }

    private func adjustPreprinted(_ delta: Int) async {
        let latest = await SupabaseService.fetchPreprintedBoarding()
        let next = PreprintedBoarding(
            count: max(0, latest.count + delta),
            lastScanAt: latest.lastScanAt
        )
        do {
            try await SupabaseService.savePreprintedBoarding(next)
            preprinted = next
        } catch {
            alertMessage = "Could not update the count."
        }
    }

    private func resetTrip() async {
        do {
            try await SupabaseService.resetBoardedBookings()
            try await SupabaseService.savePreprintedBoarding(PreprintedBoarding(count: 0, lastScanAt: nil))
            await refresh()
            alertMessage = "Ready for the next trip."
        } catch {
            alertMessage = "Could not reset. Please try again."
        }
    }

    private func sendPush() async {
        let title = pushTitle.trimmingCharacters(in: .whitespaces)
        let body = pushBody.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty, !body.isEmpty else {
            alertMessage = "Add a title and a message first."
            return
        }
        isSendingPush = true
        defer { isSendingPush = false }
        do {
            let count = try await BookingAPI.sendBroadcastPush(title: title, body: body)
            if count == 0 {
                alertMessage = "No devices have registered for push yet."
            } else {
                pushTitle = ""
                pushBody = ""
                alertMessage = "Notification sent to \(count) device\(count == 1 ? "" : "s")."
            }
        } catch {
            alertMessage = "Could not send the push. Please try again."
        }
    }
}
