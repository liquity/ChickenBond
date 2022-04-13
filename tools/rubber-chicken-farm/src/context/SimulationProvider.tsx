import { createContext, useContext, useEffect, useState } from "react";

import { ChickenFarm, ChickenFarmDatum, ChickenFarmSteerParams } from "../model/ChickenFarm";
import { parseSimulationKnobs, SimulationKnobs } from "../knobs";
import { useKnobs } from "./KnobsProvider";
import { collectSamples, PID } from "../utils";

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
}

export const SimulationProvider: React.FC<SimulationProviderProps> = ({
  debounceDelayMs,
  period,
  passes,
  children
}) => {
  const { state } = useKnobs<SimulationKnobs>();
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
        } = parseSimulationKnobs(state);

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

        const scheduleOnePass = () =>
          setTimeout(() => {
            const samplesThisPass =
              Math.round((pass / passes) ** 2 * samples) - collectedData.length;

            try {
              collectedData = [
                ...collectedData,
                ...collectSamples(samplesThisPass, () => farm.farm())
              ];

              setData(collectedData);

              if (pass++ < passes) {
                timeoutId = scheduleOnePass();
              } else {
                const endTime = new Date();
                const durationMs = endTime.getTime() - startTime.getTime();
                console.log(`Simulation took ${durationMs / 1000} seconds.`);
                console.log("Data:");
                console.log(collectedData);
                console.log("Population:");
                console.log(farm.population);
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
  }, [debounceDelayMs, passes, period, state]);

  return (
    <SimulationContext.Provider value={{ period, data }}>{children}</SimulationContext.Provider>
  );
};

export const useSimulation = () => useContext(SimulationContext);
