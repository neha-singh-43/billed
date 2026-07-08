import { render, screen } from '@testing-library/react';
import App from './App';
import { AppProvider } from './AppContext';
import { expect, test, describe, vi } from 'vitest';

// Mock Mascot component to avoid loading SVG/image assets in testing
vi.mock('./Mascot', () => ({
  default: () => <div data-testid="mock-mascot" />
}));

describe('App', () => {
  test('renders the main app UI when windowLabel is main', async () => {
    // We already mocked getCurrentWindow to return 'main' in setupTests.ts
    render(
      <AppProvider>
        <App />
      </AppProvider>
    );

    // Initial render is "Loading..." since loading is true initially
    expect(screen.getByText(/Loading...|Opencode/i)).toBeInTheDocument();
    
    // Wait for AppProvider to fetch the usage and disable loading
    const todayElement = await screen.findByText('Today');
    expect(todayElement).toBeInTheDocument();
    
    // Check if models list is rendered
    expect(screen.getByText('Models')).toBeInTheDocument();
  });
});
