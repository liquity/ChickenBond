export const viewBoxWidth = 750;
export const viewBoxHeight = 1050;

export const roundDigits = 1;
export const roundScale = 10 ** roundDigits;
export const round = (n: number) => Math.round(roundScale * n) / roundScale;

const range = (n: number) => [...new Array(n).keys()];

const unzip = <T extends [unknown, unknown][]>(abs: T) =>
  abs.reduce<[unknown[], unknown[]]>(
    ([as, bs], [a, b]) => [
      [...as, a],
      [...bs, b]
    ],
    [[], []]
  ) as [{ [P in keyof T]: T[P][0] }, { [P in keyof T]: T[P][1] }];

const cartesian2 = <T extends unknown[], U>(ts: T[], us: U[]) =>
  ts.flatMap(t => us.map((u): [...T, U] => [...t, u]));

const cartesian = <TT extends unknown[]>(...[ts, ...tss]: { [P in keyof TT]: TT[P][] }) =>
  tss.reduce<unknown[][]>(
    cartesian2,
    ts.map((t): [TT[0]] => [t])
  ) as TT[];

const unflatten = (xs: unknown[], dims: number[]): unknown[] => {
  if (dims.length === 0) {
    return xs;
  }

  const [d, ...ds] = dims;

  return range(d)
    .map(i => xs.slice((xs.length * i) / d, (xs.length * (i + 1)) / d))
    .map(slice => unflatten(slice, ds));
};

const solidityStringLiteral = (templateString: string) =>
  `'${templateString
    .split(/\s+/)
    .join(" ")
    .replace(new RegExp(" {", "g"), "{")
    .replace(new RegExp(" }", "g"), "}")
    .replace(new RegExp("{ ", "g"), "{")
    .replace(new RegExp("} ", "g"), "}")
    .replace(new RegExp(" <", "g"), "<")
    .replace(new RegExp("> ", "g"), ">")
    .replace(new RegExp("\\) ", "g"), ")")
    .replace(new RegExp(", ", "g"), ",")
    .replace(new RegExp(": ", "g"), ":")
    .replace(new RegExp("; ", "g"), ";")}'`;

const indent3 = (x: string) => "            " + x;
const indent4 = (x: string) => "                " + x;

const chop = <T>(arr: T[], n: number): T[][] =>
  arr.length <= n ? [arr] : [arr.slice(0, n), ...chop(arr.slice(n), n)];

const stringify = (x: unknown[] | unknown): string =>
  Array.isArray(x) ? `[${x.map(stringify).join(", ")}]` : String(x);

const maxPiecesPerEncode = 13;

export const template = <T extends unknown[], U = {}>(
  [firstTemplateString, ...templateStrings]: TemplateStringsArray,
  ...templateSubstitutions: (((...args: T) => unknown) | keyof U)[]
) => ({
  templateStrings,
  templateSubstitutions,

  instantiate: (args: T, substitutions: U) =>
    [
      firstTemplateString,
      ...templateSubstitutions.flatMap((templateSubstitution, i) => {
        const substitution =
          typeof templateSubstitution === "function"
            ? String(templateSubstitution(...args))
            : String(substitutions[templateSubstitution]);

        return [substitution, templateStrings[i]];
      })
    ].join(""),

  solidity: (
    contractName: string,
    signature: string,
    variables: { [P in keyof T]: [string, T[P][]] },
    accessors: { [P in keyof U]: string }
  ) => {
    const functionalSubstitutions = templateSubstitutions.filter(
      (templateSubstitution): templateSubstitution is (...args: T) => unknown =>
        typeof templateSubstitution === "function"
    );

    const [subs, ranges]: [{ [P in keyof T]: string }, { [P in keyof T]: T[P][] }] =
      unzip(variables);

    const cols = [functionalSubstitutions, ...ranges] as const;

    const values = cartesian<[(...args: T) => unknown, ...{ [P in keyof T]: T[P] }]>(...cols).map(
      ([f, ...args]) => solidityStringLiteral(String(f(...args)))
    );

    const dims = [functionalSubstitutions, ...ranges].map(x => x.length);
    const lookup = unflatten(values, dims.slice(0, ranges.length));

    let j = 0;
    const pieces = [
      solidityStringLiteral(firstTemplateString.trimStart()),
      ...templateSubstitutions.flatMap((templateSubstitution, i) => {
        const access =
          typeof templateSubstitution === "function"
            ? `p[${[j++, ...subs].join("][")}]`
            : accessors[templateSubstitution];

        return [access, solidityStringLiteral(templateStrings[i])];
      })
    ];

    return `
contract ${contractName} {
    function ${signature} external pure returns (bytes memory) {${
      lookup.length > 0
        ? `
        string[${[...dims].reverse().join("][")}] memory p = [
${lookup
  .map(row => stringify(row))
  .map(indent3)
  .join(",\n")}
        ];
`
        : ""
    }
        return abi.encodePacked(
${
  pieces.length <= maxPiecesPerEncode
    ? pieces.map(indent3).join(",\n")
    : chop(pieces, maxPiecesPerEncode)
        .map(slice =>
          slice.length === 1
            ? indent3(slice[0])
            : `            abi.encodePacked(
${slice.map(indent4).join(",\n")}
            )`
        )
        .join(",\n")
}
        );
    }
}`.trimStart();
  }
});
