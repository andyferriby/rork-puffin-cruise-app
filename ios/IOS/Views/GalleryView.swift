import SwiftUI
import PhotosUI

struct GalleryView: View {
    @State private var photos: [GalleryPhoto] = []
    @State private var isLoading = true

    @State private var showUpload = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var pendingImage: UIImage?
    @State private var caption = ""
    @State private var guestName = ""
    @State private var isUploading = false
    @State private var showCamera = false
    @State private var errorMessage: String?

    private let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

    var body: some View {
        VStack(spacing: 0) {
            header
            actionButtons

            if isLoading {
                Spacer()
                ProgressView().tint(Theme.sea)
                Spacer()
            } else if photos.isEmpty {
                emptyState
            } else {
                photoGrid
            }
        }
        .background(Theme.bg)
        .task { await loadPhotos() }
        .sheet(isPresented: $showUpload) {
            uploadSheet
        }
        .sheet(isPresented: $showCamera) {
            cameraPicker
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    pendingImage = image
                    showUpload = true
                }
                selectedPhotoItem = nil
            }
        }
        .alert("Upload failed", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Guest Gallery")
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(Theme.text)
            Text("Share your favourite moments from on board.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button { showCamera = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera")
                    Text("Take photo")
                        .fontWeight(.bold)
                }
                .font(.system(size: 14))
                .foregroundStyle(Theme.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Theme.sea)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                    Text("From library")
                        .fontWeight(.bold)
                }
                .font(.system(size: 14))
                .foregroundStyle(Theme.sea)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Theme.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.sea, lineWidth: 1.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Grid

    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(photos) { photo in
                    photoTile(photo)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    private func photoTile(_ photo: GalleryPhoto) -> some View {
        Color(Theme.foam)
            .aspectRatio(1, contentMode: .fill)
            .overlay {
                AsyncImage(url: URL(string: photo.imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                } placeholder: {
                    Color(Theme.foam)
                }
            }
            .overlay(alignment: .bottom) {
                if photo.caption != nil || photo.guestName != nil {
                    VStack(alignment: .leading, spacing: 2) {
                        if let caption = photo.caption {
                            Text(caption)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.white)
                                .lineLimit(2)
                        }
                        if let name = photo.guestName {
                            Text("— \(name)")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.white.opacity(0.85))
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.deep.opacity(0.55))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("📸")
                .font(.system(size: 48))
            Text("Be the first to share a photo")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.text)
            Text("Snap a puffin, seal or sunset and add it to the public gallery.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(40)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Upload Sheet

    private var uploadSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Share your photo")
                    .font(.system(size: 20, weight: .heavy))
                Spacer()
                Button { showUpload = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.textMuted)
                }
            }

            if let image = pendingImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .clipped()
            }

            TextField("Caption (optional)", text: $caption)
                .font(.system(size: 15))
                .padding(12)
                .background(Theme.bg)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            TextField("Your name (optional)", text: $guestName)
                .font(.system(size: 15))
                .padding(12)
                .background(Theme.bg)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                uploadPhoto()
            } label: {
                if isUploading {
                    ProgressView().tint(Theme.white)
                } else {
                    Text("Post to gallery")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.sea)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .disabled(isUploading)
        }
        .padding(20)
        .padding(.bottom, 40)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Camera Picker

    private var cameraPicker: some View {
        CameraPickerView { image in
            pendingImage = image
            showCamera = false
            showUpload = true
        }
    }

    // MARK: - Actions

    private func loadPhotos() async {
        photos = await SupabaseService.shared.fetchPhotos()
        isLoading = false
    }

    private func uploadPhoto() {
        guard let image = pendingImage else { return }
        isUploading = true
        Task {
            do {
                guard let data = image.jpegData(compressionQuality: 0.7) else {
                    throw NSError(domain: "Gallery", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not process image"])
                }
                try await SupabaseService.shared.uploadPhoto(
                    data: data,
                    contentType: "image/jpeg",
                    caption: caption.trimmingCharacters(in: .whitespaces).isEmpty ? nil : caption.trimmingCharacters(in: .whitespaces),
                    guestName: guestName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : guestName.trimmingCharacters(in: .whitespaces)
                )
                showUpload = false
                pendingImage = nil
                caption = ""
                guestName = ""
                await loadPhotos()
            } catch {
                errorMessage = error.localizedDescription
            }
            isUploading = false
        }
    }
}

// MARK: - Camera Picker Wrapper

struct CameraPickerView: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }
    }
}

#Preview {
    GalleryView()
}
