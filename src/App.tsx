import { useEffect, useState, useRef } from "react";
import { invoke } from "@tauri-apps/api/core";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { emit, listen } from "@tauri-apps/api/event";
import "./App.css";

// Import locally copied spritesheets
import codexSprite from "./assets/sprites/codex.webp";
import seedySprite from "./assets/sprites/seedy.webp";
import fireballSprite from "./assets/sprites/fireball.webp";
import hootsSprite from "./assets/sprites/hoots.webp";
import deweySprite from "./assets/sprites/dewey.webp";
import rockySprite from "./assets/sprites/rocky.webp";
import stackySprite from "./assets/sprites/stacky.webp";
import bsodSprite from "./assets/sprites/bsod.webp";
import nullSignalSprite from "./assets/sprites/null-signal.webp";

const spriteMaps: Record<string, string> = {
  codex: codexSprite,
  seedy: seedySprite,
  fireball: fireballSprite,
  hoots: hootsSprite,
  dewey: deweySprite,
  rocky: rockySprite,
  stacky: stackySprite,
  bsod: bsodSprite,
  "null-signal": nullSignalSprite
};

interface MascotProps {
  petId: string;
  width?: string;
  height?: string;
}

function Mascot({ petId, width = "22px", height = "24px" }: MascotProps) {
  const [spritesheet, setSpritesheet] = useState<string | null>(null);
  const [state, setState] = useState<string>("idle");
  const [frame, setFrame] = useState<{ rowIndex: number; columnIndex: number }>({ rowIndex: 0, columnIndex: 0 });
  const timeoutRef = useRef<number | null>(null);

  useEffect(() => {
    let unlistenFn: (() => void) | null = null;
    const setupListener = async () => {
      const unlisten = await listen<{ state: string }>("cursor-agent-status", (event) => {
        setState(event.payload.state);
      });
      unlistenFn = unlisten;
    };
    setupListener();
    return () => {
      if (unlistenFn) unlistenFn();
    };
  }, []);

  useEffect(() => {
    if (petId === "unknown" || !spriteMaps[petId]) {
      setSpritesheet(null);
    } else {
      setSpritesheet(spriteMaps[petId]);
    }
  }, [petId]);

  const rowFrames = {
    idle: [
      { rowIndex: 0, columnIndex: 0, duration: 280 },
      { rowIndex: 0, columnIndex: 1, duration: 110 },
      { rowIndex: 0, columnIndex: 2, duration: 110 },
      { rowIndex: 0, columnIndex: 3, duration: 140 },
      { rowIndex: 0, columnIndex: 4, duration: 140 },
      { rowIndex: 0, columnIndex: 5, duration: 320 }
    ],
    jumping: Array.from({ length: 5 }, (_, i) => ({ rowIndex: 4, columnIndex: i, duration: i === 4 ? 280 : 140 })),
    waving: Array.from({ length: 4 }, (_, i) => ({ rowIndex: 3, columnIndex: i, duration: i === 3 ? 280 : 140 })),
    review: Array.from({ length: 6 }, (_, i) => ({ rowIndex: 8, columnIndex: i, duration: i === 5 ? 280 : 150 })),
    running: Array.from({ length: 6 }, (_, i) => ({ rowIndex: 7, columnIndex: i, duration: i === 5 ? 220 : 120 })),
    waiting: Array.from({ length: 6 }, (_, i) => ({ rowIndex: 6, columnIndex: i, duration: i === 5 ? 260 : 150 })),
    failed: Array.from({ length: 8 }, (_, i) => ({ rowIndex: 5, columnIndex: i, duration: i === 7 ? 240 : 140 }))
  };

  useEffect(() => {
    let activeFrames = rowFrames.idle;
    let loopStart = 0;

    if (state === "jumping") {
      const repeated = [...rowFrames.jumping, ...rowFrames.jumping, ...rowFrames.jumping];
      activeFrames = [...repeated, ...rowFrames.idle];
      loopStart = repeated.length;
    } else if (state === "waving") {
      const repeated = [...rowFrames.waving, ...rowFrames.waving, ...rowFrames.waving];
      activeFrames = [...repeated, ...rowFrames.idle];
      loopStart = repeated.length;
    } else if (state === "review") {
      const repeated = [...rowFrames.review, ...rowFrames.review, ...rowFrames.review];
      activeFrames = [...repeated, ...rowFrames.idle];
      loopStart = repeated.length;
    } else if (state === "running") {
      const repeated = [...rowFrames.running, ...rowFrames.running, ...rowFrames.running];
      activeFrames = [...repeated, ...rowFrames.idle];
      loopStart = repeated.length;
    } else if (state === "waiting") {
      const repeated = [...rowFrames.waiting, ...rowFrames.waiting, ...rowFrames.waiting];
      activeFrames = [...repeated, ...rowFrames.idle];
      loopStart = repeated.length;
    } else if (state === "failed") {
      const repeated = [...rowFrames.failed, ...rowFrames.failed, ...rowFrames.failed];
      activeFrames = [...repeated, ...rowFrames.idle];
      loopStart = repeated.length;
    }

    let currentIndex = 0;

    const nextFrame = () => {
      const current = activeFrames[currentIndex];
      if (!current) return;

      setFrame({ rowIndex: current.rowIndex, columnIndex: current.columnIndex });

      timeoutRef.current = window.setTimeout(() => {
        currentIndex++;
        if (currentIndex >= activeFrames.length) {
          currentIndex = loopStart;
          setState("idle");
        }
        nextFrame();
      }, current.duration);
    };

    nextFrame();

    return () => {
      if (timeoutRef.current) window.clearTimeout(timeoutRef.current);
    };
  }, [state, petId]);

  const handleClick = () => {
    const states = ["jumping", "waving", "review"];
    const randomState = states[Math.floor(Math.random() * states.length)];
    setState(randomState);
  };

  if (!spritesheet) return <div className="mascot-placeholder" />;

  const xPercentage = (frame.columnIndex / 7) * 100;
  const yPercentage = (frame.rowIndex / 8) * 100;

  return (
    <div
      className="mascot-sprite"
      data-tauri-drag-region
      style={{
        backgroundImage: `url(${spritesheet})`,
        backgroundPosition: `${xPercentage}% ${yPercentage}%`,
        backgroundSize: '800% 900%',
        width: width,
        height: height,
        cursor: 'grab'
      }}
      onClick={handleClick}
      title={`Codex Mascot: ${petId}. Drag to move, click to interact!`}
    />
  );
}

