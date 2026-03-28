import Link from "next/link";
import { useRouter } from "next/router";
import type { ReactNode } from "react";

const nav = [
  { href: "/docs", label: "Docs" },
  { href: "/learn", label: "Learn" },
  { href: "/try", label: "Try" },
];

const docsNav = [{ href: "/docs", label: "Webhook API" }];

const learnNav = [
  { href: "/learn", label: "Overview" },
  { href: "/learn/curl", label: "cURL" },
  { href: "/learn/json", label: "JSON body" },
  { href: "/learn/browser-get", label: "GET in browser" },
];

export default function SiteLayout({ children }: { children: ReactNode }) {
  const { pathname } = useRouter();
  const showDocsSidebar = pathname.startsWith("/docs");
  const showLearnSidebar = pathname.startsWith("/learn");

  return (
    <div className="min-h-screen flex flex-col">
      <header className="border-b border-[var(--border)] bg-[var(--background)] sticky top-0 z-10">
        <div className="max-w-6xl mx-auto px-4 h-14 flex items-center justify-between gap-6">
          <Link href="/docs" className="font-semibold text-lg tracking-tight">
            Ping
          </Link>
          <nav className="flex items-center gap-6 text-sm font-medium">
            {nav.map((item) => {
              const active =
                item.href === "/docs"
                  ? pathname === "/docs" || pathname.startsWith("/docs/")
                  : pathname === item.href || pathname.startsWith(`${item.href}/`);
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  className={
                    active
                      ? "text-[var(--foreground)]"
                      : "text-[var(--muted)] hover:text-[var(--foreground)]"
                  }
                >
                  {item.label}
                </Link>
              );
            })}
          </nav>
        </div>
      </header>
      <div className="flex flex-1 max-w-6xl w-full mx-auto px-4 pb-16">
        {(showDocsSidebar || showLearnSidebar) && (
          <aside className="hidden md:block w-52 shrink-0 pt-8 pr-6 border-r border-[var(--border)]">
            <p className="text-xs font-semibold uppercase tracking-wide text-[var(--muted)] mb-3">
              {showDocsSidebar ? "Docs" : "Learn"}
            </p>
            <ul className="space-y-1 text-sm">
              {(showDocsSidebar ? docsNav : learnNav).map((item) => (
                <li key={item.href}>
                  <Link
                    href={item.href}
                    className={
                      pathname === item.href
                        ? "text-[var(--accent)] font-medium"
                        : "text-[var(--muted)] hover:text-[var(--foreground)]"
                    }
                  >
                    {item.label}
                  </Link>
                </li>
              ))}
            </ul>
          </aside>
        )}
        <main className="flex-1 min-w-0 pt-8 md:pl-2">
          {pathname === "/try" ? (
            <div className="max-w-xl">{children}</div>
          ) : (
            <div className="markdoc max-w-2xl">{children}</div>
          )}
        </main>
      </div>
    </div>
  );
}
