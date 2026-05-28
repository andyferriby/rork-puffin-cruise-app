import SwiftUI

struct NotificationsView: View {
    @State private var notifications: [NotificationRecord] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            header

            if isLoading {
                Spacer()
                ProgressView().tint(Theme.sea)
                Spacer()
            } else if notifications.isEmpty {
                emptyState
            } else {
                notificationList
            }
        }
        .background(Theme.bg)
        .task { await loadNotifications() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Notifications")
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(Theme.text)
            Text("Updates from the crew about sailings, weather, and more.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell")
                .font(.system(size: 44))
                .foregroundStyle(Theme.sea)
                .frame(width: 88, height: 88)
                .background(Theme.foam)
                .clipShape(Circle())

            Text("No notifications yet")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Theme.text)
            Text("When the crew sends updates about schedules, weather, or special offers, they'll appear here.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 40)
    }

    // MARK: - List

    private var notificationList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(notifications) { notif in
                    notificationCard(notif)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    private func notificationCard(_ notif: NotificationRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: iconFor(notif.title))
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Theme.sea)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(notif.title)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text(formatDate(notif.sentAt))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted)
                }

                Spacer()

                if notif.recipientCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text("\(notif.recipientCount)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Theme.sea)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.foam)
                    .clipShape(Capsule())
                }
            }

            Text(notif.body)
                .font(.system(size: 14))
                .foregroundStyle(Theme.text)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.border))
        .shadow(color: Theme.deep.opacity(0.04), radius: 8, y: 3)
    }

    // MARK: - Helpers

    private func loadNotifications() async {
        notifications = await SupabaseService.shared.fetchNotifications()
        isLoading = false
    }

    private func iconFor(_ title: String) -> String {
        let t = title.lowercased()
        if t.contains("weather") || t.contains("tide") { return "cloud.sun.fill" }
        if t.contains("schedule") || t.contains("sailing") || t.contains("time") { return "calendar.badge.clock" }
        if t.contains("offer") || t.contains("special") || t.contains("deal") { return "tag.fill" }
        if t.contains("alert") || t.contains("urgent") || t.contains("cancel") { return "exclamationmark.triangle.fill" }
        return "bell.fill"
    }

    private func formatDate(_ str: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = f.date(from: str) ?? ISO8601DateFormatter().date(from: str) else { return str }
        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .abbreviated
        return rel.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NotificationsView()
}
