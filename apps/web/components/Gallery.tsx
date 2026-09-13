"use client";
import Image from "next/image";
import { useRef, useState } from "react";
import s from "./experience.module.css";
import { studies } from "../lib/studies";
export default function Gallery() {
  const [active, setActive] = useState(0);
  const dialog = useRef<HTMLDialogElement>(null);
  const trigger = useRef<HTMLButtonElement | null>(null);
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
          if (e.key === "ArrowRight")
            setActive((v) => (v + 1) % studies.length);
          if (e.key === "ArrowLeft")
            setActive((v) => (v + studies.length - 1) % studies.length);
        }}
      >
        <div className={s.viewerBody}>
          <div className={s.viewerHeader}>
            <span aria-live="polite">
              Study {active + 1} / {studies.length}
            </span>
            <div>
              <button
                aria-label="Previous study"
                onClick={() =>
                  setActive((v) => (v + studies.length - 1) % studies.length)
                }
              >
                ←
              </button>
              <button
                aria-label="Next study"
                onClick={() => setActive((v) => (v + 1) % studies.length)}
              >
                →
              </button>
              <button onClick={close}>Close</button>
            </div>
          </div>
          <Image
            className={s.viewerImage}
            src={studies[active]}
            width={1600}
            height={1000}
            alt={`Abstract development study ${active + 1}`}
            unoptimized
          />
        </div>
      </dialog>
    </>
  );
}
