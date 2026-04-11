export type MenuItemClass = "food" | "drinks";

export type Json = Record<string, unknown>;

export type MenuVisualKind =
  | "plated_food"
  | "dessert"
  | "packaged_beer"
  | "draft_beer"
  | "cocktail"
  | "wine"
  | "spirits"
  | "coffee"
  | "tea"
  | "soft_drink";

export interface MenuItemSignalRecord {
  name: string | null;
  category: string | null;
  description: string | null;
  tags?: string[] | null;
  class?: string | null;
  menu_context?: unknown;
}

export interface MenuItemResearchProfile {
  class: MenuItemClass;
  confidence: number;
  canonical_name: string;
  canonical_category: string;
  canonical_description: string;
  visual_subject: string;
  serving_style: string;
  visual_directions: string[];
  visual_do_not: string[];
  keyword_signals: string[];
  source_queries: string[];
  source_urls: string[];
  research_summary: string;
}

export interface MenuItemResearchContext {
  class: string | null;
  menu_context: unknown | null;
  menu_context_status: string | null;
  menu_context_error: string | null;
  menu_context_model: string | null;
  menu_context_attempts: number | null;
  menu_context_locked: boolean | null;
  menu_context_updated_at: string | null;
}

export const menuItemResearchSchema = {
  type: "object",
  properties: {
    class: {
      type: "string",
      enum: ["food", "drinks"],
    },
    confidence: {
      type: "number",
    },
    canonical_name: {
      type: "string",
    },
    canonical_category: {
      type: "string",
    },
    canonical_description: {
      type: "string",
    },
    visual_subject: {
      type: "string",
    },
    serving_style: {
      type: "string",
    },
    visual_directions: {
      type: "array",
      items: {
        type: "string",
      },
    },
    visual_do_not: {
      type: "array",
      items: {
        type: "string",
      },
    },
    keyword_signals: {
      type: "array",
      items: {
        type: "string",
      },
    },
    source_queries: {
      type: "array",
      items: {
        type: "string",
      },
    },
    source_urls: {
      type: "array",
      items: {
        type: "string",
      },
    },
    research_summary: {
      type: "string",
    },
  },
  required: [
    "class",
    "confidence",
    "canonical_name",
    "canonical_category",
    "canonical_description",
    "visual_subject",
    "serving_style",
    "visual_directions",
    "visual_do_not",
    "keyword_signals",
    "source_queries",
    "source_urls",
    "research_summary",
  ],
} as const;

const foodCategoryPrefixes = [
  "main",
  "mains",
  "starter",
  "starters",
  "appetizer",
  "appetizers",
  "salad",
  "salads",
  "soup",
  "soups",
  "sandwich",
  "sandwiches",
  "wrap",
  "wraps",
  "burger",
  "burgers",
  "pizza",
  "pasta",
  "grill",
  "bbq",
  "barbecue",
  "seafood",
  "fish",
  "dessert",
  "desserts",
  "pastry",
  "pastries",
  "bakery",
  "breakfast",
  "brunch",
  "lunch",
  "dinner",
  "sides",
  "side",
  "bowls",
  "bowls and salads",
  "noodles",
  "rice",
];

const drinkCategoryPrefixes = [
  "drink",
  "drinks",
  "beverage",
  "beverages",
  "hot drink",
  "hot drinks",
  "cold drink",
  "cold drinks",
  "wine",
  "wines",
  "beer",
  "beers",
  "lager",
  "lagers",
  "ale",
  "ales",
  "stout",
  "stouts",
  "porter",
  "porters",
  "cider",
  "ciders",
  "cocktail",
  "cocktails",
  "mocktail",
  "mocktails",
  "spirits",
  "spirit",
  "liquor",
  "liquors",
  "liqueur",
  "liqueurs",
  "whisky",
  "whiskey",
  "scotch",
  "bourbon",
  "single malt",
  "vodka",
  "gin",
  "rum",
  "tequila",
  "mezcal",
  "brandy",
  "cognac",
  "aperitif",
  "aperitifs",
  "digestif",
  "digestifs",
  "shot",
  "shots",
  "shooter",
  "shooters",
  "soft drink",
  "soft drinks",
  "soda",
  "sodas",
  "coffee",
  "tea",
  "juice",
  "juices",
  "smoothie",
  "smoothies",
  "milkshake",
  "milkshakes",
  "water",
  "sparkling water",
  "still water",
  "energy drink",
  "energy drinks",
  "tonic",
  "tonics",
  "bar",
  "pub",
  "lounge",
];

