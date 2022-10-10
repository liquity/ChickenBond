import { createContext, useContext, useReducer } from "react";

export type KnobsContextType<T = unknown> = [state: T, setState: (values: Partial<T>) => void];

const KnobsContext = createContext<KnobsContextType>([
  {},

  () => {
    throw new Error("You must use a <SimulationKnobsProvider>");
  }
]);

export interface KnobsProviderProps<T> extends React.PropsWithChildren {
  initialState: T;
}

export function KnobsProvider<T>({ initialState, children }: KnobsProviderProps<T>) {
  return (
    <KnobsContext.Provider
      value={useReducer(
        (state: T, values: Partial<T>): T => ({ ...state, ...values }),
        initialState
      )}
    >
      {children}
    </KnobsContext.Provider>
  );
}

export function useKnobs<T>() {
  return useContext(KnobsContext as React.Context<KnobsContextType<T>>);
}
