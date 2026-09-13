import fixture from "@nto/shared-types/fixtures";
export const demoEnabled = () => process.env.NTO_DEMO === "1";
export const demoProject = {
  ...fixture.projects[0],
  slug: "studies-in-light",
  description:
    "A study of form, contrast, and the space a photograph leaves behind.",
};
export { studies } from "./studies";
