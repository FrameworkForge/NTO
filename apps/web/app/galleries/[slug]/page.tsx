import { notFound } from "next/navigation";
import Link from "next/link";
import s from "../../../components/experience.module.css";
import { demoEnabled, demoProject } from "../../../lib/content";
import Gallery from "../../../components/Gallery";
export default async function GalleryPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  if (!demoEnabled() || slug !== demoProject.slug) notFound();
  return (
    <main id="main" className={s.main}>
      <div className={s.eyebrow}>
        <Link href={`/projects/${slug}`}>← Project story</Link>
        <span>Development gallery / {String(demoProject.count).padStart(3, "0")} studies</span>
      </div>
      <h1 className={s.subhead}>{demoProject.title}</h1>
      <Gallery title={demoProject.title} />
      <p className={s.note}>
        Fixture artwork. Downloads and private gallery delivery are not
        available in this scaffold.
      </p>
    </main>
  );
}
