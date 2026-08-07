import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    // 5173 belongs to the credits/AI dashboard; this is a separate admin app.
    port: 5174,
    proxy: {
      "/api": {
        target: "http://localhost:8003",
        changeOrigin: true,
      },
    },
  },
  test: {
    globals: true,
    environment: "jsdom",
    setupFiles: "./src/test-setup.ts",
  },
});
