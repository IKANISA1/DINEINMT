import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";

import {
  extractMenuImagePromptClass,
  extractMenuImagePromptVisualKind,
  isMenuImagePromptCompatible,
  shouldRefreshMenuItemContext,
} from "./menu-image.ts";
import type { MenuItemResearchProfile } from "./menu-item-context.ts";

function makeProfile(
  itemClass: "food" | "drinks",
): MenuItemResearchProfile {
  return {
    class: itemClass,
    confidence: 0.9,
    canonical_name: itemClass === "drinks" ? "Drink" : "Dish",
    canonical_category: itemClass === "drinks" ? "Drinks" : "Food",
    canonical_description: "",
    visual_subject: "",
    serving_style: "",
    visual_directions: [],
    visual_do_not: [],
    keyword_signals: [],
    source_queries: [],
    source_urls: [],
    research_summary: "",
  };
}

Deno.test(
  "shouldRefreshMenuItemContext invalidates stale food profile for explicit drinks",
  () => {
    assertEquals(
      shouldRefreshMenuItemContext(
        {
          name: "Mojito",
          category: "Cocktails",
          description: "",
          tags: [],
          class: "drinks",
        },
        makeProfile("food"),
      ),
      true,
    );
  },
);

Deno.test(
  "shouldRefreshMenuItemContext invalidates stale food profile for strong drink signals",
  () => {
    assertEquals(
      shouldRefreshMenuItemContext(
        {
          name: "Blue Label",
          category: "Whisky",
          description: "",
          tags: [],
          class: null,
        },
        makeProfile("food"),
      ),
      true,
    );
  },
);

Deno.test("menu image prompt compatibility requires matching class and kind", () => {
  const drinkPrompt = `
This item is classified as: drinks
Visual kind: spirits
Resolved class: drinks
`.trim();

  const foodPrompt = `
This item is classified as: food
Visual kind: plated_food
Resolved class: food
`.trim();

  assertEquals(extractMenuImagePromptClass(drinkPrompt), "drinks");
  assertEquals(extractMenuImagePromptVisualKind(drinkPrompt), "spirits");
  assertEquals(
    isMenuImagePromptCompatible(drinkPrompt, {
      itemClass: "drinks",
      visualKind: "spirits",
    }),
    true,
  );
  assertEquals(
    isMenuImagePromptCompatible(foodPrompt, {
      itemClass: "drinks",
      visualKind: "spirits",
    }),
    false,
  );
});
