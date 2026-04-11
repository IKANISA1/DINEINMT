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

Deno.test(
  "buildMenuItemResearchPrompt requires evidence-bound descriptions",
  () => {
    const prompt = buildMenuItemResearchPrompt({
      item: {
        name: "Rolex",
        category: "Street food",
        description: "Chapati wrap",
        tags: ["uganda"],
        class: null,
        menu_context: null,
      },
      venueName: "Kampala Corner",
      venueCategory: "Restaurants",
      venueDescription: "East African casual dining",
    });

    assertStringIncludes(
      prompt,
      "Do not invent ingredients, origin stories, cooking methods, garnishes, serving vessels, side dishes, or locality claims",
    );
    assertStringIncludes(
      prompt,
      "If the evidence is weak, stay close to the input wording and lower confidence",
    );
    assertStringIncludes(
      prompt,
      "Do not turn a simple or everyday item into an upscale or fusion reinterpretation.",
    );
  },
);
