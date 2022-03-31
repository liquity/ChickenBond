import { useEffect, useMemo, useReducer, useState } from "react";

import {
  Box,
  Button,
  Flex,
  Heading,
  Input,
  Label,
  Radio,
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
  "#4F7DA1"
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

const [bondedStyle, capStyle, payoutStyle, rightAxisStyle] = colorScale.map(color =>
  lineStyle(color)
);

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

const numSamples = 366;
const range = [...Array(numSamples).keys()];

const rightAxisOptions = {
  roi: {
    name: "Return on Investment",
    label: "ROI"
  },

  apr: {
    name: "Annual Percentage Rate",
    label: "APR"
  },

  arr: {
    name: "Annualized Rate of Return",
    label: "ARR"
  },

  toll: {
    name: "Toll",
    label: "Toll"
  }
};

type RightAxis = keyof typeof rightAxisOptions;

const checkRightAxis = (value: string): RightAxis => {
  if (!Object.keys(rightAxisOptions).includes(value)) {
    throw new Error(`wrong RightAxis value "${value}"`);
  }

  return value as RightAxis;
};

const rightAxisLabelSet = new Set(Object.values(rightAxisOptions).map(o => o.label));

type Series = { x: number; y: number }[] | undefined;

const defaultPolRatioInit = 4;
const defaultFairPremiumPct = 100;
const defaultMktDeviationPct = 0;
const defaultNaturalRatePct = 0;
const defaultBond = 100;

const defaultFCurve = `p => k => k / (k + 60)`;
const defaultFFairPremiumPct = `k => ${defaultFairPremiumPct}`;
const defaultFMktDeviationPct = `k => ${defaultMktDeviationPct}`;
const defaultFNaturalRatePct = `k => ${defaultNaturalRatePct}`;

const App = () => {
  const [polRatioInitInput, setPolRatioInitInput] = useState(`${defaultPolRatioInit}`);
  const [fairPremiumPctInput, setFairPremiumPctInput] = useState(`${defaultFairPremiumPct}`);
  const [fFairPremiumPctInput, setFFairPremiumPctInput] = useState(`${defaultFFairPremiumPct}`);
  const [mktDeviationPctInput, setMktDeviationPctInput] = useState(`${defaultMktDeviationPct}`);
  const [fMktDeviationPctInput, setFMktDeviationPctInput] = useState(`${defaultFMktDeviationPct}`);
  const [naturalRatePctInput, setNaturalRatePctInput] = useState(`${defaultNaturalRatePct}`);
  const [fNaturalRatePctInput, setFNaturalRatePctInput] = useState(`${defaultFNaturalRatePct}`);
  const [bondInput, setBondInput] = useState(`${defaultBond}`);
  const [fCurveInput, setFCurveInput] = useState(`${defaultFCurve}`);
  const [useFunctions, setUseFunctions] = useState(false);
  const [rightAxis, setRightAxis] = useState<RightAxis>("arr");
  const [revertDummy, revert] = useReducer(() => ({}), {});

  useEffect(() => {
    setPolRatioInitInput(`${defaultPolRatioInit}`);
    setFairPremiumPctInput(`${defaultFairPremiumPct}`);
    setFFairPremiumPctInput(`${defaultFFairPremiumPct}`);
    setMktDeviationPctInput(`${defaultMktDeviationPct}`);
    setFMktDeviationPctInput(`${defaultFMktDeviationPct}`);
    setNaturalRatePctInput(`${defaultNaturalRatePct}`);
    setFNaturalRatePctInput(`${defaultFNaturalRatePct}`);
    setBondInput(`${defaultBond}`);
    setFCurveInput(`${defaultFCurve}`);
    setUseFunctions(false);
  }, [revertDummy]);

  const polRatioInit = Number(polRatioInitInput);
  const naturalRate = Number(naturalRatePctInput) / 100;
  const fairPremium = Number(fairPremiumPctInput) / 100;
  const mktDeviation = Number(mktDeviationPctInput) / 100;
  const bond = Number(bondInput);

  const yieldSeries = useMemo(() => {
    if (useFunctions) {
      try {
        // eslint-disable-next-line no-new-func
        const f = new Function("k", `"use strict"; return ${fNaturalRatePctInput};`)();

        return range.map(x => ({
          x,
          y: (1 + f(x) / 100) ** (1 / range[range.length - 1])
        }));
      } catch {}
    } else {
      if (!isNaN(naturalRate)) {
        const y = (1 + naturalRate) ** (1 / range[range.length - 1]);

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

  const fairPremiumSeries = useMemo(() => {
    if (useFunctions) {
      try {
        // eslint-disable-next-line no-new-func
        const f = new Function("k", `"use strict"; return ${fFairPremiumPctInput};`)();

        return range.map(x => ({ x, y: f(x) / 100 }));
      } catch {}
    } else {
      if (!isNaN(fairPremium)) {
        return range.map(x => ({ x, y: fairPremium }));
      }
    }
  }, [useFunctions, fairPremium, fFairPremiumPctInput]);

  const mktDeviationSeries = useMemo(() => {
    if (useFunctions) {
      try {
        // eslint-disable-next-line no-new-func
        const f = new Function("k", `"use strict"; return ${fMktDeviationPctInput};`)();

        return range.map(x => ({ x, y: f(x) / 100 }));
      } catch {}
    } else {
      if (!isNaN(mktDeviation)) {
        return range.map(x => ({ x, y: mktDeviation }));
      }
    }
  }, [useFunctions, mktDeviation, fMktDeviationPctInput]);

  const tollSeries = useMemo(() => {
    const p = fairPremiumSeries ? fairPremiumSeries[0].y : 0;

    try {
      // eslint-disable-next-line no-new-func
      const f = new Function("k", `"use strict"; return ${fCurveInput};`)()(p);

      return range.map(x => ({ x, y: 1 - f(x) }));
    } catch {}
  }, [fCurveInput, fairPremiumSeries]);

  const capSeries = useMemo(() => {
    if (isNaN(bond) || !polRatioSeries || !fairPremiumSeries || !mktDeviationSeries) {
      return undefined;
    }

    return polRatioSeries.map(({ x, y: polRatio }, i) => ({
      x,
      sTOKEN: bond / polRatio,
      y: bond * (1 + fairPremiumSeries[i].y) * (1 + mktDeviationSeries[i].y)
    }));
  }, [bond, polRatioSeries, fairPremiumSeries, mktDeviationSeries]);

  const payoutSeries = useMemo(() => {
    if (!capSeries || !tollSeries) {
      return undefined;
    }

    return capSeries.map(({ x, sTOKEN, y }, i) => ({
      x,
      sTOKEN: sTOKEN * (1 - tollSeries[i].y),
      y: y * (1 - tollSeries[i].y)
    }));
  }, [capSeries, tollSeries]);

  const roiSeries = useMemo(() => {
    if (isNaN(bond) || !payoutSeries) {
      return undefined;
    }

    return payoutSeries.map(({ x, y: payout }) => ({
      x,
      y: payout / bond - 1
    }));
  }, [bond, payoutSeries]);

  const aprSeries = useMemo(() => {
    if (!roiSeries) {
      return undefined;
    }

    return roiSeries.map(({ x, y: roi }) => ({
      x,
      y: x !== 0 ? roi * (range[range.length - 1] / x) : -1 / 0
    }));
  }, [roiSeries]);

  const arrSeries = useMemo(() => {
    if (!roiSeries) {
      return undefined;
    }

    return roiSeries.map(({ x, y: roi }) => ({
      x,
      y: (x !== 0 ? (1 + roi) ** (range[range.length - 1] / x) : 0) - 1
    }));
  }, [roiSeries]);

  const rightAxisMap: { [k: string]: Series } = {
    roi: roiSeries,
    apr: aprSeries?.filter(({ y }) => y >= -1),
    arr: arrSeries,
    toll: tollSeries
  };

  const rawRightAxis = rightAxisMap[rightAxis];

  const maxLeftAxis = seriesMax(payoutSeries);
  const maxRightAxis = seriesMax(rawRightAxis);
  const scale = maxLeftAxis / maxRightAxis;
  const scaledRightAxis = rawRightAxis?.map(({ x, y }) => ({ x, y: y * scale }));

  const percent = (y: number) => `${Math.round((y * 10000) / scale) / 100}%`;

  const maxApr = aprSeries?.reduce((a, b) => (a.y > b.y ? a : b));
  const maxArr = arrSeries?.reduce((a, b) => (a.y > b.y ? a : b));

  return (
    <ThemeProvider theme={theme}>
      <Heading as="h1">🐔 Crazier Chicken Investment Calculator</Heading>

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

              <Label sx={{ mt: 3 }}>Accrual Curve</Label>
              <Textarea
                sx={!tollSeries ? { bg: "pink" } : {}}
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

              <Label sx={{ mt: 3 }}>sTOKEN Fair Premium [%]</Label>
              {useFunctions ? (
                <Textarea
                  sx={!fairPremiumSeries ? { bg: "pink" } : {}}
                  value={fFairPremiumPctInput}
                  onChange={e => setFFairPremiumPctInput(e.target.value)}
                />
              ) : (
                <Input
                  type="number"
                  min={0}
                  value={fairPremiumPctInput}
                  onChange={e => setFairPremiumPctInput(e.target.value)}
                />
              )}

              <Label sx={{ mt: 3 }}>sTOKEN Market Deviation [%]</Label>
              {useFunctions ? (
                <Textarea
                  sx={!mktDeviationSeries ? { bg: "pink" } : {}}
                  value={fMktDeviationPctInput}
                  onChange={e => setFMktDeviationPctInput(e.target.value)}
                />
              ) : (
                <Input
                  type="number"
                  value={mktDeviationPctInput}
                  onChange={e => setMktDeviationPctInput(e.target.value)}
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
                voronoiBlacklist={["maxApr", "maxArr"]}
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
                { name: "Bonded" },
                { name: "Cap" },
                { name: "Payout" },
                { name: rightAxisOptions[rightAxis].label }
              ]}
            />

            <VictoryAxis />
            <VictoryAxis dependentAxis />
            <VictoryAxis dependentAxis orientation="right" tickFormat={percent} />

            {maxApr && (
              <VictoryLine
                name="maxApr"
                style={{
                  data: { strokeWidth: 1, stroke: "rgb(144, 164, 174)", strokeDasharray: "5,5" },
                  labels: { fontWeight: "bold" }
                }}
                labels={[`Max APR ≈ ${Math.round(maxApr.y * 10000) / 100}%`]}
                labelComponent={
                  <VictoryLabel
                    y={rightAxis === "toll" ? 458 : 430} // XXX
                    dx={maxApr.x < range[range.length - 1] * 0.75 ? 5 : -5}
                    textAnchor={maxApr.x < range[range.length - 1] * 0.75 ? "start" : "end"}
                  />
                }
                x={() => maxApr.x}
              />
            )}

            {maxArr && (
              <VictoryLine
                name="maxArr"
                style={{
                  data: { strokeWidth: 1, stroke: "rgb(144, 164, 174)" },
                  labels: { fontWeight: "bold" }
                }}
                labels={[`Max ARR ≈ ${Math.round(maxArr.y * 10000) / 100}%`]}
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

            {(!isNaN(bond) || capSeries || payoutSeries || scaledRightAxis) && (
              <VictoryGroup>
                {!isNaN(bond) && (
                  <VictoryLine
                    name="Bonded [TOKEN]"
                    data={range.map(x => ({ x, y: bond }))}
                    style={bondedStyle}
                  />
                )}

                {capSeries && <VictoryLine name="Cap [sTOKEN]" data={capSeries} style={capStyle} />}

                {payoutSeries && (
                  <VictoryLine name="Payout [sTOKEN]" data={payoutSeries} style={payoutStyle} />
                )}

                {scaledRightAxis && (
                  <VictoryLine
                    name={rightAxisOptions[rightAxis].label}
                    data={scaledRightAxis}
                    style={rightAxisStyle}
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
