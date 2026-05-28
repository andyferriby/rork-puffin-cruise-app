import SwiftUI
import UIKit

struct TicketDetailView: View {
    let booking: Booking
    @Environment(\.dismiss) private var dismiss

    @State private var walletError: String?
    @State private var walletLoading = false
    @State private var existingReview: Review?
    @State private var reviewRating = 0
    @State private var reviewComment = ""
    @State private var submittingReview = false
    @State private var reviewSubmitted = false

    private var isPastCruise: Bool {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let cruiseDate = f.date(from: booking.cruiseDate) else { return false }
        return cruiseDate < Date()
    }

    private var canReview: Bool {
        booking.isPaid && isPastCruise && existingReview == nil && !reviewSubmitted
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ticketCard
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                if canReview || (existingReview != nil || reviewSubmitted) {
                    reviewSection
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                }

                actions
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
            }
        }
        .background(Theme.bg)
        .presentationDragIndicator(.visible)
        .task { await loadReview() }
        .alert("Apple Wallet", isPresented: .constant(walletError != nil)) {
            Button("OK") { walletError = nil }
        } message: {
            Text(walletError ?? "")
        }
    }

    private var ticketCard: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("🐧")
                        .font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("PUFFIN CRUISES")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.4)
                            .foregroundStyle(.white.opacity(0.85))
                        Text("Boarding Pass")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    statusBadge
                }

                Text(booking.cruiseName)
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.top, 6)

                HStack(spacing: 24) {
                    detailColumn(label: "DATE", value: formatDate(booking.cruiseDate))
                    detailColumn(label: "TIME", value: booking.cruiseTime)
                }
                .padding(.top, 10)

                HStack(spacing: 24) {
                    detailColumn(label: "PASSENGERS", value: booking.passengerSummary)
                    detailColumn(label: "TOTAL", value: String(format: "£%.2f", booking.totalPounds))
                }
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Theme.deep, Theme.sea, Theme.wave],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            perforatedDivider

            VStack(spacing: 14) {
                if let qr = QRCodeService.generate(booking.id) {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(12)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Theme.border, lineWidth: 1)
                        )
                }

                VStack(spacing: 2) {
                    Text("REFERENCE")
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(Theme.textMuted)
                    Text(booking.id.prefix(8).uppercased())
                        .font(.system(size: 18, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Theme.text)
                }

                Text("Show this code to the crew at boarding.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Theme.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Theme.deep.opacity(0.18), radius: 24, y: 12)
    }

    private var statusBadge: some View {
        let isCheckedIn = booking.isCheckedIn
        return HStack(spacing: 4) {
            Image(systemName: isCheckedIn ? "checkmark.seal.fill" : "checkmark.circle.fill")
                .font(.system(size: 11))
            Text(isCheckedIn ? "CHECKED IN" : "CONFIRMED")
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.6)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isCheckedIn ? Color.green : Color.white.opacity(0.22))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.3)))
    }

    private func detailColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var perforatedDivider: some View {
        ZStack {
            Rectangle()
                .fill(Theme.card)
                .frame(height: 28)

            HStack(spacing: 6) {
                ForEach(0..<28, id: \.self) { _ in
                    Circle()
                        .fill(Theme.bg)
                        .frame(width: 5, height: 5)
                }
            }

            HStack {
                Circle()
                    .fill(Theme.bg)
                    .frame(width: 24, height: 24)
                    .offset(x: -12)
                Spacer()
                Circle()
                    .fill(Theme.bg)
                    .frame(width: 24, height: 24)
                    .offset(x: 12)
            }
        }
    }

    // MARK: - Review Section

    private var reviewSection: some View {
        VStack(spacing: 14) {
            if let review = existingReview {
                postedReviewCard(review)
            } else if reviewSubmitted {
                thankYouCard
            } else if canReview {
                reviewForm
            }
        }
    }

    private var reviewForm: some View {
        VStack(spacing: 14) {
            Text("How was your cruise?")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Theme.text)

            // Star picker
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            reviewRating = star
                        }
                    } label: {
                        Image(systemName: star <= reviewRating ? "star.fill" : "star")
                            .font(.system(size: 32))
                            .foregroundStyle(star <= reviewRating ? Theme.coral : Theme.border)
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("Share your experience (optional)", text: $reviewComment, axis: .vertical)
                .font(.system(size: 14))
                .padding(12)
                .background(Theme.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.border))
                .lineLimit(3...6)

            Button {
                Task { await submitReview() }
            } label: {
                HStack(spacing: 8) {
                    if submittingReview {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                    Text(submittingReview ? "Posting..." : "Submit review")
                        .font(.system(size: 14, weight: .heavy))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(reviewRating > 0 ? Theme.coral : Theme.coral.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(reviewRating == 0 || submittingReview)
        }
        .padding(18)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.border))
    }

    private func postedReviewCard(_ review: Review) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= review.rating ? "star.fill" : "star")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.coral)
                }
            }

            if let comment = review.comment, !comment.isEmpty {
                Text("\"\(comment)\"")
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Text("Your review")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.coral.opacity(0.2)))
    }

    private var thankYouCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.coral)

            Text("Thanks for your review!")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(Theme.text)

            Text("Your feedback helps other passengers choose their adventure.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.border))
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                Task { await addToWallet() }
            } label: {
                HStack(spacing: 10) {
                    if walletLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "wallet.pass.fill")
                            .font(.system(size: 18))
                    }
                    Text("Add to Apple Wallet")
                        .font(.system(size: 15, weight: .heavy))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(walletLoading)

            Button {
                shareTicket()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                        .fontWeight(.bold)
                }
                .font(.system(size: 14))
                .foregroundStyle(Theme.sea)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.foam)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Helpers

    private func loadReview() async {
        existingReview = await SupabaseService.shared.fetchReviews(forBooking: booking.id)
    }

    private func submitReview() async {
        guard reviewRating > 0 else { return }
        submittingReview = true
        do {
            let insert = ReviewInsert(
                bookingId: booking.id,
                cruiseId: booking.cruiseId ?? "",
                cruiseName: booking.cruiseName,
                rating: reviewRating,
                comment: reviewComment.trimmingCharacters(in: .whitespaces).isEmpty ? nil : reviewComment.trimmingCharacters(in: .whitespaces),
                guestName: booking.customerName
            )
            try await SupabaseService.shared.submitReview(insert)
            reviewSubmitted = true
        } catch {
            print("[review] submit error:", error.localizedDescription)
        }
        submittingReview = false
    }

    private func addToWallet() async {
        walletLoading = true
        defer { walletLoading = false }
        let scenes = UIApplication.shared.connectedScenes
        let window = scenes.compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        let topVC = window?.rootViewController?.topMostController()
        do {
            try await WalletService.addToWallet(bookingId: booking.id, presenter: topVC)
        } catch {
            walletError = error.localizedDescription
        }
    }

    private func shareTicket() {
        let text = """
        Puffin Cruises Booking
        \(booking.cruiseName) — \(formatDate(booking.cruiseDate)) at \(booking.cruiseTime)
        Ref: \(booking.id.prefix(8).uppercased())
        \(booking.passengerSummary)
        """
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        let scenes = UIApplication.shared.connectedScenes
        let window = scenes.compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        window?.rootViewController?.topMostController().present(av, animated: true)
    }

    private func formatDate(_ str: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: str) else { return str }
        f.dateFormat = "EEE d MMM"
        return f.string(from: d)
    }
}

extension UIViewController {
    func topMostController() -> UIViewController {
        if let presented = self.presentedViewController {
            return presented.topMostController()
        }
        if let nav = self as? UINavigationController, let visible = nav.visibleViewController {
            return visible.topMostController()
        }
        if let tab = self as? UITabBarController, let selected = tab.selectedViewController {
            return selected.topMostController()
        }
        return self
    }
}
