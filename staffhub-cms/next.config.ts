import type { NextConfig } from "next";
import path from "path";

/** CMS app root — prevents Turbopack from using monorepo parent lockfile as workspace root. */
const appRoot = path.join(__dirname);

const nextConfig: NextConfig = {
  turbopack: {
    root: appRoot,
  },
  outputFileTracingRoot: appRoot,
};

export default nextConfig;
