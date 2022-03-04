import { createContext, useContext, useEffect, useState } from "react";

import { ChickenFarm, ChickenFarmDatum, ChickenFarmSteerParams } from "../model/ChickenFarm";
import { parseSimulationKnobs, SimulationKnobs } from "../knobs";
import { useKnobs } from "./KnobsProvider";
import { collectSamples, PID } from "../utils";

export interface SimulationContextType {
  samples: number;
  period: number;
  data: ChickenFarmDatum[];
}

const SimulationContext = createContext<SimulationContextType>({
  samples: 0,
  period: 0,
  data: []
});

const asymmetricSteer =
  (adjustmentRate: number) =>
  ({ e, u }: ChickenFarmSteerParams) =>
    e < 0 ? u * (1 - adjustmentRate) : u;

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
  samples: number;
  passes: number;
}

export const SimulationProvider: React.FC<SimulationProviderProps> = ({
  debounceDelayMs,
  period,
  samples,
  passes,
  children
}) => {
  const { state } = useKnobs<SimulationKnobs>();
  const [data, setData] = useState<ChickenFarmDatum[]>([]);

  useEffect(() => {
    let cancelled = false;

    setTimeout(() => {
      if (cancelled) {
        return;
      }

      setData([]);

      try {
        const { selectedSteer, asymmetricAdjustmentRate, pidKp, pidKi, pidKd, ...params } =
          parseSimulationKnobs(state);

        const steer =
          selectedSteer === "asymmetric"
            ? asymmetricSteer(asymmetricAdjustmentRate)
            : pidSteer(period, pidKp, pidKi, pidKd);

        const farm = new ChickenFarm({ period, steer, ...params });

        let collectedData: ChickenFarmDatum[] = [];
        let pass = 1;

        const scheduleOnePass = () => {
          setTimeout(() => {
            const samplesThisPass = Math.round((pass / passes) * samples) - collectedData.length;

            if (cancelled) {
              return;
            }

            try {
              collectedData = [
                ...collectedData,
                ...collectSamples(samplesThisPass, () => farm.farm())
              ];
            } catch (error) {
              console.error(error);
            }

            setData(collectedData);

            if (pass++ < passes) {
              scheduleOnePass();
            } else {
              console.log(collectedData);
            }
          }, 0);
        };

        scheduleOnePass();
      } catch (error) {
        console.error(error);
      }
    }, debounceDelayMs);

    return () => {
      cancelled = true;
    };
  }, [debounceDelayMs, passes, period, samples, state]);

  return (
    <SimulationContext.Provider value={{ samples, period, data }}>
      {children}
    </SimulationContext.Provider>
  );
};

export const useSimulation = () => useContext(SimulationContext);
