import SwiftUI

struct MembershipView: View {
    @State private var email = ""
    @State private var pass: MembershipPass?
    @State private var isSyncing = false
    @State private var statusMessage: String?
    @State private var showCopied = false

    private let memberIdKey = "puffin_member_id"
    private let memberEmailKey = "puffin_member_email"
    private let memberPassKey = "puffin_member_pass"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    priceCard
                    passCreator
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
            Text("£100/year")
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

            Link(destination: URL(string: "https://puffincruisesamble.co.uk/membership/")!) {
                Text("Start Membership")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.coral)
                    .clipShape(.rect(cornerRadius: 18))
            }

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

    // MARK: - Persistence

    private func memberId() -> String {
        if let existing = UserDefaults.standard.string(forKey: memberIdKey) { return existing }
        let next = "mem_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(8))"
        UserDefaults.standard.set(next, forKey: memberIdKey)
        return next
    }

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
        let expiry = ISO8601DateFormatter().string(from: Date().addingTimeInterval(365 * 24 * 60 * 60))
        do {
            let next = try await BookingAPI.syncMembership(
                memberId: memberId(),
                email: email,
                active: true,
                expiresAt: expiry
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
