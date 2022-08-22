import { useState } from "react";

import { SvgBox } from "./components/SvgBox";
import { CardColor, cardColors, generateSVG, ShellColor, shellColors } from "./svg/template";

export const App: React.FC = () => {
  const [cardColor, setCardColor] = useState<CardColor>("blue");
  const [shellColor, setShellColor] = useState<ShellColor>("off-white");
  const svgData = generateSVG({ cardColor, shellColor });

  return (
    <div style={{ display: "flex", height: "100vh" }}>
      <div style={{ margin: "30px" }}>
        <h1>Scrambled Eggs</h1>

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

        <div style={{ marginTop: "30px" }}>
          <SvgBox width="250px" height="350px" svgData={svgData} />
        </div>

        <div style={{ marginTop: "20px" }}>
          Number of variations: {cardColors.length * shellColors.length}
        </div>
      </div>

      <pre style={{ overflow: "scroll" }}>{svgData}</pre>
    </div>
  );
};
