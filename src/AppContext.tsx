import React, { createContext, useContext, useState, useEffect, useRef } from "react";
import { invoke } from "@tauri-apps/api/core";
import { emit } from "@tauri-apps/api/event";
import { getCurrentWindow } from "@tauri-apps/api/window";

export interface PlanUsage {
  enabled: boolean;
  used: number;
  limit: number;
  remaining: number;
  breakdown: {
    included: number;
    bonus: number;
    total: number;
  };
  autoPercentUsed: number;
  apiPercentUsed: number;
  totalPercentUsed: number;
}

export interface UsageSummary {
  billingCycleStart: string;
  billingCycleEnd: string;
  membershipType: string;
  limitType: string;
  isUnlimited: boolean;
  autoModelSelectedDisplayMessage: string;
  namedModelSelectedDisplayMessage: string;
  individualUsage: {
    plan?: PlanUsage;
    onDemand?: {
      enabled: boolean;
      used: number;
      limit: number | null;
      remaining: number | null;
    };
  };
}

export interface UsageEvent {
  timestamp: string;
  model: string;
  kind: string;
  requestsCosts: number;
  isTokenBasedCall: boolean;
  tokenUsage?: {
    inputTokens: number;
    outputTokens: number;
    cacheReadTokens: number;
    totalCents: number;
  };
  isHeadless: boolean;
  chargedCents: number;
  conversationId?: string;
}

export interface UsageEventsResponse {
  totalUsageEventsCount: number;
  usageEventsDisplay?: UsageEvent[];
}

export interface BackendResponse {
  summary: UsageSummary;
  events: UsageEventsResponse;
}

export type RangeType = "Today" | "7D" | "30D" | "Cycle";
export type TrendType = "Tokens" | "Cost";
export type AppMode = "Cursor" | "Opencode";

export interface AppState {
  loading: boolean;
  error: string | null;
  data: BackendResponse | null;
  range: RangeType;
  setRange: (range: RangeType) => void;
  trendType: TrendType;
  setTrendType: (trendType: TrendType) => void;
  launchAtLogin: boolean;
  setLaunchAtLogin: (launch: boolean) => void;
  lastUpdated: Date;
  activePet: string;
  setActivePet: (pet: string) => void;
  windowLabel: string;
  appMode: AppMode;
  setAppMode: (mode: AppMode) => void;
  fetchUsage: () => Promise<void>;
}

const AppContext = createContext<AppState | undefined>(undefined);

export const AppProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [data, setData] = useState<BackendResponse | null>(null);
  const [range, setRange] = useState<RangeType>("Cycle");
  const [trendType, setTrendType] = useState<TrendType>("Tokens");
  const [launchAtLogin, setLaunchAtLogin] = useState(true);
  const [lastUpdated, setLastUpdated] = useState<Date>(new Date());
  const [activePet, setActivePet] = useState<string>(() => {
    return localStorage.getItem("activeMascot") || "codex";
  });
  const [windowLabel, setWindowLabel] = useState<string>("main");
  const [appMode, setAppMode] = useState<AppMode>("Opencode");
  const prevEventsCount = useRef<number | null>(null);

  const fetchUsage = async () => {
    setLoading(true);
    setError(null);
    try {
      const cmd = appMode === "Cursor" ? "get_cursor_usage" : "get_opencode_usage";
      const result = await invoke<BackendResponse>(cmd);
      setData(result);
      setLastUpdated(new Date());

      const currentCount = result.events?.totalUsageEventsCount || 0;
      if (prevEventsCount.current !== null && currentCount > prevEventsCount.current) {
        emit("cursor-agent-status", { state: "running" });
        setTimeout(() => {
          emit("cursor-agent-status", { state: "jumping" });
        }, 3000);
      }
      prevEventsCount.current = currentCount;
    } catch (err: any) {
      console.error(err);
      setError(err?.toString() || `Failed to fetch ${appMode} usage stats`);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsage();
  }, [appMode]);

  useEffect(() => {
    const pollInterval = setInterval(() => {
      const cmd = appMode === "Cursor" ? "get_cursor_usage" : "get_opencode_usage";
      invoke<BackendResponse>(cmd)
        .then((result) => {
          setData(result);
          setLastUpdated(new Date());
          const currentCount = result.events?.totalUsageEventsCount || 0;
          if (prevEventsCount.current !== null && currentCount > prevEventsCount.current) {
            emit("cursor-agent-status", { state: "running" });
            setTimeout(() => {
              emit("cursor-agent-status", { state: "jumping" });
            }, 3000);
          }
          prevEventsCount.current = currentCount;
        })
        .catch((err) => console.error("Poll usage error", err));
    }, 8000);
    
    const handleStorageChange = (e: StorageEvent) => {
      if (e.key === "activeMascot" && e.newValue) {
        setActivePet(e.newValue);
      }
    };
    window.addEventListener("storage", handleStorageChange);

    try {
      setWindowLabel(getCurrentWindow().label);
    } catch (e) {
      console.error("Failed to get window label", e);
    }

    return () => {
      clearInterval(pollInterval);
      window.removeEventListener("storage", handleStorageChange);
    };
  }, [appMode]);

  return (
    <AppContext.Provider
      value={{
        loading,
        error,
        data,
        range,
        setRange,
        trendType,
        setTrendType,
        launchAtLogin,
        setLaunchAtLogin,
        lastUpdated,
        activePet,
        setActivePet,
        windowLabel,
        appMode,
        setAppMode,
        fetchUsage,
      }}
    >
      {children}
    </AppContext.Provider>
  );
};

export const useAppState = () => {
  const context = useContext(AppContext);
  if (context === undefined) {
    throw new Error("useAppState must be used within an AppProvider");
  }
  return context;
};
