import {
  VictoryAxis,
  VictoryChart,
  VictoryLegend,
  VictoryLine,
  VictoryTheme,
  VictoryVoronoiContainer
} from "victory";

import { useSimulation } from "../context/SimulationProvider";
import { colorScale, lineStyle, padding } from "../chartStyle";
import { ChartTooltip } from "./ChartTooltip";

const [yStyle, rStyle, uStyle, eStyle] = colorScale.map(color => lineStyle(color));

export const ControlChart: React.FC = () => {
  const { data } = useSimulation();

  return (
    <VictoryChart
      theme={VictoryTheme.material}
      width={800}
      height={360}
      domainPadding={1}
      padding={padding}
      containerComponent={
        <VictoryVoronoiContainer
          voronoiDimension="x"
          labels={({ datum }) => `${datum.childName}: ${Math.round(datum._y * 100) / 100}`}
          labelComponent={<ChartTooltip centerOffset={{ y: -56 }} />}
        />
      }
    >
      <VictoryLegend
        x={690}
        y={122}
        colorScale={colorScale}
        data={[{ name: "y" }, { name: "r" }, { name: "u" }, { name: "e" }]}
      />

      <VictoryAxis />
      <VictoryAxis dependentAxis />

      <VictoryLine name="y" data={data} x="k" y="y" style={yStyle} />
      <VictoryLine name="r" data={data} x="k" y="r" style={rStyle} />
      <VictoryLine name="u" data={data} x="k" y="u" style={uStyle} />
      <VictoryLine name="e" data={data} x="k" y="e" style={eStyle} />
    </VictoryChart>
  );
};
