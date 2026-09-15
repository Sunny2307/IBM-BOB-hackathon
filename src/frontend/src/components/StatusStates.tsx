interface LoadingBlockProps {
  label?: string;
}

export function LoadingBlock({ label = "Loading" }: LoadingBlockProps) {
  return (
    <div className="flex items-center gap-3 border-l-2 border-carbon-blue-60 bg-carbon-white px-5 py-6">
      <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-carbon-blue-60" />
      <span className="font-sans text-sm font-medium text-carbon-gray-100">{label}…</span>
    </div>
  );
}

interface EmptyBlockProps {
  message: string;
}

export function EmptyBlock({ message }: EmptyBlockProps) {
  return (
    <div className="border border-carbon-gray-20 px-4 py-12 text-center font-serif text-base text-carbon-gray-70 italic">
      {message}
    </div>
  );
}

interface ErrorBlockProps {
  message: string;
}

export function ErrorBlock({ message }: ErrorBlockProps) {
  return (
    <div className="border-l-2 border-risk-critical bg-carbon-white px-5 py-4">
      <p className="font-sans text-sm font-bold text-carbon-gray-100">Connection Failed</p>
      <p className="mt-1 text-sm text-carbon-gray-70">{message}</p>
    </div>
  );
}

interface FallbackBannerProps {
  message?: string;
}

/**
 * Unmissable full-width warning strip shown whenever the UI has fallen back
 * to local mock data because the live backend could not be reached. Must
 * never read as "the app is just static" — so this is deliberately loud
 * (full bleed, high-contrast, icon) rather than a small inline note.
 */
export function FallbackBanner({
  message = "Backend unreachable — showing cached demo data instead of live grid data.",
}: FallbackBannerProps) {
  return (
    <div
      role="alert"
      className="flex w-full items-center gap-3 border-l-2 border-risk-medium bg-risk-medium-bg px-5 py-3"
    >
      <span
        className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full border border-risk-medium font-serif text-sm font-semibold text-risk-medium"
        aria-hidden
      >
        !
      </span>
      <span className="font-sans text-sm text-carbon-gray-100">
        <strong className="uppercase tracking-wide">Showing cached demo data</strong>
        <span className="mx-1.5 text-carbon-gray-70">—</span>
        {message}
      </span>
    </div>
  );
}
