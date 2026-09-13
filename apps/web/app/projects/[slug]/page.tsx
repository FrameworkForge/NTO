import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import s from "../../../components/experience.module.css";
import { demoEnabled, demoProject, studies } from "../../../lib/content";
export default async function Story({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  if (!demoEnabled() || slug !== demoProject.slug) notFound();
  return (
    <main id="main" className={s.main}>
      <div className={s.eyebrow}>
        <Link href="/#work">← Selected work</Link>
        <span>Study / 2026</span>
      </div>
      <h1 className={s.subhead}>{demoProject.title}</h1>
      <div className={s.intro}>
        <p>{demoProject.description}</p>
        <Link href={`/galleries/${slug}`}>Enter gallery ↗</Link>
      </div>
      {studies.map((src, i) => (
        <figure className={s.figure} key={src}>
          <Image
            className={s.image}
            src={src}
            width={1600}
            height={1000}
            alt={`Abstract development study ${i + 1}: monochrome form and light`}
            unoptimized
          />
          <figcaption className={s.caption}>
            0{i + 1} / Development artwork
          </figcaption>
        </figure>
      ))}
      <p className={s.note}>
        Fixture project. Publishing from Studio is a later milestone.
      </p>
    </main>
  );
}
