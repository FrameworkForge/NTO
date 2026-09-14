import { test, expect } from "@playwright/test";
test("portfolio, story, and gallery are navigable", async ({ page }) => {
  await page.goto("/");
  await expect(
    page.getByRole("heading", { name: "The space between." }),
  ).toBeVisible();
  await expect(page.getByRole("list", { name: /NTO workflow/ }).getByRole("listitem")).toHaveCount(7);
  await page.getByRole("link", { name: /01 \/ Studies/ }).click();
  await expect(
    page.getByRole("heading", { name: "Studies in light" }),
  ).toBeVisible();
  await page.getByRole("link", { name: "Enter gallery" }).click();
  await page.getByRole("button", { name: "Open study 1" }).click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await page.keyboard.press("ArrowRight");
  await expect(page.getByText("Study 2 / 3")).toBeVisible();
  await page.getByRole("dialog").getByRole("button", { name: "Study 3" }).click();
  await expect(page.getByText("Study 3 / 3")).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(page.getByRole("dialog")).not.toBeVisible();
  await expect(
    page.getByRole("button", { name: "Open study 1" }),
  ).toBeFocused();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
});
test("keyboard, reduced motion, and missing routes", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");
  await page.keyboard.press("Tab");
  await expect(
    page.getByRole("link", { name: "Skip to photographs" }),
  ).toBeFocused();
  expect(
    await page.evaluate(
      () => getComputedStyle(document.documentElement).scrollBehavior,
    ),
  ).toBe("auto");
  await page.goto("/projects/missing");
  await expect(
    page.getByRole("heading", { name: "This work isn’t here." }),
  ).toBeVisible();
});
