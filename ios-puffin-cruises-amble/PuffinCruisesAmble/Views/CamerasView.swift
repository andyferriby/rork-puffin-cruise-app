import SwiftUI
import WebKit

struct CamerasView: View {
    @State private var videos: [CameraVideo] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Cameras")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundStyle(Theme.text)
                    Text("Coquet Island live feed")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textMuted)
                }

                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView().tint(Theme.sea)
                        Text("Loading streams…").font(.system(size: 14)).foregroundStyle(Theme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                } else if videos.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.textMuted)
                        Text("No live streams")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.text)
                        Text("The crew hasn't configured any cameras yet. Check back later.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textMuted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                } else {
                    ForEach(videos) { video in
                        VStack(spacing: 0) {
                            HStack(spacing: 8) {
                                Circle().fill(Theme.coral).frame(width: 8, height: 8)
                                Text(video.label)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Theme.deep)

                            YouTubePlayer(videoId: video.id)
                                .aspectRatio(16 / 9, contentMode: .fit)
                                .background(Theme.ink)
                        }
                        .clipShape(.rect(cornerRadius: 20))
                        .overlay { RoundedRectangle(cornerRadius: 20).stroke(Theme.border, lineWidth: 1) }
                    }
                }
            }
            .padding(24)
        }
        .background(Theme.bg)
        .navigationTitle("Live Cameras")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            videos = await SupabaseService.fetchCameras()
            isLoading = false
        }
    }
}

/// Embeds a YouTube stream, matching the RN youtube-iframe player.
struct YouTubePlayer: UIViewRepresentable {
    let videoId: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: "https://www.youtube.com/embed/\(videoId)?playsinline=1&modestbranding=1&rel=0") else { return }
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}
