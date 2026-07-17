import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  manualSidebar: [
    'index',
    {
      type: 'category',
      label: 'Start here',
      collapsed: false,
      items: [
        'getting-started/mental-model',
        'getting-started/first-task',
      ],
    },
    {
      type: 'category',
      label: 'Plan & capture',
      collapsed: false,
      items: [
        'plan-and-capture/daily-os',
        'plan-and-capture/recordings',
      ],
    },
    {
      type: 'category',
      label: 'Organize & reflect',
      collapsed: false,
      items: [
        'organize-and-reflect/tasks',
        'organize-and-reflect/projects',
        'organize-and-reflect/events',
        'organize-and-reflect/journal',
        'organize-and-reflect/time-analysis',
        'organize-and-reflect/categories',
        'organize-and-reflect/labels',
        'organize-and-reflect/habits-and-measurables',
        'organize-and-reflect/dashboards',
      ],
    },
    {
      type: 'category',
      label: 'AI & automation',
      items: ['ai-and-automation/provider-setup'],
    },
    {
      type: 'category',
      label: 'Sync & data',
      items: ['sync-and-data/sync'],
    },
    {
      type: 'category',
      label: 'Reference',
      items: [
        'reference/settings',
        'reference/appearance',
        'reference/recording-style',
        'reference/keyboard-shortcuts',
        'reference/completion-celebrations',
        'reference/advanced-settings',
        'reference/manual-maintenance',
      ],
    },
  ],
};

export default sidebars;
