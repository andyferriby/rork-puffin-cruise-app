# Add Coquet Island live cameras and WooCommerce shop


## Features

- [x] **Live Cameras tab** — dedicated screen with 4 embedded YouTube live streams showing Coquet Island cameras. Crew can update the video links daily from the admin panel without needing a new build. Thumbnail placeholders show while streams load, and each stream has a short label (e.g. "Puffin Colony", "North Cliffs").

- [x] **Shop tab** — pulls real products from your WooCommerce store (prices, images, descriptions, stock status) and displays them in a clean product grid. Tapping a product shows full details. Tapping "Buy" opens the WooCommerce website to complete checkout with your existing Stripe payment flow — no additional payment integration needed.

- [x] **Admin panel additions** — two new sections below the existing schedule editor: one for updating the 4 YouTube video IDs (saved to Supabase so they update instantly), and one for entering your WooCommerce store URL and consumer keys so the shop tab pulls live product data.

## Design

Both screens follow the existing nautical theme — deep navy backgrounds, sea-blue accents, rounded card layouts. The live cameras screen shows a stacked grid of video players with puffin-orange accent borders. The shop screen uses a two-column product grid with soft-shadow product cards, price badges in sea-blue, and smooth loading skeletons.

## Screens

- [x] **Live Cameras** — new tab showing 4 YouTube live streams stacked vertically, each with a label and loading placeholder
- [x] **Shop** — new tab with product grid, product detail view, and a link-out to your WooCommerce store for checkout
- [x] **Admin (updated)** — adds YouTube link manager and WooCommerce config sections
