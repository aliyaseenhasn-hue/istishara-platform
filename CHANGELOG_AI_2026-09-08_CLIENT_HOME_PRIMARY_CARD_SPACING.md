# Client home primary-card spacing

## File

- `lib/features/home/presentation/pages/home_page.dart`

## Reason

The client-name card and the legal-specialization area still appeared visually compressed toward the top of the client home page.

## Change

- Increased the space below the client-name card from 15 to 24 logical pixels.
- Increased the upper and lower breathing room around the consultation summary cards.
- Increased the separation before the legal-specializations heading from 10 to 16 logical pixels.
- Kept card dimensions, navigation, and the responsive specialization grid unchanged.

## Result

The client-name card is now visually separated from the specialization area, while the intermediate consultation summary remains balanced and readable.

## Commit

- `fix(home): increase client card to specialties spacing`
