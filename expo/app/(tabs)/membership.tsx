import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Image } from "expo-image";
import * as Clipboard from "expo-clipboard";
import { Crown, Gift, QrCode, RefreshCw, ShieldCheck, ShipWheel, ShoppingBag, Ticket } from "lucide-react-native";
import React, { useMemo, useState } from "react";
import { ActivityIndicator, Alert, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import Purchases, { PurchasesPackage } from "react-native-purchases";

import { theme } from "@/constants/theme";
import { getMembershipCustomerInfo, getMembershipOffering, hasMembership, restoreMembership, syncMembership, type MembershipPass } from "@/lib/membership";

function qrCodeUrl(memberId: string): string {
  return `https://api.qrserver.com/v1/create-qr-code/?size=260x260&data=${encodeURIComponent(`PUFFIN_MEMBER:${memberId}`)}&bgcolor=ffffff&color=0B2A4A`;
}

export default function MembershipScreen() {
  const insets = useSafeAreaInsets();
  const qc = useQueryClient();
  const [email, setEmail] = useState<string>("");

  const offeringQuery = useQuery({ queryKey: ["membership-offering"], queryFn: getMembershipOffering });
  const customerQuery = useQuery({ queryKey: ["membership-customer"], queryFn: getMembershipCustomerInfo });
  const packageToBuy = useMemo<PurchasesPackage | null>(() => offeringQuery.data?.availablePackages[0] ?? null, [offeringQuery.data]);
  const isActive = hasMembership(customerQuery.data);

  const syncMutation = useMutation({
    mutationFn: () => syncMembership(email),
    onSuccess: (pass: MembershipPass) => {
      qc.setQueryData(["membership-pass"], pass);
      Alert.alert("Membership ready", "Your QR pass is ready to use.");
    },
    onError: () => Alert.alert("Could not sync", "Please check your email and connection, then try again."),
  });

  const purchaseMutation = useMutation({
    mutationFn: async () => {
      if (!packageToBuy) throw new Error("No membership product available");
      const result = await Purchases.purchasePackage(packageToBuy);
      return result.customerInfo;
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["membership-customer"] });
      if (email.trim()) syncMutation.mutate();
    },
    onError: (err: unknown) => {
      const maybe = err as { userCancelled?: boolean };
      if (!maybe.userCancelled) Alert.alert("Purchase failed", "The membership could not be started. Please try again.");
    },
  });

  const restoreMutation = useMutation({
    mutationFn: restoreMembership,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["membership-customer"] });
      Alert.alert("Purchases restored", "If your membership is active, enter your email and tap Create QR Pass.");
    },
    onError: () => Alert.alert("Restore failed", "Please try again."),
  });

  const pass = qc.getQueryData<MembershipPass>(["membership-pass"]);
  const price = packageToBuy?.product.priceString ?? "£100/year";

  return (
    <View style={styles.root}>
      <ScrollView contentContainerStyle={{ paddingBottom: 36 }} keyboardShouldPersistTaps="handled">
        <View style={[styles.hero, { paddingTop: insets.top + 20 }]}>
          <View style={styles.heroIcon}><Crown size={34} color={theme.sand} /></View>
          <Text style={styles.kicker}>PUFFIN CREW MEMBER</Text>
          <Text style={styles.title}>12 boat trips a year, one simple pass.</Text>
          <Text style={styles.subtitle}>Includes 1 adult boat trip every month, plus 10% off in the shop.</Text>
        </View>

        <View style={styles.priceCard}>
          <Text style={styles.price}>{price}</Text>
          <Text style={styles.priceSub}>Annual membership</Text>
          <View style={styles.benefits}>
            <Benefit icon={<Ticket size={17} color={theme.sea} />} text="12 adult trip credits per year" />
            <Benefit icon={<QrCode size={17} color={theme.sea} />} text="QR pass scanned by crew in admin" />
            <Benefit icon={<ShoppingBag size={17} color={theme.sea} />} text="10% off in-store purchases" />
            <Benefit icon={<Gift size={17} color={theme.sea} />} text="Use anytime of the year, subject to availability" />
          </View>

          {!isActive ? (
            <Pressable onPress={() => purchaseMutation.mutate()} disabled={!packageToBuy || purchaseMutation.isPending} style={styles.primaryBtn}>
              {purchaseMutation.isPending ? <ActivityIndicator color={theme.white} /> : <Text style={styles.primaryText}>Start Membership</Text>}
            </Pressable>
          ) : (
            <View style={styles.activeBadge}><ShieldCheck size={18} color={theme.sea} /><Text style={styles.activeText}>Membership active</Text></View>
          )}
          <Pressable onPress={() => restoreMutation.mutate()} style={styles.restoreBtn}>
            <RefreshCw size={14} color={theme.sea} /><Text style={styles.restoreText}>{restoreMutation.isPending ? "Restoring…" : "Restore Purchases"}</Text>
          </Pressable>
        </View>

        {isActive && (
          <View style={styles.passCard}>
            <Text style={styles.sectionTitle}>Create your QR pass</Text>
            <Text style={styles.helper}>Use the same email you want crew to recognise. Admin scanning will deduct 1 credit.</Text>
            <TextInput value={email} onChangeText={setEmail} placeholder="Your email" placeholderTextColor={theme.textMuted} autoCapitalize="none" keyboardType="email-address" style={styles.input} />
            <Pressable onPress={() => syncMutation.mutate()} disabled={!email.trim() || syncMutation.isPending} style={[styles.primaryBtn, (!email.trim() || syncMutation.isPending) && { opacity: 0.55 }]}>
              <Text style={styles.primaryText}>{syncMutation.isPending ? "Creating…" : "Create QR Pass"}</Text>
            </Pressable>
          </View>
        )}

        {pass && pass.active && (
          <View style={styles.memberPass}>
            <View style={styles.passTop}><ShipWheel size={20} color={theme.sand} /><Text style={styles.passTitle}>Member Pass</Text></View>
            <Text style={styles.passEmail}>{pass.email}</Text>
            <View style={styles.qrWrap}><Image source={{ uri: qrCodeUrl(pass.memberId) }} style={styles.qr} contentFit="contain" /></View>
            <Text style={styles.credits}>{pass.creditsRemaining} / {pass.creditsTotal} trips remaining</Text>
            <Text style={styles.expires}>Valid until {new Date(pass.expiresAt).toLocaleDateString("en-GB")}</Text>
            <Pressable onPress={() => Clipboard.setStringAsync(pass.memberId)} style={styles.copyBtn}><Text style={styles.copyText}>Copy member ID</Text></Pressable>
          </View>
        )}
      </ScrollView>
    </View>
  );
}

