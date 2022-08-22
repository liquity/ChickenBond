export interface SvgBoxProperties {
  width: string;
  height: string;
  svgData: string;
  backgroundColor?: string;
}

export const SvgBox: React.FC<SvgBoxProperties> = ({ width, height, svgData, backgroundColor }) => {
  const image = `data:image/svg+xml;base64,${window.btoa(svgData)}`;

  return (
    <div
      style={{
        display: "block",
        width,
        height,
        backgroundColor,
        backgroundImage: `url(${image})`,
        backgroundPosition: "center",
        backgroundRepeat: "no-repeat",
        backgroundSize: `${width} ${height}`
      }}
    />
  );
};
