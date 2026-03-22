export interface GeminiImageConfigOptions {
  aspectRatio: string;
  imageSize?: string;
}

export function buildGeminiImageGenerationConfig(
  options: GeminiImageConfigOptions,
) {
  const { aspectRatio, imageSize } = options;
  const imageConfig: Record<string, string> = { aspectRatio };

  if (imageSize) {
    imageConfig.imageSize = imageSize;
  }

  return {
    responseModalities: ["IMAGE"],
    imageConfig,
  };
}
