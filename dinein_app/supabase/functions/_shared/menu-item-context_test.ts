import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.208.0/assert/mod.ts";

import {
  buildMenuItemResearchPrompt,
  inferMenuItemClass,
} from "./menu-item-context.ts";

Deno.test("inferMenuItemClass treats brand-only spirits as drinks", () => {
  assertEquals(
    inferMenuItemClass({
      name: "Blue Label",
      category: "Whisky",
      description: "",
      tags: [],
      class: null,
      menu_context: null,
    }),
    "drinks",
  );

  assertEquals(
    inferMenuItemClass({
      name: "Bombay Sapphire",
      category: "Gin",
      description: "",
      tags: [],
      class: null,
      menu_context: null,
    }),
    "drinks",
  );
});

Deno.test(
  "buildMenuItemResearchPrompt keeps brand-only alcohol names in drinks guidance",
  () => {
    const prompt = buildMenuItemResearchPrompt({
      item: {
        name: "Red Label",
        category: "Whisky",
        description: "",
        tags: [],
        class: null,
        menu_context: null,
      },
      venueName: "Malta Lounge",
      venueCategory: "Bar",
      venueDescription: "Cocktails and spirits",
    });

    assertStringIncludes(prompt, 'class must be "drinks"');
    assertStringIncludes(prompt, '"Red Label"');
    assertStringIncludes(prompt, '"Bombay Sapphire"');
  },
);
