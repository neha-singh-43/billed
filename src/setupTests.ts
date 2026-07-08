import '@testing-library/jest-dom';
import { vi } from 'vitest';

// Mock Tauri APIs
vi.mock('@tauri-apps/api/core', () => ({
  invoke: vi.fn(async (cmd) => {
    if (cmd === 'get_cursor_usage' || cmd === 'get_opencode_usage') {
      return {
        summary: {
          billingCycleStart: "2026-07-01T00:00:00Z",
          billingCycleEnd: "2026-07-31T23:59:59Z",
          membershipType: "Pro",
          limitType: "Monthly",
          isUnlimited: false,
          autoModelSelectedDisplayMessage: "GPT-4",
          namedModelSelectedDisplayMessage: "Claude",
          individualUsage: {}
        },
        events: {
          totalUsageEventsCount: 10,
          usageEventsDisplay: []
        }
      };
    }
    return null;
  }),
}));

vi.mock('@tauri-apps/api/window', () => ({
  getCurrentWindow: vi.fn(() => ({
    label: 'main',
  })),
}));

vi.mock('@tauri-apps/api/event', () => ({
  emit: vi.fn(),
  listen: vi.fn(async () => {
    return () => {}; // return unlisten function
  }),
}));

// Mock ResizeObserver
vi.stubGlobal('ResizeObserver', class ResizeObserver {
  observe() {}
  unobserve() {}
  disconnect() {}
});

// Mock localStorage
const localStorageMock = (function () {
  let store: Record<string, string> = {};
  return {
    getItem(key: string) {
      return store[key] || null;
    },
    setItem(key: string, value: string) {
      store[key] = value.toString();
    },
    clear() {
      store = {};
    },
    removeItem(key: string) {
      delete store[key];
    }
  };
})();
Object.defineProperty(window, 'localStorage', {
  value: localStorageMock
});
