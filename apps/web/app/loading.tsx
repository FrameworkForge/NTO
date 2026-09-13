import { Progress } from "../components/State";
export default function Loading() {
  return (
    <main id="main" style={{ padding: 40 }}>
      <Progress label="Loading the work…" />
    </main>
  );
}
