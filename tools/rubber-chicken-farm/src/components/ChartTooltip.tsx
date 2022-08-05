import { VictoryTooltip, VictoryTooltipProps } from "victory";

export const ChartTooltip = ({ datum, text, style, ...props }: VictoryTooltipProps) => (
  <VictoryTooltip
    {...props}
    datum={datum}
    text={[`k = ${(datum as any)._x}`, ...(text as [])]}
    style={[{ fontWeight: 600 }, ...(style as [])]}
    pointerLength={1}
    cornerRadius={3}
    flyoutStyle={{
      stroke: "#293147",
      strokeOpacity: 0.5,
      fill: "white"
    }}
  />
);
