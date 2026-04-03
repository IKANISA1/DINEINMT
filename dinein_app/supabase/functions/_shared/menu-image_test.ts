import { assertEquals } from "https://deno.land/std@0.208.0/assert/mod.ts";

import {
  auditRegenerationBlockedReason,
  classifyMenuVisualKind,
  extractMenuImagePromptClass,
  extractMenuImagePromptVisualKind,
  isMenuImagePromptCompatible,
  shouldRefreshMenuItemContext,
  shouldRegenerateAuditedMenuImage,
} from "./menu-image.ts";
import type { MenuItemResearchProfile } from "./menu-item-context.ts";

const venue = {
  id: "venue-1",
  name: "Test Venue",
  category: "bar",
  description: "Cocktails and spirits",
  owner_id: null,
  phone: null,
  owner_contact_phone: null,
  owner_whatsapp_number: null,
};

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

Deno.test("menu image prompt compatibility accepts the production BEVERAGE / DRINK header", () => {
  const productionStylePrompt = `
This item is classified as: BEVERAGE / DRINK
Visual kind: tea
`;

  assertEquals(
    isMenuImagePromptCompatible(productionStylePrompt, {
      itemClass: "drinks",
      visualKind: "tea",
    }),
    true,
  );
});

Deno.test("classifyMenuVisualKind routes coffee drinks to coffee instead of beer", () => {
  assertEquals(
    classifyMenuVisualKind(
      {
        id: "item-1",
        venue_id: "venue-1",
        name: "Iced Coffee",
        description: "Cold brew over ice",
        category: "Coffees & Teas",
        class: "drinks",
        menu_context: null,
        menu_context_status: "ready",
        menu_context_error: null,
        menu_context_model: null,
        menu_context_attempts: 0,
        menu_context_locked: false,
        menu_context_updated_at: null,
        image_url: null,
        image_source: null,
        image_status: "pending",
        image_model: null,
        image_prompt: null,
        image_error: null,
        image_attempts: 0,
        image_locked: false,
        image_storage_path: null,
        tags: [],
      },
      venue,
      "drinks",
      null,
    ),
    "coffee",
  );
});

Deno.test("classifyMenuVisualKind keeps espresso-shot language in the coffee branch", () => {
  assertEquals(
    classifyMenuVisualKind(
      {
        id: "item-1b",
        venue_id: "venue-1",
        name: "Latte",
        description: "Classic latte",
        category: "Coffees & Teas",
        class: "drinks",
        menu_context: null,
        menu_context_status: "ready",
        menu_context_error: null,
        menu_context_model: null,
        menu_context_attempts: 0,
        menu_context_locked: false,
        menu_context_updated_at: null,
        image_url: null,
        image_source: null,
        image_status: "pending",
        image_model: null,
        image_prompt: null,
        image_error: null,
        image_attempts: 0,
        image_locked: false,
        image_storage_path: null,
        tags: [],
      },
      venue,
      "drinks",
      {
        canonical_name: "Latte",
        canonical_category: "Coffee",
        canonical_description:
          "A classic espresso-based beverage prepared with a shot of rich espresso and steamed milk.",
        visual_subject: "a hot cafe latte with latte art",
        serving_style:
          "Served in a tall clear glass or a classic white ceramic mug on a saucer.",
        research_summary: "A standard milk-based coffee drink.",
        source_queries: [],
        source_urls: [],
        keyword_signals: ["espresso", "latte art", "milk coffee"],
        visual_directions: [],
        visual_do_not: [],
        class: "drinks",
        confidence: 1,
      },
    ),
    "coffee",
  );
});

Deno.test("classifyMenuVisualKind keeps herbal tea in the tea branch for mixed coffee/tea categories", () => {
  assertEquals(
    classifyMenuVisualKind(
      {
        id: "item-1c",
        venue_id: "venue-1",
        name: "Homemade Ginger, Honey, Lemon & Mint Tea",
        description: "Hot herbal infusion",
        category: "Coffees & Teas",
        class: "drinks",
        menu_context: null,
        menu_context_status: "ready",
        menu_context_error: null,
        menu_context_model: null,
        menu_context_attempts: 0,
        menu_context_locked: false,
        menu_context_updated_at: null,
        image_url: null,
        image_source: null,
        image_status: "pending",
        image_model: null,
        image_prompt: null,
        image_error: null,
        image_attempts: 0,
        image_locked: false,
        image_storage_path: null,
        tags: [],
      },
      venue,
      "drinks",
      {
        canonical_name: "Homemade Ginger, Honey, Lemon & Mint Tea",
        canonical_category: "Herbal Teas",
        canonical_description:
          "A soothing hot herbal infusion prepared with fresh ginger root, lemon slices, honey, and mint.",
        visual_subject:
          "a glass mug of hot herbal tea with fresh lemon slices, ginger pieces, and mint sprigs",
        serving_style: "served hot in a transparent glass mug on a saucer",
        research_summary: "A caffeine-free tea alternative.",
        source_queries: [],
        source_urls: [],
        keyword_signals: ["herbal tea", "infusion", "hot beverage"],
        visual_directions: [],
        visual_do_not: [],
        class: "drinks",
        confidence: 1,
      },
    ),
    "tea",
  );
});

