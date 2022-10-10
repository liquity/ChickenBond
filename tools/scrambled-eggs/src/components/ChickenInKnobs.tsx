import { beaks, combs, ShellColor, shellColors, tails, Traits, wings } from "../traits";
import { useKnobs } from "../context/KnobsProvider";

export const ChickenInKnobs = () => {
  const [state, set] = useKnobs<Traits>();

  return (
    <>
      <div>
        <label htmlFor="chicken-color">Chicken: </label>

        <select
          id="chicken-color"
          value={state.chickenColor}
          onChange={e => set({ chickenColor: e.target.value as ShellColor })}
        >
          {shellColors.map(color => (
            <option key={color}>{color}</option>
          ))}
        </select>
      </div>

      <div style={{ display: "flex" }}>
        <div style={{ marginRight: "16px" }}>
          <label htmlFor="chicken-comb">Comb: </label>

          <select
            id="chicken-comb"
            value={state.comb}
            onChange={e => set({ comb: parseInt(e.target.value) })}
          >
            {combs.map(comb => (
              <option key={comb}>{comb}</option>
            ))}
          </select>
        </div>

        <div>
          <label htmlFor="chicken-beak">Beak: </label>

          <select
            id="chicken-beak"
            value={state.beak}
            onChange={e => set({ beak: parseInt(e.target.value) })}
          >
            {beaks.map(beak => (
              <option key={beak}>{beak}</option>
            ))}
          </select>
        </div>
      </div>

      <div style={{ display: "flex" }}>
        <div style={{ marginRight: "16px" }}>
          <label htmlFor="chicken-tail">Tail: </label>

          <select
            id="chicken-tail"
            value={state.tail}
            onChange={e => set({ tail: parseInt(e.target.value) })}
          >
            {tails.map(tail => (
              <option key={tail}>{tail}</option>
            ))}
          </select>
        </div>

        <div>
          <label htmlFor="chicken-wing">Wing: </label>

          <select
            id="chicken-wing"
            value={state.wing}
            onChange={e => set({ wing: parseInt(e.target.value) })}
          >
            {wings.map(wing => (
              <option key={wing}>{wing}</option>
            ))}
          </select>
        </div>
      </div>

      <div style={{ display: "flex" }}>
        <div style={{ marginRight: "8px" }}>
          <input
            id="special-attribute-trove"
            type="checkbox"
            checked={state.trove}
            onChange={() => set({ trove: !state.trove })}
          />

          <label htmlFor="special-attribute-trove">Trove</label>
        </div>

        <div style={{ marginRight: "8px" }}>
          <input
            id="special-attribute-llama"
            type="checkbox"
            checked={state.llama}
            onChange={() => set({ llama: !state.llama })}
          />

          <label htmlFor="special-attribute-llama">Llama</label>
        </div>

        <div>
          <input
            id="special-attribute-lqty"
            type="checkbox"
            checked={state.lqtyBand}
            onChange={() => set({ lqtyBand: !state.lqtyBand })}
          />

          <label htmlFor="special-attribute-lqty">LQTY</label>
        </div>
      </div>
    </>
  );
};
