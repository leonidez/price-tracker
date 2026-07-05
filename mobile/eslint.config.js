// Flat config: Expo's rules + Prettier (disables formatting rules; `prettier --check` enforces format).
const expoConfig = require("eslint-config-expo/flat");
const prettierConfig = require("eslint-config-prettier/flat");

module.exports = [
  ...expoConfig,
  prettierConfig,
  {
    ignores: ["dist/*", ".expo/*", "node_modules/*"],
  },
];
