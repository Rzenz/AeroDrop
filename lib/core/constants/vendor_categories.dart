const vendorCategories = <String>[
  'Cafe',
  'School Canteen',
  'Milk Tea',
  'Bakery',
  'Convenience Store',
  'Restaurant',
  'Snack Store',
  'Other',
];

bool isPredefinedVendorCategory(String? value) {
  if (value == null) return false;
  return vendorCategories.contains(value) && value != 'Other';
}
