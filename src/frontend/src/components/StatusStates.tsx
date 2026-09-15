interface LoadingBlockProps {
  label?: string;
}

export function LoadingBlock({ label = "Loading" }: LoadingBlockProps) {
  return (
    <div className="flex items-center gap-3 border border-console-700 bg-console-900 px-4 py-6 text-sm text-slate-400">
      <span className="h-2 w-2 animate-pulse bg-signal" />
      <span className="font-mono tracking-wide">{label}…</span>
    </div>
  );
}

interface EmptyBlockProps {
  message: string;
}

export function EmptyBlock({ message }: EmptyBlockProps) {
  return (
    <div className="border border-dashed border-console-700 bg-console-900 px-4 py-10 text-center text-sm text-slate-400">
      {message}
    </div>
  );
}

interface ErrorBlockProps {
  message: string;
}

export function ErrorBlock({ message }: ErrorBlockProps) {
  return (
    <div className="border border-risk-critical/40 bg-risk-critical/5 px-4 py-6 text-sm text-slate-200">
      <p className="font-mono font-semibold text-risk-critical">CONNECTION FAILED</p>
      <p className="mt-1 text-slate-400">{message}</p>
    </div>
  );
}

interface FallbackBannerProps {
  message?: string;
}

export function FallbackBanner({
  message = "Backend unreachable — showing local demo data.",
}: FallbackBannerProps) {
  return (
    <div className="flex items-center gap-2 border border-risk-medium/40 bg-risk-medium/10 px-3 py-2 text-xs text-risk-medium">
      <span className="h-1.5 w-1.5 shrink-0 bg-risk-medium" />
      <span className="font-mono tracking-wide">DEMO DATA — {message}</span>
    </div>
  );
}
