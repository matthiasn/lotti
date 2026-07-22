export type VideoSourceOptions = {
  scenario: string;
  locale: string;
  videoBaseUrl: string;
};

export function tutorialVideoSource(options: VideoSourceOptions): string;
export function tutorialCaptionsSource(options: VideoSourceOptions): string;
