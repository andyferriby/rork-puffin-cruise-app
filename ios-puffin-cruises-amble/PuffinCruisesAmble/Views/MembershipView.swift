import RevenueCat
import SwiftUI

struct MembershipView: View {
    @State private var email = ""
    @State private var pass: MembershipPass?
    @State private var isSyncing = false
    @State private var statusMessage: String?
    @State private var showCopied = false
    @State private var offeringPackage: Package?
    @State private var isMembershipActive = false
    @State private var isPurchasing = false
    @State private var isRestoring = false

    private let memberEmailKey = "puffin_member_email"
    private let memberPassKey = "puffin_member_pass"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    priceCard
                    if isMembershipActive {
                        passCreator
                    }
                    if let pass, pass.active {
                        memberPass(pass)
                    }
                }
                .padding(.bottom, 36)
            }
            .background(Theme.deep)
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear(perform: loadPersisted)
            .task { await loadMembershipState() }
            .alert("Membership", isPresented: .init(
                get: { statusMessage != nil },
                set: { if !$0 { statusMessage = nil } }
            )) {
                Button("OK", role: .cancel) { statusMessage = nil }
            } message: {
                Text(statusMessage ?? "")
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: "crown.fill")
                .font(.system(size: 30))
                .foregroundStyle(Theme.sand)
                .frame(width: 68, height: 68)
                .background(Theme.sand.opacity(0.12))
                .clipShape(.rect(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24).stroke(Theme.sand.opacity(0.22), lineWidth: 1)
                }

            Text("PUFFIN CREW MEMBER")
                .font(.system(size: 12, weight: .black))
                .tracking(1.5)
                .foregroundStyle(Theme.sand)
                .padding(.top, 18)

            Text("12 boat trips a year, one simple pass.")
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(.white)
                .lineSpacing(2)
                .padding(.top, 8)

            Text("Includes 1 adult boat trip every month, plus 10% off in the shop.")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.75))
                .lineSpacing(5)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 18)
    }

    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(offeringPackage?.localizedPriceString ?? "£100/year")
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(Theme.text)
            Text("Annual membership")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.textMuted)

            VStack(alignment: .leading, spacing: 10) {
                benefit("ticket.fill", "12 adult trip credits per year")
                benefit("qrcode", "QR pass scanned by crew in admin")
                benefit("bag.fill", "10% off in-store purchases")
                benefit("gift.fill", "Use anytime of the year, subject to availability")
            }
            .padding(.vertical, 18)

            if isMembershipActive {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                    Text("Membership active")
                        .font(.system(size: 16, weight: .black))
                }
                .foregroundStyle(Theme.sea)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.foam)
                .clipShape(.rect(cornerRadius: 18))
            } else {
                Button { Task { await purchaseMembership() } } label: {
                    Group {
                        if isPurchasing {
                            ProgressView().tint(.white)
                        } else {
                            Text("Start Membership").font(.system(size: 16, weight: .black))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.coral)
                    .clipShape(.rect(cornerRadius: 18))
                }
                .disabled(offeringPackage == nil || isPurchasing)
                .opacity(offeringPackage == nil || isPurchasing ? 0.55 : 1)
            }

            Button { Task { await restoreMembership() } } label: {
                HStack(spacing: 6) {
                    if isRestoring {
                        ProgressView().tint(Theme.sea)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .bold))
                        Text("Restore Purchases")
                            .font(.system(size: 14, weight: .black))
                    }
                }
                .foregroundStyle(Theme.sea)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Theme.foam)
                .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(isRestoring)
            .padding(.top, 12)

            HStack(spacing: 6) {
                Link("Privacy Policy", destination: URL(string: "https://puffincruisesamble.co.uk/privacy-policy/")!)
                Text("·").foregroundStyle(Theme.textMuted)
                Link("Terms of Use", destination: URL(string: "https://puffincruisesamble.co.uk/terms-conditions/")!)
            }
            .font(.system(size: 12, weight: .bold))
            .tint(Theme.sea)
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
        }
        .padding(18)
        .background(.white)
        .clipShape(.rect(cornerRadius: 28))
        .padding(16)
    }

    private func benefit(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 15)).foregroundStyle(Theme.sea).frame(width: 20)
            Text(text).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.text)
            Spacer(minLength: 0)
        }
    }

    private var passCreator: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create your QR pass")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Theme.text)
            Text("Use the same email you want crew to recognise. Admin scanning will deduct 1 credit.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
                .lineSpacing(4)

            TextField("Your email", text: $email)
                .font(.system(size: 15))
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Theme.bg)
                .clipShape(.rect(cornerRadius: 16))
                .onChange(of: email) { _, value in
                    UserDefaults.standard.set(value.lowercased(), forKey: memberEmailKey)
                }

            Button { Task { await syncPass() } } label: {
                Group {
                    if isSyncing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Create QR Pass").font(.system(size: 16, weight: .black))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.coral)
                .clipShape(.rect(cornerRadius: 18))
            }
            .disabled(email.trimmingCharacters(in: .whitespaces).isEmpty || isSyncing)
            .opacity(email.trimmingCharacters(in: .whitespaces).isEmpty || isSyncing ? 0.55 : 1)
        }
        .padding(16)
        .background(.white)
        .clipShape(.rect(cornerRadius: 24))
        .padding(.horizontal, 16)
    }

    private func memberPass(_ pass: MembershipPass) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "steeringwheel").foregroundStyle(Theme.sand)
                Text("Member Pass")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
            }
            Text(pass.email)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.8))

            QRCodeView(value: "PUFFIN_MEMBER:\(pass.memberId)", size: 200)
                .padding(.vertical, 6)

            Text("\(pass.creditsRemaining) / \(pass.creditsTotal) trips remaining")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(Theme.sand)
            Text("Valid until \(pass.expiryDisplay)")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))

            Button {
                UIPasteboard.general.string = pass.memberId
                showCopied = true
            } label: {
                Text(showCopied ? "Copied!" : "Copy member ID")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.deep)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Theme.sand)
                    .clipShape(.capsule)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Theme.ink)
        .clipShape(.rect(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(Theme.sand.opacity(0.3), lineWidth: 1) }
        .padding(16)
    }

    // MARK: - RevenueCat membership

    private func loadMembershipState() async {
        offeringPackage = await MembershipService.loadOfferingPackage()
        isMembershipActive = await MembershipService.isMembershipActive()
    }

    private func purchaseMembership() async {
        guard let package = offeringPackage else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            _ = try await MembershipService.purchase(package)
            isMembershipActive = await MembershipService.isMembershipActive()
            if isMembershipActive {
                if email.trimmingCharacters(in: .whitespaces).isEmpty {
                    statusMessage = "Membership active! Add your email below to create your QR pass."
                } else {
                    await syncPass()
                }
            }
        } catch {
            if (error as? ErrorCode) != .purchaseCancelledError {
                statusMessage = "The membership could not be started. Please try again."
            }
        }
    }

    private func restoreMembership() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            _ = try await MembershipService.restorePurchases()
            isMembershipActive = await MembershipService.isMembershipActive()
            statusMessage = isMembershipActive
                ? "Purchases restored. Your membership is active."
                : "No active membership found for this Apple ID."
        } catch {
            statusMessage = "Restore failed. Please try again."
        }
    }

    // MARK: - Persistence

    private func loadPersisted() {
        if let saved = UserDefaults.standard.string(forKey: memberEmailKey), email.isEmpty {
            email = saved
        }
        if let data = UserDefaults.standard.data(forKey: memberPassKey),
           let saved = try? JSONDecoder().decode(MembershipPass.self, from: data) {
            pass = saved
        }
    }

    private func syncPass() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            let info = await MembershipService.customerInfo()
            let next = try await BookingAPI.syncMembership(
                memberId: MembershipService.memberID(),
                email: email,
                active: await MembershipService.isMembershipActive(),
                expiresAt: MembershipService.activeExpirationISO(from: info)
            )
            pass = next
            if let data = try? JSONEncoder().encode(next) {
                UserDefaults.standard.set(data, forKey: memberPassKey)
            }
            statusMessage = "Your QR pass is ready to use."
        } catch {
            statusMessage = "Could not create your pass. Please check your email and connection, then try again."
        }
    }
}
