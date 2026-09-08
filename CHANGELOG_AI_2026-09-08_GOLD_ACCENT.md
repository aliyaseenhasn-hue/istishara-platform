# Gold Accent Alignment — 2026-09-08

## Scope
Add a clearer premium gold accent across both client and lawyer experiences without changing layouts, navigation, business logic, Supabase, bookings, payments, or authentication.

## Changes
- `AppColors.ctaGold` now uses the real brand gold instead of the secondary blue.
- Increased visibility of `goldSoft` and `goldSoftStrong` so existing gold borders, profile rings, chips, and accents are easier to see.
- Updated `goldGradient` to produce a more intentional light-to-gold progression.
- Existing client and lawyer profile headers automatically inherit the stronger gold accents.
- Booking progress UI that already consumes `ctaGold` now displays the intended gold accent.

## Design rule
Navy/blue remains the primary legal brand color. Gold is used as a restrained premium accent to preserve readability and contrast.
