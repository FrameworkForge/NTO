"use client";
import Image from "next/image";
import { useCallback, useEffect, useRef, useState } from "react";
import { preload } from "react-dom";
import s from "./experience.module.css";
import { studies, studyCaptions } from "../lib/studies";

const IDLE_MS = 2500;
const SWIPE_PX = 48;

export default function Gallery({ title }: { title: string }) {
  const [active, setActive] = useState(0);
  const [idle, setIdle] = useState(false);
  const [open, setOpen] = useState(false);
  const dialog = useRef<HTMLDialogElement>(null);
  const trigger = useRef<HTMLButtonElement | null>(null);
  const idleTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pointerStart = useRef<number | null>(null);
  const swiped = useRef(false);
  const count = studies.length;
  const next = useCallback(() => setActive((v) => (v + 1) % count), [count]);
  const prev = useCallback(() => setActive((v) => (v + count - 1) % count), [count]);

  // Controls recede after a short idle period and return on any pointer, key or focus activity.
  const armIdle = useCallback(() => {
    if (idleTimer.current) clearTimeout(idleTimer.current);
    idleTimer.current = setTimeout(() => setIdle(true), IDLE_MS);
  }, []);
  const wake = useCallback(() => {
    setIdle(false);
    armIdle();
  }, [armIdle]);
  useEffect(() => {
    if (!open) return;
    armIdle();
    return () => {
      if (idleTimer.current) clearTimeout(idleTimer.current);
    };
  }, [open, armIdle]);

  const close = () => {
    dialog.current?.close();
    setOpen(false);
    setIdle(false);
    trigger.current?.focus();
  };
  // Neighbouring studies are preloaded so arrow and swipe navigation never waits on a fetch. React dedupes by URL.
  useEffect(() => {
    if (!open) return;
    for (const i of [(active + count - 1) % count, (active + 1) % count]) {
      if (i !== active) preload(studies[i], { as: "image" });
    }
  }, [open, active, count]);

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
              setOpen(true);
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
        data-idle={idle ? "true" : "false"}
        onCancel={(e) => {
          e.preventDefault();
          close();
        }}
        onKeyDown={(e) => {
          wake();
          if (e.key === "ArrowRight") next();
          if (e.key === "ArrowLeft") prev();
        }}
        onPointerMove={wake}
        onFocus={wake}
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
            <div
              className={s.viewerCanvas}
              onPointerDown={(e) => {
                pointerStart.current = e.clientX;
                swiped.current = false;
              }}
              onPointerUp={(e) => {
                if (pointerStart.current === null) return;
                const delta = e.clientX - pointerStart.current;
                pointerStart.current = null;
                if (Math.abs(delta) < SWIPE_PX) return;
                swiped.current = true;
                if (delta < 0) next();
                else prev();
              }}
              onPointerCancel={() => {
                pointerStart.current = null;
              }}
            >
              <Image
                key={active}
                className={s.viewerImage}
                src={studies[active]}
                width={1600}
                height={1000}
                alt={`Abstract development study ${active + 1}`}
                draggable={false}
                unoptimized
              />
              <button
                className={`${s.viewerZone} ${s.viewerZonePrev}`}
                aria-label="Previous study"
                onClick={() => {
                  if (!swiped.current) prev();
                }}
                tabIndex={-1}
              />
              <button
                className={`${s.viewerZone} ${s.viewerZoneNext}`}
                aria-label="Next study"
                onClick={() => {
                  if (!swiped.current) next();
                }}
                tabIndex={-1}
              />
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
