import type { NextConfig } from "next";
const config: NextConfig = {
  transpilePackages: ["@nto/shared-types", "@nto/design-tokens"],
};
export default config;
