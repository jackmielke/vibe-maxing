#!/usr/bin/env node

/**
 * Enforce pnpm usage in this monorepo
 * This script prevents installation with npm, yarn, or bun
 */

if (!/pnpm/.test(process.env.npm_execpath || '')) {
  console.warn(
    '\n\x1b[33m⚠️  This repository uses pnpm for package management.\x1b[0m\n' +
    '\x1b[31m❌ Please use pnpm instead of npm, yarn, or bun.\x1b[0m\n\n' +
    'Install pnpm globally:\n' +
    '  \x1b[36mnpm install -g pnpm\x1b[0m\n\n' +
    'Then run:\n' +
    '  \x1b[36mpnpm install\x1b[0m\n'
  );
  process.exit(1);
}

