import { ShellColor, shellColors, Traits } from "../traits";
import { useKnobs } from "../context/KnobsProvider";

export const ActiveKnobs = () => {
  const [state, set] = useKnobs<Traits>();

  return (
    <div>
      <label htmlFor="shell-color">Egg: </label>

      <select
        id="shell-color"
        value={state.shellColor}
        onChange={e => set({ shellColor: e.target.value as ShellColor })}
      >
        {shellColors.map(color => (
          <option key={color}>{color}</option>
        ))}
      </select>
    </div>
  );
};
