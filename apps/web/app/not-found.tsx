import { ErrorState } from "../components/State";
export default function NotFound() {
  return (
    <ErrorState title="This work isn’t here.">
      The project may be unavailable, or the address may have changed.
    </ErrorState>
  );
}
