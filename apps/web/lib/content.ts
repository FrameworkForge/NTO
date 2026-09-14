import fixture from "@nto/shared-types/fixtures";
import { studies } from "./studies";
export const demoEnabled = () => process.env.NTO_DEMO === "1";
export interface ProjectCard {
  id: string;
  slug: string;
  title: string;
  description: string;
  kicker: string;
  year: string;
  count: number;
  cover: string;
}
export const demoProject: ProjectCard = {
  id: fixture.projects[0].id,
  slug: "studies-in-light",
  title: fixture.projects[0].title,
  description:
    "A study of form, contrast, and the space a photograph leaves behind.",
  kicker: "Study / Series",
  year: "2026",
  count: studies.length,
  cover: studies[0],
};
/** The projects shown on the landing page: the fixture project under NTO_DEMO, otherwise none. */
export const projects = (): ProjectCard[] => (demoEnabled() ? [demoProject] : []);
export const pipeline: { name: string; state: string }[] = [
  { name: "Shoot", state: "Yours" },
  { name: "Import", state: "Studio" },
  { name: "Cull", state: "Studio" },
  { name: "Edit", state: "Studio" },
  { name: "Publish", state: "Coming" },
  { name: "Sell", state: "Later" },
  { name: "Deliver", state: "Later" },
];
export { studies, studyCaptions } from "./studies";
