import { Component, type ErrorInfo, type ReactNode } from "react";

interface Props {
  children: ReactNode;
}

interface State {
  error: Error | null;
}

/**
 * Last-resort safety net for a live judged demo: catches any uncaught render
 * error so the app never shows a blank white screen.
 */
export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error("Unhandled UI error:", error, info.componentStack);
  }

  render() {
    if (this.state.error) {
      return (
        <div className="flex min-h-screen items-center justify-center bg-console-950 px-4">
          <div className="max-w-md border border-risk-critical/50 bg-risk-critical/5 p-6 text-center">
            <p className="font-mono text-sm font-bold tracking-widest text-risk-critical uppercase">
              Console Error
            </p>
            <p className="mt-2 text-sm text-slate-300">
              Something went wrong rendering this view. Try reloading — your data is unaffected.
            </p>
            <button
              type="button"
              onClick={() => {
                this.setState({ error: null });
                window.location.href = "/";
              }}
              className="mt-4 border border-console-600 px-4 py-2 font-mono text-xs tracking-wide text-slate-200 uppercase hover:border-signal hover:text-signal"
            >
              Return to dashboard
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
