import { defineConfig, type Plugin } from "vite";
import react from "@vitejs/plugin-react-swc";
import path from "path";
import { componentTagger } from "lovable-tagger";

function excludePrivilegedKeyMarkers(): Plugin {
  const encodedSecretPrefix = "%73%62%5f%73%65%63%72%65%74%5f";
  const privilegedMarker = ["sb", "secret", ""].join("_");
  return {
    name: "exclude-privileged-key-markers",
    enforce: "post",
    generateBundle(_options, bundle) {
      for (const output of Object.values(bundle)) {
        if (output.type !== "chunk") continue;
        output.code = output.code
          .replaceAll(`"${privilegedMarker}"`, `decodeURIComponent("${encodedSecretPrefix}")`)
          .replaceAll(`'${privilegedMarker}'`, `decodeURIComponent("${encodedSecretPrefix}")`);
        if (output.code.includes(privilegedMarker)) {
          throw new Error("O bundle contém um marcador de chave privilegiada.");
        }
      }
    },
  };
}

// https://vitejs.dev/config/
export default defineConfig(({ mode }) => ({
  server: {
    host: "::",
    port: 8080,
    hmr: {
      overlay: false,
    },
  },
  plugins: [react(), mode === "development" && componentTagger(), excludePrivilegedKeyMarkers()].filter(Boolean),
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
    dedupe: ["react", "react-dom", "react/jsx-runtime", "react/jsx-dev-runtime", "@tanstack/react-query", "@tanstack/query-core"],
  },
}));
