import { Wallet } from "@ethersproject/wallet";
import { Decimal } from "@liquity/lib-base";
import { lambertW0 } from "lambert-w";
import { Box, Flex, ThemeProvider } from "theme-ui";

import { ChickenFarm } from "./model/ChickenFarm";
import { asymmetricFarm } from "./examples/asymmetric";
import { cyclingFarm } from "./examples/cycling";
import { constantFarm } from "./examples/constant";

import theme from "./theme";
import { simulationDefaults } from "./knobs";
import { collectSamples, csv, flatten, lowpass, randomBinomial } from "./utils";
import { installLUSDChickenBonds, LUSDChickenBondGlobals } from "./utils/tinker";
import { KnobsProvider } from "./context/KnobsProvider";
import { SimulationProvider } from "./context/SimulationProvider";
import { Knobs } from "./components/Knobs";
import { ControlChart } from "./components/ControlChart";
import { ProtocolChart } from "./components/ProtocolChart";

declare global {
  interface Window extends LUSDChickenBondGlobals {}
}

Object.assign(window, {
  // utilities used by "knob" functions
  lowpass,
  round: Math.round,
  random: Math.random,
  randomBinomial,
  W: lambertW0,

  // ChickenFarm constructor function and example ChickenFarms
  ChickenFarm,
  asymmetricFarm,
  cyclingFarm,
  constantFarm,

  // utilities for running simulations in the console and exporting results
  collectSamples,
  flatten,
  csv,

  Decimal,
  Wallet
});

// console interaction with the real Solidity implementation
installLUSDChickenBonds(window);

const App = () => (
  <ThemeProvider theme={theme}>
    <KnobsProvider defaults={simulationDefaults}>
      {/* <Heading as="h1">🐔 Crazy Chicken Farm</Heading> */}

      <Flex sx={{ alignItems: "flex-start" }}>
        <Knobs />

        <Box sx={{ flexGrow: 1, py: 4, maxHeight: "100vh", overflow: "auto" }}>
          <SimulationProvider period={360} debounceDelayMs={200} passes={100} passPerRender={20}>
            <ControlChart />
            <ProtocolChart />
          </SimulationProvider>
        </Box>
      </Flex>
    </KnobsProvider>
  </ThemeProvider>
);

export default App;
