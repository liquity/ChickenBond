import { useCallback, useState } from "react";

import { SvgBox } from "./components/SvgBox";

import {
  BorderColor,
  borderColors,
  CardColor,
  cardColors,
  EggSize,
  eggSizes,
  generateSVG,
  ShellColor,
  shellColors
} from "./svg/template";

const randInt = (max: number) => Math.floor(max * Math.random());
const randElem = <T extends unknown>(arr: T[]): T => arr[randInt(arr.length)];

export const App: React.FC = () => {
  const [borderColor, setBorderColor] = useState<BorderColor>("white");
  const [cardColor, setCardColor] = useState<CardColor>("blue");
  const [shellColor, setShellColor] = useState<ShellColor>("off-white");
  const [eggSize, setEggSize] = useState<EggSize>("normal");
  const svgData = generateSVG({ tokenID: 1234, borderColor, cardColor, shellColor, eggSize });

  const randomize = useCallback(() => {
    setBorderColor(randElem(borderColors));
    setCardColor(randElem(cardColors));
    setShellColor(randElem(shellColors));
    setEggSize(randElem(eggSizes));
  }, []);

  return (
    <div style={{ display: "flex", height: "100vh" }}>
      <div style={{ margin: "30px" }}>
        <h1>Scrambled Eggs</h1>

        <div>
          <label htmlFor="card-color">Border: </label>

          <select
            id="border-color"
            value={borderColor}
            onChange={e => setBorderColor(e.target.value as BorderColor)}
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
            value={cardColor}
            onChange={e => setCardColor(e.target.value as CardColor)}
          >
            {cardColors.map(color => (
              <option key={color}>{color}</option>
            ))}
          </select>
        </div>

        <div>
          <label htmlFor="shell-color">Egg: </label>

          <select
            id="shell-color"
            value={shellColor}
            onChange={e => setShellColor(e.target.value as ShellColor)}
          >
            {shellColors.map(color => (
              <option key={color}>{color}</option>
            ))}
          </select>
        </div>

        <div>
          <label htmlFor="egg-size">Size: </label>

          <select
            id="egg-size"
            value={eggSize}
            onChange={e => setEggSize(e.target.value as EggSize)}
          >
            {eggSizes.map(size => (
              <option key={size}>{size}</option>
            ))}
          </select>
        </div>

        <div style={{ display: "flex", justifyContent: "center", marginTop: "15px" }}>
          <button onClick={randomize}>Scramble!</button>
        </div>

        <div style={{ marginTop: "30px" }}>
          <SvgBox width="250px" height="350px" svgData={svgData} />
        </div>

        <div style={{ marginTop: "20px" }}>
          Number of variations:{" "}
          {borderColors.length * cardColors.length * shellColors.length * eggSizes.length}
        </div>
      </div>

      <pre style={{ overflow: "scroll" }}>{svgData}</pre>
    </div>
  );
};
