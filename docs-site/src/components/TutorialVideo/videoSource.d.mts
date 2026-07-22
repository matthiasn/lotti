export type VideoSourceOptions = {
  scenario: string;
  locale: string;
  videoBaseUrl: string;
  viewport?: 'mobile' | 'desktop';
};

export function tutorialVideoSource(options: VideoSourceOptions): string;
export function tutorialCaptionsSource(options: VideoSourceOptions): string;
