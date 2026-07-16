import React from 'react';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import DropdownNavbarItem from '@theme/NavbarItem/DropdownNavbarItem';

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
  const {siteConfig} = useDocusaurusContext();
  const currentVersion = String(
    siteConfig.customFields?.manualVersion ?? 'development',
  );
  const manualRootPath = String(
    siteConfig.customFields?.manualRootPath ?? '/manual',
  ).replace(/\/$/, '');
  const catalog = siteConfig.customFields?.manualReleases as ReleaseCatalog;
  const items = catalog.versions.map((release) => ({
    label:
      release.status === 'development'
        ? `${release.label} (${String(siteConfig.customFields?.sourceAppVersion)})`
        : release.label,
    href: `${manualRootPath}/${release.version}/`,
  }));

  return (
    <DropdownNavbarItem
      {...props}
      items={items}
      label={currentVersion === 'development' ? 'Development' : currentVersion}
    />
  );
}
