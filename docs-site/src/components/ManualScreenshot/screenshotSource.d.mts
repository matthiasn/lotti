export type ScreenshotSourceOptions = {
  caseId: string;
  defaultLocale: string;
  locale: string;
  mediaBaseUrl: string;
  theme: 'light' | 'dark';
  version: string;
  viewport: 'mobile' | 'desktop';
};

export function manualScreenshotSource(options: ScreenshotSourceOptions): string;
