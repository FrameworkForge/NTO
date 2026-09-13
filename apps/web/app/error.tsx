"use client";
import { ErrorState } from "../components/State";
export default function Error({ reset }: { reset: () => void }) {
  return (
    <>
      <ErrorState title="The work could not load.">
        Try again to reconnect to this page.
      </ErrorState>
      <div style={{ padding: 40 }}>
        <button onClick={reset}>Try again</button>
      </div>
    </>
  );
}
