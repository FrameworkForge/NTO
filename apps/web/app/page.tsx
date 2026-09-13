import Image from "next/image";
import Link from "next/link";
import s from "../components/experience.module.css";
import { EmptyState } from "../components/State";
import { demoEnabled, demoProject } from "../lib/content";
export default function Home() {
  const demo = demoEnabled();
  return (
    <main id="main" className={s.main}>
      <div className={s.eyebrow}>
        <span>nto.motion / Selected perspectives</span>
        <span>01 — 2026</span>
      </div>
      <h1 className={s.title}>
        The space
        <br />
        between.
      </h1>
      <div className={s.intro}>
        <p>
          Photography. Software. Motion.
          <br />A place for the work to speak.
        </p>
        <a href="#work">Explore selected work ↘</a>
      </div>
      {demo && (
        <>
          <figure className={s.figure}>
            <Image
              className={s.image}
              src="/fixtures/study-01.svg"
              width={1600}
              height={1000}
              alt="Development study: a pale circular form suspended over dark architectural planes"
              preload
              unoptimized
            />
          </figure>
          <div className={s.caption}>
            <span>Studies in light</span>
            <span>Development artwork / 01</span>
          </div>
        </>
      )}
      <section id="work" className={s.section}>
        <div className={s.sectionTitle}>
          <h2>Selected work</h2>
          <span>{demo ? "001 project" : "A space in progress"}</span>
        </div>
        {demo ? (
          <Link className={s.card} href={`/projects/${demoProject.slug}`}>
            <figure className={s.figure}>
              <Image
                className={s.image}
                src="/fixtures/study-02.svg"
                width={1600}
                height={1000}
                alt="Development study in light and shadow"
                unoptimized
              />
            </figure>
            <div className={s.caption}>
              <span>01 / {demoProject.title}</span>
              <span>View story ↗</span>
            </div>
          </Link>
        ) : (
          <EmptyState title="The work begins here.">
            Projects will appear here when they are ready to be shared.
          </EmptyState>
        )}
      </section>
      {demo && (
        <p className={s.note}>
          Development preview. These abstract studies are fixture artwork, not
          published photographs.
        </p>
      )}
    </main>
  );
}
