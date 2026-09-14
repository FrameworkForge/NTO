"use client";
import Image from "next/image";
import { useRef, useState } from "react";
import s from "./experience.module.css";
import { studies, studyCaptions } from "../lib/studies";
export default function Gallery({ title }: { title: string }) {
  const [active, setActive] = useState(0);
  const dialog = useRef<HTMLDialogElement>(null);
  const trigger = useRef<HTMLButtonElement | null>(null);
  const count = studies.length;
  const next = () => setActive((v) => (v + 1) % count);
  const prev = () => setActive((v) => (v + count - 1) % count);
  const close = () => {
    dialog.current?.close();
    trigger.current?.focus();
  };
  return (
    <>
      <div className={s.grid}>
        {studies.map((src, i) => (
          <button
            className={s.tile}
            key={src}
            aria-label={`Open study ${i + 1}`}
            onClick={(e) => {
              trigger.current = e.currentTarget;
              setActive(i);
              dialog.current?.showModal();
            }}
          >
            <Image
              className={s.image}
              src={src}
              width={1600}
              height={1000}
              alt={`Abstract monochrome development study ${i + 1}`}
              unoptimized
            />
          </button>
        ))}
      </div>
      <dialog
        ref={dialog}
        className={s.viewer}
        aria-label="Study viewer"
        onCancel={close}
        onKeyDown={(e) => {
          if (e.key === "ArrowRight") next();
          if (e.key === "ArrowLeft") prev();
        }}
      >
        <div className={s.viewerBody}>
          <nav className={s.viewerRail} aria-label="Studies">
            <span className={s.viewerMark} aria-hidden="true">
              nto<span>.</span>
            </span>
            <ol className={s.viewerIndex}>
              {studies.map((src, i) => (
                <li key={src}>
                  <button
                    className={i === active ? s.viewerIndexActive : undefined}
                    aria-label={`Study ${i + 1}`}
                    aria-current={i === active ? "true" : undefined}
                    onClick={() => setActive(i)}
                  >
                    {String(i + 1).padStart(2, "0")}
                  </button>
                </li>
              ))}
            </ol>
            <span className={s.viewerKeys} aria-hidden="true">
              ← →<br />
              ESC
            </span>
          </nav>
          <div className={s.viewerStage}>
            <div className={s.viewerHeader}>
              <span className={s.viewerTitle}>{title} · gallery</span>
              <span aria-live="polite">
                Study {active + 1} / {count}
              </span>
              <div className={s.viewerControls}>
                <button aria-label="Previous study" onClick={prev}>
                  ←
                </button>
                <button aria-label="Next study" onClick={next}>
                  →
                </button>
                <button onClick={close} autoFocus>
                  Close
                </button>
              </div>
            </div>
            <div className={s.viewerCanvas}>
              <Image
                key={active}
                className={s.viewerImage}
                src={studies[active]}
                width={1600}
                height={1000}
                alt={`Abstract development study ${active + 1}`}
                unoptimized
              />
              <button className={`${s.viewerZone} ${s.viewerZonePrev}`} aria-label="Previous study" onClick={prev} tabIndex={-1} />
              <button className={`${s.viewerZone} ${s.viewerZoneNext}`} aria-label="Next study" onClick={next} tabIndex={-1} />
            </div>
            <div className={s.viewerFoot}>
              <p className={s.viewerCaption}>{studyCaptions[active]}</p>
              <span className={s.viewerMeta}>Development artwork · no camera data</span>
            </div>
            <div className={s.viewerProgress} aria-hidden="true">
              <div style={{ width: `${((active + 1) / count) * 100}%` }} />
            </div>
          </div>
        </div>
      </dialog>
    </>
  );
}