const drinkKeywordPhrases = [
  "beer",
  "lager",
  "ale",
  "ipa",
  "stout",
  "porter",
  "pilsner",
  "cider",
  "draft",
  "draught",
  "tap",
  "pint",
  "cisk",
  "wine",
  "red wine",
  "white wine",
  "rose wine",
  "rosé",
  "prosecco",
  "champagne",
  "cocktail",
  "mocktail",
  "mojito",
  "margarita",
  "martini",
  "negroni",
  "spritz",
  "aperol spritz",
  "old fashioned",
  "gin tonic",
  "gin and tonic",
  "daiquiri",
  "cosmopolitan",
  "manhattan",
  "sangria",
  "pina colada",
  "caipirinha",
  "whisky",
  "whiskey",
  "vodka",
  "rum",
  "gin",
  "tequila",
  "mezcal",
  "cognac",
  "brandy",
  "liqueur",
  "aperitif",
  "digestif",
  "port",
  "sherry",
  "vermouth",
  "limoncello",
  "grappa",
  "johnnie walker",
  "red label",
  "black label",
  "blue label",
  "double black",
  "chivas",
  "ballantines",
  "jameson",
  "jack daniels",
  "jim beam",
  "glenfiddich",
  "glenlivet",
  "macallan",
  "talisker",
  "bombay sapphire",
  "gordons",
  "gordon s",
  "tanqueray",
  "hendricks",
  "hendrick s",
  "smirnoff",
  "absolut",
  "grey goose",
  "bacardi",
  "captain morgan",
  "malibu",
  "hennessy",
  "martell",
  "courvoisier",
  "remy martin",
  "baileys",
  "jagermeister",
  "jägermeister",
  "disaronno",
  "kahlua",
  "tia maria",
  "cointreau",
  "amaretto",
  "espresso",
  "coffee",
  "latte",
  "cappuccino",
  "flat white",
  "americano",
  "macchiato",
  "mocha",
  "frappe",
  "iced coffee",
  "cold brew",
  "tea",
  "matcha",
  "chai",
  "herbal tea",
  "green tea",
  "juice",
  "lemonade",
  "soda",
  "cola",
  "coke",
  "coke zero",
  "diet coke",
  "coca cola",
  "coca-cola",
  "pepsi",
  "pepsi max",
  "sprite",
  "sprite zero",
  "fanta",
  "schweppes",
  "schweppes tonic",
  "fever tree",
  "tonic",
  "sparkling water",
  "still water",
  "energy drink",
  "smoothie",
  "milkshake",
  "iced tea",
  "kinnie",
  "san pellegrino",
  "perrier",
  "acqua panna",
  "red bull",
  "monster",
  "guinness",
  "heineken",
  "carlsberg",
  "corona",
  "budweiser",
  "stella artois",
  "cisk",
];

const foodKeywordPhrases = [
  "pizza",
  "pasta",
  "burger",
  "fries",
  "chips",
  "salad",
  "soup",
  "sandwich",
  "wrap",
  "shawarma",
  "kebab",
  "falafel",
  "taco",
  "tacos",
  "bowl",
  "bowls",
  "steak",
  "chicken",
  "beef",
  "lamb",
  "pork",
  "fish",
  "seafood",
  "shrimp",
  "prawn",
  "sushi",
  "ramen",
  "noodle",
  "noodles",
  "rice",
  "curry",
  "dessert",
  "cake",
  "cheesecake",
  "ice cream",
  "gelato",
  "pudding",
  "pastry",
  "cookie",
  "waffle",
  "pancake",
  "ftira",
  "pastizzi",
  "rabbit",
  "brochette",
  "brochettes",
  "pilau",
  "matoke",
  "ugali",
  "isombe",
  "matooke",
  "nyama choma",
  "vegetarian",
  "vegan",
  "grilled",
  "fried",
  "roasted",
  "baked",
];

export function normalizeMenuItemClass(value: unknown): MenuItemClass | null {
  if (typeof value !== "string") return null;

  const normalized = normalizePromptText(value);
  if (!normalized) return null;

  if (["food", "dish", "dishes", "meal", "meals"].includes(normalized)) {
    return "food";
  }

  if (
    ["drink", "drinks", "beverage", "beverages", "booze", "liquid"]
      .includes(normalized)
  ) {
    return "drinks";
  }

  return normalized === "food" || normalized === "drinks" ? normalized : null;
}

export function resolveMenuItemClass(
  item: MenuItemSignalRecord,
): MenuItemClass {
  const explicitClass = normalizeMenuItemClass(item.class);
  if (explicitClass) return explicitClass;

  const profile = parseMenuItemResearchProfile(item.menu_context);
  if (profile) return profile.class;

  return inferMenuItemClass(item);
}

