import { useMutation, useQuery } from "@tanstack/react-query";
import { CameraView, useCameraPermissions, type BarcodeScanningResult } from "expo-camera";
import * as Haptics from "expo-haptics";
import { router } from "expo-router";
import { useRef, useState } from "react";
import {
  ActivityIndicator,
  Image,
  Linking,
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from "react-native";

import { ApiError } from "@/api/client";
import { createWatch, getStores, getWatches, postResolution } from "@/api/endpoints";
import type { ResolutionResponse, RuleInput, Store } from "@/api/types";
import { RuleEditor } from "@/components/RuleEditor";
import { formatCents } from "@/lib/money";
import { useDefaultStore } from "@/lib/storeMemory";

const BARCODE_TYPES = ["upc_a", "ean13", "upc_e"] as const;

type Phase = "scan" | "picker" | "resolving" | "confirm" | "duplicate" | "failed" | "rules";

export default function ScanScreen() {
  const [permission, requestPermission] = useCameraPermissions();
  const storesQuery = useQuery({ queryKey: ["stores"], queryFn: getStores });
  const watchesQuery = useQuery({ queryKey: ["watches"], queryFn: getWatches });
  const { storeId: defaultStoreId, remember } = useDefaultStore();

  const [phase, setPhase] = useState<Phase>("scan");
  const [scanned, setScanned] = useState<{ code: string; symbology: string } | null>(null);
  const [storeId, setStoreId] = useState<number | null>(null);
  const [existingWatchId, setExistingWatchId] = useState<number | null>(null);
  const [torch, setTorch] = useState(false);
  const scanLock = useRef(false);

  const resolvableStores = (storesQuery.data ?? []).filter((store) => store.supports_resolution);
  const selectedStore = storesQuery.data?.find((store) => store.id === storeId) ?? null;

  const resolve = useMutation({
    mutationFn: (vars: { code: string; symbology: string; storeId: number }) =>
      postResolution({ barcode: vars.code, symbology: vars.symbology, store_id: vars.storeId }),
    onSuccess: (data) => {
      const existing = findExistingWatch(data);
      if (existing) {
        setExistingWatchId(existing.id);
        setPhase("duplicate");
      } else {
        setPhase("confirm");
      }
    },
    onError: () => setPhase("failed"),
  });

  const create = useMutation({
    mutationFn: (vars: { baselineCents: number; rules: RuleInput[] }) => {
      const data = resolve.data as ResolutionResponse;
      return createWatch({
        barcode: scanned!.code,
        store_id: storeId!,
        resolution: data.resolution,
        baseline_price_cents: vars.baselineCents,
        rules: vars.rules,
      });
    },
    onSuccess: (watch) => {
      if (storeId !== null) remember(storeId);
      router.replace({ pathname: "/watch/[id]", params: { id: String(watch.id) } });
    },
  });

  function findExistingWatch(data: ResolutionResponse) {
    const gtin13 = data.product.gtin13;
    if (!gtin13 || !selectedStore) return undefined;
    return watchesQuery.data?.find(
      (watch) => watch.product.gtin13 === gtin13 && watch.store.slug === selectedStore.slug,
    );
  }

  function reset() {
    scanLock.current = false;
    setScanned(null);
    setStoreId(null);
    setExistingWatchId(null);
    resolve.reset();
    create.reset();
    setPhase("scan");
  }

  function pickStore(id: number) {
    if (!scanned) return;
    setStoreId(id);
    setPhase("resolving");
    resolve.mutate({ code: scanned.code, symbology: scanned.symbology, storeId: id });
  }

  function handleScan(result: BarcodeScanningResult) {
    if (scanLock.current) return;
    scanLock.current = true;
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    setScanned({ code: result.data, symbology: result.type });

    // Auto-resolve against the remembered store; otherwise ask.
    const canAuto = defaultStoreId != null && resolvableStores.some((s) => s.id === defaultStoreId);
    if (canAuto) {
      setStoreId(defaultStoreId);
      setPhase("resolving");
      resolve.mutate({ code: result.data, symbology: result.type, storeId: defaultStoreId });
    } else {
      setPhase("picker");
    }
  }

  // --- permission gates ---
  if (!permission) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator />
      </View>
    );
  }
  if (!permission.granted) {
    return (
      <View style={styles.centered}>
        <Text style={styles.permTitle}>Camera access needed</Text>
        <Text style={styles.permBody}>Allow the camera to scan product barcodes.</Text>
        {permission.canAskAgain ? (
          <Pressable style={styles.primary} onPress={() => requestPermission()}>
            <Text style={styles.primaryText}>Allow camera</Text>
          </Pressable>
        ) : (
          <Pressable style={styles.primary} onPress={() => Linking.openSettings()}>
            <Text style={styles.primaryText}>Open Settings</Text>
          </Pressable>
        )}
      </View>
    );
  }

  // --- rules step takes over the screen ---
  if (phase === "rules" && resolve.data) {
    return (
      <RuleEditor
        initialBaselineCents={resolve.data.resolution.price_cents ?? 0}
        submitLabel="Track this"
        submitting={create.isPending}
        onSubmit={(baselineCents, rules) => create.mutate({ baselineCents, rules })}
      />
    );
  }

  return (
    <View style={styles.container}>
      <CameraView
        style={StyleSheet.absoluteFill}
        facing="back"
        enableTorch={torch}
        barcodeScannerSettings={{ barcodeTypes: [...BARCODE_TYPES] }}
        onBarcodeScanned={phase === "scan" ? handleScan : undefined}
      />

      <View style={styles.overlay} pointerEvents="box-none">
        <View style={styles.reticle} />
        <Text style={styles.hint}>Point at a product barcode</Text>
        <Pressable style={styles.torch} onPress={() => setTorch((on) => !on)}>
          <Text style={styles.torchText}>{torch ? "🔦 On" : "🔦 Off"}</Text>
        </Pressable>
      </View>

      <Modal visible={phase !== "scan"} transparent animationType="slide" onRequestClose={reset}>
        <Pressable style={styles.sheetBackdrop} onPress={reset} />
        <View style={styles.sheet}>
          {scanned && <Text style={styles.scannedCode}>Scanned {scanned.code}</Text>}

          {phase === "picker" && (
            <StorePicker
              stores={resolvableStores}
              defaultStoreId={defaultStoreId}
              onPick={pickStore}
              onByUrl={() => {
                reset();
                router.push("/add-url");
              }}
            />
          )}

          {phase === "resolving" && (
            <View style={styles.resolving}>
              <ActivityIndicator />
              <Text style={styles.resolvingText}>
                Looking it up at {selectedStore?.name ?? "the store"}…
              </Text>
            </View>
          )}

          {phase === "confirm" && resolve.data && (
            <Confirmation
              data={resolve.data}
              storeName={selectedStore?.name ?? ""}
              onTrack={() => setPhase("rules")}
              onReject={() => setPhase("picker")}
            />
          )}

          {phase === "duplicate" && (
            <View style={styles.block}>
              <Text style={styles.blockTitle}>Already tracking this</Text>
              <Text style={styles.blockBody}>
                You already have a watch for this item at {selectedStore?.name}.
              </Text>
              <Pressable
                style={styles.primary}
                onPress={() => {
                  const id = existingWatchId;
                  reset();
                  if (id != null)
                    router.replace({ pathname: "/watch/[id]", params: { id: String(id) } });
                }}
              >
                <Text style={styles.primaryText}>Open it</Text>
              </Pressable>
              <Pressable style={styles.secondary} onPress={reset}>
                <Text style={styles.secondaryText}>Scan again</Text>
              </Pressable>
            </View>
          )}

          {phase === "failed" && (
            <View style={styles.block}>
              <Text style={styles.blockTitle}>{failureTitle(resolve.error)}</Text>
              <Text style={styles.blockBody}>{failureBody(resolve.error)}</Text>
              <Pressable style={styles.primary} onPress={() => setPhase("picker")}>
                <Text style={styles.primaryText}>Try a different store</Text>
              </Pressable>
              <Pressable
                style={styles.secondary}
                onPress={() => {
                  reset();
                  router.push("/add-url");
                }}
              >
                <Text style={styles.secondaryText}>Add by URL instead</Text>
              </Pressable>
              <Pressable style={styles.secondary} onPress={reset}>
                <Text style={styles.secondaryText}>Scan again</Text>
              </Pressable>
            </View>
          )}
        </View>
      </Modal>
    </View>
  );
}

