import {
  VictoryAxis,
  VictoryChart,
  VictoryLegend,
  VictoryLine,
  VictoryTheme,
  VictoryTooltip,
  VictoryTooltipProps,
  VictoryVoronoiContainer
} from "victory";

import { useSimulation } from "../context/SimulationProvider";

const colorScale = [
  "#4F7DA1",
  "#45B29D",
  "#EFC94C",
  "#E27A3F"
  // "#334D5C"
  // "#DF5A49",
  // "#DF948A",
  // "#55DBC1",
  // "#EFDA97",
  // "#E2A37F",
];

const lineStyle = (color = "#cccccc") => ({
  labels: { fill: color },
  data: { stroke: color }
});

const [yStyle, rStyle, uStyle, eStyle] = colorScale.map(color => lineStyle(color));

const Tooltip = ({ datum, text, style, ...props }: VictoryTooltipProps) => (
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

export const SimulationChart: React.FC = () => {
  const { data } = useSimulation();

  return (
    <VictoryChart
      theme={VictoryTheme.material}
      width={800}
      height={620}
      domainPadding={1}
      padding={{
        top: 20,
        bottom: 45,
        left: 55,
        right: 100
      }}
      containerComponent={
        <VictoryVoronoiContainer
          voronoiDimension="x"
          labels={({ datum }) => `${datum.childName}: ${Math.round(datum._y * 100) / 100}`}
          labelComponent={<Tooltip centerOffset={{ y: -56 }} />}
        />
      }
    >
      <VictoryLegend
        x={720}
        y={240}
        colorScale={colorScale}
        data={[{ name: "y" }, { name: "r" }, { name: "u" }, { name: "e" }]}
      />

      <VictoryAxis />
      <VictoryAxis dependentAxis />
      {/* <VictoryAxis dependentAxis orientation="right" tickFormat={percent} /> */}

      <VictoryLine name="y" data={data} x="k" y="y" style={yStyle} />
      <VictoryLine name="r" data={data} x="k" y="r" style={rStyle} />
      <VictoryLine name="u" data={data} x="k" y="u" style={uStyle} />
      <VictoryLine name="e" data={data} x="k" y="e" style={eStyle} />
    </VictoryChart>
  );
};