export function inferMenuItemClass(
  item: MenuItemSignalRecord,
): MenuItemClass {
  const context = normalizePromptText(
    [
      item.name,
      item.category,
      item.description,
      (item.tags ?? []).join(" "),
    ].filter(Boolean).join(" "),
  );

  if (matchesAny(context, foodCategoryPrefixes)) {
    return "food";
  }

  if (matchesAny(context, drinkCategoryPrefixes)) {
    return "drinks";
  }

  if (matchesAny(context, foodKeywordPhrases)) {
    return "food";
  }

  if (matchesAny(context, drinkKeywordPhrases)) {
    return "drinks";
  }

  return "food";
}

export function parseMenuItemResearchProfile(
  raw: unknown,
): MenuItemResearchProfile | null {
  if (!raw) return null;

  const parsed = typeof raw === "string"
    ? parseJsonObjectText(raw)
    : isRecord(raw)
    ? raw
    : null;
  if (!parsed) return null;

  const itemClass = normalizeMenuItemClass(parsed.class);
  if (!itemClass) return null;

  return {
    class: itemClass,
    confidence: clampConfidence(numberValue(parsed.confidence)),
    canonical_name: stringValue(parsed.canonical_name) ??
      stringValue(parsed.canonicalName) ?? "",
    canonical_category: stringValue(parsed.canonical_category) ??
      stringValue(parsed.canonicalCategory) ?? "",
    canonical_description: stringValue(parsed.canonical_description) ??
      stringValue(parsed.canonicalDescription) ?? "",
    visual_subject: stringValue(parsed.visual_subject) ??
      stringValue(parsed.visualSubject) ?? "",
    serving_style: stringValue(parsed.serving_style) ??
      stringValue(parsed.servingStyle) ?? "",
    visual_directions: stringArrayValue(
      parsed.visual_directions ?? parsed.visualDirections,
    ),
    visual_do_not: stringArrayValue(
      parsed.visual_do_not ?? parsed.visualDoNot,
    ),
    keyword_signals: stringArrayValue(
      parsed.keyword_signals ?? parsed.keywordSignals,
    ),
    source_queries: stringArrayValue(
      parsed.source_queries ?? parsed.sourceQueries,
    ),
    source_urls: stringArrayValue(
      parsed.source_urls ?? parsed.sourceUrls,
    ),
    research_summary: stringValue(parsed.research_summary) ??
      stringValue(parsed.researchSummary) ?? "",
  };
}

export function buildMenuItemResearchPrompt(args: {
  item: MenuItemSignalRecord;
  venueName: string | null;
  venueCategory: string | null;
  venueDescription: string | null;
}): string {
  const item = args.item;
  const tags = (item.tags ?? []).map((tag) => tag.trim()).filter(Boolean);
  const tagsLine = tags.length > 0 ? tags.join(", ") : "none";

  return `
You are enriching a menu item record for a production hospitality app.

Use Google Search grounding and your own reasoning to identify the most accurate menu-item class and image guidance.
Return JSON only and do not include markdown fences.

CRITICAL RULES:
- Use the item name as the primary truth source.
- Never let venue context override the item itself.
- If the item is clearly a beverage, class must be "drinks".
- If the item is a plated dish, dessert, or snack, class must be "food".
- If the item is ambiguous, default to "food" unless the name or context clearly indicates a drink.
- Keep the canonical description concise and factual.
- Keep the visual subject specific enough for accurate image generation.
- Do not invent ingredients, origin stories, cooking methods, garnishes, serving vessels, side dishes, or locality claims that are not supported by the menu text or grounded search evidence.
- If the evidence is weak, stay close to the input wording and lower confidence instead of filling gaps with plausible-sounding details.
- Preserve explicit local or branded identity in the item name when present.
- Do not turn a simple or everyday item into an upscale or fusion reinterpretation.

Input item:
- Name: ${item.name ?? ""}
- Category: ${item.category ?? ""}
- Description: ${item.description ?? ""}
- Tags: ${tagsLine}
- Current class: ${item.class ?? ""}

Venue context:
- Venue name: ${args.venueName ?? ""}
- Venue category: ${args.venueCategory ?? ""}
- Venue description: ${args.venueDescription ?? ""}

Return a JSON object with:
- class: "food" or "drinks"
- confidence: number between 0 and 1
- canonical_name: string
- canonical_category: string
- canonical_description: string
- visual_subject: string
- serving_style: string
- visual_directions: array of strings
- visual_do_not: array of strings
- keyword_signals: array of strings
- source_queries: array of strings
- source_urls: array of strings
- research_summary: short factual summary

Guidance:
- Use the current class as a strong signal if it already matches the item.
- Override the current class only when the item text clearly contradicts it.
- Keep drinks classes for beverages, bottles, cans, glasses, cocktails, wines, coffees, teas, and soft drinks.
- Keep food classes for dishes, desserts, snacks, starters, mains, and sides.
- If the category or item text indicates whisky, whiskey, vodka, gin, rum, tequila, cognac, brandy, liqueur, beer, cider, wine, cocktail, mocktail, soda, juice, smoothie, milkshake, coffee, or tea, class must be "drinks".
- Brand-only alcohol names such as "Red Label", "Black Label", "Blue Label", or "Bombay Sapphire" are still drinks.
- Venue context may help with ambience or tie-breaking, but it must not rewrite the menu item itself.
`.trim();
}

