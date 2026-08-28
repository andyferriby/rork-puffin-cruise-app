import SwiftUI

struct GalleryView: View {
    @State private var photos: [GalleryPhoto] = []
    @State private var isLoading = true
    @State private var selected: GalleryPhoto?

    private let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gallery")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(Theme.text)
                    Text("Photos shared by guests on the water.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textMuted)
                }

                if isLoading {
                    ProgressView().tint(Theme.sea)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                } else if photos.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 38))
                            .foregroundStyle(Theme.textMuted)
                        Text("No photos yet")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Theme.text)
                        Text("Guest photos appear here once the crew approves them.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textMuted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                    .puffinCard(radius: 22, fill: .white)
                } else {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(photos) { photo in
                            Button { selected = photo } label: {
                                Color(.secondarySystemBackground)
                                    .frame(height: 180)
                                    .overlay {
                                        AsyncImage(url: URL(string: photo.image_url)) { phase in
                                            switch phase {
                                            case let .success(image):
                                                image.resizable().aspectRatio(contentMode: .fill)
                                                    .allowsHitTesting(false)
                                            case .failure:
                                                Image(systemName: "photo")
                                                    .font(.system(size: 24))
                                                    .foregroundStyle(Theme.textMuted)
                                            default:
                                                ProgressView().tint(Theme.sea)
                                            }
                                        }
                                    }
                                    .clipShape(.rect(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Theme.bg)
        .navigationTitle("Gallery")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            photos = await SupabaseService.fetchGalleryPhotos()
            isLoading = false
        }
        .sheet(item: $selected) { photo in
            photoDetail(photo)
        }
    }

    private func photoDetail(_ photo: GalleryPhoto) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AsyncImage(url: URL(string: photo.image_url)) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else {
                            ProgressView().tint(Theme.sea).frame(height: 240)
                        }
                    }
                    .clipShape(.rect(cornerRadius: 18))

                    if let caption = photo.caption, !caption.isEmpty {
                        Text(caption)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.text)
                    }
                    if let guest = photo.guest_name, !guest.isEmpty {
                        Text("Shared by \(guest)")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
                .padding(16)
            }
            .background(Theme.bg)
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { selected = nil }
                }
            }
        }
    }
}
