export const colorScale = [
  "#4F7DA1",
  "#45B29D",
  "#EFC94C",
  "#E27A3F",
  "#334D5C"
  // "#DF5A49",
  // "#DF948A",
  // "#55DBC1",
  // "#EFDA97",
  // "#E2A37F",
];

export const lineStyle = (color = "#cccccc") => ({
  labels: { fill: color },
  data: { stroke: color }
});

export const areaStyle = (color = "#cccccc") => ({
  labels: { fill: color },
  data: { fill: color, fillOpacity: 0.5, strokeWidth: "2px" }
});

export const padding = {
  top: 5,
  bottom: 25,
  left: 60,
  right: 160
};
