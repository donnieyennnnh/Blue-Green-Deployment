// eslint.config.js — ESLint v9 flat-config style.
// Lint runs in CI (`npm run lint`) and locally with `npm run lint`.

const js = require('@eslint/js');
const globals = require('globals');

module.exports = [
  js.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'commonjs',
      globals: {
        ...globals.node,
        ...globals.jest,
      },
    },
    rules: {
      // Allow intentionally-unused args/vars when prefixed with underscore
      // (common Express pattern: (_req, res) => ...).
      'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    },
  },
  {
    ignores: ['node_modules/', 'coverage/'],
  },
];
