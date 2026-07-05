import { useState } from "react";
import { StyleSheet, TextInput } from "react-native";

interface Props {
  cents: number;
  onChange: (cents: number) => void;
  placeholder?: string;
}

// Cents-safe money input: displays dollars, reports integer cents. No floats stored.
export function CurrencyInput({ cents, onChange, placeholder = "0.00" }: Props) {
  const [text, setText] = useState(cents > 0 ? (cents / 100).toString() : "");

  function handleChange(next: string) {
    const cleaned = next.replace(/[^0-9.]/g, "");
    setText(cleaned);
    const dollars = parseFloat(cleaned);
    onChange(Number.isFinite(dollars) ? Math.round(dollars * 100) : 0);
  }

  return (
    <TextInput
      style={styles.input}
      value={text}
      onChangeText={handleChange}
      keyboardType="decimal-pad"
      placeholder={placeholder}
      inputMode="decimal"
    />
  );
}

const styles = StyleSheet.create({
  input: {
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: "#c8c8c8",
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
    minWidth: 90,
  },
});
