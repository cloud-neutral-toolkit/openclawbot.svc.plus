import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { Tab } from "./navigation.ts";
import { applySettingsFromUrl, setTabFromRoute } from "./app-settings.ts";

type SettingsHost = Parameters<typeof setTabFromRoute>[0] & {
  logsPollInterval: number | null;
  debugPollInterval: number | null;
  password?: string;
  theme: string;
  themeResolved: string;
  applySessionKey: string;
  sessionKey: string;
  tab: Tab;
  connected: boolean;
  chatHasAutoScrolled: boolean;
  logsAtBottom: boolean;
  eventLog: unknown[];
  eventLogBuffer: unknown[];
  basePath: string;
  themeMedia: MediaQueryList | null;
  themeMediaHandler: ((event: MediaQueryListEvent) => void) | null;
};

const createHost = (tab: Tab): SettingsHost => ({
  settings: {
    gatewayUrl: "",
    token: "",
    sessionKey: "main",
    lastActiveSessionKey: "main",
    theme: "system",
    chatFocusMode: false,
    chatShowThinking: true,
    splitRatio: 0.6,
    navCollapsed: false,
    navGroupsCollapsed: {},
  },
  theme: "system",
  themeResolved: "dark",
  applySessionKey: "main",
  sessionKey: "main",
  tab,
  connected: false,
  chatHasAutoScrolled: false,
  logsAtBottom: false,
  eventLog: [],
  eventLogBuffer: [],
  basePath: "",
  themeMedia: null,
  themeMediaHandler: null,
  logsPollInterval: null,
  debugPollInterval: null,
});

describe("setTabFromRoute", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("starts and stops log polling based on the tab", () => {
    const host = createHost("chat");

    setTabFromRoute(host, "logs");
    expect(host.logsPollInterval).not.toBeNull();
    expect(host.debugPollInterval).toBeNull();

    setTabFromRoute(host, "chat");
    expect(host.logsPollInterval).toBeNull();
  });

  it("starts and stops debug polling based on the tab", () => {
    const host = createHost("chat");

    setTabFromRoute(host, "debug");
    expect(host.debugPollInterval).not.toBeNull();
    expect(host.logsPollInterval).toBeNull();

    setTabFromRoute(host, "chat");
    expect(host.debugPollInterval).toBeNull();
  });
});

describe("applySettingsFromUrl", () => {
  it("correctly parses token containing '+' from hash", () => {
    const host = createHost("chat");
    const testToken = "uTvryFvAbz6M5sRtmTaSTQY6otLZ95hneBsWqXu+35I=";

    // Mock window.location
    const originalLocation = window.location;
    delete (window as any).location;
    window.location = new URL("https://example.com/chat#token=" + testToken) as any;

    applySettingsFromUrl(host);

    expect(host.settings.token).toBe(testToken);

    // Cleanup
    window.location = originalLocation;
  });
});
