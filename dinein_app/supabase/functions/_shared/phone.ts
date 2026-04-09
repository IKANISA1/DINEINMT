type PhoneRule = {
  countryCode: string;
  localLengths: number[];
  trunkPrefix?: string;
};

const PHONE_RULES: PhoneRule[] = [
  {
    countryCode: "250",
    localLengths: [9],
    trunkPrefix: "0",
  },
  {
    countryCode: "356",
    localLengths: [8],
    trunkPrefix: "0",
  },
];

function currentDefaultCountryCode(explicit?: string): string {
  return (explicit ?? Deno.env.get("DEFAULT_WHATSAPP_COUNTRY_CODE") ?? "356")
    .replace(/\D/g, "");
}

function digitsOnly(value: string): string {
  return value.replace(/\D/g, "");
}

function phoneRuleForCountry(countryCode: string): PhoneRule | null {
  return PHONE_RULES.find((rule) => rule.countryCode === countryCode) ?? null;
}

function stripNationalTrunkPrefix(
  digits: string,
  rule: PhoneRule | null,
): string {
  if (!rule?.trunkPrefix || !digits.startsWith(rule.trunkPrefix)) {
    return digits;
  }

  const stripped = digits.slice(rule.trunkPrefix.length);
  if (rule.localLengths.includes(stripped.length)) {
    return stripped;
  }

  return digits;
}

function maybeNormalizeLocalDigits(
  digits: string,
  defaultCountryCode: string,
): string | null {
  const rule = phoneRuleForCountry(defaultCountryCode);
  if (!rule) return null;

  const stripped = stripNationalTrunkPrefix(digits, rule);
  if (rule.localLengths.includes(stripped.length)) {
    return `${rule.countryCode}${stripped}`;
  }

  return null;
}

function canonicalizeInternationalDigits(digits: string): string {
  for (const rule of PHONE_RULES) {
    if (!digits.startsWith(rule.countryCode)) continue;

    const nationalDigits = digits.slice(rule.countryCode.length);
    const stripped = stripNationalTrunkPrefix(nationalDigits, rule);
    if (stripped !== nationalDigits) {
      return `${rule.countryCode}${stripped}`;
    }

    return digits;
  }

  return digits;
}

export function normalizeWhatsAppPhone(
  raw: string,
  options: { defaultCountryCode?: string } = {},
): string {
  const trimmed = raw.trim();
  const digits = digitsOnly(trimmed);

  if (!digits) {
    throw new Error("A valid WhatsApp number is required.");
  }

  const defaultCountryCode = currentDefaultCountryCode(
    options.defaultCountryCode,
  );

  let candidateDigits: string | null = null;
  if (trimmed.startsWith("+")) {
    candidateDigits = digits;
  } else if (trimmed.startsWith("00")) {
    candidateDigits = digits.slice(2);
  } else {
    candidateDigits = maybeNormalizeLocalDigits(digits, defaultCountryCode);
    if (candidateDigits == null && digits.length >= 10 && digits.length <= 15) {
      candidateDigits = digits;
    }
  }

  const normalizedDigits = candidateDigits == null
    ? null
    : canonicalizeInternationalDigits(candidateDigits);
  if (
    normalizedDigits == null || normalizedDigits.length < 8 ||
    normalizedDigits.length > 15
  ) {
    throw new Error("A valid WhatsApp number is required.");
  }

  return `+${normalizedDigits}`;
}

export function optionalNormalizedWhatsAppPhone(
  raw?: string | null,
  options: { defaultCountryCode?: string } = {},
): string | null {
  if (!raw || !raw.trim()) return null;
  try {
    return normalizeWhatsAppPhone(raw, options);
  } catch {
    return null;
  }
}

export function canonicalPhoneDigits(
  raw?: string | null,
  options: { defaultCountryCode?: string } = {},
): string | null {
  const normalized = optionalNormalizedWhatsAppPhone(raw, options);
  return normalized == null ? null : digitsOnly(normalized);
}

export function phoneNumbersMatch(
  left?: string | null,
  right?: string | null,
  options: { defaultCountryCode?: string } = {},
): boolean {
  const leftDigits = canonicalPhoneDigits(left, options);
  const rightDigits = canonicalPhoneDigits(right, options);
  return leftDigits != null && leftDigits === rightDigits;
}
