import { randomTraits, Status, statuses, Traits } from "../traits";
import { generateEggSVG } from "../svg/egg";
import { useKnobs } from "../context/KnobsProvider";
import { ActiveKnobs } from "./ActiveKnobs";
import { CommonKnobs } from "./CommonKnobs";
import { SvgImage } from "./SvgBox";
import { generateChickenInSVG } from "../svg/chickenIn";
import { generateChickenOutSVG } from "../svg/chickenOut";
import { ChickenOutKnobs } from "./ChickenOutKnobs";
import { ChickenInKnobs } from "./ChickenInKnobs";

export const Main: React.FC = () => {
  const [{ status, ...traits }, set] = useKnobs<Traits>();

  const generateSVG =
    status === "chickened in"
      ? generateChickenInSVG
      : status === "chickened out"
      ? generateChickenOutSVG
      : generateEggSVG;

  const svgData = generateSVG({ tokenID: 1234, ...traits });

  return (
    <div style={{ display: "flex", height: "100vh" }}>
      <div style={{ margin: "16px" }}>
        <h1 style={{ fontSize: "20px" }}>Scrambled Eggs</h1>

        <div>
          <label htmlFor="status">Status: </label>

          <select
            id="status"
            value={status}
            onChange={e => set({ status: e.target.value as Status })}
          >
            {statuses.map(size => (
              <option key={size}>{size}</option>
            ))}
          </select>
        </div>

        <CommonKnobs />

        {status === "chickened out" ? (
          <ChickenOutKnobs />
        ) : status === "chickened in" ? (
          <ChickenInKnobs />
        ) : (
          <ActiveKnobs />
        )}

        <div style={{ display: "flex", justifyContent: "center", marginTop: "16px" }}>
          <button onClick={() => set(randomTraits())}>Scramble!</button>
        </div>

        <div style={{ marginTop: "24px" }}>
          <SvgImage
            alt="NFT artwork"
            style={{ width: "250px", height: "350px" }}
            svgData={svgData}
          />
        </div>
      </div>

      <pre style={{ overflow: "scroll" }}>{svgData}</pre>
    </div>
  );
};
