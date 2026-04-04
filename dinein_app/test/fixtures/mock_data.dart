import 'package:core_pkg/constants/enums.dart';
import 'package:db_pkg/models/models.dart';

/// Mock data ported from React constants.ts.
/// Used as fallback when Supabase is unavailable.
abstract final class MockData {
  static final List<Venue> venues = [
    Venue(
      id: '1',
      name: 'The Artisan Grill',
      slug: 'the-artisan-grill',
      category: 'Contemporary Gastronomy',
      description:
          'Contemporary Gastronomy & Prime Cuts. Experience the pinnacle of Japanese bovine excellence.',
      address: 'Republic Street, Valletta',
      phone: '+356 2123 4567',
      email: 'concierge@artisangrill.com',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCUatAlz3wpD_Tt2oNiSY4Cx3f0blmu-5oK-XIKsGinZNizl2IwpTpfCML283GOry8oEw9aL2f4sEDP8eIuuOb3uCQCG3_L0EHNw9riD1HVa0hNOqlpAT4753-LI-DLw1UxEGMddODp0mdNOiKV2QVCvoKkcQiwpTl3vNEWf-Sc0o3l-QEr34t2Ma9ql43uPUiF-1Wt_YFwiJBNAI2h-rpftwb5GRHLeOGM9AY_UEkomiE_CtZ-bZdtPikaQu5ha5qAhGbtaErFbU8',
      status: VenueStatus.active,
      orderingEnabled: true,
      rating: 4.9,
      ratingCount: 156,
      country: Country.mt,
      openingHours: {
        'Monday': const OpeningHours(open: '09:00', close: '22:00'),
        'Tuesday': const OpeningHours(open: '09:00', close: '22:00'),
        'Wednesday': const OpeningHours(open: '09:00', close: '22:00'),
        'Thursday': const OpeningHours(open: '09:00', close: '22:00'),
        'Friday': const OpeningHours(open: '09:00', close: '23:30'),
        'Saturday': const OpeningHours(open: '10:00', close: '00:00'),
        'Sunday': const OpeningHours(
          open: '10:00',
          close: '22:00',
          isOpen: false,
        ),
      },
    ),
    Venue(
      id: '2',
      name: 'Vantage Rooftop',
      slug: 'vantage-rooftop',
      category: 'Skyline Vistas',
      description:
          'Skyline Vistas & Signature Cocktails. Open air rooftop bar with city skyline view at sunset.',
      address: 'The Strand, Sliema',
      phone: '+356 2134 5678',
      email: 'hello@vantagerooftop.com',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAbkXthgBhDCfPymd-NsbizhRkF_9hyjh9C2b0GK5Ez_rofbY_ACktQHOpVbDWMBHZRXKGOXajM7cCNuymoWwSQkw0h2DGL-1iOqDpRGaC4xxx1elS2Z5qG6U5_9ERiH48r-bdoOP2hl0agYimat3gzUxBfk7fKD2EFM1Ub1eXIJ9e-Pdg59N0vxSUU4VuXItN63heZqOygyMMT4BMcFHKAXSyPfYEEMRUZx8W6AF9svch-XI-qjWwc2ic-5PCWWcTmO26QDhRi3WU',
      status: VenueStatus.active,
      orderingEnabled: true,
      rating: 4.8,
      ratingCount: 89,
      country: Country.mt,
    ),
    Venue(
      id: '3',
      name: 'Lumina Lounge',
      slug: 'lumina-lounge',
      category: 'Immersive Sound',
      description:
          'Immersive Sound & Velvet Comfort. Modern minimal lounge with neon accents and marble floors.',
      address: 'Paceville, St Julian\'s',
      phone: '+356 2138 9012',
      email: 'info@luminalounge.jp',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuBxzIovA2T99Wwsti94HX6kLODaF7SyoRzoGXD7kSqL6X6EnK6S_nnO8u1jZeWzHndlVAnSyvCQXGWHHCC8zVZUmQ8XvSDJXStA_RWj_9QDeEc7RI9wtY_GJ6JjkkaJDFLpR6qp6-x9ZgBLMqNlgz4ByiwBfR8SIje315wjsT5JhXeLnAzgRztqGYEkirqMzfM-i6ZhHTiKSy5I3VgIYU7FHFDBkdAVjXkjJlgfNIsDL8xWYasR65ul8V7EDWQQB4fuFyN0sr7WdIc',
      status: VenueStatus.inactive,
      rating: 4.7,
      ratingCount: 210,
      country: Country.mt,
    ),
  ];

