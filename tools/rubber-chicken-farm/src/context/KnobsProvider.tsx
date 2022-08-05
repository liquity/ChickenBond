import { createContext, useCallback, useContext, useReducer } from "react";

export interface KnobsContextType<T> {
  state: Readonly<T>;
  latchedState: Readonly<T>;
  set<P extends keyof T>(key: P, value: T[P]): void;
  latch(): void;
  resetAll(): void;
}

const KnobsContext = createContext<KnobsContextType<unknown>>({
  state: {},
  latchedState: {},

  set() {
    throw new Error("You must use a <SimulationKnobsProvider>");
  },

  latch() {},
  resetAll() {}
});

type KnobsAction<T> =
  | {
      type: "set";
      key: keyof T;
      value: unknown;
    }
  | {
      type: "latch" | "resetAll";
    };

interface KnobsState<T> {
  state: Readonly<T>;
  latchedState: Readonly<T>;
}

function knobsReducer<T>(defaults: Readonly<T>) {
  return ({ state, latchedState }: KnobsState<T>, action: KnobsAction<T>): KnobsState<T> => {
    switch (action.type) {
      case "set":
        return {
          state: {
            ...state,
            [action.key]: action.value
          },
          latchedState
        };

      case "latch":
        return {
          state,
          latchedState: state
        };

      case "resetAll":
        return {
          state: defaults,
          latchedState
        };
    }
  };
}

function initialKnobsState<T>(defaults: Readonly<T>): KnobsState<T> {
  return {
    state: defaults,
    latchedState: defaults
  };
}

export interface KnobsProviderProps<T> {
  defaults: Readonly<T>;
}

export function KnobsProvider<T>({
  defaults,
  children
}: React.PropsWithChildren<KnobsProviderProps<T>>) {
  const [{ state, latchedState }, dispatch] = useReducer(
    knobsReducer(defaults),
    initialKnobsState(defaults)
  );

  const set = useCallback((key, value) => dispatch({ type: "set", key, value }), []);
  const latch = useCallback(() => dispatch({ type: "latch" }), []);
  const resetAll = useCallback(() => dispatch({ type: "resetAll" }), []);

  return (
    <KnobsContext.Provider value={{ state, latchedState, set, latch, resetAll }}>
      {children}
    </KnobsContext.Provider>
  );
}

export function useKnobs<T>() {
  return useContext(KnobsContext as React.Context<KnobsContextType<T>>);
}
