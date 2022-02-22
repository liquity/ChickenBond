declare module "lambert-w" {
  function lambertW0(x: number): number;
  function halleySolution(x: number, w0: number): number;
  function seriesSolution(r: number): number;
}