interface PlanUsage {
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

interface UsageSummary {
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

interface UsageEvent {
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

interface UsageEventsResponse {
  totalUsageEventsCount: number;
  usageEventsDisplay?: UsageEvent[];
}

interface BackendResponse {
  summary: UsageSummary;
  events: UsageEventsResponse;
}

type RangeType = "Today" | "7D" | "30D" | "Cycle";
type TrendType = "Tokens" | "Cost";

function App() {
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
  const [appMode, _setAppMode] = useState<"Cursor" | "Opencode">("Opencode");
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

  useEffect(() => {
    if (windowLabel !== "main") return;

    const container = document.querySelector(".app-container");
    if (!container) return;

    const observer = new ResizeObserver((entries) => {
      const entry = entries[0];
      if (!entry) return;
      const height = Math.ceil(entry.contentRect.height);
      const constrained = Math.max(150, Math.min(height, 850));
      invoke("resize_window", { height: constrained }).catch((e) =>
        console.error("Failed to resize window", e)
      );
    });

    observer.observe(container);
    return () => observer.disconnect();
  }, [windowLabel]);

  if (windowLabel === "mascot") {
    return (
      <div className="mascot-overlay-window">
        {activePet !== "unknown" && (
          <Mascot petId={activePet} width="80px" height="87px" />
        )}
      </div>
    );
  }

  const formatDate = (dateInput?: string | number | Date) => {
    if (!dateInput) return "";
    const date = dateInput instanceof Date ? dateInput : parseDate(dateInput);
    return date.toLocaleDateString("en-US", {
      day: "numeric",
      month: "short",
      year: "numeric",
    });
  };

  const getRangeLabel = () => {
    if (range === "Cycle") return "Billing cycle";
    if (range === "Today") return "Today";
    if (range === "7D") return "Last 7 Days";
    if (range === "30D") return "Last 30 Days";
    return "Period";
  };

  const getRangeDates = () => {
    if (range === "Cycle" && summary) {
      return `${formatDate(summary.billingCycleStart)} – ${formatDate(summary.billingCycleEnd)}`;
    }
    const today = new Date();
    if (range === "Today") {
      return formatDate(today);
    }
    if (range === "7D") {
      const sevenDaysAgo = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000);
      return `${formatDate(sevenDaysAgo)} – ${formatDate(today)}`;
    }
    if (range === "30D") {
      const thirtyDaysAgo = new Date(today.getTime() - 30 * 24 * 60 * 60 * 1000);
      return `${formatDate(thirtyDaysAgo)} – ${formatDate(today)}`;
    }
    return "";
  };

