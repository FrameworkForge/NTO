import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import s from "../../../components/experience.module.css";
import { demoEnabled, demoProject, studies, studyCaptions } from "../../../lib/content";
export default async function Story({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  if (!demoEnabled() || slug !== demoProject.slug) notFound();
  return (
    <main id="main">
      <section className={s.storyHero}>
        <div className={s.heroMedia} aria-hidden="true">
          <Image className={s.heroImage} src={demoProject.cover} width={1600} height={1000} alt="" preload unoptimized />
        </div>
        <div className={`${s.eyebrow} ${s.heroEyebrow}`}>
          <Link href="/#work">← Selected work</Link>
          <span>
            {demoProject.kicker} / {demoProject.year}
          </span>
        </div>
        <h1 className={s.storyTitle}>{demoProject.title}</h1>
        <div className={s.heroIntro}>
          <p>{demoProject.description}</p>
          <Link href={`/galleries/${slug}`}>Enter gallery ↗</Link>
        </div>
      </section>
      <div className={s.story}>
        {studies.map((src, i) => (
          <figure className={`${s.figure} ${i % 3 === 1 ? s.figureNarrow : ""}`} key={src}>
            <Image
              className={s.image}
              src={src}
              width={1600}
              height={1000}
              alt={`Abstract development study ${i + 1}: monochrome form and light`}
              unoptimized
            />
            <figcaption className={s.caption}>
              <span>0{i + 1} / Development artwork</span>
              <span>{studyCaptions[i]}</span>
            </figcaption>
          </figure>
        ))}
        <p className={s.note}>
          Fixture project. Publishing from Studio is a later milestone.
        </p>
      </div>
    </main>
  );
}
