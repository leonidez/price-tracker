import AsyncStorage from "@react-native-async-storage/async-storage";
import { useCallback, useEffect, useState } from "react";

// Remembers the last store you resolved against (the "standing in Walmart
// scanning five things" case). Also surfaced + clearable in Settings.
const KEY = "defaultStoreId";

export async function getDefaultStoreId(): Promise<number | null> {
  const value = await AsyncStorage.getItem(KEY);
  return value ? Number(value) : null;
}

export async function setDefaultStoreId(id: number): Promise<void> {
  await AsyncStorage.setItem(KEY, String(id));
}

export async function clearDefaultStoreId(): Promise<void> {
  await AsyncStorage.removeItem(KEY);
}

export function useDefaultStore() {
  const [storeId, setStoreId] = useState<number | null>(null);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    getDefaultStoreId().then((id) => {
      setStoreId(id);
      setLoaded(true);
    });
  }, []);

  const remember = useCallback(async (id: number) => {
    await setDefaultStoreId(id);
    setStoreId(id);
  }, []);

  const clear = useCallback(async () => {
    await clearDefaultStoreId();
    setStoreId(null);
  }, []);

  return { storeId, loaded, remember, clear };
}
