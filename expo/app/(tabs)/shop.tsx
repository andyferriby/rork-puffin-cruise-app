import { fetchProducts, type WooProduct } from "@/lib/shop";
import { theme, radius, spacing } from "@/constants/theme";
import { useQuery } from "@tanstack/react-query";
import * as WebBrowser from "expo-web-browser";
import { ExternalLink, Package, ShoppingBag } from "lucide-react-native";
import React, { useCallback, useState } from "react";
import {
  ActivityIndicator,
  Dimensions,
  Image,
  Linking,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

const SCREEN_WIDTH = Dimensions.get("window").width;
const CARD_GAP = spacing.md;
const CARD_WIDTH = (SCREEN_WIDTH - spacing.xl * 2 - CARD_GAP) / 2;

export default function ShopScreen() {
  const insets = useSafeAreaInsets();
  const [selectedProduct, setSelectedProduct] = useState<WooProduct | null>(null);

  const { data: products = [], isLoading } = useQuery({
    queryKey: ["woocommerce-products"],
    queryFn: fetchProducts,
    staleTime: 120_000,
  });

  const handleBuy = useCallback(async (permalink: string) => {
    if (Platform.OS === "web") {
      window.open(permalink, "_blank");
      return;
    }
    try {
      await WebBrowser.openBrowserAsync(permalink, {
        toolbarColor: theme.deep,
        controlsColor: theme.white,
      });
    } catch {
      Linking.openURL(permalink);
    }
  }, []);

  const formatPrice = useCallback((p: WooProduct) => {
    if (p.on_sale && p.sale_price) {
      return (
        <View style={styles.priceRow}>
          <Text style={styles.salePrice}>£{p.sale_price}</Text>
          <Text style={styles.regularPriceStrikethrough}>£{p.regular_price}</Text>
        </View>
      );
    }
    return <Text style={styles.price}>£{p.price || p.regular_price}</Text>;
  }, []);

  return (
    <View style={[styles.root, { paddingTop: insets.top }]}>
      <ScrollView
        contentContainerStyle={[
          styles.scrollContent,
          { paddingBottom: insets.bottom + spacing.xl },
        ]}
      >
        <View style={styles.header}>
          <Text style={styles.title}>Shop</Text>
          <Text style={styles.subtitle}>Puffin Cruises store</Text>
        </View>

        {isLoading ? (
          <View style={styles.loadingWrap}>
            <ActivityIndicator color={theme.sea} size="large" />
            <Text style={styles.loadingText}>Loading products…</Text>
          </View>
        ) : products.length === 0 ? (
          <View style={styles.emptyWrap}>
            <Package size={40} color={theme.textMuted} />
            <Text style={styles.emptyTitle}>No products yet</Text>
            <Text style={styles.emptyText}>
              The shop hasn't been configured or no products are available. The
              crew can set up WooCommerce from the admin panel.
            </Text>
          </View>
        ) : (
          <>
            {/* Product Grid */}
            <View style={styles.grid}>
              {products.map((product) => (
                <Pressable
                  key={product.id}
                  style={styles.card}
                  onPress={() => setSelectedProduct(product)}
                >
                  <View style={styles.imageWrap}>
                    {product.images?.[0]?.src ? (
                      <Image
                        source={{ uri: product.images[0].src }}
                        style={styles.image}
                        resizeMode="cover"
                      />
                    ) : (
                      <View style={styles.imagePlaceholder}>
                        <ShoppingBag size={24} color={theme.textMuted} />
                      </View>
                    )}
                    {product.on_sale && (
                      <View style={styles.saleBadge}>
                        <Text style={styles.saleBadgeText}>SALE</Text>
                      </View>
                    )}
                    {product.stock_status === "outofstock" && (
                      <View style={styles.outOfStockOverlay}>
                        <Text style={styles.outOfStockText}>Sold out</Text>
                      </View>
                    )}
                  </View>
                  <View style={styles.cardBody}>
                    <Text style={styles.productName} numberOfLines={2}>
                      {product.name}
                    </Text>
                    {formatPrice(product)}
                  </View>
                </Pressable>
              ))}
            </View>
          </>
        )}

        {/* Product Detail Modal */}
        {selectedProduct && (
          <View style={styles.overlay}>
            <Pressable
              style={styles.backdrop}
              onPress={() => setSelectedProduct(null)}
            />
            <View style={styles.sheet}>
              <ScrollView bounces={false}>
                <View style={styles.sheetImageWrap}>
                  {selectedProduct.images?.[0]?.src ? (
                    <Image
                      source={{ uri: selectedProduct.images[0].src }}
                      style={styles.sheetImage}
                      resizeMode="cover"
                    />
                  ) : (
                    <View style={styles.sheetImagePlaceholder}>
                      <ShoppingBag size={48} color={theme.textMuted} />
                    </View>
                  )}
                </View>

                <View style={styles.sheetBody}>
                  <Text style={styles.sheetName}>{selectedProduct.name}</Text>
                  <View style={styles.sheetPriceRow}>
                    {selectedProduct.on_sale && selectedProduct.sale_price ? (
                      <>
                        <Text style={styles.sheetSalePrice}>
                          £{selectedProduct.sale_price}
                        </Text>
                        <Text style={styles.sheetRegularPrice}>
                          £{selectedProduct.regular_price}
                        </Text>
                      </>
                    ) : (
                      <Text style={styles.sheetPrice}>
                        £{selectedProduct.price || selectedProduct.regular_price}
                      </Text>
                    )}
                    {selectedProduct.stock_status === "instock" && (
                      <View style={styles.inStockBadge}>
                        <Text style={styles.inStockText}>In stock</Text>
                      </View>
                    )}
                    {selectedProduct.stock_status === "outofstock" && (
                      <View style={styles.outOfStockBadge}>
                        <Text style={styles.outOfStockText}>
                          Out of stock
                        </Text>
                      </View>
                    )}
                  </View>

                  {selectedProduct.short_description ? (
                    <Text style={styles.sheetDesc}>
                      {selectedProduct.short_description.replace(/<\/?[^>]+(>|$)/g, "")}
                    </Text>
                  ) : null}

                  <Pressable
                    style={[
                      styles.buyBtn,
                      selectedProduct.stock_status === "outofstock" &&
                        styles.buyBtnDisabled,
                    ]}
                    disabled={selectedProduct.stock_status === "outofstock"}
                    onPress={() => handleBuy(selectedProduct.permalink)}
                  >
                    <ExternalLink size={18} color={theme.white} />
                    <Text style={styles.buyBtnText}>
                      {selectedProduct.stock_status === "outofstock"
                        ? "Unavailable"
                        : "Buy on Website"}
                    </Text>
                  </Pressable>

                  <Pressable
                    onPress={() => setSelectedProduct(null)}
                    style={styles.closeBtn}
                  >
                    <Text style={styles.closeBtnText}>Close</Text>
                  </Pressable>
                </View>
              </ScrollView>
            </View>
          </View>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: theme.bg,
  },
  scrollContent: {
    paddingHorizontal: spacing.xl,
    paddingTop: spacing.md,
  },
  header: {
    gap: spacing.xs,
    marginBottom: spacing.xl,
  },
  title: {
    fontSize: 28,
    fontWeight: "800",
    color: theme.text,
  },
  subtitle: {
    fontSize: 14,
    color: theme.textMuted,
  },
  loadingWrap: {
    alignItems: "center",
    paddingVertical: 80,
    gap: spacing.md,
  },
  loadingText: {
    color: theme.textMuted,
    fontSize: 14,
  },
  emptyWrap: {
    alignItems: "center",
    paddingVertical: 80,
    gap: spacing.md,
  },
  emptyTitle: {
    fontSize: 16,
    fontWeight: "700",
    color: theme.text,
  },
  emptyText: {
    fontSize: 14,
    color: theme.textMuted,
    textAlign: "center",
    lineHeight: 20,
  },

  // Grid
  grid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: CARD_GAP,
  },
  card: {
    width: CARD_WIDTH,
    backgroundColor: theme.white,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: theme.border,
    overflow: "hidden",
  },
  imageWrap: {
    width: "100%",
    aspectRatio: 1,
    backgroundColor: theme.foam,
    position: "relative",
  },
  image: {
    width: "100%",
    height: "100%",
  },
  imagePlaceholder: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: theme.foam,
  },
  saleBadge: {
    position: "absolute",
    top: spacing.sm,
    left: spacing.sm,
    backgroundColor: theme.coral,
    paddingHorizontal: spacing.sm,
    paddingVertical: 2,
    borderRadius: radius.sm,
  },
  saleBadgeText: {
    color: theme.white,
    fontSize: 10,
    fontWeight: "800",
    letterSpacing: 0.5,
  },
  outOfStockOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(0,0,0,0.45)",
    alignItems: "center",
    justifyContent: "center",
  },
  outOfStockText: {
    color: theme.white,
    fontSize: 13,
    fontWeight: "800",
  },
  cardBody: {
    padding: spacing.md,
    gap: spacing.xs,
  },
  productName: {
    fontSize: 13,
    fontWeight: "600",
    color: theme.text,
    lineHeight: 18,
  },
  price: {
    fontSize: 15,
    fontWeight: "800",
    color: theme.sea,
  },
  priceRow: {
    flexDirection: "row",
    alignItems: "baseline",
    gap: spacing.sm,
  },
  salePrice: {
    fontSize: 15,
    fontWeight: "800",
    color: theme.coral,
  },
  regularPriceStrikethrough: {
    fontSize: 13,
    fontWeight: "500",
    color: theme.textMuted,
    textDecorationLine: "line-through",
  },

  // Detail sheet
  overlay: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: "flex-end",
    zIndex: 100,
  },
  backdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(0,0,0,0.4)",
  },
  sheet: {
    backgroundColor: theme.white,
    borderTopLeftRadius: radius.xl,
    borderTopRightRadius: radius.xl,
    maxHeight: "85%",
  },
  sheetImageWrap: {
    width: "100%",
    aspectRatio: 16 / 9,
    backgroundColor: theme.foam,
  },
  sheetImage: {
    width: "100%",
    height: "100%",
  },
  sheetImagePlaceholder: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: theme.foam,
  },
  sheetBody: {
    padding: spacing.xl,
    gap: spacing.md,
  },
  sheetName: {
    fontSize: 20,
    fontWeight: "800",
    color: theme.text,
  },
  sheetPriceRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.md,
  },
  sheetPrice: {
    fontSize: 20,
    fontWeight: "800",
    color: theme.sea,
  },
  sheetSalePrice: {
    fontSize: 20,
    fontWeight: "800",
    color: theme.coral,
  },
  sheetRegularPrice: {
    fontSize: 15,
    color: theme.textMuted,
    textDecorationLine: "line-through",
  },
  inStockBadge: {
    backgroundColor: "#E6F7ED",
    paddingHorizontal: spacing.sm,
    paddingVertical: 2,
    borderRadius: radius.sm,
  },
  inStockText: {
    color: "#1B7A3D",
    fontSize: 11,
    fontWeight: "700",
  },
  outOfStockBadge: {
    backgroundColor: "#FDE8E8",
    paddingHorizontal: spacing.sm,
    paddingVertical: 2,
    borderRadius: radius.sm,
  },
  sheetDesc: {
    fontSize: 14,
    color: theme.textMuted,
    lineHeight: 20,
  },
  buyBtn: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: spacing.sm,
    backgroundColor: theme.sea,
    paddingVertical: 14,
    borderRadius: radius.md,
    marginTop: spacing.sm,
  },
  buyBtnDisabled: {
    opacity: 0.4,
  },
  buyBtnText: {
    color: theme.white,
    fontSize: 15,
    fontWeight: "700",
  },
  closeBtn: {
    alignItems: "center",
    paddingVertical: spacing.md,
  },
  closeBtnText: {
    fontSize: 14,
    fontWeight: "600",
    color: theme.textMuted,
  },
});
