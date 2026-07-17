import {readFileSync} from 'node:fs';
import {dirname, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

import releases from './metadata/releases.json';

const siteDirectory = dirname(fileURLToPath(import.meta.url));
const pubspec = readFileSync(resolve(siteDirectory, '..', 'pubspec.yaml'), 'utf8');
const sourceVersionMatch = pubspec.match(/^version:\s*([^+\s]+)(?:\+\S+)?$/m);

if (!sourceVersionMatch) {
  throw new Error('Could not read the application version from pubspec.yaml.');
}

const sourceAppVersion = sourceVersionMatch[1];
const manualVersion = process.env.MANUAL_VERSION ?? 'development';
const manualRootPath = normalizeRootPath(
  process.env.MANUAL_ROOT_PATH ?? '/manual',
);
const baseUrl = normalizeBaseUrl(
  process.env.MANUAL_BASE_URL ?? `${manualRootPath}/${manualVersion}/`,
);

function normalizeRootPath(value: string): string {
  return `/${value.split('/').filter(Boolean).join('/')}`;
}

function normalizeBaseUrl(value: string): string {
  return `${normalizeRootPath(value)}/`;
}

const config: Config = {
  title: 'Lotti Manual',
  tagline: 'Plan your days, capture what happened, and learn from it.',
  url: process.env.MANUAL_SITE_URL ?? 'https://manual.example.invalid',
  baseUrl,
  trailingSlash: true,
  onBrokenLinks: 'throw',
  future: {
    v4: true,
  },
  i18n: {
    defaultLocale: 'en',
    locales: ['en', 'de'],
    localeConfigs: {
      en: {
        label: 'English',
        htmlLang: 'en-US',
      },
      de: {
        label: 'Deutsch',
        htmlLang: 'de-DE',
      },
    },
  },
  customFields: {
    manualVersion,
    sourceAppVersion,
    manualRootPath,
    manualMediaBaseUrl:
      process.env.MANUAL_MEDIA_BASE_URL ??
      'https://raw.githubusercontent.com/matthiasn/lotti-docs/main/manual/screenshots',
    manualReleases: releases,
  },
  presets: [
    [
      'classic',
      {
        docs: {
          routeBasePath: '/',
          sidebarPath: './sidebars.ts',
          breadcrumbs: true,
          editUrl: ({locale, docPath}) =>
            locale === 'en'
              ? `https://github.com/matthiasn/lotti/edit/main/docs-site/docs/${docPath}`
              : `https://github.com/matthiasn/lotti/edit/main/docs-site/i18n/${locale}/docusaurus-plugin-content-docs/current/${docPath}`,
          showLastUpdateAuthor: true,
          showLastUpdateTime: true,
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],
  themes: [
    [
      '@easyops-cn/docusaurus-search-local',
      {
        hashed: true,
        indexDocs: true,
        indexBlog: false,
        indexPages: false,
        docsRouteBasePath: '/',
        language: ['en', 'de'],
      },
    ],
  ],
  themeConfig: {
    colorMode: {
      defaultMode: 'dark',
      disableSwitch: false,
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'Lotti Manual',
      hideOnScroll: true,
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'manualSidebar',
          position: 'left',
          label: 'Guide',
        },
        {
          type: 'custom-manualVersion',
          position: 'right',
        },
        {
          type: 'localeDropdown',
          position: 'right',
        },
        {
          href: 'https://github.com/matthiasn/lotti',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Manual',
          items: [
            {label: 'Start here', to: '/'},
            {label: 'Daily OS', to: '/plan-and-capture/daily-os/'},
            {label: 'Tasks', to: '/organize-and-reflect/tasks/'},
          ],
        },
        {
          title: 'Project',
          items: [
            {
              label: 'Source code',
              href: 'https://github.com/matthiasn/lotti',
            },
            {
              label: 'Report a documentation issue',
              href: 'https://github.com/matthiasn/lotti/issues/new',
            },
          ],
        },
      ],
      copyright: `Lotti · ${manualVersion} · App ${sourceAppVersion}`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