  const getUpdatedText = () => {
    const diffMs = new Date().getTime() - lastUpdated.getTime();
    const diffMin = Math.floor(diffMs / 60000);
    if (diffMin < 1) return "Updated just now";
    return `Updated ${diffMin}m ago`;
  };

  const summary = data?.summary;
  const events = data?.events?.usageEventsDisplay || [];

  const parseDate = (val: string | number) => {
    if (!val) return new Date();
    const num = Number(val);
    return isNaN(num) ? new Date(val) : new Date(num);
  };

  // Filter events based on selected Range
  const now = new Date();
  const filteredEvents = events.filter((evt) => {
    const evtDate = parseDate(evt.timestamp);
    if (isNaN(evtDate.getTime())) return false;

    if (range === "Today") {
      return evtDate.toDateString() === now.toDateString();
    }
    if (range === "7D") {
      const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      return evtDate >= sevenDaysAgo;
    }
    if (range === "30D") {
      const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      return evtDate >= thirtyDaysAgo;
    }
    if (range === "Cycle" && summary) {
      const start = parseDate(summary.billingCycleStart);
      const end = parseDate(summary.billingCycleEnd);
      return evtDate >= start && evtDate <= end;
    }
    return true;
  });

  // Calculate Metrics from filtered events
  let inputTokens = 0;
  let outputTokens = 0;
  let cacheReadTokens = 0;
  let totalCents = 0;
  let headlessRequests = 0;
  const totalRequests = filteredEvents.length;

  // Daily grouping for trend and busiest day
  const dailyStats: Record<string, { tokens: number; cents: number; dateLabel: string; dateObj: Date }> = {};
  
  // 24 hour bucket activity
  const hourlyActivity = Array(24).fill(false);

  filteredEvents.forEach((evt) => {
    totalCents += evt.chargedCents;
    if (evt.isHeadless) {
      headlessRequests++;
    }
    
    const date = parseDate(evt.timestamp);
    if (!isNaN(date.getTime())) {
      const dateKey = date.toDateString();
      const hour = date.getHours();
      hourlyActivity[hour] = true;

      const tokens = evt.tokenUsage 
        ? evt.tokenUsage.inputTokens + evt.tokenUsage.outputTokens + evt.tokenUsage.cacheReadTokens
        : 0;

      if (evt.tokenUsage) {
        inputTokens += evt.tokenUsage.inputTokens;
        outputTokens += evt.tokenUsage.outputTokens;
        cacheReadTokens += evt.tokenUsage.cacheReadTokens;
      }

      if (!dailyStats[dateKey]) {
        dailyStats[dateKey] = {
          tokens: 0,
          cents: 0,
          dateLabel: date.toLocaleDateString("en-US", { weekday: "short", day: "numeric", month: "short" }),
          dateObj: date
        };
      }
      dailyStats[dateKey].tokens += tokens;
      dailyStats[dateKey].cents += evt.chargedCents;
    }
  });

  const totalTokens = inputTokens + outputTokens + cacheReadTokens;

  // Find Busiest Day
  let busiestDayStr = "No data";
  let busiestDayVal = "0 tokens";
  let maxDailyTokens = -1;

  Object.values(dailyStats).forEach((day) => {
    if (day.tokens > maxDailyTokens) {
      maxDailyTokens = day.tokens;
      busiestDayStr = day.dateLabel;
      busiestDayVal = `${(day.tokens / 1000).toFixed(1)}K tokens`;
    }
  });

  const formatTokens = (tokens: number) => {
    if (tokens >= 1_000_000) {
      return `${(tokens / 1_000_000).toFixed(1)}M`;
    }
    return `${(tokens / 1_000).toFixed(1)}K`;
  };

  const formatCost = (cents: number) => {
    return `$${(cents / 100).toFixed(2)}`;
  };

  useEffect(() => {
    const cost = formatCost(totalCents);
    invoke('set_tray_title', { title: cost }).catch(console.error);
  }, [totalCents]);

