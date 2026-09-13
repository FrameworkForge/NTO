import type { Metadata } from "next";
import Link from "next/link";
import "@nto/design-tokens/tokens.css";
import "./globals.css";
export const metadata: Metadata = {
  title: {
    default: "nto.motion — Photography. Software. Motion.",
    template: "%s — nto.motion",
  },
  description: "A space for photographs and the stories between them.",
};
export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" data-scroll-behavior="smooth">
      <body>
        <a className="skip" href="#main">
          Skip to photographs
        </a>
        <header>
          <Link className="wordmark" href="/" aria-label="NTO home">
            nto<span>.</span>
          </Link>
          <nav aria-label="Main navigation">
            <Link href="/#work">Selected work</Link>
            <span className="identity">Photography & motion</span>
          </nav>
        </header>
        {children}
        <footer>
          <span>NTO © 2026</span>
          <span>One photograph. One ecosystem.</span>
        </footer>
      </body>
    </html>
  );
}