function StorePicker({
  stores,
  defaultStoreId,
  onPick,
  onByUrl,
}: {
  stores: Store[];
  defaultStoreId: number | null;
  onPick: (id: number) => void;
  onByUrl: () => void;
}) {
  return (
    <ScrollView>
      <Text style={styles.sheetTitle}>Which store?</Text>
      {stores.map((store) => (
        <Pressable key={store.id} style={styles.storeRow} onPress={() => onPick(store.id)}>
          <Text style={styles.storeName}>{store.name}</Text>
          {store.id === defaultStoreId && <Text style={styles.lastUsed}>last used</Text>}
        </Pressable>
      ))}
      <Pressable style={styles.storeRow} onPress={onByUrl}>
        <Text style={[styles.storeName, styles.byUrl]}>Other / by URL…</Text>
      </Pressable>
    </ScrollView>
  );
}

function Confirmation({
  data,
  storeName,
  onTrack,
  onReject,
}: {
  data: ResolutionResponse;
  storeName: string;
  onTrack: () => void;
  onReject: () => void;
}) {
  const { resolution, product } = data;
  return (
    <ScrollView>
      <View style={styles.confirmHeader}>
        {resolution.image_url ? (
          <Image source={{ uri: resolution.image_url }} style={styles.confirmImage} />
        ) : (
          <View style={[styles.confirmImage, styles.placeholder]}>
            <Text style={styles.placeholderIcon}>🏷️</Text>
          </View>
        )}
        <View style={styles.confirmInfo}>
          <Text style={styles.confirmTitle} numberOfLines={2}>
            {resolution.title ?? product.name ?? "Product"}
          </Text>
          <Text style={styles.confirmStore}>{storeName}</Text>
          <Text style={styles.confirmPrice}>
            {resolution.price_cents != null
              ? formatCents(resolution.price_cents, resolution.currency)
              : "Price unavailable"}
          </Text>
        </View>
      </View>

      {!resolution.verified && (
        <Text style={styles.unverified}>
          ⚠️ We couldn’t verify the barcode match — double-check this is the right item.
        </Text>
      )}

      <Pressable style={styles.primary} onPress={onTrack}>
        <Text style={styles.primaryText}>Track this</Text>
      </Pressable>
      <Pressable style={styles.secondary} onPress={onReject}>
        <Text style={styles.secondaryText}>Not this item</Text>
      </Pressable>
    </ScrollView>
  );
}