function Benefit({ icon, text }: { icon: React.ReactNode; text: string }) {
  return <View style={styles.benefit}>{icon}<Text style={styles.benefitText}>{text}</Text></View>;
}

const styles = StyleSheet.create({
  root:{flex:1,backgroundColor:theme.deep}, hero:{paddingHorizontal:20,paddingBottom:18}, heroIcon:{width:68,height:68,borderRadius:24,backgroundColor:"rgba(244,227,193,0.12)",alignItems:"center",justifyContent:"center",borderWidth:1,borderColor:"rgba(244,227,193,0.22)"}, kicker:{marginTop:18,color:theme.sand,fontSize:12,fontWeight:"900",letterSpacing:1.5}, title:{marginTop:8,color:theme.white,fontSize:36,fontWeight:"900",lineHeight:40}, subtitle:{marginTop:10,color:"rgba(255,255,255,0.75)",fontSize:16,lineHeight:23}, priceCard:{margin:16,padding:18,borderRadius:28,backgroundColor:theme.white}, price:{fontSize:36,fontWeight:"900",color:theme.text}, priceSub:{color:theme.textMuted,fontWeight:"700"}, benefits:{gap:10,marginTop:18,marginBottom:18}, benefit:{flexDirection:"row",alignItems:"center",gap:10}, benefitText:{flex:1,color:theme.text,fontSize:14,fontWeight:"700"}, primaryBtn:{height:52,borderRadius:18,backgroundColor:theme.coral,alignItems:"center",justifyContent:"center"}, primaryText:{color:theme.white,fontWeight:"900",fontSize:16}, restoreBtn:{marginTop:12,height:42,borderRadius:14,alignItems:"center",justifyContent:"center",flexDirection:"row",gap:8,backgroundColor:theme.foam}, restoreText:{color:theme.sea,fontWeight:"900"}, activeBadge:{height:52,borderRadius:18,backgroundColor:theme.foam,alignItems:"center",justifyContent:"center",flexDirection:"row",gap:8}, activeText:{color:theme.sea,fontWeight:"900",fontSize:16}, passCard:{marginHorizontal:16,marginBottom:16,padding:16,borderRadius:24,backgroundColor:theme.white}, sectionTitle:{fontSize:20,fontWeight:"900",color:theme.text}, helper:{marginTop:6,color:theme.textMuted,lineHeight:20}, input:{height:50,borderRadius:16,backgroundColor:theme.bg,paddingHorizontal:14,color:theme.text,fontSize:15,marginVertical:14}, memberPass:{margin:16,padding:18,borderRadius:30,backgroundColor:theme.ink,borderWidth:1,borderColor:"rgba(244,227,193,0.25)",alignItems:"center"}, passTop:{alignSelf:"stretch",flexDirection:"row",alignItems:"center",gap:8}, passTitle:{color:theme.sand,fontSize:18,fontWeight:"900"}, passEmail:{alignSelf:"stretch",marginTop:6,color:"rgba(255,255,255,0.72)"}, qrWrap:{marginTop:18,padding:14,borderRadius:24,backgroundColor:theme.white}, qr:{width:220,height:220}, credits:{marginTop:16,color:theme.white,fontSize:24,fontWeight:"900"}, expires:{marginTop:4,color:"rgba(255,255,255,0.65)"}, copyBtn:{marginTop:14,paddingHorizontal:16,height:38,borderRadius:14,backgroundColor:"rgba(255,255,255,0.1)",alignItems:"center",justifyContent:"center"}, copyText:{color:theme.white,fontWeight:"800"}
});
