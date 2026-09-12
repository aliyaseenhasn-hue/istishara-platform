# Client home spacing balance

## File

- `lib/features/home/presentation/pages/home_page.dart`

## Reason

The profile, statistics, legal-specialization cards, and suggested-lawyers section were visually compressed toward the top of the client home page.

## Change

- Added a small amount of breathing room below the client profile card.
- Increased the separation around the consultation statistics and specialization heading.
- Increased the space below the specialization grid and before the suggested-lawyers section.
- Kept the existing layout, card sizes, and responsive grid unchanged.

## Result

The upper sections now have a clearer visual rhythm without introducing excessive empty space or changing the page architecture.

## Commit

- `fix(home): balance client home section spacing`
