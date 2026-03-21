-- ============================================================================
-- Migration: Update RLS Functions for Simplified Roles
-- Date: 2026-01-15
-- Purpose: Update database helper functions to work with simplified 'ADMIN' and 'STAFF' roles
-- Note: We create public versions since we cannot modify auth schema functions
-- ============================================================================

-- Create/update public.is_staff() function to check for new simplified roles
-- This works alongside or replaces auth.is_staff() depending on RLS policy usage
DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
    EXECUTE '
    CREATE OR REPLACE FUNCTION public.is_staff()
    RETURNS BOOLEAN AS $func$
    BEGIN
      RETURN EXISTS (
        SELECT 1 FROM profiles
        WHERE user_id = auth.uid()
        AND role IN (''ADMIN'', ''STAFF'', ''PLATFORM_ADMIN'', ''INSTITUTION_ADMIN'', ''INSTITUTION_STAFF'', ''INSTITUTION_TREASURER'', ''INSTITUTION_AUDITOR'')
        AND status = ''ACTIVE''
      );
    END;
    $func$ LANGUAGE plpgsql SECURITY DEFINER;
    ';
    
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.is_staff() TO authenticated;';
  END IF;
END $$;
-- Create/update public.is_admin() function to check for new simplified roles
DO $$
BEGIN
  IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
    EXECUTE '
    CREATE OR REPLACE FUNCTION public.is_admin()
    RETURNS BOOLEAN AS $func$
    BEGIN
      RETURN EXISTS (
        SELECT 1 FROM profiles
        WHERE user_id = auth.uid()
        AND role IN (''ADMIN'', ''PLATFORM_ADMIN'', ''INSTITUTION_ADMIN'')
        AND status = ''ACTIVE''
      );
    END;
    $func$ LANGUAGE plpgsql SECURITY DEFINER;
    ';
    
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;';
  END IF;
END $$;
-- Update update_staff_role function to accept new simplified roles (if it exists)
-- Note: This function update is skipped if the function doesn't exist to avoid errors
-- The function will be updated when the base schema is applied;
