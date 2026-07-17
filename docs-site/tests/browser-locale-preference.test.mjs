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
      ['ro-RO', 'fr-FR', 'cs-CZ', 'de-DE', 'en-US'],
      ['en', 'de', 'fr', 'es', 'cs', 'ro', 'pt'],
      'en',
    ),
    'ro',
  );
  assert.equal(
    preferredSupportedLocale(
      ['pt-BR', 'fr-FR', 'de-DE', 'en-US'],
      ['en', 'de', 'fr', 'es', 'cs', 'ro', 'pt'],
      'en',
    ),
    'pt',
  );
  assert.equal(
    preferredSupportedLocale(
      ['es-ES', 'fr-FR', 'cs-CZ', 'de-DE', 'en-US'],
      ['en', 'de', 'fr', 'es', 'cs', 'ro', 'pt'],
      'en',
    ),
    'es',
  );
  assert.equal(
    preferredSupportedLocale(
      ['fr-FR', 'cs-CZ', 'de-DE', 'en-US'],
      ['en', 'de', 'fr', 'es', 'cs', 'ro', 'pt'],
      'en',
    ),
    'fr',
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
  assert.equal(
    localeRootUrl('/lotti/manual/development/', 'fr', 'en'),
    '/lotti/manual/development/fr/',
  );
  assert.equal(
    localeRootUrl('/lotti/manual/development/', 'ro', 'en'),
    '/lotti/manual/development/ro/',
  );
  assert.equal(
    localeRootUrl('/lotti/manual/development/', 'pt', 'en'),
    '/lotti/manual/development/pt/',
  );
  assert.equal(
    localeRootUrl('/lotti/manual/development/', 'es', 'en'),
    '/lotti/manual/development/es/',
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
      fr: {htmlLang: 'fr-FR'},
      es: {htmlLang: 'es-ES'},
      cs: {htmlLang: 'cs-CZ'},
      ro: {htmlLang: 'ro-RO'},
      pt: {htmlLang: 'pt-BR'},
    },
    storage: {setItem: (key, value) => stored.set(key, value)},
  });

  clickListener({
    target: {closest: () => ({lang: 'ro-RO'})},
  });

  assert.equal(stored.get(manualLocaleStorageKey), 'ro');
});
