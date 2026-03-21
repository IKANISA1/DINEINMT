update public.dinein_venues
set category = case
  when category is null or btrim(category) = '' then category
  when lower(category) like '%hotel%' then 'Hotels'
  when lower(category) like '%bar%' and lower(category) like '%restaurant%' then 'Bar & Restaurants'
  when lower(category) like '%bar%' then 'Bar'
  when lower(category) like '%restaurant%' then 'Restaurants'
  else category
end
where category is not null
  and btrim(category) <> '';
