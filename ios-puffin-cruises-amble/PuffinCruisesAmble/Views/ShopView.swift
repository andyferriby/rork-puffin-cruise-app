import SwiftUI

struct ShopView: View {
    @State private var products: [ShopProduct] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shop")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(Theme.text)
                    Text("Souvenirs and gifts from Amble Harbour.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textMuted)
                }

                HStack(spacing: 10) {
                    Image(systemName: "crown.fill").foregroundStyle(Theme.sand)
                    Text("Members get 10% off in store — show your QR pass at the counter.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineSpacing(3)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.deep)
                .clipShape(.rect(cornerRadius: 16))

                if isLoading {
                    ProgressView().tint(Theme.sea)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                } else if products.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "bag")
                            .font(.system(size: 38))
                            .foregroundStyle(Theme.textMuted)
                        Text("Shop coming soon")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(Theme.text)
                        Text("Merchandise will appear here once the online store is connected.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textMuted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                    .puffinCard(radius: 22, fill: .white)
                } else {
                    VStack(spacing: 12) {
                        ForEach(products) { product in
                            productCard(product)
                        }
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Theme.bg)
        .navigationTitle("Shop")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            products = await BookingAPI.fetchShopProducts()
            isLoading = false
        }
    }

    private func productCard(_ product: ShopProduct) -> some View {
        Link(destination: URL(string: product.permalink) ?? URL(string: "https://puffincruisesamble.co.uk")!) {
            HStack(spacing: 14) {
                Color(.secondarySystemBackground)
                    .frame(width: 84, height: 84)
                    .overlay {
                        AsyncImage(url: product.imageURL) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                                    .allowsHitTesting(false)
                            } else {
                                Image(systemName: "bag.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Theme.textMuted)
                            }
                        }
                    }
                    .clipShape(.rect(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 6) {
                        Text("£\(product.price)")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Theme.sea)
                        if product.on_sale {
                            Text("SALE")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Theme.coral)
                                .clipShape(.capsule)
                        }
                    }
                    if product.stock_status != "instock" {
                        Text("Out of stock")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.coral)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(12)
            .puffinCard(radius: 18, fill: .white)
        }
        .buttonStyle(.plain)
    }
}
