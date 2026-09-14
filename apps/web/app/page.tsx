import Image from "next/image";
import Link from "next/link";
import s from "../components/experience.module.css";
import { EmptyState } from "../components/State";
import { demoEnabled, pipeline, projects, studies } from "../lib/content";
export default function Home() {
  const demo = demoEnabled();
  const work = projects();
  const marquee = (
    <>
      <span>Photography</span>
      <span aria-hidden="true">·</span>
      <span>Software</span>
      <span aria-hidden="true">·</span>
      <span>Motion</span>
      <span aria-hidden="true">·</span>
      <span>Shoot → Import → Cull → Edit → Publish → Sell → Deliver</span>
      <span aria-hidden="true">·</span>
    </>
  );
  return (
    <main id="main">
      <section className={s.hero} id="top">
        {demo && (
          <div className={s.heroMedia} aria-hidden="true">
            <Image
              className={s.heroImage}
              src={studies[0]}
              width={1600}
              height={1000}
              alt=""
              preload
              unoptimized
            />
          </div>
        )}
        <div className={`${s.eyebrow} ${s.heroEyebrow}`}>
          <span>nto.motion / Selected perspectives</span>
          <span>01 — 2026</span>
        </div>
        <h1 className={s.heroTitle}>
          <span className={s.unmask}>The space</span>
          <span className={`${s.unmask} ${s.unmaskLate}`}>between.</span>
        </h1>
        <div className={s.heroIntro}>
          <p>
            Photography. Software. Motion.
            <br />A place for the work to speak.
          </p>
          <a href="#work">
            Explore selected work{" "}
            <span className={s.cue} aria-hidden="true">
              ↓
            </span>
          </a>
        </div>
      </section>

      <div className={s.marquee} aria-hidden="true">
        <div className={s.marqueeTrack}>
          {marquee}
          {marquee}
        </div>
      </div>

      <section id="work" className={s.workHeader}>
        <div className={s.sectionTitle}>
          <h2>Selected work</h2>
          <span>
            {work.length === 0
              ? "A space in progress"
              : `${String(work.length).padStart(3, "0")} project${work.length === 1 ? "" : "s"}`}
          </span>
        </div>
        {work.length === 0 && (
          <EmptyState title="The work begins here.">
            Projects will appear here when they are ready to be shared.
          </EmptyState>
        )}
      </section>

      {work.map((project, i) => (
        <section className={s.project} key={project.id} aria-labelledby={`project-${project.slug}`}>
          <div className={s.projectMedia} aria-hidden="true">
            <Image
              className={s.projectImage}
              src={project.cover}
              width={1600}
              height={1000}
              alt=""
              unoptimized
            />
          </div>
          <div className={s.projectBody}>
            <div className={s.eyebrow}>
              <span>{project.kicker}</span>
              <span>{project.year}</span>
            </div>
            <div className={s.projectFoot}>
              <div className={s.projectText}>
                <Link
                  className={s.projectLink}
                  href={`/projects/${project.slug}`}
                  aria-label={`0${i + 1} / ${project.title}`}
                >
                  <span className={s.projectIndex} aria-hidden="true">
                    0{i + 1}
                  </span>
                  <h3 id={`project-${project.slug}`}>{project.title}</h3>
                </Link>
                <p>{project.description}</p>
              </div>
              <div className={s.projectActions}>
                <span className={s.eyebrow}>
                  {String(project.count).padStart(3, "0")} photographs
                </span>
                <Link className={s.enter} href={`/galleries/${project.slug}`}>
                  Enter gallery ↗
                </Link>
              </div>
            </div>
          </div>
        </section>
      ))}

      <section id="studio" className={s.studio}>
        <div className={s.studioText}>
          <span className={s.eyebrow}>NTO Studio · macOS</span>
          <h2>
            One photograph.
            <br />
            One ecosystem.
          </h2>
          <p>
            A native, local-first workflow. You own your originals, your
            catalogue, your edits, your presets and your exports. No account, no
            subscription, no upload required.
          </p>
        </div>
        <ol className={s.pipeline} aria-label="The NTO workflow and what exists today">
          {pipeline.map((step, i) => (
            <li key={step.name}>
              <span className={s.pipelineIndex}>0{i + 1}</span>
              <span className={s.pipelineName}>{step.name}</span>
              <span className={s.pipelineState}>{step.state}</span>
            </li>
          ))}
        </ol>
      </section>

      <section className={s.closing}>
        {demo && (
          <Image
            className={s.closingImage}
            src={studies[2]}
            width={1600}
            height={1000}
            alt=""
            aria-hidden="true"
            unoptimized
          />
        )}
        <div className={s.closingBody}>
          <h2>
            A place for the
            <br />
            work to speak.
          </h2>
          <a href="#work">Back to the work ↑</a>
        </div>
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
