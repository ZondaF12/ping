"use client";

import { PRODUCTION_API_BASE } from "@/lib/productionApiBase";
import { useCallback, useMemo, useState } from "react";

type Result =
  | { kind: "idle" }
  | { kind: "ok"; body: string; status: number }
  | { kind: "error"; message: string };

function buildPayload(input: {
  message: string;
  title: string;
  subtitle: string;
  url: string;
  image_url: string;
  expiration_date: string;
  interruption_level: string;
  filter_criteria: string;
}): Record<string, string> | null {
  const message = input.message.trim();
  if (!message) {
    return null;
  }
  const out: Record<string, string> = { message };
  const opt = (key: string, value: string) => {
    const t = value.trim();
    if (t) {
      out[key] = t;
    }
  };
  opt("title", input.title);
  opt("subtitle", input.subtitle);
  opt("url", input.url);
  opt("image_url", input.image_url);
  opt("expiration_date", input.expiration_date);
  if (input.interruption_level.trim()) {
    out["interruption-level"] = input.interruption_level.trim();
  }
  opt("filter-criteria", input.filter_criteria);
  return out;
}

function escapeShellSingleQuoted(s: string): string {
  return `'${s.replace(/'/g, `'\\''`)}'`;
}

export default function SendTestForm() {
  const [secret, setSecret] = useState("");
  const [message, setMessage] = useState("Hello world");
  const [title, setTitle] = useState("");
  const [subtitle, setSubtitle] = useState("");
  const [url, setUrl] = useState("");
  const [imageUrl, setImageUrl] = useState("");
  const [expirationDate, setExpirationDate] = useState("");
  const [interruptionLevel, setInterruptionLevel] = useState("");
  const [filterCriteria, setFilterCriteria] = useState("");
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<Result>({ kind: "idle" });

  const targetUrl = useMemo(() => {
    const s = secret.trim();
    if (!s) {
      return "";
    }
    try {
      const u = new URL(
        `${PRODUCTION_API_BASE}/v1/${encodeURIComponent(s)}`,
      );
      return u.toString();
    } catch {
      return "";
    }
  }, [secret]);

  const curlCommand = useMemo(() => {
    if (!targetUrl) {
      return "";
    }
    const payload = buildPayload({
      message,
      title,
      subtitle,
      url,
      image_url: imageUrl,
      expiration_date: expirationDate,
      interruption_level: interruptionLevel,
      filter_criteria: filterCriteria,
    });
    if (!payload) {
      return "";
    }
    const json = JSON.stringify(payload);
    return `curl -X POST ${escapeShellSingleQuoted(targetUrl)} \\\n  -H 'Content-Type: application/json' \\\n  -d ${escapeShellSingleQuoted(json)}`;
  }, [
    targetUrl,
    message,
    title,
    subtitle,
    url,
    imageUrl,
    expirationDate,
    interruptionLevel,
    filterCriteria,
  ]);

  const onSubmit = useCallback(
    async (e: React.FormEvent) => {
      e.preventDefault();
      setResult({ kind: "idle" });
      const payload = buildPayload({
        message,
        title,
        subtitle,
        url,
        image_url: imageUrl,
        expiration_date: expirationDate,
        interruption_level: interruptionLevel,
        filter_criteria: filterCriteria,
      });
      if (!targetUrl || !payload) {
        setResult({
          kind: "error",
          message: "Enter your secret and a non-empty message.",
        });
        return;
      }
      setLoading(true);
      try {
        const res = await fetch(targetUrl, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        });
        const text = await res.text();
        let pretty = text;
        try {
          pretty = JSON.stringify(JSON.parse(text), null, 2);
        } catch {
          /* keep raw */
        }
        setResult({
          kind: "ok",
          body: pretty,
          status: res.status,
        });
      } catch (err) {
        const message =
          err instanceof Error ? err.message : "Request failed (network or CORS).";
        setResult({ kind: "error", message });
      } finally {
        setLoading(false);
      }
    },
    [
      targetUrl,
      message,
      title,
      subtitle,
      url,
      imageUrl,
      expirationDate,
      interruptionLevel,
      filterCriteria,
    ],
  );

  const inputClass =
    "w-full rounded-md border border-[var(--border)] bg-transparent px-3 py-2 text-sm text-[var(--foreground)] placeholder:text-[var(--muted)] focus:outline-none focus:ring-2 focus:ring-[var(--accent)]";

  return (
    <div className="space-y-6">
      <p className="text-sm text-[var(--muted)] leading-relaxed">
        Requests go from your browser to{" "}
        <span className="font-mono text-[13px] text-[var(--foreground)]">
          {PRODUCTION_API_BASE}
        </span>
        . This site never receives your secret. Do not share your secret or
        leave it in screenshots.
      </p>

      <form onSubmit={onSubmit} className="space-y-4">
        <div>
          <label className="block text-xs font-medium text-[var(--muted)] mb-1">
            Secret
          </label>
          <input
            className={inputClass}
            placeholder="from the app"
            value={secret}
            onChange={(e) => setSecret(e.target.value)}
            autoComplete="off"
            spellCheck={false}
          />
        </div>
        <div>
          <label className="block text-xs font-medium text-[var(--muted)] mb-1">
            Message <span className="text-red-500">*</span>
          </label>
          <textarea
            className={`${inputClass} min-h-[88px]`}
            required
            value={message}
            onChange={(e) => setMessage(e.target.value)}
          />
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-[var(--muted)] mb-1">
              Title
            </label>
            <input
              className={inputClass}
              value={title}
              onChange={(e) => setTitle(e.target.value)}
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-[var(--muted)] mb-1">
              Subtitle
            </label>
            <input
              className={inputClass}
              value={subtitle}
              onChange={(e) => setSubtitle(e.target.value)}
            />
          </div>
        </div>
        <div>
          <label className="block text-xs font-medium text-[var(--muted)] mb-1">
            URL
          </label>
          <input
            className={inputClass}
            placeholder="https://…"
            value={url}
            onChange={(e) => setUrl(e.target.value)}
          />
        </div>
        <div>
          <label className="block text-xs font-medium text-[var(--muted)] mb-1">
            Image URL
          </label>
          <input
            className={inputClass}
            value={imageUrl}
            onChange={(e) => setImageUrl(e.target.value)}
          />
        </div>
        <div>
          <label className="block text-xs font-medium text-[var(--muted)] mb-1">
            Expiration (ISO 8601)
          </label>
          <input
            className={inputClass}
            placeholder="2026-12-31T12:00:00.000Z"
            value={expirationDate}
            onChange={(e) => setExpirationDate(e.target.value)}
          />
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className="block text-xs font-medium text-[var(--muted)] mb-1">
              Interruption level
            </label>
            <select
              className={inputClass}
              value={interruptionLevel}
              onChange={(e) => setInterruptionLevel(e.target.value)}
            >
              <option value="">(default)</option>
              <option value="passive">passive</option>
              <option value="active">active</option>
              <option value="time-sensitive">time-sensitive</option>
            </select>
          </div>
          <div>
            <label className="block text-xs font-medium text-[var(--muted)] mb-1">
              Filter criteria
            </label>
            <input
              className={inputClass}
              value={filterCriteria}
              onChange={(e) => setFilterCriteria(e.target.value)}
            />
          </div>
        </div>

        <button
          type="submit"
          disabled={loading}
          className="rounded-md bg-[var(--accent)] text-white px-4 py-2 text-sm font-medium hover:opacity-90 disabled:opacity-50"
        >
          {loading ? "Sending…" : "Send notification"}
        </button>
      </form>

      {result.kind === "error" && (
        <div className="rounded-lg border border-red-300 bg-red-50 dark:bg-red-950/40 dark:border-red-800 px-4 py-3 text-sm text-red-800 dark:text-red-200">
          {result.message}
        </div>
      )}

      {result.kind === "ok" && (
        <div>
          <p className="text-xs font-medium text-[var(--muted)] mb-2">
            Response <span className="text-[var(--foreground)]">({result.status})</span>
          </p>
          <pre className="font-mono text-[13px] leading-relaxed bg-zinc-100 dark:bg-zinc-900 border border-[var(--border)] rounded-lg p-4 overflow-x-auto">
            {result.body}
          </pre>
        </div>
      )}

      {curlCommand && (
        <div>
          <p className="text-xs font-medium text-[var(--muted)] mb-2">cURL</p>
          <pre className="font-mono text-[13px] leading-relaxed bg-zinc-100 dark:bg-zinc-900 border border-[var(--border)] rounded-lg p-4 overflow-x-auto whitespace-pre-wrap break-all">
            {curlCommand}
          </pre>
        </div>
      )}
    </div>
  );
}
