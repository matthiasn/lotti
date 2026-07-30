import React, {useEffect, useState} from 'react';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import {translate} from '@docusaurus/Translate';
import DropdownNavbarItem from '@theme/NavbarItem/DropdownNavbarItem';

import {fetchLiveCatalog} from './catalog.mjs';

type Release = {
  label: string;
  status: 'development' | 'published' | 'archived';
  version: string;
};

type ReleaseCatalog = {
  latestPublished: string | null;
  versions: Release[];
};

type Props = Omit<
  import('@theme/NavbarItem/DropdownNavbarItem').Props,
  'items' | 'label'
>;

export default function ManualVersionNavbarItem(
  props: Props,
): React.JSX.Element {
  const {
    i18n: {currentLocale, defaultLocale},
    siteConfig,
  } = useDocusaurusContext();
  const currentVersion = String(
    siteConfig.customFields?.manualVersion ?? 'development',
  );
  const manualRootPath = String(
    siteConfig.customFields?.manualRootPath ?? '/manual',
  ).replace(/\/$/, '');
  const bakedCatalog = siteConfig.customFields?.manualReleases as ReleaseCatalog;
  // The baked catalog only knows the releases that existed when this version
  // was built; an immutable release snapshot would otherwise never list the
  // versions published after it. Every Pages deploy writes a live catalog
  // next to the version directories, so prefer that and fall back to the
  // baked list when it is unreachable (local dev server, offline).
  const [catalog, setCatalog] = useState<ReleaseCatalog>(bakedCatalog);
  useEffect(() => {
    let cancelled = false;
    void fetchLiveCatalog(`${manualRootPath}/releases.json`).then((live) => {
      if (!cancelled && live !== null) {
        setCatalog(live as ReleaseCatalog);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [manualRootPath]);

  const localeSuffix = currentLocale === defaultLocale ? '' : `/${currentLocale}`;
  const items = catalog.versions.map((release) => ({
    label:
      release.status === 'development'
        ? translate({
            id: 'manual.version.development',
            message: 'Development',
          })
        : release.label,
    href: `${manualRootPath}/${release.version}${localeSuffix}/`,
  }));

  return (
    <DropdownNavbarItem
      {...props}
      items={items}
      label={
        currentVersion === 'development'
          ? `${translate({
              id: 'manual.version.development',
              message: 'Development',
            })} (${String(siteConfig.customFields?.sourceAppVersion)})`
          : currentVersion
      }
    />
  );
}
