import Svg, { Polyline } from "react-native-svg";

interface Props {
  data: number[];
  width?: number;
  height?: number;
  color?: string;
}

// Tiny inline sparkline from an array of price_cents.
export function Sparkline({ data, width = 84, height = 26, color = "#1a7f37" }: Props) {
  if (data.length < 2) return null;

  const min = Math.min(...data);
  const max = Math.max(...data);
  const range = max - min || 1;
  const stepX = width / (data.length - 1);

  const points = data
    .map((value, index) => {
      const x = index * stepX;
      const y = height - ((value - min) / range) * height;
      return `${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(" ");

  return (
    <Svg width={width} height={height}>
      <Polyline points={points} fill="none" stroke={color} strokeWidth={1.5} />
    </Svg>
  );
}
