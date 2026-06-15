import type { NextConfig } from "next";
import path from "path";

/** CMS app root — prevents Turbopack from using monorepo parent lockfile as workspace root. */
const appRoot = path.join(__dirname);

const apiProxyTarget =
  (process.env.API_PROXY_TARGET || "http://127.0.0.1:3000").replace(/\/$/, "");

const nextConfig: NextConfig = {
  turbopack: {
    root: appRoot,
  },
  outputFileTracingRoot: appRoot,
  /** Same-origin proxy in dev — avoids Chrome "local network requests" (PNA) blocks. */
  async rewrites() {
    if (process.env.NODE_ENV !== "development") return [];
    return [
      {
        source: "/api-backend/:path*",
        destination: `${apiProxyTarget}/api/:path*`,
      },
    ];
  },
};

export default nextConfig;