function failureTitle(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.code === "not_found") return "No match found";
    if (error.code === "blocked") return "The store blocked the lookup";
    if (error.code === "unsupported") return "This store can’t be scanned";
  }
  return "Couldn’t look it up";
}

function failureBody(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.code === "not_found") return "We couldn’t find this barcode at this store.";
    if (error.code === "blocked") return "Try again later, a different store, or add it by URL.";
    if (error.code === "unsupported") return "Pick a different store or add it by URL.";
  }
  return "Check your connection and try again, or add it by URL.";
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#000" },
  centered: { flex: 1, alignItems: "center", justifyContent: "center", gap: 12, padding: 24 },
  overlay: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    alignItems: "center",
    justifyContent: "center",
  },
  reticle: {
    width: 240,
    height: 140,
    borderWidth: 2,
    borderColor: "rgba(255,255,255,0.85)",
    borderRadius: 12,
  },
  hint: { color: "#fff", marginTop: 16, fontSize: 15 },
  torch: {
    position: "absolute",
    bottom: 48,
    backgroundColor: "rgba(0,0,0,0.5)",
    paddingVertical: 10,
    paddingHorizontal: 18,
    borderRadius: 24,
  },
  torchText: { color: "#fff", fontSize: 15 },
  permTitle: { fontSize: 20, fontWeight: "600" },
  permBody: { fontSize: 15, color: "#666", textAlign: "center" },
  sheetBackdrop: { flex: 1, backgroundColor: "rgba(0,0,0,0.35)" },
  sheet: {
    backgroundColor: "#fff",
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: 20,
    maxHeight: "75%",
  },
  scannedCode: { color: "#888", fontSize: 13, marginBottom: 8 },
  sheetTitle: { fontSize: 18, fontWeight: "600", marginBottom: 8 },
  storeRow: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingVertical: 14,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: "#eee",
  },
  storeName: { fontSize: 17 },
  byUrl: { color: "#0a7ea4" },
  lastUsed: { fontSize: 12, color: "#888" },
  resolving: { alignItems: "center", gap: 12, paddingVertical: 24 },
  resolvingText: { fontSize: 15, color: "#444" },
  confirmHeader: { flexDirection: "row", gap: 14, marginBottom: 12 },
  confirmImage: { width: 84, height: 84, borderRadius: 10, backgroundColor: "#f0f0f0" },
  placeholder: { alignItems: "center", justifyContent: "center" },
  placeholderIcon: { fontSize: 34 },
  confirmInfo: { flex: 1, gap: 4 },
  confirmTitle: { fontSize: 17, fontWeight: "600" },
  confirmStore: { fontSize: 14, color: "#666" },
  confirmPrice: { fontSize: 22, fontWeight: "800" },
  unverified: {
    color: "#8a5300",
    backgroundColor: "#fff4e5",
    padding: 10,
    borderRadius: 8,
    marginBottom: 8,
  },
  block: { gap: 10, paddingVertical: 8 },
  blockTitle: { fontSize: 18, fontWeight: "600" },
  blockBody: { fontSize: 15, color: "#555" },
  primary: {
    backgroundColor: "#0a7ea4",
    borderRadius: 10,
    paddingVertical: 14,
    alignItems: "center",
    marginTop: 12,
  },
  primaryText: { color: "#fff", fontSize: 16, fontWeight: "600" },
  secondary: { paddingVertical: 12, alignItems: "center" },
  secondaryText: { color: "#0a7ea4", fontSize: 15 },
});
