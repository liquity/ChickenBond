import { createContext, useContext, useEffect, useState } from "react";

import { ChickenFarm, ChickenFarmDatum, ChickenFarmSteerParams } from "../model/ChickenFarm";
import { parseSimulationKnobs, SimulationKnobs } from "../knobs";
import { useKnobs } from "./KnobsProvider";
import { collectSamples, percent, PID, round } from "../utils";

export interface SimulationContextType {
  period: number;
  data: ChickenFarmDatum[];
}

const SimulationContext = createContext<SimulationContextType>({
  period: 0,
  data: []
});

const asymmetricSteer =
  (adjustmentRate: number) =>
  ({ e, u }: ChickenFarmSteerParams) =>
    e < 0 ? u * (1 - adjustmentRate) : u;

const symmetricSteer =
  (adjustmentRate: number) =>
  ({ e, u }: ChickenFarmSteerParams) =>
    e < 0 ? u * (1 - adjustmentRate) : e > 0 ? u / (1 - adjustmentRate) : u;

const coalesceNaN = (x: number, defaultValue: number) => (isNaN(x) ? defaultValue : x);

const pidSteer = (
  period: number,
  pidKp: (params: ChickenFarmSteerParams) => number,
  pidKi: (params: ChickenFarmSteerParams) => number,
  pidKd: (params: ChickenFarmSteerParams) => number
) => {
  const pid = PID(1 / period);

  return (params: ChickenFarmSteerParams) =>
    coalesceNaN(pid(pidKp(params), pidKi(params), pidKd(params), params.e), params.u);
};

export interface SimulationProviderProps {
  debounceDelayMs: number;
  period: number;
  passes: number;
  passPerRender: number;
}

export const SimulationProvider: React.FC<SimulationProviderProps> = ({
  debounceDelayMs,
  period,
  passes,
  passPerRender,
  children
}) => {
  const { latchedState } = useKnobs<SimulationKnobs>();
  const [data, setData] = useState<ChickenFarmDatum[]>([]);

  useEffect(() => {
    let timeoutId = setTimeout(() => {
      const startTime = new Date();

      setData([]);

      try {
        const {
          periods,
          selectedSteer,
          asymmetricAdjustmentRate,
          symmetricAdjustmentRate,
          pidKp,
          pidKi,
          pidKd,
          ...params
        } = parseSimulationKnobs(latchedState);

        const samples = periods * period + 1;

        const steer =
          selectedSteer === "asymmetric"
            ? asymmetricSteer(asymmetricAdjustmentRate)
            : selectedSteer === "symmetric"
            ? symmetricSteer(symmetricAdjustmentRate)
            : pidSteer(period, pidKp, pidKi, pidKd);

        const farm = new ChickenFarm({ period, steer, ...params });

        let collectedData: ChickenFarmDatum[] = [];
        let pass = 1;
        let renderCounter = 0;

        const scheduleOnePass = () =>
          setTimeout(() => {
            const samplesThisPass = Math.round((pass / passes) * samples) - collectedData.length;

            try {
              collectedData = [
                ...collectedData,
                ...collectSamples(samplesThisPass, () => farm.farm())
              ];

              if (pass++ < passes) {
                if (renderCounter++ % passPerRender === 0) {
                  setData(collectedData);
                }

                timeoutId = scheduleOnePass();
              } else {
                setData(collectedData);

                const endTime = new Date();
                const durationMs = endTime.getTime() - startTime.getTime();
                const lastDatum = collectedData[collectedData.length - 1];

                console.log(`Simulation took ${durationMs / 1000} seconds.`);
                console.log("Data:");
                console.log(collectedData);
                console.log("Population:");
                console.log(farm.population);
                console.log("Finals:");
                console.log(`  POL ratio: ${round(lastDatum.polRatio)}`);
                console.log(`  Premium:   ${percent(lastDatum.premium)}`);
                console.log(`  Toll:      ${percent(lastDatum.tollTOKEN / lastDatum.in.TOKEN)}`);
                console.log("---------------------------------------------------------------------");
              }
            } catch (error) {
              console.error(error);
            }
          }, 0);

        timeoutId = scheduleOnePass();
      } catch (error) {
        console.error(error);
      }
    }, debounceDelayMs);

    return () => clearTimeout(timeoutId);
  }, [debounceDelayMs, passes, passPerRender, period, latchedState]);

  return (
    <SimulationContext.Provider value={{ period, data }}>{children}</SimulationContext.Provider>
  );
};

export const useSimulation = () => useContext(SimulationContext);
