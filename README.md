# astshara

A new Flutter project.

For help getting started with Flutter development, view the online Flutter documentation.

## Production Audit — 2026-09-07

- Latest client-home UI refinement: `8f95b7f9186b1f10cae7e78d2a9edf6dfe374832` — simplified the client home into a calmer composition: compact header, lighter consultation CTA, tighter legal-specialization cards, and cleaner suggested-lawyer cards. Existing routes, providers, notification behavior, lawyer loading, and business logic were preserved.
- Latest landing-page UI refinement: `09edc61338b9f1a80ef4a89ef1c0ccde5f6cd2de` — replaced the visually heavy navy hero with a quiet off-white/white layout, reduced illustration size, simplified typography, softened section cards, and retained the existing signup/login/lawyer navigation and real lawyer data.
- Both pages remain RTL and preserve the Istishara identity through restrained navy/gold accents rather than large saturated blocks.
- Status: `WARNING — NOT FULLY TESTED` pending GitHub CI and rendered-device verification.

- Previous client-home refinement: `eb96e42525e6e463b4824f4ab4f23738a10013ee` — tightened the vertical rhythm between the consultation CTA, legal-specialization cards, and suggested-lawyer section without changing routes, data flow, or business logic.
- Previous notification-page refinement: `7772f22aec1ed5659ce8f20c97cb8c612cce8a4b` — modernized notification visuals while preserving loading/error/empty states, refresh, mark-read, mark-all-read, and navigation behavior.