Deno.test("classifyMenuVisualKind keeps beer items in the beer branch", () => {
  assertEquals(
    classifyMenuVisualKind(
      {
        id: "item-2",
        venue_id: "venue-1",
        name: "Moretti",
        description: "Italian lager",
        category: "Bottled Beer & Ciders",
        class: "drinks",
        menu_context: null,
        menu_context_status: "ready",
        menu_context_error: null,
        menu_context_model: null,
        menu_context_attempts: 0,
        menu_context_locked: false,
        menu_context_updated_at: null,
        image_url: null,
        image_source: null,
        image_status: "pending",
        image_model: null,
        image_prompt: null,
        image_error: null,
        image_attempts: 0,
        image_locked: false,
        image_storage_path: null,
        tags: [],
      },
      venue,
      "drinks",
      null,
    ),
    "packaged_beer",
  );
});

Deno.test("classifyMenuVisualKind keeps bottled ales packaged despite pint-glass context", () => {
  assertEquals(
    classifyMenuVisualKind(
      {
        id: "item-3",
        venue_id: "venue-1",
        name: "Hobgoblin Ruby Beer",
        description: "Ruby ale served in a pint glass with the 500ml bottle",
        category: "Bottled Beer & Ciders",
        class: "drinks",
        menu_context: null,
        menu_context_status: "ready",
        menu_context_error: null,
        menu_context_model: null,
        menu_context_attempts: 0,
        menu_context_locked: false,
        menu_context_updated_at: null,
        image_url: null,
        image_source: null,
        image_status: "pending",
        image_model: null,
        image_prompt: null,
        image_error: null,
        image_attempts: 0,
        image_locked: false,
        image_storage_path: null,
        tags: [],
      },
      venue,
      "drinks",
      {
        canonical_name: "Hobgoblin Ruby Beer",
        canonical_category: "Ruby Ale",
        canonical_description:
          "A bottled English ruby ale with chocolate malt and a creamy head.",
        visual_subject:
          "a glass of deep ruby ale beside the iconic illustrated 500ml bottle",
        serving_style:
          "served in a traditional pint glass or tankard with the bottle nearby",
        research_summary: "Best presented as a bottled ruby ale.",
        source_queries: [],
        source_urls: [],
        keyword_signals: ["bottled beer", "ruby ale"],
        visual_directions: [],
        visual_do_not: [],
        class: "drinks",
        confidence: 1,
      },
    ),
    "packaged_beer",
  );
});

Deno.test("classifyMenuVisualKind keeps true tap beer in the draft branch", () => {
  assertEquals(
    classifyMenuVisualKind(
      {
        id: "item-4",
        venue_id: "venue-1",
        name: "Cisk Lager",
        description: "Fresh draught lager",
        category: "Draft Beer",
        class: "drinks",
        menu_context: null,
        menu_context_status: "ready",
        menu_context_error: null,
        menu_context_model: null,
        menu_context_attempts: 0,
        menu_context_locked: false,
        menu_context_updated_at: null,
        image_url: null,
        image_source: null,
        image_status: "pending",
        image_model: null,
        image_prompt: null,
        image_error: null,
        image_attempts: 0,
        image_locked: false,
        image_storage_path: null,
        tags: [],
      },
      venue,
      "drinks",
      {
        canonical_name: "Cisk Lager",
        canonical_category: "Beer",
        canonical_description: "A crisp lager poured from the tap.",
        visual_subject: "a freshly poured draught lager with a stable white head",
        serving_style: "served on tap in a chilled pint glass",
        research_summary: "A classic draught lager.",
        source_queries: [],
        source_urls: [],
        keyword_signals: ["draught beer", "on tap"],
        visual_directions: [],
        visual_do_not: [],
        class: "drinks",
        confidence: 1,
      },
    ),
    "draft_beer",
  );
});

Deno.test("classifyMenuVisualKind treats shandy as a mixed drink instead of packaged beer", () => {
  assertEquals(
    classifyMenuVisualKind(
      {
        id: "item-5",
        venue_id: "venue-1",
        name: "Shandy",
        description: "Lager and lemonade",
        category: "Bottled Beer & Ciders",
        class: "drinks",
        menu_context: null,
        menu_context_status: "ready",
        menu_context_error: null,
        menu_context_model: null,
        menu_context_attempts: 0,
        menu_context_locked: false,
        menu_context_updated_at: null,
        image_url: null,
        image_source: null,
        image_status: "pending",
        image_model: null,
        image_prompt: null,
        image_error: null,
        image_attempts: 0,
        image_locked: false,
        image_storage_path: null,
        tags: [],
      },
      venue,
      "drinks",
      {
        canonical_name: "Shandy",
        canonical_category: "Beer Cocktails",
        canonical_description:
          "A refreshing beer-based mixed drink combining lager and lemonade.",
        visual_subject: "a chilled shandy in a tall glass with a lemon wedge",
        serving_style: "served in a tall pilsner glass",
        research_summary: "A classic beer cocktail.",
        source_queries: [],
        source_urls: [],
        keyword_signals: ["shandy", "beer cocktail", "lager and lemonade"],
        visual_directions: [],
        visual_do_not: [],
        class: "drinks",
        confidence: 1,
      },
    ),
    "cocktail",
  );
});

