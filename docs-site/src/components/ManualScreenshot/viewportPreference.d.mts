export type ScreenshotViewport = 'mobile' | 'desktop';

export type ScreenshotViewportStore = {
  getServerSnapshot: () => ScreenshotViewport;
  getSnapshot: () => ScreenshotViewport;
  setViewport: (viewport: ScreenshotViewport) => void;
  subscribe: (listener: () => void) => () => void;
};

type BrowserWindow = Pick<
  Window,
  | 'addEventListener'
  | 'innerWidth'
  | 'localStorage'
  | 'matchMedia'
  | 'removeEventListener'
>;

export function createScreenshotViewportStore(
  getBrowserWindow?: () => BrowserWindow | undefined,
): ScreenshotViewportStore;

export const screenshotViewportStore: ScreenshotViewportStore;
