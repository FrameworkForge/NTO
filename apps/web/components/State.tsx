import Link from "next/link";
import s from "./experience.module.css";
export function EmptyState({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className={s.empty}>
      <h2>{title}</h2>
      <p>{children}</p>
    </section>
  );
}
export function ErrorState({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <main id="main" className={s.main}>
      <EmptyState title={title}>{children}</EmptyState>
      <Link href="/">Return to NTO</Link>
    </main>
  );
}
export function Progress({ label }: { label: string }) {
  return (
    <div role="status">
      <span className={s.ring} aria-hidden="true" /> <span>{label}</span>
    </div>
  );
}
