begin;

update public.dinein_profiles
set whatsapp_number = '+35699742524'
where role = 'admin'
  and regexp_replace(coalesce(whatsapp_number, ''), '[^0-9]', '', 'g') =
    regexp_replace('+356999742524', '[^0-9]', '', 'g');

update auth.users
set email = 'admin-35699742524@dinein.local',
    raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb)
      || jsonb_build_object('whatsapp_number', '+35699742524')
where email = 'admin-356999742524@dinein.local'
   or id in (
    select id
    from public.dinein_profiles
    where role = 'admin'
      and regexp_replace(coalesce(whatsapp_number, ''), '[^0-9]', '', 'g') =
        regexp_replace('+35699742524', '[^0-9]', '', 'g')
  );

commit;
