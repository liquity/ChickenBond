import React from "react";

import {
  VictoryArea,
  VictoryAxis,
  VictoryChart,
  VictoryLegend,
  VictoryLine,
  VictoryStack,
  VictoryTheme,
  VictoryVoronoiContainer
} from "victory";

import { ChickenFarmDatum } from "../model/ChickenFarm";
import { months } from "../utils";
import { useSimulation } from "../context/SimulationProvider";
import { areaStyle, colorScale, lineStyle, padding } from "../chartStyle";
import { ChartTooltip } from "./ChartTooltip";

const [pendingColor, reserveColor, permanentColor, redemptionPriceColor, premiumColor] = colorScale;

const [pendingStyle, reserveStyle, permanentStyle] = [
  pendingColor,
  reserveColor,
  permanentColor
].map(areaStyle);

const [redemptionPriceStyle, premiumStyle] = [redemptionPriceColor, premiumColor].map(lineStyle);

const round = (decimals: number) => {
  const scale = 10 ** decimals;
  return (x: number) => Math.round(x * scale) / scale;
};

const millions = (decimals: number) => {
  const f = round(decimals);
  return (x: number) => `${f(x / 1e6)}M`;
};

const findMax =
  <T extends unknown>(select: (t: T) => number[]) =>
  (ts: T[], minValue = 0.1) =>
    ts.reduce((maxSoFar, t) => Math.max(maxSoFar, ...select(t).map(Math.abs)), minValue);

const findMaxLeftAxis = findMax<ChickenFarmDatum>(datum => [
  datum.coop.TOKEN + datum.in.TOKEN + datum.tollTOKEN
]);

const findMaxRightAxis = findMax<ChickenFarmDatum>(datum => [datum.polRatio + datum.premium]);

interface ProtocolChartProps {
  data: ChickenFarmDatum[];
  period: number;
}

const ProtocolChartWithProps: React.FC<ProtocolChartProps> = ({ data, period }) => {
  const maxLeftAxis = findMaxLeftAxis(data);
  const maxRightAxis = findMaxRightAxis(data);
  const scale = maxLeftAxis / maxRightAxis;
  const percent = (decimals: number) => (y: number) => `${round(decimals)(100 * (y / scale))}%`;

  const scaledRightAxis = data.map(({ k, polRatio, premium }) => ({
    k,
    polRatio: polRatio * scale,
    premium: premium * scale,
    isPercent: true
  }));

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
          labels={({ datum }) =>
            `${datum.childName}: ${(datum.isPercent ? percent(2) : millions(2))(datum._y)}`
          }
          labelComponent={<ChartTooltip centerOffset={{ y: -56 }} />}
        />
      }
    >
      <VictoryLegend
        x={690}
        y={111}
        colorScale={colorScale}
        data={[
          { name: "pending" },
          { name: "reserve" },
          { name: "permanent" },
          { name: "red. price" },
          { name: "mkt. price" }
        ]}
      />

      <VictoryAxis tickValues={months(data.length / period)} />
      <VictoryAxis dependentAxis tickFormat={percent(0)} />
      <VictoryAxis dependentAxis tickFormat={millions(0)} orientation="right" />

      <VictoryStack>
        <VictoryArea name="permanent" data={data} x="k" y="tollTOKEN" style={permanentStyle} />
        <VictoryArea name="reserve" data={data} x="k" y="in.TOKEN" style={reserveStyle} />
        <VictoryArea name="pending" data={data} x="k" y="coop.TOKEN" style={pendingStyle} />
      </VictoryStack>

      <VictoryStack>
        <VictoryLine
          name="red. price"
          data={scaledRightAxis}
          x="k"
          y="polRatio"
          style={redemptionPriceStyle}
        />

        <VictoryLine name="premium" data={scaledRightAxis} x="k" y="premium" style={premiumStyle} />
      </VictoryStack>
    </VictoryChart>
  );
};

const MemoizedProtocolChart = React.memo(ProtocolChartWithProps);

export const ProtocolChart: React.FC = () => {
  const { data, period } = useSimulation();

  return <MemoizedProtocolChart data={data} period={period} />;
};
