import { buildGeminiImageGenerationConfig } from "./gemini-image-config.ts";

Deno.test("buildGeminiImageGenerationConfig omits deprecated outputMimeType", () => {
  const config = buildGeminiImageGenerationConfig({
    aspectRatio: "16:9",
    imageSize: "1K",
  });

  if ("outputMimeType" in config) {
    throw new Error(
      "outputMimeType must not be present in Gemini image config",
    );
  }

  if (
    !Array.isArray(config.responseModalities) ||
    config.responseModalities[0] !== "IMAGE"
  ) {
    throw new Error("responseModalities should request IMAGE output");
  }

  const imageConfig = config.imageConfig as Record<string, string>;
  if (imageConfig.aspectRatio !== "16:9") {
    throw new Error(
      `Expected aspect ratio 16:9, got ${imageConfig.aspectRatio}`,
    );
  }
  if (imageConfig.imageSize !== "1K") {
    throw new Error(`Expected image size 1K, got ${imageConfig.imageSize}`);
  }
});
