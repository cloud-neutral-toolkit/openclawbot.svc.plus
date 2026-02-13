import { defineConfig } from "tsdown";

const env = {
  NODE_ENV: "production",
};

// Rolldown resolve configuration to handle .js imports resolving to .ts files
const rolldownResolve = {
  extensions: [".ts", ".tsx", ".js", ".jsx", ".json"],
};

export default defineConfig([
  {
    entry: "src/index.ts",
    env,
    fixedExtension: false,
    platform: "node",
    rolldownOptions: {
      resolve: rolldownResolve,
    },
  },
  {
    entry: "src/entry.ts",
    env,
    fixedExtension: false,
    platform: "node",
    rolldownOptions: {
      resolve: rolldownResolve,
    },
  },
  {
    entry: "src/infra/warning-filter.ts",
    env,
    fixedExtension: false,
    platform: "node",
    rolldownOptions: {
      resolve: rolldownResolve,
    },
  },
  {
    entry: "src/plugin-sdk/index.ts",
    outDir: "dist/plugin-sdk",
    env,
    fixedExtension: false,
    platform: "node",
    rolldownOptions: {
      resolve: rolldownResolve,
    },
  },
  {
    entry: "src/extensionAPI.ts",
    env,
    fixedExtension: false,
    platform: "node",
    rolldownOptions: {
      resolve: rolldownResolve,
    },
  },
  {
    entry: ["src/hooks/bundled/*/handler.ts", "src/hooks/llm-slug-generator.ts"],
    env,
    fixedExtension: false,
    platform: "node",
    rolldownOptions: {
      resolve: rolldownResolve,
    },
  },
]);
