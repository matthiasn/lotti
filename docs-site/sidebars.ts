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
        'getting-started/onboarding',
        'getting-started/first-task',
      ],
    },
    {
      type: 'category',
      label: 'Plan & capture',
      collapsed: false,
      items: [
        'plan-and-capture/daily-os',
        'plan-and-capture/entries',
        'plan-and-capture/recordings',
        'plan-and-capture/surveys',
      ],
    },
    {
      type: 'category',
      label: 'Organize & reflect',
      collapsed: false,
      items: [
        'organize-and-reflect/tasks',
        'organize-and-reflect/task-agents',
        'organize-and-reflect/task-cover-art',
        'organize-and-reflect/projects',
        'organize-and-reflect/events',
        'organize-and-reflect/journal',
        'organize-and-reflect/time-tracking',
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
      items: [
        'ai-and-automation/provider-setup',
        'ai-and-automation/models-and-profiles',
        'ai-and-automation/agents',
        'ai-and-automation/agent-blueprints',
        'ai-and-automation/skills',
        'ai-and-automation/usage',
      ],
    },
    {
      type: 'category',
      label: 'Sync & data',
      items: [
        'sync-and-data/sync',
        'sync-and-data/conflicts',
        'sync-and-data/maintenance',
        'sync-and-data/health-import',
      ],
    },
    {
      type: 'category',
      label: 'Reference',
      items: [
        'reference/settings',
        'reference/whats-new',
        'reference/appearance',
        'reference/recording-style',
        'reference/speech',
        'reference/keyboard-shortcuts',
        'reference/completion-celebrations',
        'reference/advanced-settings',
        'reference/manual-maintenance',
      ],
    },
    'roadmap',
  ],
};

export default sidebars;