Deno.test("classifyMenuVisualKind keeps bottled radlers in the packaged beer branch", () => {
  assertEquals(
    classifyMenuVisualKind(
      {
        id: "item-5b",
        venue_id: "venue-1",
        name: "Chill Lemon",
        description: "Lemon-flavored lager",
        category: "Bottled Beer & Ciders",
        class: "drinks",
        menu_context: null,
        menu_context_status: "ready",
        menu_context_error: null,
        menu_context_model: null,
        menu_context_attempts: 0,
        menu_context_locked: false,
        menu_context_updated_at: null,
        image_url: null,
        image_source: null,
        image_status: "pending",
        image_model: null,
        image_prompt: null,
        image_error: null,
        image_attempts: 0,
        image_locked: false,
        image_storage_path: null,
        tags: [],
      },
      venue,
      "drinks",
      {
        canonical_name: "Cisk Chill Lemon",
        canonical_category: "Radler",
        canonical_description:
          "A refreshing lemon-flavored lager packaged in a clear glass bottle.",
        visual_subject: "a clear bottle of lemon-flavored lager beer",
        serving_style:
          "served chilled in a 25cl or 33cl clear glass bottle with a lemon wedge",
        research_summary: "A packaged Maltese radler.",
        source_queries: [],
        source_urls: [],
        keyword_signals: ["radler", "bottled beer", "clear glass bottle"],
        visual_directions: [],
        visual_do_not: [],
        class: "drinks",
        confidence: 1,
      },
    ),
    "packaged_beer",
  );
});

Deno.test("classifyMenuVisualKind keeps small seasonal pours in the draft branch unless packaged is explicit", () => {
  assertEquals(
    classifyMenuVisualKind(
      {
        id: "item-6",
        venue_id: "venue-1",
        name: "Seasonal Beer Small",
        description: "Small craft beer pour",
        category: "Craft & Seasonal Beer",
        class: "drinks",
        menu_context: null,
        menu_context_status: "ready",
        menu_context_error: null,
        menu_context_model: null,
        menu_context_attempts: 0,
        menu_context_locked: false,
        menu_context_updated_at: null,
        image_url: null,
        image_source: null,
        image_status: "pending",
        image_model: null,
        image_prompt: null,
        image_error: null,
        image_attempts: 0,
        image_locked: false,
        image_storage_path: null,
        tags: [],
      },
      venue,
      "drinks",
      {
        canonical_name: "Seasonal Craft Beer (Small)",
        canonical_category: "Beer",
        canonical_description:
          "A small serving of seasonal craft beer poured from a tap or bottle into a 250ml to 330ml glass.",
        visual_subject:
          "a small elegant glass of chilled golden craft beer with a thin frothy white head",
        serving_style:
          "served in a small stemmed tulip glass or a half-pint glass",
        research_summary: "A refined small-pour seasonal beer.",
        source_queries: [],
        source_urls: [],
        keyword_signals: ["beer", "craft beer", "seasonal", "half pint", "draught"],
        visual_directions: [],
        visual_do_not: [],
        class: "drinks",
        confidence: 1,
      },
    ),
    "draft_beer",
  );
});

Deno.test("audit regeneration ignores prompt metadata warnings", () => {
  assertEquals(
    shouldRegenerateAuditedMenuImage([
      {
        code: "image_prompt_metadata_stale",
        severity: "warning",
        message: "Prompt metadata is stale.",
      },
    ]),
    false,
  );
});

Deno.test("audit regeneration requires repair for image verifier mismatches", () => {
  assertEquals(
    shouldRegenerateAuditedMenuImage([
      {
        code: "image_verification_mismatch",
        severity: "error",
        message: "Observed food for a drink item.",
      },
    ]),
    true,
  );
});

Deno.test("audit regeneration blocks manual image repair unless explicitly enabled", () => {
  assertEquals(
    auditRegenerationBlockedReason({
      needsRegeneration: true,
      imageLocked: false,
      imageSource: "manual",
      regenerateManual: false,
    }),
    "manual_image_requires_override",
  );
  assertEquals(
    auditRegenerationBlockedReason({
      needsRegeneration: true,
      imageLocked: true,
      imageSource: "ai_gemini",
      regenerateManual: true,
    }),
    "image_locked",
  );
  assertEquals(
    auditRegenerationBlockedReason({
      needsRegeneration: true,
      imageLocked: false,
      imageSource: "ai_gemini",
      regenerateManual: false,
    }),
    null,
  );
});
