import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { router, useLocalSearchParams } from "expo-router";
import { ActivityIndicator, Button, Text, View } from "react-native";

import { getWatch, updateWatch } from "@/api/endpoints";
import type { RuleInput } from "@/api/types";
import { RuleEditor } from "@/components/RuleEditor";

export default function EditWatchScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const watchId = Number(id);
  const queryClient = useQueryClient();

  const { data, isLoading, isError, refetch } = useQuery({
    queryKey: ["watch", watchId],
    queryFn: () => getWatch(watchId),
  });

  const save = useMutation({
    mutationFn: (payload: { baselineCents: number; rules: RuleInput[] }) =>
      updateWatch(watchId, { baseline_price_cents: payload.baselineCents, rules: payload.rules }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["watch", watchId] });
      queryClient.invalidateQueries({ queryKey: ["watches"] });
      router.back();
    },
  });

  if (isLoading) {
    return (
      <View style={{ flex: 1, alignItems: "center", justifyContent: "center" }}>
        <ActivityIndicator />
      </View>
    );
  }

  if (isError || !data) {
    return (
      <View style={{ flex: 1, alignItems: "center", justifyContent: "center", gap: 10 }}>
        <Text>Couldn’t load this watch.</Text>
        <Button title="Retry" onPress={() => refetch()} />
      </View>
    );
  }

  return (
    <RuleEditor
      initialBaselineCents={data.baseline_price_cents}
      initialRules={data.rules}
      submitLabel="Save changes"
      submitting={save.isPending}
      onSubmit={(baselineCents, rules) => save.mutate({ baselineCents, rules })}
    />
  );
}
