import { useWindowDimensions, View } from "react-native";
import Svg, { Line, Polyline } from "react-native-svg";

import type { PricePoint } from "@/api/types";

interface Props {
  points: PricePoint[];
  baselineCents: number;
  height?: number;
}

// Hand-rolled line chart: price over time with a dashed baseline. No chart lib.
export function PriceChart({ points, baselineCents, height = 160 }: Props) {
  const { width: screenWidth } = useWindowDimensions();
  const width = Math.max(240, screenWidth - 48);

  if (points.length < 2) return null;

  const prices = points.map((point) => point.price_cents);
  const min = Math.min(...prices, baselineCents);
  const max = Math.max(...prices, baselineCents);
  const range = max - min || 1;
  const pad = 8;
  const innerW = width - pad * 2;
  const innerH = height - pad * 2;

  const x = (index: number) => pad + (index / (points.length - 1)) * innerW;
  const y = (cents: number) => pad + innerH - ((cents - min) / range) * innerH;

  const line = points
    .map((point, index) => `${x(index).toFixed(1)},${y(point.price_cents).toFixed(1)}`)
    .join(" ");
  const baselineY = y(baselineCents).toFixed(1);

  return (
    <View>
      <Svg width={width} height={height}>
        <Line
          x1={pad}
          y1={baselineY}
          x2={width - pad}
          y2={baselineY}
          stroke="#9aa0a6"
          strokeWidth={1}
          strokeDasharray="4 4"
        />
        <Polyline points={line} fill="none" stroke="#0a7ea4" strokeWidth={2} />
      </Svg>
    </View>
  );
}
