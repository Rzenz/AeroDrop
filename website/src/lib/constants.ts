// lib/core/constants/vendor_categories.dart
export const VENDOR_CATEGORIES = ['Cafe', 'School Canteen', 'Milk Tea', 'Bakery', 'Convenience Store', 'Restaurant', 'Snack Store', 'Other']

// help_support_page.dart's form values, so reports filed on the web and in
// the app use the same categories.
export const REPORT_CATEGORIES = [
  { value: 'general', label: 'General Inquiries' },
  { value: 'order_issue', label: 'Order & Payment Issue' },
  { value: 'delivery_issue', label: 'Drone & Delivery Issue' },
  { value: 'account', label: 'Account & Profile' },
  { value: 'other', label: 'Other Feedback' },
]

/** SupportReportModel.categoryLabel, including older reports' free-form values. */
export function reportCategoryLabel(category: string | null | undefined) {
  const hit = REPORT_CATEGORIES.find((c) => c.value === category)
  if (hit) return hit.label
  if (!category) return 'General'
  const words = category.replace(/_/g, ' ')
  return words.charAt(0).toUpperCase() + words.slice(1)
}

/** CHECK constraints on public.support_messages (migration 28). */
export const SUPPORT_MESSAGE_MAX = 2000
export const SUPPORT_MAX_PHOTOS = 3
