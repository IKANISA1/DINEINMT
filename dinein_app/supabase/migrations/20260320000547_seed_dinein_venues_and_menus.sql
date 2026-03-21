
-- Seed 5 Malta venues
INSERT INTO dinein_venues (id, name, slug, category, description, address, country, status, rating, rating_count) VALUES
  ('a1000000-0000-0000-0000-000000000001', 'The Artisan Grill', 'the-artisan-grill', 'Fine Dining', 'Premium steakhouse with Mediterranean flair. Wagyu, seafood, and house cocktails in an intimate setting.', '42 Republic Street, Valletta', 'MT', 'active', 4.80, 312),
  ('a1000000-0000-0000-0000-000000000002', 'Vantage Rooftop', 'vantage-rooftop', 'Rooftop Bar', 'Panoramic harbour views, craft cocktails, and elevated small plates above the Sliema skyline.', '15 Tower Road, Sliema', 'MT', 'active', 4.65, 187),
  ('a1000000-0000-0000-0000-000000000003', 'Lumina Lounge', 'lumina-lounge', 'Cocktail Lounge', 'Ambient cocktail lounge with live jazz, small bites, and an award-winning bar program.', '8 Spinola Bay, St. Julian''s', 'MT', 'active', 4.50, 245),
  ('a1000000-0000-0000-0000-000000000004', 'Porto Fino', 'porto-fino', 'Italian', 'Authentic Italian trattoria nestled in the silent city. Wood-fired pizzas and handmade pasta.', '3 Villegaignon Street, Mdina', 'MT', 'inactive', 4.30, 98),
  ('a1000000-0000-0000-0000-000000000005', 'Azure Bar', 'azure-bar', 'Beach Bar', 'Laid-back beachside vibes with fresh seafood, local wines, and sunset sessions.', 'Xlendi Bay, Gozo', 'MT', 'pending_claim', 4.10, 56);

-- Seed menu items for The Artisan Grill
INSERT INTO dinein_menu_items (venue_id, name, description, price, category, tags, sort_order) VALUES
  ('a1000000-0000-0000-0000-000000000001', 'Truffle Arancini', 'Crispy Sicilian rice balls with black truffle and fontina.', 14.50, 'Starters', '{"Popular","Vegetarian"}', 1),
  ('a1000000-0000-0000-0000-000000000001', 'Carpaccio di Manzo', 'Thinly sliced aged beef with rocket, capers, and parmesan.', 16.00, 'Starters', '{}', 2),
  ('a1000000-0000-0000-0000-000000000001', 'Burrata & Heirloom Tomatoes', 'Fresh burrata, vine tomatoes, basil oil, aged balsamic.', 15.00, 'Starters', '{"Vegetarian"}', 3),
  ('a1000000-0000-0000-0000-000000000001', 'Wagyu Ribeye 300g', 'Australian Wagyu MB7, bone marrow butter, seasonal greens.', 58.00, 'Mains', '{"Signature"}', 4),
  ('a1000000-0000-0000-0000-000000000001', 'Catch of the Day', 'Line-caught local fish, saffron risotto, fennel cream.', 36.00, 'Mains', '{}', 5),
  ('a1000000-0000-0000-0000-000000000001', 'Wild Mushroom Ravioli', 'Handmade pasta, porcini cream, truffle oil, pecorino.', 28.00, 'Mains', '{"Vegetarian","Popular"}', 6),
  ('a1000000-0000-0000-0000-000000000001', 'Dark Chocolate Fondant', 'Valrhona 72%, vanilla gelato, gold leaf.', 14.00, 'Desserts', '{"Signature"}', 7),
  ('a1000000-0000-0000-0000-000000000001', 'Tiramisu Classico', 'Traditional recipe, espresso-soaked savoiardi.', 12.00, 'Desserts', '{}', 8),
  ('a1000000-0000-0000-0000-000000000001', 'Signature Negroni', 'Campari, vermouth rosso, artisan gin, orange peel.', 15.00, 'Drinks', '{"Popular"}', 9),
  ('a1000000-0000-0000-0000-000000000001', 'Espresso Martini', 'Fresh espresso, vodka, Kahlúa, vanilla.', 16.00, 'Drinks', '{}', 10);

-- Seed menu items for Vantage Rooftop
INSERT INTO dinein_menu_items (venue_id, name, description, price, category, tags, sort_order) VALUES
  ('a1000000-0000-0000-0000-000000000002', 'Crispy Calamari', 'Tender squid, lemon aioli, chilli flakes.', 13.00, 'Starters', '{"Popular"}', 1),
  ('a1000000-0000-0000-0000-000000000002', 'Tuna Tartare', 'Fresh yellowfin, avocado mousse, sesame crackers.', 18.00, 'Starters', '{"Signature"}', 2),
  ('a1000000-0000-0000-0000-000000000002', 'Grilled Sea Bass', 'Whole grilled sea bass, lemon butter, roasted vegetables.', 32.00, 'Mains', '{}', 3),
  ('a1000000-0000-0000-0000-000000000002', 'Lamb Rack', 'Herb-crusted lamb rack, mint jus, dauphinoise.', 42.00, 'Mains', '{"Signature"}', 4),
  ('a1000000-0000-0000-0000-000000000002', 'Sunset Spritz', 'Aperol, prosecco, blood orange, rosemary.', 14.00, 'Drinks', '{"Popular"}', 5);

-- Seed menu items for Lumina Lounge
INSERT INTO dinein_menu_items (venue_id, name, description, price, category, tags, sort_order) VALUES
  ('a1000000-0000-0000-0000-000000000003', 'Mezze Board', 'Hummus, babaganoush, falafel, warm pita.', 16.00, 'Starters', '{"Vegetarian","Popular"}', 1),
  ('a1000000-0000-0000-0000-000000000003', 'Beef Sliders', 'Three mini wagyu burgers, truffle mayo, pickled onion.', 19.00, 'Mains', '{"Popular"}', 2),
  ('a1000000-0000-0000-0000-000000000003', 'Jazz Old Fashioned', 'Bourbon, Angostura bitters, orange zest, Demerara.', 16.00, 'Drinks', '{"Signature"}', 3),
  ('a1000000-0000-0000-0000-000000000003', 'Lavender Collins', 'Gin, lavender syrup, lemon, sparkling water.', 14.00, 'Drinks', '{}', 4),
  ('a1000000-0000-0000-0000-000000000003', 'Panna Cotta', 'Vanilla bean panna cotta, seasonal berry compote.', 11.00, 'Desserts', '{}', 5);
;
