import SwiftUI

/// Crew editor for the Places to Eat list, stored in Supabase `app_config`
/// under `places_to_eat` — the same key the Expo admin panel and Watch use.
struct PlacesAdminSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var places: [PlaceToEat] = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?
    @State private var editingPlace: PlaceToEat?
    @State private var showNewPlace = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading places…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if places.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.textMuted)
                        Text("No places yet")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.text)
                        Text("Tap + to add the first place to eat.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if let error {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.coral)
                        }
                        ForEach(places) { place in
                            Button { editingPlace = place } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(place.name)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(Theme.text)
                                        Text(place.category.isEmpty ? "No category" : place.category)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Theme.textMuted)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.textMuted)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Theme.bg)
            .navigationTitle("Places to Eat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewPlace = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add place")
                }
            }
            .task { await load() }
            .sheet(isPresented: $showNewPlace) {
                PlaceFormSheet(place: nil) { place in
                    places.append(place)
                    Task { await persist() }
                }
            }
            .sheet(item: $editingPlace) { place in
                PlaceFormSheet(place: place) { updated in
                    if let index = places.firstIndex(where: { $0.id == updated.id }) {
                        places[index] = updated
                    }
                    Task { await persist() }
                }
            }
        }
    }

    private func load() async {
        places = await SupabaseService.fetchPlacesToEat()
        isLoading = false
    }

    private func persist() async {
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            try await SupabaseService.savePlacesToEat(places)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            self.error = "Couldn't save changes. Check your connection and try again."
        }
    }
}

/// Add / edit form for a single place. Calls back with the saved place;
/// the parent list owns persistence.
private struct PlaceFormSheet: View {
    @Environment(\.dismiss) private var dismiss

    let place: PlaceToEat?
    let onSave: (PlaceToEat) -> Void

    @State private var name = ""
    @State private var category = ""
    @State private var blurb = ""
    @State private var info = ""
    @State private var imageURL = ""
    @State private var showsWholeImage = false
    @State private var phone = ""
    @State private var website = ""
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var validationError: String?

    private var isNameValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Name (e.g. The Harbour Fish Bar)", text: $name)
                    TextField("Category (e.g. Fish & Chips)", text: $category)
                    TextField("Short blurb", text: $blurb, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Details (opening hours, menu…)", text: $info, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    TextField("Picture URL (https://…)", text: $imageURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    if !imageURL.trimmingCharacters(in: .whitespaces).isEmpty {
                        Picker("Banner display", selection: $showsWholeImage) {
                            Text("Fill banner (crops)").tag(false)
                            Text("Whole image (fits)").tag(true)
                        }
                    }
                    TextField("Phone (e.g. 01665 710 000)", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Website (https://…)", text: $website)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Links")
                } footer: {
                    Text("Best size for the banner: 1200 × 800 px, landscape. Fill banner crops the picture to a wide strip; Whole image shows it uncropped — best for logos or portrait photos.")
                }

                Section {
                    TextField("Latitude (e.g. 55.3338)", text: $latitudeText)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Longitude (e.g. -1.5803)", text: $longitudeText)
                        .keyboardType(.numbersAndPunctuation)
                } header: {
                    Text("Location")
                } footer: {
                    Text("Use the exact pin location so Apple Maps walking directions land in the right spot.")
                }

                if let validationError {
                    Text(validationError)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                }
            }
            .navigationTitle(place == nil ? "New Place" : "Edit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .font(.system(size: 16, weight: .bold))
                        .disabled(!isNameValid)
                }
            }
            .onAppear(perform: populate)
        }
    }

    private func populate() {
        guard let place else { return }
        name = place.name
        category = place.category
        blurb = place.blurb
        info = place.info
        imageURL = place.imageURL ?? ""
        showsWholeImage = place.displaysWholeImage
        phone = place.phone ?? ""
        website = place.website ?? ""
        latitudeText = String(place.latitude)
        longitudeText = String(place.longitude)
    }

    private func save() {
        guard let latitude = Double(latitudeText.trimmingCharacters(in: .whitespaces)),
              let longitude = Double(longitudeText.trimmingCharacters(in: .whitespaces)),
              latitude >= -90, latitude <= 90, longitude >= -180, longitude <= 180 else {
            validationError = "Latitude and longitude must be valid numbers, e.g. 55.3338 and -1.5803."
            return
        }
        let cleanedImage = imageURL.trimmingCharacters(in: .whitespaces)
        let cleanedWebsite = website.trimmingCharacters(in: .whitespaces)
        for (label, value) in [("picture URL", cleanedImage), ("website", cleanedWebsite)] where !value.isEmpty {
            if URL(string: value) == nil || !(value.hasPrefix("http://") || value.hasPrefix("https://")) {
                validationError = "The \(label) should be a full web address starting with https://"
                return
            }
        }
        let saved = PlaceToEat(
            id: place?.id ?? UUID().uuidString.lowercased(),
            name: name.trimmingCharacters(in: .whitespaces),
            category: category.trimmingCharacters(in: .whitespaces),
            blurb: blurb.trimmingCharacters(in: .whitespaces),
            info: info.trimmingCharacters(in: .whitespaces),
            latitude: latitude,
            longitude: longitude,
            imageURL: cleanedImage.isEmpty ? nil : cleanedImage,
            phone: phone.trimmingCharacters(in: .whitespaces).isEmpty ? nil : phone.trimmingCharacters(in: .whitespaces),
            website: cleanedWebsite.isEmpty ? nil : cleanedWebsite,
            imageFit: cleanedImage.isEmpty ? nil : (showsWholeImage ? "fit" : "fill")
        )
        onSave(saved)
        dismiss()
    }
}
