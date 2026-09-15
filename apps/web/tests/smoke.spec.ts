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
  // Neighbour preloads land in the document head via React's preload API.
  await expect(page.locator('head link[rel=preload][as=image][href$="study-02.svg"]').first()).toBeAttached();
  await expect(page.locator('head link[rel=preload][as=image][href$="study-01.svg"]').first()).toBeAttached();
  const canvas = page.getByRole("dialog").getByRole("img");
  const box = await canvas.boundingBox();
  if (!box) throw new Error("viewer image not laid out");
  await page.mouse.move(box.x + box.width * 0.7, box.y + box.height / 2);
  await page.mouse.down();
  await page.mouse.move(box.x + box.width * 0.3, box.y + box.height / 2, { steps: 6 });
  await page.mouse.up();
  await expect(page.getByText("Study 1 / 3")).toBeVisible();
  await expect(page.getByRole("dialog")).toHaveAttribute("data-idle", "false");
  await page.waitForTimeout(3000);
  await expect(page.getByRole("dialog")).toHaveAttribute("data-idle", "true");
  await page.mouse.move(box.x + 10, box.y + 10);
  await expect(page.getByRole("dialog")).toHaveAttribute("data-idle", "false");
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
