import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { login as loginRequest, setAuthToken, setUnauthorizedHandler } from "../api/client";
import { ApiError } from "../api/client";
import type { AuthSession } from "../api/types";

const STORAGE_KEY = "grid_advisor_session";

interface AuthValue {
  session: AuthSession | null;
  isAdmin: boolean;
  isSigningIn: boolean;
  error: string | null;
  signIn: (email: string, password: string) => Promise<boolean>;
  signOut: (expired?: boolean) => void;
}

const AuthContext = createContext<AuthValue | null>(null);

/** Reads the stored session synchronously on first render, so a returning user
 * never sees a flash of the signed-out header. */
function readStoredSession(): AuthSession | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as AuthSession;
    setAuthToken(parsed.access_token);
    return parsed;
  } catch {
    localStorage.removeItem(STORAGE_KEY);
    return null;
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<AuthSession | null>(readStoredSession);
  const [isSigningIn, setIsSigningIn] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const signOut = useCallback((expired = false) => {
    setSession(null);
    setAuthToken(null);
    setError(expired ? "Your session expired. Please sign in again." : null);
    localStorage.removeItem(STORAGE_KEY);
  }, []);

  // A 401 from anywhere in the app lands here, so an expired session drops the
  // user out instead of leaving them staring at an empty alert list.
  useEffect(() => {
    setUnauthorizedHandler(() => signOut(true));
    return () => setUnauthorizedHandler(null);
  }, [signOut]);

  const signIn = useCallback(async (email: string, password: string) => {
    setIsSigningIn(true);
    setError(null);
    try {
      const next = await loginRequest(email.trim(), password);
      setAuthToken(next.access_token);
      localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
      setSession(next);
      return true;
    } catch (err) {
      setError(err instanceof ApiError ? err.message : "Could not sign in.");
      return false;
    } finally {
      setIsSigningIn(false);
    }
  }, []);

  const value = useMemo<AuthValue>(
    () => ({
      session,
      isAdmin: session?.role === "admin",
      isSigningIn,
      error,
      signIn,
      signOut,
    }),
    [session, isSigningIn, error, signIn, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthValue {
  const value = useContext(AuthContext);
  if (!value) throw new Error("useAuth must be used inside <AuthProvider>");
  return value;
}
