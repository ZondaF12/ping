import dynamic from "next/dynamic";
import type { GetServerSideProps } from "next";

const SendTestForm = dynamic(() => import("@/components/SendTestForm"), {
  ssr: false,
});

/** Avoid static prerender of this page (dynamic + hooks edge case in Next 15). */
export const getServerSideProps: GetServerSideProps = async () => ({
  props: {},
});

export default function TryPage() {
  return (
    <div>
      <h1 className="text-2xl font-semibold tracking-tight mb-2">
        Send a test notification
      </h1>
      <p className="text-[15px] text-[var(--muted)] mb-8 leading-relaxed">
        Paste your webhook secret and send a JSON payload to your devices. Same
        behavior as{" "}
        <a href="/docs" className="text-[var(--accent)] underline underline-offset-2">
          POST /v1/:secret
        </a>
        .
      </p>
      <SendTestForm />
    </div>
  );
}
