import assert from 'node:assert/strict';
import test from 'node:test';

import {manualScreenshotSource} from '../src/components/ManualScreenshot/screenshotSource.mjs';

test('English screenshot URLs retain the published path contract', () => {
  assert.equal(
    manualScreenshotSource({
      caseId: 'tasks/workspace',
      defaultLocale: 'en',
      locale: 'en',
      mediaBaseUrl: 'https://media.example/manual/screenshots/',
      theme: 'dark',
      version: 'development',
      viewport: 'desktop',
    }),
    'https://media.example/manual/screenshots/development/tasks/workspace/desktop-dark.webp',
  );
});

test('non-default screenshot URLs include their locale', () => {
  assert.equal(
    manualScreenshotSource({
      caseId: 'tasks/workspace',
      defaultLocale: 'en',
      locale: 'de',
      mediaBaseUrl: 'https://media.example/manual/screenshots',
      theme: 'light',
      version: '1.0.0',
      viewport: 'mobile',
    }),
    'https://media.example/manual/screenshots/1.0.0/de/tasks/workspace/mobile-light.webp',
  );
});
