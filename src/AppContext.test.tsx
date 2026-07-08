import { renderHook, act, waitFor } from '@testing-library/react';
import { AppProvider, useAppState } from './AppContext';
import { expect, test, describe } from 'vitest';

describe('AppContext', () => {
  test('initializes state correctly', () => {
    const { result } = renderHook(() => useAppState(), { wrapper: AppProvider });
    
    expect(result.current.loading).toBe(true);
    expect(result.current.range).toBe('Cycle');
    expect(result.current.trendType).toBe('Tokens');
    expect(result.current.windowLabel).toBe('main');
    expect(result.current.activePet).toBe('codex');
    expect(result.current.appMode).toBe('Opencode');
  });

  test('fetches usage successfully on mount', async () => {
    const { result } = renderHook(() => useAppState(), { wrapper: AppProvider });
    
    // Wait for the async fetchUsage to complete
    await waitFor(() => {
      expect(result.current.loading).toBe(false);
    });

    expect(result.current.data).not.toBeNull();
    expect(result.current.data?.summary.membershipType).toBe('Pro');
    expect(result.current.data?.events.totalUsageEventsCount).toBe(10);
  });

  test('can change appMode and range', () => {
    const { result } = renderHook(() => useAppState(), { wrapper: AppProvider });
    
    act(() => {
      result.current.setAppMode('Cursor');
      result.current.setRange('Today');
    });

    expect(result.current.appMode).toBe('Cursor');
    expect(result.current.range).toBe('Today');
  });
});
