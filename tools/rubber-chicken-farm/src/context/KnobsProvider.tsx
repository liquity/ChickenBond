import { createContext, useCallback, useContext, useReducer } from "react";

export interface KnobsContextType<T> {
  state: Readonly<T>;
  set<P extends keyof T>(key: P, value: T[P]): void;
  resetAll(): void;
}

const KnobsContext = createContext<KnobsContextType<unknown>>({
  state: {},

  set() {
    throw new Error("You must use a <SimulationKnobsProvider>");
  },

  resetAll() {}
});

type KnobsAction<T> = { type: "set"; key: keyof T; value: unknown } | { type: "resetAll" };

function knobsReducer<T>(defaults: Readonly<T>) {
  return (state: Readonly<T>, action: KnobsAction<T>): Readonly<T> => {
    switch (action.type) {
      case "set":
        return {
          ...state,
          [action.key]: action.value
        };

      case "resetAll":
        return defaults;
    }
  };
}

export interface KnobsProviderProps<T> {
  defaults: Readonly<T>;
}

export function KnobsProvider<T>({
  defaults,
  children
}: React.PropsWithChildren<KnobsProviderProps<T>>) {
  const [state, dispatch] = useReducer(knobsReducer(defaults), defaults);
  const set = useCallback((key, value) => dispatch({ type: "set", key, value }), []);
  const resetAll = useCallback(() => dispatch({ type: "resetAll" }), []);

  return <KnobsContext.Provider value={{ state, set, resetAll }}>{children}</KnobsContext.Provider>;
}

export function useKnobs<T>() {
  return useContext(KnobsContext as React.Context<KnobsContextType<T>>);
}
