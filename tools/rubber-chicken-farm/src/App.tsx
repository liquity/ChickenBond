import { lambertW0 } from "lambert-w";
import { Box, Flex, ThemeProvider } from "theme-ui";

import { ChickenFarm } from "./model/ChickenFarm";
import { asymmetricFarm } from "./examples/asymmetric";
import { cyclingFarm } from "./examples/cycling";
import { constantFarm } from "./examples/constant";

import theme from "./theme";
import { simulationDefaults } from "./knobs";
import { collectSamples, csv, flatten } from "./utils";
import { KnobsProvider } from "./context/KnobsProvider";
import { SimulationProvider } from "./context/SimulationProvider";
import { Knobs } from "./components/Knobs";
import { SimulationChart } from "./components/SimulationChart";

Object.assign(window, {
  ChickenFarm,
  collectSamples,
  asymmetricFarm,
  cyclingFarm,
  constantFarm,
  csv,
  flatten,
  W: lambertW0
});

const period = 365;
const samples = 4 * period + 1;

const App = () => (
  <ThemeProvider theme={theme}>
    <KnobsProvider defaults={simulationDefaults}>
      {/* <Heading as="h1">🐔 Crazy Chicken Farm</Heading> */}

      <Flex sx={{ alignItems: "flex-start" }}>
        <Knobs />

        <Box sx={{ flexGrow: 1, mt: 4 }}>
          <SimulationProvider period={period} samples={samples} debounceDelayMs={200} passes={20}>
            <SimulationChart />
          </SimulationProvider>
        </Box>
      </Flex>
    </KnobsProvider>
  </ThemeProvider>
);

export default App;