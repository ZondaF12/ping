import type { NextConfig } from "next";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const withMarkdoc = require("@markdoc/next.js") as (
  opts?: Record<string, unknown>,
) => (config: NextConfig) => NextConfig;

const nextConfig: NextConfig = {
  pageExtensions: ["js", "jsx", "ts", "tsx", "md", "mdoc"],
  async redirects() {
    return [{ source: "/", destination: "/docs", permanent: false }];
  },
};

const merged = withMarkdoc({ mode: "static" })(nextConfig);
// Next 15.1 does not accept `turbopack` at top level; @markdoc/next.js injects it for loaders.
delete (merged as { turbopack?: unknown }).turbopack;

export default merged;
