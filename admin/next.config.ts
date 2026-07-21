import type { NextConfig } from "next";
import path from "path";

const nextConfig: NextConfig = {
  // 纯静态导出(PRD §15):构建产物 out/ 直接放 Apache,无 Node 服务端。
  output: "export",
  // Apache 对目录 + index.html 天然支持,免 rewrite 规则。
  trailingSlash: true,
  // monorepo 根目录也有 package-lock.json,显式钉住工作区根
  turbopack: { root: path.join(__dirname) },
};

export default nextConfig;
