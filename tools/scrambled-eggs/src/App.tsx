import { defaultTraits } from "./traits";
import { KnobsProvider } from "./context/KnobsProvider";
import { Main } from "./components/Main";

export const App: React.FC = () => {
  return (
    <KnobsProvider initialState={defaultTraits}>
      <Main />
    </KnobsProvider>
  );
};