  static final List<MenuItem> menuItems = [
    MenuItem(
      id: 'm1',
      venueId: '1',
      name: 'Dry-Aged Ribeye',
      description:
          '28-day dry-aged premium ribeye, char-grilled over white oak. Served with a reduction of black garlic and vintage port.',
      price: 48.00,
      category: 'Signature Mains',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCnPBDlv9ODH63VYhlzIXOLz0Lr3a0rAkUTcKVS-Pcz8NnRJU0SIR9kFCtGCbdOZ5q3uo9U1HcDsl2kQ1t-Ds3hXPT9LUbL7KosYoGNKawIXYaHU-70GSnq-ECV9h7tmjYUY5ehVGQg1C6JW_3aeMFgFvknGeJrDOEGCibm_jU77tesojUdVUEXtBy0PztgKfMJTtwQgP9Za8pkrubigMdYPDcRLnNolpUEblHHqTYy5zr8w_mLYWj8GD09V32y24xfP_Ax1914c-o',
      tags: ['GF', "Chef's Choice"],
    ),
    MenuItem(
      id: 'm2',
      venueId: '1',
      name: 'Truffle Pappardelle',
      description:
          'Hand-cut pappardelle, black winter truffle, 24-month aged parmesan, and clarified bone marrow emulsion.',
      price: 32.00,
      category: 'Signature Mains',
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuDi4kNTqaguxNO0x6utEVn6hNyz1c2oYMrFE9GwjbLS8_8sIYLks66XV13u39-wK5DmUJ5VZ31qpVGcj8qt04HK-doVWxYZ4mNizk93lAyZzr7BtJWZ9RjgSlwXCgq7tPL3DvTkq9kUIJc0iy088BP5CsmXW0L6aSq-bmw8MriO5khyngKzauSZfHAoPL9G-YZbU6mz2KnnS0Id_o-ihoDenxdRRyB9KxEpWJqkXaK0USs1Tu4GVs8CVYUUSNyqnOOHGZpYqvirITk',
      tags: ['Vegetarian'],
    ),
    MenuItem(
      id: 'm3',
      venueId: '1',
      name: 'Wagyu A5 Reserve Filet',
      description:
          'Experience the pinnacle of Japanese bovine excellence. Sourced directly from the Kagoshima prefecture.',
      price: 185.00,
      category: "Chef's Signature",
      imageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuC6FSvstK_h7BHl2sj4M9raU-C2tYp6t395ODCsy2A7wZQoiE7Kp6tVEeyztOpI5VSEcKd3QACifi8j83-I35SpWejVws7hJQO6usJBmrTiWye9QWGc3Pq6nZn7DD7b_-_2f0LkE-5Txic852I1lsU94oRkYFHImo5rXXAk755RRQzz6EPHHMjmimpDBTHWwpad4uCD499YBedY9V6ajDwPpBBUHimp4MfMyxo-CTaQ8Y6Vji1mXJNMt9aJvsqBS3PEUo5LQQ4Ca8Q',
      tags: ['Rare Batch'],
    ),
    MenuItem(
      id: 'm4',
      venueId: '1',
      name: 'Lobster Thermidor',
      description:
          'Fresh Atlantic lobster, creamy brandy sauce, gruyère crust.',
      price: 55.00,
      category: 'Seafood',
      imageUrl: 'https://picsum.photos/seed/lobster/800/600',
      tags: ['Premium'],
    ),
    MenuItem(
      id: 'm5',
      venueId: '1',
      name: 'Truffle Fries',
      description: 'Hand-cut fries, truffle oil, parmesan, chives.',
      price: 12.00,
      category: 'Sides',
      imageUrl: 'https://picsum.photos/seed/fries/800/600',
      tags: ['Vegetarian'],
    ),
    MenuItem(
      id: 'm6',
      venueId: '1',
      name: 'Chocolate Fondant',
      description:
          'Warm chocolate cake, molten center, vanilla bean ice cream.',
      price: 14.00,
      category: 'Desserts',
      imageUrl: 'https://picsum.photos/seed/dessert/800/600',
      tags: ['Sweet'],
    ),
  ];

  static final List<Order> orders = [
    Order(
      id: 'ORD-8829',
      venueId: '1',
      venueName: 'The Artisan Grill',
      userId: 'u1',
      userName: 'Alexander Wright',
      items: const [
        OrderItem(
          menuItemId: 'm1',
          name: 'Dry-Aged Ribeye',
          price: 48.00,
          quantity: 2,
        ),
        OrderItem(
          menuItemId: 'm2',
          name: 'Truffle Pappardelle',
          price: 32.00,
          quantity: 1,
        ),
      ],
      total: 128.00,
      status: OrderStatus.received,
      createdAt: DateTime.parse('2023-10-24T19:42:00Z'),
      paymentMethod: PaymentMethod.cash,
      tableNumber: '8',
    ),
  ];
}
