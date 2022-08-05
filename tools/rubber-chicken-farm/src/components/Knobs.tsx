import {
  Box,
  Flex,
  Input,
  Textarea,
  Heading,
  Button,
  Label,
  Select,
  ThemeUICSSObject
} from "theme-ui";

import { useKnobs } from "../context/KnobsProvider";
import { SimulationKnobs, validateSteerOption } from "../knobs";

const groupStyle: ThemeUICSSObject = {
  mt: 2,
  mb: 4
};

export const Knobs: React.FC = () => {
  const { state, latchedState, set, latch, resetAll } = useKnobs<SimulationKnobs>();
  const isLatched = state === latchedState;

  return (
    <Flex sx={{ flexDirection: "column", width: "430px", maxHeight: "100vh", p: 3 }}>
      <Flex sx={{ alignItems: "center", mb: 3 }}>
        <Heading>🎛️ Knobs</Heading>

        <Button variant="text" onClick={resetAll}>
          ⟲ Reset all
        </Button>

        <Flex sx={{ flexGrow: 1, alignItems: "center", justifyContent: "flex-end" }}>
          <Button
            variant="text"
            disabled={isLatched}
            sx={{ p: 0, fontSize: 5, opacity: isLatched ? 0.5 : 1 }}
            onClick={latch}
          >
            ▶️
          </Button>
        </Flex>
      </Flex>

      <Flex sx={{ flexDirection: "column", alignItems: "stretch", overflow: "auto" }}>
        <Heading as="h4">Simulation</Heading>

        <Box sx={groupStyle}>
          <Label>Duration [years]</Label>
          <Input
            type="number"
            min={0}
            step={1}
            value={state.periods}
            onChange={e => set("periods", e.target.value)}
          />

          <Label sx={{ mt: 3 }}>Initial Reserve [TOKEN, sTOKEN]</Label>
          <Input type="text" value={state.in0} onChange={e => set("in0", e.target.value)} />

          <Label sx={{ mt: 3 }}>Curve</Label>
          <Textarea rows={1} value={state.curve} onChange={e => set("curve", e.target.value)} />

          <Label sx={{ mt: 3 }}>TOKEN APY [Pending&amp;Reserve, Permanent]</Label>
          <Textarea rows={4} value={state.grow} onChange={e => set("grow", e.target.value)} />

          <Label sx={{ mt: 3 }}>sTOKEN Market Price [TOKEN]</Label>
          <Textarea rows={1} value={state.spot} onChange={e => set("spot", e.target.value)} />

          <Label sx={{ mt: 3 }}>Bonding Inflow [TOKEN]</Label>
          <Textarea rows={3} value={state.hatch} onChange={e => set("hatch", e.target.value)} />

          <Label sx={{ mt: 3 }}>Chickening</Label>
          <Textarea rows={5} value={state.move} onChange={e => set("move", e.target.value)} />
        </Box>

        <Heading as="h4">Control</Heading>

        <Box sx={groupStyle}>
          <Label>
            Initial Controller Output (
            <span>
              u<sub>0</sub>
            </span>
            )
          </Label>
          <Input type="number" value={state.u0} onChange={e => set("u0", e.target.value)} />

          <Label sx={{ mt: 3 }}>Set Point (r)</Label>
          <Textarea rows={1} value={state.point} onChange={e => set("point", e.target.value)} />

          <Label sx={{ mt: 3 }}>Process Variable (y)</Label>
          <Textarea rows={6} value={state.gauge} onChange={e => set("gauge", e.target.value)} />

          <Label sx={{ mt: 3 }}>Controller</Label>
          <Select
            value={state.selectedSteer}
            onChange={e => set("selectedSteer", validateSteerOption(e.target.value))}
          >
            <option value="asymmetric">Asymmetric (speed-up only)</option>
            <option value="symmetric">Symmetric</option>
            <option value="pid">PID</option>
          </Select>

          {state.selectedSteer === "asymmetric" ? (
            <>
              <Label sx={{ mt: 3 }}>Adjustment Rate</Label>
              <Input
                type="number"
                min={0}
                max={1}
                step={0.01}
                value={state.asymmetricAdjustmentRate}
                onChange={e => set("asymmetricAdjustmentRate", e.target.value)}
              />
            </>
          ) : state.selectedSteer === "symmetric" ? (
            <>
              <Label sx={{ mt: 3 }}>Adjustment Rate</Label>
              <Input
                type="number"
                min={0}
                max={1}
                step={0.01}
                value={state.symmetricAdjustmentRate}
                onChange={e => set("symmetricAdjustmentRate", e.target.value)}
              />
            </>
          ) : (
            <>
              <Label sx={{ mt: 3 }}>
                Proportional Coefficient (
                <span>
                  K<sub>p</sub>
                </span>
                )
              </Label>
              <Textarea value={state.pidKp} onChange={e => set("pidKp", e.target.value)} />

              <Label sx={{ mt: 3 }}>
                Integral Coefficient (
                <span>
                  K<sub>i</sub>
                </span>
                )
              </Label>
              <Textarea value={state.pidKi} onChange={e => set("pidKi", e.target.value)} />

              <Label sx={{ mt: 3 }}>
                Derivative Coefficient (
                <span>
                  K<sub>d</sub>
                </span>
                )
              </Label>
              <Textarea value={state.pidKd} onChange={e => set("pidKd", e.target.value)} />
            </>
          )}
        </Box>
      </Flex>
    </Flex>
  );
};