export function buildFallbackMenuItemResearchProfile(args: {
  item: MenuItemSignalRecord;
  itemClass: MenuItemClass;
  visualKind: MenuVisualKind;
}): MenuItemResearchProfile {
  const { item, itemClass, visualKind } = args;
  const contextTokens = [
    item.name,
    item.category,
    item.description,
    ...(item.tags ?? []),
  ]
    .map((value) => stringValue(value))
    .filter((value): value is string => Boolean(value));

  const canonicalName = trimOrFallback(
    item.name,
    itemClass === "drinks" ? "Drink" : "Dish",
  );
  const canonicalCategory = trimOrFallback(
    item.category,
    itemClass === "drinks" ? "Drinks" : "Food",
  );
  const canonicalDescription = trimOrFallback(
    item.description,
    itemClass === "drinks"
      ? "Beverage item requiring a drink-first image."
      : "Food item requiring a plated-dish image.",
  );

  return {
    class: itemClass,
    confidence: 0.45,
    canonical_name: canonicalName,
    canonical_category: canonicalCategory,
    canonical_description: canonicalDescription,
    visual_subject: fallbackVisualSubject(itemClass, visualKind),
    serving_style: fallbackServingStyle(itemClass, visualKind),
    visual_directions: fallbackVisualDirections(itemClass, visualKind),
    visual_do_not: fallbackVisualDoNot(itemClass),
    keyword_signals: [...new Set(contextTokens)].slice(0, 12),
    source_queries: [],
    source_urls: [],
    research_summary:
      "Heuristic fallback profile derived from the menu text because web research was unavailable.",
  };
}

export function parseJsonObjectText(value: string): Json | null {
  const candidates = [
    value.trim(),
    stripMarkdownCodeFence(value),
    extractBalancedJsonObject(value),
  ].filter((entry): entry is string =>
    Boolean(entry && entry.trim().length > 0)
  );

  for (const candidate of candidates) {
    try {
      const parsed = JSON.parse(candidate);
      return isRecord(parsed) ? (parsed as Json) : null;
    } catch (_) {
      continue;
    }
  }

  return null;
}

export function extractJsonPayloadFromCandidate(
  candidate: Json,
): string | null {
  const content = candidate.content;
  if (!isRecord(content)) return null;
  const parts = content.parts;
  if (!Array.isArray(parts)) return null;

  const text = parts
    .map((entry) => isRecord(entry) ? stringValue(entry.text) : null)
    .filter((entry): entry is string => Boolean(entry))
    .join("\n")
    .trim();
  return text.length > 0 ? text : null;
}

export function extractResearchSourceUrls(candidate: Json): string[] {
  const groundingMetadata = isRecord(candidate.groundingMetadata)
    ? candidate.groundingMetadata as Json
    : null;
  if (!groundingMetadata) return [];

  const chunks = Array.isArray(groundingMetadata.groundingChunks)
    ? groundingMetadata.groundingChunks
    : [];

  return chunks
    .map((entry) => {
      if (!isRecord(entry)) return null;
      const web = isRecord(entry.web) ? entry.web as Json : null;
      if (!web) return null;
      return stringValue(web.uri) ?? stringValue(web.url) ?? null;
    })
    .filter((entry): entry is string => Boolean(entry));
}

function normalizePromptText(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}

function matchesAny(value: string, phrases: string[]): boolean {
  return phrases.some((phrase) => {
    const normalized = normalizePromptText(phrase);
    const escaped = normalized.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const wordBoundaryRegex = new RegExp(
      `(?:^|\\s|[^a-z0-9])${escaped}(?:\\s|[^a-z0-9]|$)`,
    );
    return wordBoundaryRegex.test(value);
  });
}

function stringArrayValue(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((entry) => stringValue(entry))
    .filter((entry): entry is string => Boolean(entry))
    .map((entry) => entry.trim())
    .filter((entry) => entry.length > 0);
}

