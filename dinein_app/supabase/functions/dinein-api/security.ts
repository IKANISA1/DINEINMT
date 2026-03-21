const supportedMenuUploadContentTypes = new Set([
  "application/pdf",
  "image/heic",
  "image/jpeg",
  "image/png",
  "image/webp",
]);

export function normalizeMenuUploadContentType(
  contentType: string | null | undefined,
): string | null {
  if (!contentType) return null;
  const normalized = contentType.split(";")[0]?.trim().toLowerCase() ?? "";
  if (!supportedMenuUploadContentTypes.has(normalized)) {
    return null;
  }
  return normalized;
}

export function isAllowedMenuUploadUrl(
  fileUrl: string,
  supabaseUrl: string,
): boolean {
  try {
    const upload = new URL(fileUrl);
    const supabase = new URL(supabaseUrl);
    if (upload.host != supabase.host) {
      return false;
    }
    return upload.pathname.startsWith(
      "/storage/v1/object/sign/menu-uploads/uploads/",
    ) ||
      upload.pathname.startsWith(
        "/storage/v1/object/public/menu-uploads/uploads/",
      );
  } catch {
    return false;
  }
}
