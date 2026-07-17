import assert from 'node:assert/strict';
import test from 'node:test';

import {
  installLocalePreferenceTracking,
  localeRootUrl,
  manualLocaleStorageKey,
  preferredSupportedLocale,
  shouldRedirectToPreferredLocale,
} from '../src/browserLocalePreference.mjs';

test('browser locale matching uses the first supported language', () => {
  assert.equal(
    preferredSupportedLocale(
      ['fr-FR', 'cs-CZ', 'de-DE', 'en-US'],
      ['en', 'de', 'cs'],
      'en',
    ),
    'cs',
  );
  assert.equal(
    preferredSupportedLocale(['fr-FR', 'de-DE', 'en-US'], ['en', 'de', 'cs'], 'en'),
    'de',
  );
  assert.equal(
    preferredSupportedLocale(['fr-FR'], ['en', 'de'], 'en'),
    'en',
  );
});

test('automatic locale redirects only happen at the default-locale root', () => {
  assert.equal(
    shouldRedirectToPreferredLocale({
      baseUrl: '/lotti/manual/development/',
      currentLocale: 'en',
      defaultLocale: 'en',
      pathname: '/lotti/manual/development/',
      preferredLocale: 'de',
      storedLocale: null,
    }),
    true,
  );
  for (const overrides of [
    {pathname: '/lotti/manual/development/organize-and-reflect/tasks/'},
    {storedLocale: 'en'},
    {currentLocale: 'de'},
    {preferredLocale: 'en'},
  ]) {
    assert.equal(
      shouldRedirectToPreferredLocale({
        baseUrl: '/lotti/manual/development/',
        currentLocale: 'en',
        defaultLocale: 'en',
        pathname: '/lotti/manual/development/',
        preferredLocale: 'de',
        storedLocale: null,
        ...overrides,
      }),
      false,
    );
  }
});

test('locale root URLs preserve the default route and add alternatives', () => {
  assert.equal(
    localeRootUrl('/lotti/manual/development/', 'en', 'en'),
    '/lotti/manual/development/',
  );
  assert.equal(
    localeRootUrl('/lotti/manual/development/', 'de', 'en'),
    '/lotti/manual/development/de/',
  );
  assert.equal(
    localeRootUrl('/lotti/manual/development/', 'cs', 'en'),
    '/lotti/manual/development/cs/',
  );
});

test('an explicit locale dropdown choice is persisted', () => {
  let clickListener;
  const stored = new Map();
  const document = {
    addEventListener(type, listener) {
      if (type === 'click') clickListener = listener;
    },
    removeEventListener() {},
  };
  installLocalePreferenceTracking({
    document,
    localeConfigs: {
      en: {htmlLang: 'en-US'},
      de: {htmlLang: 'de-DE'},
      cs: {htmlLang: 'cs-CZ'},
    },
    storage: {setItem: (key, value) => stored.set(key, value)},
  });

  clickListener({
    target: {closest: () => ({lang: 'de-DE'})},
  });

  assert.equal(stored.get(manualLocaleStorageKey), 'de');
});