  // Percentage Calculations
  const inPct = totalTokens > 0 ? Math.round((inputTokens / totalTokens) * 100) : 0;
  const outPct = totalTokens > 0 ? Math.round((outputTokens / totalTokens) * 100) : 0;
  const cacheRPct = totalTokens > 0 ? Math.round((cacheReadTokens / totalTokens) * 100) : 0;
  const cacheWPct = 0;

  const meanCharge = totalRequests > 0 ? formatCost(totalCents / totalRequests) : "$0.00";

  // Projected Spend
  let projectedSpend = "$0.00";
  if (summary) {
    const startObj = parseDate(summary.billingCycleStart);
    const endObj = parseDate(summary.billingCycleEnd);
    const start = startObj.getTime();
    const end = endObj.getTime();
    const totalDuration = end - start;
    const elapsed = now.getTime() - start;

    if (elapsed > 0 && totalDuration > 0) {
      const currentCents = events.reduce((acc, evt) => {
        const t = parseDate(evt.timestamp).getTime();
        if (t >= start && t <= end) {
          return acc + evt.chargedCents;
        }
        return acc;
      }, 0);
      const projectedCents = (currentCents / elapsed) * totalDuration;
      projectedSpend = formatCost(projectedCents);
    }
  }

  // Generate Daily Trend Chart Points
  const trendPoints: { xLabel: string; value: number; rawValue: number }[] = [];
  
  if (summary) {
    const start = parseDate(summary.billingCycleStart);
    const end = parseDate(summary.billingCycleEnd);
    
    // Create points for every 2 days across the cycle to avoid cluttering, or group by day
    const dayMs = 24 * 60 * 60 * 1000;
    for (let time = start.getTime(); time <= end.getTime(); time += dayMs) {
      const d = new Date(time);
      const key = d.toDateString();
      const stats = dailyStats[key];
      const rawVal = stats ? (trendType === "Tokens" ? stats.tokens : stats.cents) : 0;
      
      trendPoints.push({
        xLabel: d.toLocaleDateString("en-US", { day: "numeric", month: "short" }),
        value: rawVal,
        rawValue: rawVal
      });
    }
  }


  // Group by Models
  const modelStats: Record<string, number> = {};
  filteredEvents.forEach((evt) => {
    const m = evt.model;
    const tokens = evt.tokenUsage 
      ? evt.tokenUsage.inputTokens + evt.tokenUsage.outputTokens + evt.tokenUsage.cacheReadTokens
      : 0;
    modelStats[m] = (modelStats[m] || 0) + tokens;
  });

  const sortedModels = Object.entries(modelStats).sort((a, b) => b[1] - a[1]);

