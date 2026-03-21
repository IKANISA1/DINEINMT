import {
  isAllowedMenuUploadUrl,
  normalizeMenuUploadContentType,
} from "./security.ts";

Deno.test("normalizeMenuUploadContentType accepts supported content types", () => {
  if (
    normalizeMenuUploadContentType("image/jpeg; charset=binary") != "image/jpeg"
  ) {
    throw new Error("expected JPEG content type to normalize");
  }
  if (normalizeMenuUploadContentType("application/pdf") != "application/pdf") {
    throw new Error("expected PDF content type to normalize");
  }
});

Deno.test("normalizeMenuUploadContentType rejects unsupported content types", () => {
  if (normalizeMenuUploadContentType("text/plain") != null) {
    throw new Error("expected text/plain to be rejected");
  }
});

Deno.test("isAllowedMenuUploadUrl only accepts this project's menu upload bucket", () => {
  const supabaseUrl = "https://project.supabase.co";
  if (
    !isAllowedMenuUploadUrl(
      "https://project.supabase.co/storage/v1/object/sign/menu-uploads/uploads/file.pdf?token=123",
      supabaseUrl,
    )
  ) {
    throw new Error("expected signed menu upload URL to be accepted");
  }
  if (
    isAllowedMenuUploadUrl(
      "https://example.com/storage/v1/object/sign/menu-uploads/uploads/file.pdf?token=123",
      supabaseUrl,
    )
  ) {
    throw new Error("expected foreign host to be rejected");
  }
  if (
    isAllowedMenuUploadUrl(
      "https://project.supabase.co/storage/v1/object/sign/avatars/uploads/file.pdf?token=123",
      supabaseUrl,
    )
  ) {
    throw new Error("expected non-menu bucket to be rejected");
  }
});
