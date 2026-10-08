/// Shared icon mapping for categories.
library;

import 'package:flutter/material.dart';

/// Map category iconRef to IconData.
IconData iconForCategory(String ref) {
  return switch (ref) {
    'food' || 'dining' => Icons.restaurant_outlined,
    'shopping' => Icons.shopping_bag_outlined,
    'daily' => Icons.shopping_basket_outlined,
    'transport' => Icons.directions_bus_outlined,
    'fruit' => Icons.eco_outlined,
    'entertainment' => Icons.movie_outlined,
    'telecom' => Icons.phone_iphone_outlined,
    'housing' => Icons.home_outlined,
    'medical' => Icons.local_hospital_outlined,
    'study' => Icons.school_outlined,
    'social' => Icons.card_giftcard_outlined,
    'salary' => Icons.payments_outlined,
    'bonus' => Icons.star_outline,
    'income' => Icons.trending_up_outlined,
    // Account-type refs used by CategoryAvatar on the assets page.
    'payments' || 'cash' => Icons.payments_outlined,
    'card' || 'bank' => Icons.credit_card_outlined,
    'other' => Icons.category_outlined,
    _ => Icons.category_outlined,
  };
}
