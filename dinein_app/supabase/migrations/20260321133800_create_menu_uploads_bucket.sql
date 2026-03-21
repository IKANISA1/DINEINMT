-- Create menu-uploads storage bucket for OCR menu file processing
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'menu-uploads',
  'menu-uploads',
  false,
  10485760, -- 10MB
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf']
)
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to upload to menu-uploads bucket
CREATE POLICY "Authenticated users can upload menu files"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'menu-uploads');

-- Allow service role to read (for OCR processing)
CREATE POLICY "Service role can read menu uploads"
ON storage.objects FOR SELECT
TO authenticated
USING (bucket_id = 'menu-uploads');

-- Allow users to delete their own uploads
CREATE POLICY "Users can delete their own uploads"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'menu-uploads');
