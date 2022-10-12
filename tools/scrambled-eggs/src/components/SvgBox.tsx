export interface SvgImageProperties {
  svgData: string;
  style: React.CSSProperties;
  alt?: string;
}

export const SvgImage: React.FC<SvgImageProperties> = ({ svgData, style, alt }) => (
  <img style={style} alt={alt} src={`data:image/svg+xml;base64,${window.btoa(svgData)}`} />
);
