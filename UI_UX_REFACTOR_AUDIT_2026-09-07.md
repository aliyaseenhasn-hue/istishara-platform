# UI/UX Refactor Audit — 2026-09-07

## Scope

This pass is a Frontend/UI/UX refactor only. No database, Supabase migration, API contract, authentication, authorization, business rule, or workflow logic is intentionally changed.

## Existing UI map reviewed

### Shared navigation
- `lib/shared/widgets/app_shell.dart`
  - Client primary navigation: الرئيسية → المحامون → استشاراتي → الإعدادات.
  - Lawyer primary navigation: الرئيسية → استشاراتي → الإعدادات.
  - Deep pages keep their existing route grouping and current tab selection.
- `lib/shared/widgets/main_bottom_nav.dart`
  - Lawyer had four secondary shortcuts permanently visible above the bottom navigation: المواعيد، ملفي، أوقات التوفر، المحفظة.
  - These are secondary/multiple options and were the clearest candidate for progressive disclosure.

### Client home
- `lib/features/home/presentation/pages/home_page.dart`
  - Header + notifications.
  - Client profile summary.
  - Consultation counters.
  - Legal specializations grid (first 8 displayed on home; full list exists separately).
  - Lawyer search action.
  - Suggested lawyers list.
- Existing navigation already exposes the full lawyers/categories surfaces; no business data source or provider is changed in this pass.

### Client settings
- `lib/features/profile/presentation/pages/profile_page.dart`
  - Consultation history.
  - Payment methods.
  - Personal information.
  - Theme.
  - Notifications.
  - Help center.
  - Privacy policy.
  - Logout.
  - Delete-account action.
  - This page is already the natural secondary/settings container and is preserved as-is in this refactor pass.

### Lawyer home
- `lib/features/lawyers/presentation/pages/lawyer_dashboard_page.dart`
  - Profile hero and edit action.
  - Active/completed consultation metrics.
  - Consultation amounts.
  - Professional profile entry.
  - Incoming consultation requests.
  - Existing app-bar edit action remains part of the existing workflow.

### Routing inventory
The current router retains routes for authentication, client home, lawyer directory/details, legal categories, lawyer home/profile/availability/specialization/wallet, bookings, archived bookings, chat, payments, profile/settings, notifications, help, and admin operations. The refactor does not remove any route.

## Classification used

### Primary
- الرئيسية
- المحامون / lawyer discovery
- استشاراتي
- الإعدادات
- Existing page-level primary action(s), such as opening a lawyer profile or booking flow.

### Secondary / grouped
- Lawyer: المواعيد، ملفي، أوقات التوفر، المحفظة.
- Client settings and support items remain inside the existing الإعدادات surface.

### Advanced / multiple
- Lawyer secondary shortcuts are grouped behind a single `المزيد` disclosure control.
- The underlying destinations and route names remain unchanged.

## Implemented in this pass

1. Lawyer secondary shortcuts are no longer displayed as four persistent cards in the bottom navigation area.
2. The same four actions are available from `المزيد` as a popup menu.
3. The original routes are preserved exactly:
   - `/bookings`
   - `/lawyer-profile-edit`
   - `/lawyer-availability`
   - `/lawyer-wallet`
4. Primary bottom navigation remains unchanged.
5. Client navigation remains unchanged.
6. No backend/database/API/auth/RLS/business logic changes are included.

## Regression checklist

- [x] Existing lawyer secondary destinations remain reachable.
- [x] Existing primary bottom-navigation destinations remain unchanged.
- [x] Existing route paths remain unchanged.
- [x] No database or Supabase files changed.
- [x] No authentication/authorization logic changed.
- [x] No booking/payment/chat workflow logic changed.
- [ ] Full automated Flutter analyze/test/build must pass before merging to `main`.
- [ ] Responsive verification on phone/tablet/desktop should be completed against the generated build.

## Safety rule for subsequent passes

Do not delete an existing option to simplify a screen. Group or disclose it instead. Any future UI changes must preserve the existing route, state, inputs, and business behavior.
