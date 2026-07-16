import assert from 'node:assert/strict';
import test from 'node:test';

import {createScreenshotViewportStore} from '../src/components/ManualScreenshot/viewportPreference.mjs';

function createBrowserWindow(initialViewport) {
  const storage = new Map();
  if (initialViewport !== undefined) {
    storage.set('lotti-manual-screenshot-viewport', initialViewport);
  }
  const storageListeners = new Set();

  return {
    addEventListener(type, listener) {
      if (type === 'storage') storageListeners.add(listener);
    },
    localStorage: {
      getItem(key) {
        return storage.get(key) ?? null;
      },
      setItem(key, value) {
        storage.set(key, value);
      },
    },
    removeEventListener(type, listener) {
      if (type === 'storage') storageListeners.delete(listener);
    },
    sendStorageEvent(value) {
      for (const listener of storageListeners) {
        listener({
          key: 'lotti-manual-screenshot-viewport',
          newValue: value,
        });
      }
    },
    storedViewport() {
      return storage.get('lotti-manual-screenshot-viewport');
    },
  };
}

test('one selection updates every screenshot subscriber and persists', () => {
  const window = createBrowserWindow('mobile');
  const store = createScreenshotViewportStore(() => window);
  let firstUpdates = 0;
  let secondUpdates = 0;
  const unsubscribeFirst = store.subscribe(() => firstUpdates += 1);
  const unsubscribeSecond = store.subscribe(() => secondUpdates += 1);

  store.setViewport('desktop');

  assert.equal(store.getSnapshot(), 'desktop');
  assert.equal(window.storedViewport(), 'desktop');
  assert.equal(firstUpdates, 1);
  assert.equal(secondUpdates, 1);

  unsubscribeFirst();
  unsubscribeSecond();
});

test('a storage event synchronizes the preference from another tab', () => {
  const window = createBrowserWindow('desktop');
  const store = createScreenshotViewportStore(() => window);
  let updates = 0;
  const unsubscribe = store.subscribe(() => updates += 1);

  window.sendStorageEvent('mobile');

  assert.equal(store.getSnapshot(), 'mobile');
  assert.equal(updates, 1);
  unsubscribe();
});

test('invalid viewport values cannot enter the global store', () => {
  const window = createBrowserWindow();
  const store = createScreenshotViewportStore(() => window);
  assert.throws(() => store.setViewport('tablet'), /Unknown screenshot viewport/);
});
