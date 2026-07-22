const storageKey = 'lotti-manual-screenshot-viewport';
// Mirrors kDesktopBreakpoint in lib/features/design_system/theme/breakpoints.dart —
// the same width the app itself switches from bottom-nav to sidebar at.
const desktopBreakpointPx = 960;

function isViewport(value) {
  return value === 'mobile' || value === 'desktop';
}

export function createScreenshotViewportStore(
  getBrowserWindow = () => globalThis.window,
) {
  let viewport = 'mobile';
  let initialized = false;
  let listeningToStorage = false;
  const listeners = new Set();

  function browserWindow() {
    try {
      return getBrowserWindow();
    } catch {
      return undefined;
    }
  }

  function detectViewport(window) {
    if (typeof window.matchMedia === 'function') {
      return window.matchMedia(`(max-width: ${desktopBreakpointPx - 1}px)`)
        .matches
        ? 'mobile'
        : 'desktop';
    }
    if (typeof window.innerWidth === 'number') {
      return window.innerWidth < desktopBreakpointPx ? 'mobile' : 'desktop';
    }
    return 'mobile';
  }

  function initialize() {
    if (initialized) return;
    initialized = true;
    const window = browserWindow();
    const storedViewport = window?.localStorage.getItem(storageKey);
    if (isViewport(storedViewport)) {
      viewport = storedViewport;
    } else if (window) {
      viewport = detectViewport(window);
    }
  }

  function notify() {
    for (const listener of listeners) listener();
  }

  function handleStorage(event) {
    if (event.key !== storageKey || !isViewport(event.newValue)) return;
    if (viewport === event.newValue) return;
    viewport = event.newValue;
    notify();
  }

  function getSnapshot() {
    initialize();
    return viewport;
  }

  function getServerSnapshot() {
    return 'mobile';
  }

  function setViewport(nextViewport) {
    if (!isViewport(nextViewport)) {
      throw new Error(`Unknown screenshot viewport: ${nextViewport}`);
    }
    initialize();
    browserWindow()?.localStorage.setItem(storageKey, nextViewport);
    if (viewport === nextViewport) return;
    viewport = nextViewport;
    notify();
  }

  function subscribe(listener) {
    initialize();
    listeners.add(listener);
    const window = browserWindow();
    if (!listeningToStorage && window) {
      window.addEventListener('storage', handleStorage);
      listeningToStorage = true;
    }
    return () => {
      listeners.delete(listener);
      if (listeners.size === 0 && listeningToStorage && window) {
        window.removeEventListener('storage', handleStorage);
        listeningToStorage = false;
      }
    };
  }

  return {
    getServerSnapshot,
    getSnapshot,
    setViewport,
    subscribe,
  };
}

export const screenshotViewportStore = createScreenshotViewportStore();