  return (
    <div className="app-container">
      {/* Top Controls Bar */}
      <header className="app-top-bar">
        <div className="left-header-group">
          <label className="checkbox-container">
            <input 
              type="checkbox" 
              checked={launchAtLogin} 
              onChange={(e) => setLaunchAtLogin(e.target.checked)} 
            />
            <span className="checkmark" />
            <span className="checkbox-label">Launch at login</span>
          </label>
          <button 
            className={`refresh-footer-btn ${loading ? "spinning" : ""}`} 
            onClick={fetchUsage}
            disabled={loading}
            title="Refresh"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" className="w-4 h-4">
              <path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l.73-2.73" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </button>
        </div>
        <div className="top-actions">
          {activePet !== "unknown" && (
            <div className="active-pet-wrapper" style={{ position: 'relative' }}>
              <Mascot petId={activePet} />
              <span className="active-pet-name">{activePet}</span>
              <select 
                value={activePet} 
                onChange={(e) => {
                  const newPet = e.target.value;
                  localStorage.setItem("activeMascot", newPet);
                  setActivePet(newPet);
                  window.dispatchEvent(new StorageEvent("storage", {
                    key: "activeMascot",
                    newValue: newPet
                  }));
                }}
                style={{
                  position: 'absolute',
                  top: 0,
                  left: 0,
                  width: '100%',
                  height: '100%',
                  opacity: 0,
                  cursor: 'pointer'
                }}
              >
                {["codex", "seedy", "fireball", "hoots", "dewey", "rocky", "stacky", "bsod", "null-signal"].map((p) => (
                  <option key={p} value={p}>{p}</option>
                ))}
              </select>
            </div>
          )}
          <button className="top-action-btn" title="Settings">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" className="w-4 h-4">
              <path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.1a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z" />
              <circle cx="12" cy="12" r="3" />
            </svg>
          </button>
          <button className="top-action-btn" title="Quit Application" onClick={() => invoke("quit")}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" className="w-4 h-4">
              <path d="M18.36 6.64a9 9 0 1 1-12.73 0M12 2v10" strokeLinecap="round" strokeLinejoin="round" />
            </svg>
          </button>
        </div>
      </header>

      {/* Range Segmented Controls */}
      <section className="range-selector-section">
        <div className="range-container">
          <span className="range-title">Range</span>
          <div className="segmented-control">
            {(["Today", "7D", "30D", "Cycle"] as RangeType[]).map((r) => (
              <button 
                key={r}
                className={`segment-btn ${range === r ? "active" : ""}`}
                onClick={() => setRange(r)}
              >
                {r}
              </button>
            ))}
          </div>
        </div>
        <p className="updated-text">{getUpdatedText()}</p>
      </section>

      {/* Main Content Scrollable Area */}
      <main className="app-main-content">
        {loading && !data ? (
          <div className="loading-state">
            <div className="spinner" />
            <p>Loading usage summary...</p>
          </div>
        ) : error ? (
          <div className="error-state">
            <p className="error-title">Authentication Required</p>
            <p className="error-desc">{error}</p>
            <button className="retry-btn" onClick={fetchUsage}>Retry</button>
          </div>
        ) : (
          <div className="usage-layout-grid">
            {/* Primary Stat Cards */}
            <div className="stat-cards-row">
              <div className="stat-card">
                <span className="card-lbl">Tokens</span>
                <span className="card-val">{formatTokens(totalTokens)}</span>
                <span className="card-sub">{totalRequests} requests</span>
              </div>
              <div className="stat-card">
                <span className="card-lbl">Cost</span>
                <span className="card-val">{formatCost(totalCents)}</span>
                <span className="card-sub">Sum of chargedCents</span>
              </div>
            </div>

            {/* Cycle Details */}
            <div className="cycle-row">
              <div className="cycle-col">
                <span className="cycle-lbl">{getRangeLabel()}</span>
                <span className="cycle-val">
                  {getRangeDates()}
                </span>
              </div>
              <div className="cycle-col text-right">
                <span className="cycle-lbl">Projected</span>
                <span className="cycle-val highlight">{projectedSpend}</span>
              </div>
            </div>

            {/* Scrollable sections below billing cycle */}
            <div className="scrollable-content">
              {/* Daily Trend Chart */}
              <div className="daily-trend-section">
                <div className="trend-header">
                  <span className="section-title">Daily trend</span>
                  <div className="segmented-control tiny">
                    {(["Tokens", "Cost"] as TrendType[]).map((t) => (
                      <button
                        key={t}
                        className={`segment-btn ${trendType === t ? "active" : ""}`}
                        onClick={() => setTrendType(t)}
                      >
                        {t}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Custom SVG Bar Chart */}
                <div className="trend-chart-container">
                  <div className="y-axis-labels">
                    <span>{trendType === "Tokens" ? "600K" : "$6.00"}</span>
                    <span>{trendType === "Tokens" ? "400K" : "$4.00"}</span>
                    <span>{trendType === "Tokens" ? "200K" : "$2.00"}</span>
                    <span>0</span>
                  </div>
                  <div className="chart-bars-scroll">
                    <svg className="trend-svg" viewBox="0 0 300 100" preserveAspectRatio="none">
                      {/* Grid lines */}
                      <line x1="0" y1="0" x2="300" y2="0" stroke="rgba(255,255,255,0.05)" strokeWidth="1" />
                      <line x1="0" y1="33" x2="300" y2="33" stroke="rgba(255,255,255,0.05)" strokeWidth="1" />
                      <line x1="0" y1="66" x2="300" y2="66" stroke="rgba(255,255,255,0.05)" strokeWidth="1" />
                      <line x1="0" y1="100" x2="300" y2="100" stroke="rgba(255,255,255,0.1)" strokeWidth="1" />

                      {/* Bars */}
                      {trendPoints.map((point, index) => {
                        const barWidth = 300 / trendPoints.length - 2;
                        const barHeight = (point.value / (trendType === "Tokens" ? 600_000 : 600)) * 100;
                        const x = index * (300 / trendPoints.length);
                        const y = 100 - Math.min(barHeight, 100);
                        
                        return (
                          <rect
                            key={index}
                            x={x}
                            y={y}
                            width={Math.max(barWidth, 2)}
                            height={Math.max(barHeight, 0)}
                            fill="var(--accent-blue)"
                            rx="1.5"
                          />
                        );
                      })}
                    </svg>
                    <div className="x-axis-labels">
                      {trendPoints.filter((_, i) => i % 5 === 0).map((p, i) => (
                        <span key={i}>{p.xLabel}</span>
                      ))}
                    </div>
                  </div>
                </div>
              </div>

              {/* Token Split Segments */}
              <div className="token-split-section">
                <span className="section-title">Token split</span>
                <div className="split-progress-bar">
                  <div className="progress-seg in" style={{ width: `${inPct}%` }} />
                  <div className="progress-seg out" style={{ width: `${outPct}%` }} />
                  <div className="progress-seg cache-w" style={{ width: `${cacheWPct}%` }} />
                  <div className="progress-seg cache-r" style={{ width: `${cacheRPct}%` }} />
                </div>
                <div className="split-legends">
                  <span className="legend-item"><span className="dot in" />In {inPct}%</span>
                  <span className="legend-item"><span className="dot out" />Out {outPct}%</span>
                  <span className="legend-item"><span className="dot cache-w" />Cache W {cacheWPct}%</span>
                  <span className="legend-item"><span className="dot cache-r" />Cache R {cacheRPct}%</span>
                </div>
              </div>

              {/* Time of Day */}
              <div className="time-of-day-section">
                <span className="section-title">Time of day</span>
                <div className="hours-grid">
                  {hourlyActivity.map((active, hour) => (
                    <div 
                      key={hour} 
                      className={`hour-block ${active ? "active" : ""}`}
                      title={`${hour}:00 - ${active ? "Active" : "Inactive"}`}
                    />
                  ))}
                </div>
                <div className="hours-labels">
                  <span>12a</span>
                  <span>6a</span>
                  <span>12p</span>
                  <span>6p</span>
                </div>
              </div>

              {/* Activity Block */}
              <div className="activity-section">
                <span className="section-title">Activity</span>
                <div className="activity-grid">
                  <div className="activity-card">
                    <span className="act-lbl">Requests</span>
                    <span className="act-val">{totalRequests}</span>
                    <span className="act-sub">{totalRequests - headlessRequests} interactive</span>
                  </div>
                  <div className="activity-card">
                    <span className="act-lbl">Background agents</span>
                    <span className="act-val">{headlessRequests}</span>
                    <span className="act-sub">headless requests</span>
                  </div>
                  <div className="activity-card">
                    <span className="act-lbl">Avg / request</span>
                    <span className="act-val">{meanCharge}</span>
                    <span className="act-sub">mean charge</span>
                  </div>
                  <div className="activity-card">
                    <span className="act-lbl">Cache reads</span>
                    <span className="act-val">{cacheRPct}%</span>
                    <span className="act-sub">of all tokens</span>
                  </div>
                </div>
              </div>

              {/* Busiest Day */}
              <div className="busiest-day-section">
                <div className="stat-card">
                  <span className="card-lbl">Busiest day</span>
                  <span className="card-val text-large">{busiestDayStr}</span>
                  <span className="card-sub">{busiestDayVal}</span>
                </div>
              </div>

              {/* Models Token Split List */}
              <div className="models-list-section">
                <div className="models-header">
                  <span className="section-title">Models</span>
                  <div className="dropdown-like-lbl">Tokens</div>
                </div>
                <div className="models-rows">
                  {sortedModels.map(([name, tokens]) => (
                    <div className="model-list-row" key={name}>
                      <div className="model-row-meta">
                        <span className="model-row-name">{name}</span>
                        <span className="model-row-val">{formatTokens(tokens)}</span>
                      </div>
                      <div className="model-progress-bg">
                        <div 
                          className="model-progress-fill" 
                          style={{ width: `${(tokens / Math.max(totalTokens, 1)) * 100}%` }}
                        />
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>

          </div>
        )}
      </main>

      {/* Bottom Bar */}
      <footer className="app-bottom-bar" />
    </div>
  );
}

export default App;
