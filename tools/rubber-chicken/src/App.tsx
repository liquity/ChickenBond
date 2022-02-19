import { useEffect, useMemo, useReducer, useState } from "react";

import {
  Box,
  Button,
  Flex,
  Heading,
  Input,
  Label,
  Radio,
  Select,
  Switch,
  Textarea,
  ThemeProvider,
  ThemeUICSSObject
} from "theme-ui";

import {
  VictoryAxis,
  VictoryChart,
  VictoryGroup,
  VictoryLabel,
  VictoryLegend,
  VictoryLine,
  VictoryTheme,
  VictoryTooltip,
  VictoryTooltipProps,
  VictoryVoronoiContainer
} from "victory";

import theme from "./theme";

const groupStyle: ThemeUICSSObject = {
  mt: 2,
  mb: 4
};

const colorScale = [
  "#E27A3F",
  "#EFC94C",
  "#45B29D",
  "#4F7DA1",
  "#334D5C"
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

const [topUpStyle, payoutInStyle, payoutUpStyle, rightAxisInStyle, rightAxisUpStyle] =
  colorScale.map(color => lineStyle(color));

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

const seriesMax = (series?: Array<{ x: number; y: number | null }>) =>
  series?.reduce((a, b) => Math.max(Math.abs(b.y ?? a), a), 0.1) ?? 0.1;

const numSamples = 201;
const range = [...Array(numSamples).keys()];

const tollBasisOptions = new Map([
  ["initial" as const, "Initial bond"],
  ["toppedUp" as const, "Topped-up bond"],
  ["netGain" as const, "Net gain"]
]);

type TollBasis = typeof tollBasisOptions extends Map<infer T, unknown> ? T : never;

const checkTollBasis = (value: string): TollBasis => {
  if (!(tollBasisOptions as Map<string, never>).has(value)) {
    throw new Error(`wrong TollBasis value "${value}"`);
  }

  return value as TollBasis;
};

const rightAxisOptions = {
  roi: {
    name: "Return on Investment",
    labels: {
      in: "ROI (In)",
      up: "ROI (Up)"
    }
  },

  arr: {
    name: "Annualized Rate of Return",
    labels: {
      in: "ARR (In)",
      up: "ARR (Up)"
    }
  },

  toll: {
    name: "Effective Toll",
    labels: {
      in: "Effective Toll (In)",
      up: "Effective Toll (Up)"
    }
  }
};

type RightAxis = keyof typeof rightAxisOptions;

const checkRightAxis = (value: string): RightAxis => {
  if (!Object.keys(rightAxisOptions).includes(value)) {
    throw new Error(`wrong RightAxis value "${value}"`);
  }

  return value as RightAxis;
};

const rightAxisLabelSet = new Set(
  Object.values(rightAxisOptions).flatMap(o => Object.values(o.labels))
);

type Series = { x: number; y: number }[] | undefined;

const defaultPolRatioInit = 4;
const defaultTollPct = 20;
const defaultTollBasis = "initial";
const defaultPremiumPct = 100;
const defaultNaturalRatePct = 0;
const defaultBond = 100;

const defaultFCurve = `toll => k => (k / ${range[range.length - 1]})`;
const defaultFPremiumPct = `k => ${defaultPremiumPct}`;
const defaultFNaturalRatePct = `k => ${defaultNaturalRatePct}`;

const App = () => {
  const [polRatioInitInput, setPolRatioInitInput] = useState(`${defaultPolRatioInit}`);
  const [tollPctInput, setTollPctInput] = useState(`${defaultTollPct}`);
  const [tollBasis, setTollBasis] = useState<TollBasis>(`${defaultTollBasis}`);
  const [premiumPctInput, setPremiumPctInput] = useState(`${defaultPremiumPct}`);
  const [fPremiumPctInput, setFPremiumPctInput] = useState(`${defaultFPremiumPct}`);
  const [naturalRatePctInput, setNaturalRatePctInput] = useState(`${defaultNaturalRatePct}`);
  const [fNaturalRatePctInput, setFNaturalRatePctInput] = useState(`${defaultFNaturalRatePct}`);
  const [bondInput, setBondInput] = useState(`${defaultBond}`);
  const [fCurveInput, setFCurveInput] = useState(`${defaultFCurve}`);
  const [useFunctions, setUseFunctions] = useState(false);
  const [rightAxis, setRightAxis] = useState<RightAxis>("arr");
  const [revertDummy, revert] = useReducer(() => ({}), {});

  useEffect(() => {
    setPolRatioInitInput(`${defaultPolRatioInit}`);
    setTollPctInput(`${defaultTollPct}`);
    setTollBasis(`${defaultTollBasis}`);
    setPremiumPctInput(`${defaultPremiumPct}`);
    setFPremiumPctInput(`${defaultFPremiumPct}`);
    setNaturalRatePctInput(`${defaultNaturalRatePct}`);
    setFNaturalRatePctInput(`${defaultFNaturalRatePct}`);
    setBondInput(`${defaultBond}`);
    setFCurveInput(`${defaultFCurve}`);
    setUseFunctions(false);
  }, [revertDummy]);

  const polRatioInit = Number(polRatioInitInput);
  const naturalRate = Number(naturalRatePctInput) / 100;
  const premium = Number(premiumPctInput) / 100;
  const bond = Number(bondInput);
  const toll = Number(tollPctInput) / 100;

  const yieldSeries = useMemo(() => {
    if (useFunctions) {
      try {
        // eslint-disable-next-line no-new-func
        const f = new Function("k", `"use strict"; return ${fNaturalRatePctInput};`)();

        return range.map(x => ({
          x,
          y: Math.pow(1 + f(x) / 100, 1 / range[range.length - 1])
        }));
      } catch {}
    } else {
      if (!isNaN(naturalRate)) {
        const y = Math.pow(1 + naturalRate, 1 / range[range.length - 1]);

        return range.map(x => ({ x, y }));
      }
    }
  }, [useFunctions, naturalRate, fNaturalRatePctInput]);

  const polRatioSeries = useMemo(() => {
    if (isNaN(polRatioInit) || !yieldSeries) {
      return undefined;
    }

    let y = polRatioInit;

    return yieldSeries.map(({ x, y: yieldPerStep }) => {
      const ret = { x, y };
      y *= yieldPerStep;
      return ret;
    });
  }, [polRatioInit, yieldSeries]);

  const curveSeries = useMemo(() => {
    try {
      // eslint-disable-next-line no-new-func
      const f = new Function("k", `"use strict"; return ${fCurveInput};`)()(toll);

      return range.map(x => ({ x, y: f(x) }));
    } catch {}
  }, [fCurveInput, toll]);

  const accruedSeries = useMemo(() => {
    if (isNaN(bond) || !curveSeries) {
      return undefined;
    }

    return curveSeries.map(({ x, y: curve }) => ({ x, y: bond * curve }));
  }, [bond, curveSeries]);

  const cappedSeries = useMemo(() => {
    if (isNaN(bond) || !polRatioSeries || !accruedSeries) {
      return undefined;
    }

    return accruedSeries.map(({ x, y: accrued }, i) => ({
      x,
      y: Math.min(accrued, bond / polRatioSeries[i].y)
    }));
  }, [bond, polRatioSeries, accruedSeries]);

  const topUpSeries = useMemo(() => {
    if (isNaN(bond) || !polRatioSeries || !accruedSeries || !cappedSeries) {
      return undefined;
    }

    return accruedSeries.map(({ x, y: accrued }, i) => ({
      x,
      y: Math.max((accrued - cappedSeries[i].y) * polRatioSeries[i].y, 0)
    }));
  }, [bond, polRatioSeries, accruedSeries, cappedSeries]);

  const premiumSeries = useMemo(() => {
    if (useFunctions) {
      try {
        // eslint-disable-next-line no-new-func
        const f = new Function("k", `"use strict"; return ${fPremiumPctInput};`)();

        return range.map(x => ({ x, y: f(x) / 100 }));
      } catch {}
    } else {
      if (!isNaN(premium)) {
        return range.map(x => ({ x, y: premium }));
      }
    }
  }, [useFunctions, premium, fPremiumPctInput]);

  const tollInSeries = useMemo(() => {
    if (isNaN(toll)) {
      return undefined;
    }

    if (tollBasis !== "netGain") {
      return range.map(x => ({ x, y: toll }));
    }

    if (!curveSeries || !polRatioSeries || !premiumSeries) {
      return undefined;
    }

    return curveSeries.map(({ x, y: curve }, i) => ({
      x,
      y:
        curve * polRatioSeries[i].y * (1 + premiumSeries[i].y) < 1
          ? 0
          : toll - toll / (1 + premiumSeries[i].y) / Math.min(curve * polRatioSeries[i].y, 1)
    }));
  }, [tollBasis, toll, curveSeries, polRatioSeries, premiumSeries]);

  const tollUpSeries = useMemo(() => {
    if (tollBasis !== "initial") {
      return tollInSeries;
    }

    if (isNaN(toll) || !curveSeries || !polRatioSeries) {
      return undefined;
    }

    return curveSeries.map(({ x, y: curve }, i) => ({
      x,
      y: toll / Math.max(curve * polRatioSeries[i].y, 1)
    }));
  }, [tollBasis, toll, tollInSeries, curveSeries, polRatioSeries]);

  const payoutInSeries = useMemo(() => {
    if (!cappedSeries || !tollInSeries || !polRatioSeries || !premiumSeries) {
      return undefined;
    }

    return cappedSeries.map(({ x, y: capped }, i) => ({
      x,
      y: capped * (1 - tollInSeries[i].y) * (polRatioSeries[i].y * (1 + premiumSeries[i].y)),
      sTOKEN: capped * (1 - tollInSeries[i].y)
    }));
  }, [cappedSeries, tollInSeries, polRatioSeries, premiumSeries]);

  const payoutUpSeries = useMemo(() => {
    if (!accruedSeries || !tollUpSeries || !polRatioSeries || !premiumSeries) {
      return undefined;
    }

    return accruedSeries.map(({ x, y: accrued }, i) => ({
      x,
      y: accrued * (1 - tollUpSeries[i].y) * (polRatioSeries[i].y * (1 + premiumSeries[i].y)),
      sTOKEN: accrued * (1 - tollUpSeries[i].y)
    }));
  }, [accruedSeries, tollUpSeries, polRatioSeries, premiumSeries]);

  const roiInSeries = useMemo(() => {
    if (isNaN(bond) || !payoutInSeries) {
      return undefined;
    }

    return payoutInSeries.map(({ x, y: payout }) => ({
      x,
      y: payout / bond - 1
    }));
  }, [bond, payoutInSeries]);

  const roiUpSeries = useMemo(() => {
    if (isNaN(bond) || !payoutUpSeries || !topUpSeries) {
      return undefined;
    }

    return payoutUpSeries.map(({ x, y: payout }, i) => ({
      x,
      y: (payout - topUpSeries[i].y) / bond - 1
    }));
  }, [bond, payoutUpSeries, topUpSeries]);

  const arrInSeries = useMemo(() => {
    if (!roiInSeries) {
      return undefined;
    }

    return roiInSeries.map(({ x, y: roi }) => ({
      x,
      y: (x !== 0 ? Math.pow(1 + roi, range[range.length - 1] / x) : 0) - 1
    }));
  }, [roiInSeries]);

  const arrUpSeries = useMemo(() => {
    if (!roiUpSeries) {
      return undefined;
    }

    return roiUpSeries.map(({ x, y: roi }) => ({
      x,
      y: (x !== 0 ? Math.pow(1 + roi, range[range.length - 1] / x) : 0) - 1
    }));
  }, [roiUpSeries]);

  const rightAxisMap: { [k: string]: [Series, Series] } = {
    roi: [roiInSeries, roiUpSeries],
    arr: [arrInSeries, arrUpSeries],
    toll: [tollInSeries, tollUpSeries]
  };

  const rawRightAxis = rightAxisMap[rightAxis];

  const maxLeftAxis = Math.max(seriesMax(payoutUpSeries), seriesMax(topUpSeries));
  const maxRightAxis = Math.max(...rawRightAxis.map(seriesMax));
  const scale = maxLeftAxis / maxRightAxis;
  const percent = (y: number) => `${Math.round((y * 10000) / scale) / 100}%`;

  const [rightAxisIn, rightAxisUp] = rawRightAxis.map(series =>
    series?.map(({ x, y }) => ({ x, y: y * scale }))
  );

  const maxArr =
    arrInSeries && arrUpSeries
      ? [...arrInSeries, ...arrUpSeries].reduce((a, b) => (a.y > b.y ? a : b))
      : undefined;

  return (
    <ThemeProvider theme={theme}>
      <Heading as="h1">🐔 Crazy Chicken Investment Calculator</Heading>

      <Flex sx={{ alignItems: "flex-start", p: 3 }}>
        <Box sx={{ width: "300px" }}>
          <Flex sx={{ alignItems: "center", mb: 3 }}>
            <Heading>🎛️ Knobs</Heading>

            <Button variant="text" onClick={revert}>
              ⟲ Reset all
            </Button>
          </Flex>

          <Flex sx={{ flexDirection: "column", alignItems: "stretch", m: 2 }}>
            <Heading as="h4">System</Heading>
            <Box sx={groupStyle}>
              <Label>Initial POL Ratio</Label>
              <Input
                type="number"
                min={0}
                step={0.1}
                value={polRatioInitInput}
                onChange={e => setPolRatioInitInput(e.target.value)}
              />

              <Label sx={{ mt: 3 }}>Toll [%]</Label>
              <Input
                type="number"
                min={0}
                step={1}
                value={tollPctInput}
                onChange={e => setTollPctInput(e.target.value)}
              />

              <Label sx={{ mt: 3 }}>Toll Basis</Label>
              <Select value={tollBasis} onChange={e => setTollBasis(checkTollBasis(e.target.value))}>
                {[...tollBasisOptions].map(([key, description]) => (
                  <option key={key} value={key}>
                    {description}
                  </option>
                ))}
              </Select>
            </Box>

            <Heading as="h4">Chicken Bond</Heading>
            <Box sx={groupStyle}>
              <Label>Bonded [TOKEN]</Label>
              <Input
                type="number"
                min={0}
                value={bondInput}
                onChange={e => setBondInput(e.target.value)}
              />

              <Label sx={{ mt: 3 }}>Curve</Label>
              <Textarea
                sx={!curveSeries ? { bg: "pink" } : {}}
                value={fCurveInput}
                onChange={e => setFCurveInput(e.target.value)}
              />
            </Box>

            <Flex sx={{ alignItems: "center", justifyContent: "space-between" }}>
              <Heading as="h4">Market</Heading>
              <Box
                sx={{
                  span: {
                    fontSize: 1,
                    fontWeight: "bold",
                    lineHeight: 1
                  }
                }}
              >
                <Switch
                  label="𝑓(𝑘)"
                  checked={useFunctions}
                  onChange={() => setUseFunctions(!useFunctions)}
                />
              </Box>
            </Flex>

            <Box sx={groupStyle}>
              <Label>TOKEN Natural Rate [%]</Label>
              {useFunctions ? (
                <Textarea
                  sx={!yieldSeries ? { bg: "pink" } : {}}
                  value={fNaturalRatePctInput}
                  onChange={e => setFNaturalRatePctInput(e.target.value)}
                />
              ) : (
                <Input
                  type="number"
                  value={naturalRatePctInput}
                  onChange={e => setNaturalRatePctInput(e.target.value)}
                />
              )}

              <Label sx={{ mt: 3 }}>sTOKEN Premium [%]</Label>
              {useFunctions ? (
                <Textarea
                  sx={!premiumSeries ? { bg: "pink" } : {}}
                  value={fPremiumPctInput}
                  onChange={e => setFPremiumPctInput(e.target.value)}
                />
              ) : (
                <Input
                  type="number"
                  value={premiumPctInput}
                  onChange={e => setPremiumPctInput(e.target.value)}
                />
              )}
            </Box>
          </Flex>
        </Box>

        <Box sx={{ flexGrow: 1, mt: 4 }}>
          <Box sx={{ ml: 5 }}>
            <Label sx={{ mb: 2, fontWeight: "bold" }}>Right Axis</Label>

            {Object.entries(rightAxisOptions).map(([key, { name }]) => (
              <Label key={key} sx={{ ml: 2 }}>
                <Radio
                  name="right-axis"
                  value={key}
                  checked={rightAxis === key}
                  onChange={e => setRightAxis(checkRightAxis(e.target.value))}
                />
                {name}
              </Label>
            ))}
          </Box>

          <VictoryChart
            theme={VictoryTheme.material}
            width={800}
            height={500}
            domainPadding={{ y: [1, 25] }}
            padding={{
              top: 20,
              bottom: 45,
              left: 55,
              right: 220
            }}
            containerComponent={
              <VictoryVoronoiContainer
                voronoiDimension="x"
                voronoiBlacklist={["maxArr"]}
                labels={({ datum }) =>
                  `${datum.childName}: ${
                    rightAxisLabelSet.has(datum.childName)
                      ? percent(datum._y)
                      : Math.round(
                          (datum.childName.includes("[sTOKEN]") ? datum.sTOKEN : datum._y) * 100
                        ) / 100
                  }`
                }
                labelComponent={<Tooltip centerOffset={{ y: -56 }} />}
              />
            }
          >
            <VictoryLegend
              x={660}
              y={140}
              colorScale={colorScale}
              data={[
                { name: "Top-up" },
                { name: "Payout (In)" },
                { name: "Payout (Up)" },

                ...Object.values(rightAxisOptions[rightAxis].labels).map(name => ({ name }))
              ]}
            />

            <VictoryAxis />
            <VictoryAxis dependentAxis />
            <VictoryAxis dependentAxis orientation="right" tickFormat={percent} />

            {maxArr && (
              <VictoryLine
                name="maxArr"
                style={{
                  data: { strokeWidth: 1, stroke: "rgb(144, 164, 174)" },
                  labels: { fontWeight: "bold" }
                }}
                labels={[`Max ARR = ${Math.round(maxArr.y * 10000) / 100}%`]}
                labelComponent={
                  <VictoryLabel
                    y={rightAxis === "toll" ? 48 : 20} // XXX
                    dx={maxArr.x < range[range.length - 1] * 0.75 ? 5 : -5}
                    textAnchor={maxArr.x < range[range.length - 1] * 0.75 ? "start" : "end"}
                  />
                }
                x={() => maxArr.x}
              />
            )}

            {(topUpSeries || payoutInSeries || payoutUpSeries || rightAxisIn || rightAxisUp) && (
              <VictoryGroup>
                {topUpSeries && (
                  <VictoryLine name="Top-up [TOKEN]" data={topUpSeries} style={topUpStyle} />
                )}

                {payoutInSeries && (
                  <VictoryLine
                    name="Payout (In) [sTOKEN]"
                    data={payoutInSeries}
                    style={payoutInStyle}
                  />
                )}

                {payoutUpSeries && (
                  <VictoryLine
                    name="Payout (Up) [sTOKEN]"
                    data={payoutUpSeries}
                    style={payoutUpStyle}
                  />
                )}

                {rightAxisIn && (
                  <VictoryLine
                    name={rightAxisOptions[rightAxis].labels.in}
                    data={rightAxisIn}
                    style={rightAxisInStyle}
                  />
                )}

                {rightAxisUp && (
                  <VictoryLine
                    name={rightAxisOptions[rightAxis].labels.up}
                    data={rightAxisUp}
                    style={rightAxisUpStyle}
                  />
                )}
              </VictoryGroup>
            )}
          </VictoryChart>
        </Box>
      </Flex>
    </ThemeProvider>
  );
};

export default App;
