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
  "#45B29D",
  "#EFC94C",
  "#E27A3F",
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

const [accruedStyle, cappedStyle, topUpStyle, arrInStyle, arrUpStyle] = colorScale.map(color =>
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

const numSamples = 201;
const range = [...Array(numSamples).keys()];

const tollBasisOptions = new Map([
  ["initial" as const, "Initial bond"],
  ["toppedUp" as const, "Topped-up bond"]
]);

type TollBasis = typeof tollBasisOptions extends Map<infer T, unknown> ? T : never;

const checkTollBasis = (value: string): TollBasis => {
  if (!(tollBasisOptions as Map<string, never>).has(value)) {
    throw new Error(`wrong TollBasis value "${value}"`);
  }

  return value as TollBasis;
};

const defaultPolRatioInit = 3;
const defaultTollPct = 20;
const defaultTollBasis = "initial";
const defaultPremiumPct = 45;
const defaultNaturalRatePct = 10;
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
  const [revertDummy, revert] = useReducer(() => ({}), {});

  useEffect(() => {
    setPolRatioInitInput(`${defaultPolRatioInit}`);
    setTollPctInput(`${defaultTollPct}`);
    setPremiumPctInput(`${defaultPremiumPct}`);
    setFPremiumPctInput(`${defaultFPremiumPct}`);
    setNaturalRatePctInput(`${defaultNaturalRatePct}`);
    setFNaturalRatePctInput(`${defaultFNaturalRatePct}`);
    setBondInput(`${defaultBond}`);
    setFCurveInput(`${defaultFCurve}`);
    setUseFunctions(false);
  }, [revertDummy]);

  const polRatioInit = Number(polRatioInitInput);
  const naturalRatePct = Number(naturalRatePctInput);
  const premiumPct = Number(premiumPctInput);
  const bond = Number(bondInput);
  const tollPct = Number(tollPctInput);

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
      if (!isNaN(naturalRatePct)) {
        const y = Math.pow(1 + naturalRatePct / 100, 1 / range[range.length - 1]);

        return range.map(x => ({ x, y }));
      }
    }
  }, [useFunctions, naturalRatePct, fNaturalRatePctInput]);

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
    if (isNaN(bond) || isNaN(tollPct) || !polRatioSeries || !accruedSeries) {
      return undefined;
    }

    return accruedSeries.map(({ x, y: accrued }, i) => ({
      x,
      y: Math.min(accrued, ((1 - tollPct / 100) * bond) / polRatioSeries[i].y)
    }));
  }, [bond, tollPct, polRatioSeries, accruedSeries]);

  const topUpSeries = useMemo(() => {
    if (isNaN(bond) || isNaN(tollPct) || !polRatioSeries || !accruedSeries || !cappedSeries) {
      return undefined;
    }

    return accruedSeries.map(({ x, y: accrued }, i) => ({
      x,
      y: Math.max(
        ((accrued - cappedSeries[i].y) * polRatioSeries[i].y) /
          (1 - (tollBasis === "toppedUp" ? tollPct / 100 : 0)),
        0
      )
    }));
  }, [bond, tollPct, tollBasis, polRatioSeries, accruedSeries, cappedSeries]);

  const premiumPctSeries = useMemo(() => {
    if (useFunctions) {
      try {
        // eslint-disable-next-line no-new-func
        const f = new Function("k", `"use strict"; return ${fPremiumPctInput};`)();

        return range.map(x => ({ x, y: f(x) }));
      } catch {}
    } else {
      if (!isNaN(premiumPct)) {
        return range.map(x => ({ x, y: premiumPct }));
      }
    }
  }, [useFunctions, premiumPct, fPremiumPctInput]);

  const arrInSeries = useMemo(() => {
    if (isNaN(bond) || !cappedSeries || !polRatioSeries || !premiumPctSeries) {
      return undefined;
    }

    return cappedSeries.map(({ x, y: capped }, i) => ({
      x,
      y:
        x !== 0
          ? Math.pow(
              (capped * polRatioSeries[i].y * (1 + premiumPctSeries[i].y / 100)) / bond,
              range[range.length - 1] / x
            ) - 1
          : null
    }));
  }, [bond, cappedSeries, polRatioSeries, premiumPctSeries]);

  const arrUpSeries = useMemo(() => {
    if (isNaN(bond) || !accruedSeries || !topUpSeries || !polRatioSeries || !premiumPctSeries) {
      return undefined;
    }

    return accruedSeries.map(({ x, y: accrued }, i) => ({
      x,
      y:
        x !== 0
          ? Math.pow(
              (accrued * polRatioSeries[i].y * (1 + premiumPctSeries[i].y / 100) -
                topUpSeries[i].y) /
                bond,
              range[range.length - 1] / x
            ) - 1
          : null
    }));
  }, [bond, accruedSeries, topUpSeries, polRatioSeries, premiumPctSeries]);

  const maxAccrued = seriesMax(accruedSeries);
  const maxTopUp = seriesMax(topUpSeries);
  const maxArrIn = seriesMax(arrInSeries);
  const maxArrUp = seriesMax(arrUpSeries);

  const scale = Math.max(maxAccrued, maxTopUp) / Math.max(maxArrIn, maxArrUp);
  const percent = (y: number) => `${Math.round((y * 10000) / scale) / 100}%`;

  const scaledArrIn = arrInSeries
    ?.filter((irr): irr is { x: number; y: number } => irr.y != null && irr.y >= -0.25)
    .map(({ x, y }) => ({ x, y: y * scale }));

  const scaledArrUp = arrUpSeries
    ?.filter((irr): irr is { x: number; y: number } => irr.y != null && irr.y >= -0.25)
    .map(({ x, y }) => ({ x, y: y * scale }));

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
                  sx={!premiumPctSeries ? { bg: "pink" } : {}}
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
                    datum.childName === "ARR (In)" || datum.childName === "ARR (Up)"
                      ? percent(datum._y)
                      : Math.round(datum._y * 100) / 100
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
                { name: "Accrued [sTOKEN]" },
                { name: "Capped [sTOKEN]" },
                { name: "Top-up [TOKEN]" },
                { name: "ARR (In)" },
                { name: "ARR (Up)" }
              ]}
            />

            <VictoryAxis />
            <VictoryAxis dependentAxis />
            <VictoryAxis dependentAxis orientation="right" tickFormat={percent} />

            {(accruedSeries || cappedSeries || topUpSeries || scaledArrIn || scaledArrUp) && (
              <VictoryGroup>
                {accruedSeries && (
                  <VictoryLine name="Accrued [sTOKEN]" data={accruedSeries} style={accruedStyle} />
                )}

                {cappedSeries && (
                  <VictoryLine name="Capped [sTOKEN]" data={cappedSeries} style={cappedStyle} />
                )}

                {topUpSeries && (
                  <VictoryLine name="Top-up (Up) [TOKEN]" data={topUpSeries} style={topUpStyle} />
                )}

                {scaledArrIn && (
                  <VictoryLine name="ARR (In)" data={scaledArrIn} style={arrInStyle} />
                )}
                {scaledArrUp && (
                  <VictoryLine name="ARR (Up)" data={scaledArrUp} style={arrUpStyle} />
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
