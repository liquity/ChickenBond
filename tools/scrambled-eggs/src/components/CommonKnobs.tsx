import { BorderColor, borderColors, CardColor, cardColors, Size, sizes, Traits } from "../traits";
import { useKnobs } from "../context/KnobsProvider";

export const CommonKnobs = () => {
  const [state, set] = useKnobs<Traits>();

  return (
    <>
      <div>
        <label htmlFor="size">Size: </label>

        <select id="size" value={state.size} onChange={e => set({ size: e.target.value as Size })}>
          {sizes.map(size => (
            <option key={size}>{size}</option>
          ))}
        </select>
      </div>

      <div>
        <label htmlFor="card-color">Border: </label>

        <select
          id="border-color"
          value={state.borderColor}
          onChange={e => set({ borderColor: e.target.value as BorderColor })}
        >
          {borderColors.map(color => (
            <option key={color}>{color}</option>
          ))}
        </select>
      </div>

      <div>
        <label htmlFor="card-color">Card: </label>

        <select
          id="card-color"
          value={state.cardColor}
          onChange={e => set({ cardColor: e.target.value as CardColor })}
        >
          {cardColors.map(color => (
            <option key={color}>{color}</option>
          ))}
        </select>
      </div>
    </>
  );
};