function clampConfidence(value: number | null): number {
  if (value == null || Number.isNaN(value)) return 0.5;
  return Math.max(0, Math.min(1, value));
}

function stringValue(value: unknown): string | null {
  return typeof value === "string" ? value.trim() : null;
}

function numberValue(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function trimOrFallback(value: unknown, fallback: string): string {
  const trimmed = stringValue(value);
  return trimmed && trimmed.length > 0 ? trimmed : fallback;
}

function fallbackVisualSubject(
  itemClass: MenuItemClass,
  visualKind: MenuVisualKind,
): string {
  if (itemClass === "drinks") {
    switch (visualKind) {
      case "packaged_beer":
        return "a chilled beer bottle or can as the hero subject";
      case "draft_beer":
        return "a freshly poured draft beer in a clean glass";
      case "cocktail":
        return "a single signature cocktail in the correct glassware";
      case "wine":
        return "a premium wine serve with a stemmed glass";
      case "spirits":
        return "a premium spirit serve with bottle and glass";
      case "coffee":
        return "a premium coffee drink in a cup or glass";
      case "tea":
        return "a premium tea service in a cup or glass";
      case "soft_drink":
      default:
        return "a chilled beverage hero shot in the correct glass, bottle, or can";
    }
  }

  switch (visualKind) {
    case "dessert":
      return "a premium plated dessert as the hero subject";
    case "plated_food":
    default:
      return "a single premium plated dish as the hero subject";
  }
}

function fallbackServingStyle(
  itemClass: MenuItemClass,
  visualKind: MenuVisualKind,
): string {
  if (itemClass === "drinks") {
    switch (visualKind) {
      case "packaged_beer":
        return "Use a chilled bottle or can with minimal premium props.";
      case "draft_beer":
        return "Use a proper pint or beer glass with realistic foam and condensation.";
      case "cocktail":
        return "Use the correct cocktail glassware with a restrained garnish.";
      case "wine":
        return "Use a stemmed wine glass and, if helpful, a partial bottle.";
      case "spirits":
        return "Use a neat pour or bottle-and-glass presentation with polished bar styling.";
      case "coffee":
        return "Use a cup, glass, or mug that matches the drink style.";
      case "tea":
        return "Use a cup or glass with elegant tea service styling.";
      case "soft_drink":
      default:
        return "Use the drink's natural package or serve style without extra snacks.";
    }
  }

  return visualKind === "dessert"
    ? "Use refined dessert plating with controlled garnish."
    : "Use premium plated-dish presentation with restrained garnish.";
}

function fallbackVisualDirections(
  itemClass: MenuItemClass,
  visualKind: MenuVisualKind,
): string[] {
  const base = [
    "Square 1:1 composition optimized for a mobile menu card crop",
    "Center the hero subject and keep the silhouette immediately legible",
    "Use realistic texture, lighting, and hospitality-grade presentation",
    "Keep the frame dark, premium, and free of text or clutter",
  ];

  if (itemClass === "drinks") {
    return [
      ...base,
      fallbackVisualSubject(itemClass, visualKind),
      "No plated food, side dishes, or table spread",
    ];
  }

  return [
    ...base,
    fallbackVisualSubject(itemClass, visualKind),
    "No drinks as the hero subject",
  ];
}

function fallbackVisualDoNot(itemClass: MenuItemClass): string[] {
  return itemClass === "drinks"
    ? [
      "No plated food as the hero subject",
      "No bowls, cutlery, or meal presentation",
      "No text overlays, logos, or menu graphics",
    ]
    : [
      "No beverage hero shot as the main subject",
      "No bar clutter, bottles, or glassware as the focus",
      "No text overlays, logos, or menu graphics",
    ];
}

function stripMarkdownCodeFence(value: string): string {
  const match = value.match(/```(?:json)?\s*([\s\S]*?)```/i);
  return match?.[1]?.trim() ?? value.trim();
}

function extractBalancedJsonObject(value: string): string | null {
  const source = stripMarkdownCodeFence(value);
  const startIndex = source.indexOf("{");
  if (startIndex < 0) return null;

  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let index = startIndex; index < source.length; index += 1) {
    const char = source[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char === "\\") {
        escaped = true;
      } else if (char === '"') {
        inString = false;
      }
      continue;
    }

    if (char === '"') {
      inString = true;
      continue;
    }

    if (char === "{") {
      depth += 1;
      continue;
    }

    if (char === "}") {
      depth -= 1;
      if (depth === 0) {
        return source.slice(startIndex, index + 1);
      }
    }
  }

  return null;
}

function isRecord(value: unknown): value is Json {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}
