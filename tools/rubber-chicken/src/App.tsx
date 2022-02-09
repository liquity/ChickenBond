import { useEffect, useMemo, useReducer, useState } from "react";

import {
  Box,
  Button,
  Flex,
  Heading,
  Input,
  Label,
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

const [topUpStyle, payoutInStyle, payoutUpStyle, returnInStyle, returnUpStyle] = colorScale.map(
  color => lineStyle(color)
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

const returnLabels = {
  roi: {
    in: "ROI (In)",
    up: "ROI (Up)"
  },

  arr: {
    in: "ARR (In)",
    up: "ARR (Up)"
  }
};

const percentBasedLabels = new Set(Object.values(returnLabels).flatMap(o => Object.values(o)));

const defaultPolRatioInit = 4;
const defaultTollPct = 20;
const defaultTollBasis = "initial";
const defaultPremiumPct = 100;
const defaultNaturalRatePct = 0;
const defaultBond = 100;

const defaultFCurve = `k => (k / ${range[range.length - 1]})`;
const defaultFPremiumPct = "k => 20";
const defaultFNaturalRatePct = "k => 10";

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
  const [annualize, setAnnualize] = useState(true);
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
      const f = new Function("k", `"use strict"; return ${fCurveInput};`)();

      return range.map(x => ({ x, y: f(x) }));
    } catch {}
  }, [fCurveInput]);

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

  const returnInSeries = useMemo(() => {
    if (isNaN(bond) || !payoutInSeries) {
      return undefined;
    }

    return payoutInSeries.map(({ x, y: payout }) => ({
      x,
      y: (x !== 0 ? Math.pow(payout / bond, annualize ? range[range.length - 1] / x : 1) : 0) - 1
    }));
  }, [bond, payoutInSeries, annualize]);

  const returnUpSeries = useMemo(() => {
    if (isNaN(bond) || !payoutUpSeries || !topUpSeries) {
      return undefined;
    }

    return payoutUpSeries.map(({ x, y: payout }, i) => ({
      x,
      y:
        (x !== 0
          ? Math.pow((payout - topUpSeries[i].y) / bond, annualize ? range[range.length - 1] / x : 1)
          : 0) - 1
    }));
  }, [bond, payoutUpSeries, topUpSeries, annualize]);

  const maxPayout = seriesMax(payoutUpSeries);
  const maxTopUp = seriesMax(topUpSeries);
  const maxReturnIn = seriesMax(returnInSeries);
  const maxReturnUp = seriesMax(returnUpSeries);

  const scale = Math.max(maxPayout, maxTopUp) / Math.max(maxReturnIn, maxReturnUp);
  const percent = (y: number) => `${Math.round((y * 10000) / scale) / 100}%`;

  const scaledReturnIn = returnInSeries?.map(({ x, y }) => ({ x, y: y * scale }));
  const scaledReturnUp = returnUpSeries?.map(({ x, y }) => ({ x, y: y * scale }));

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
                  rows={5}
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
                  rows={5}
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
          <Box
            sx={{
              ml: 5,
              span: {
                fontSize: 1,
                fontWeight: "bold",
                lineHeight: 1
              }
            }}
          >
            <Switch
              label="Annualize returns"
              checked={annualize}
              onChange={() => setAnnualize(!annualize)}
            />
          </Box>

          <VictoryChart
            theme={VictoryTheme.material}
            width={800}
            height={500}
            domainPadding={{ y: 1 }}
            padding={{
              top: 20,
              bottom: 45,
              left: 55,
              right: 220
            }}
            containerComponent={
              <VictoryVoronoiContainer
                voronoiDimension="x"
                labels={({ datum }) =>
                  `${datum.childName}: ${
                    percentBasedLabels.has(datum.childName)
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
              x={645}
              y={140}
              colorScale={colorScale}
              data={[
                { name: "Top-up" },
                { name: "Payout (In)" },
                { name: "Payout (Up)" },

                ...Object.values(annualize ? returnLabels.arr : returnLabels.roi).map(name => ({
                  name
                }))
              ]}
            />

            <VictoryAxis />
            <VictoryAxis dependentAxis />
            <VictoryAxis dependentAxis orientation="right" tickFormat={percent} />

            {(topUpSeries ||
              payoutInSeries ||
              payoutUpSeries ||
              scaledReturnIn ||
              scaledReturnUp) && (
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

                {scaledReturnIn && (
                  <VictoryLine
                    name={annualize ? returnLabels.arr.in : returnLabels.roi.in}
                    data={scaledReturnIn}
                    style={returnInStyle}
                  />
                )}

                {scaledReturnUp && (
                  <VictoryLine
                    name={annualize ? returnLabels.arr.up : returnLabels.roi.up}
                    data={scaledReturnUp}
                    style={returnUpStyle}
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
