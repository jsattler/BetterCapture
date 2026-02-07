# Landing Page Setup Tasks - Issue #7

## Overview
Transform the existing dark-themed landing page (originally for "deaper/betterASO") into a light-themed landing page for BetterCapture - a macOS screen recorder.

## Design Changes

### 1. Theme Conversion: Dark to Light ✅
- [ ] Update BaseLayout.astro
  - Change body background from `bg-black` to `bg-white`
  - Change text color from `text-white` to appropriate dark colors
  - Update meta theme-color from `#000000` to light color
  - Update color-scheme from `dark` to `light`
- [ ] Update global styles if needed (global.css)
- [ ] Update Navbar component for light theme
- [ ] Update text colors throughout all components

### 2. Hero Section - Complete Redesign ✅
**New Design:** Card-based hero that fills almost entire viewport

**Implementation:**
- [ ] Create new Hero.svelte component with:
  - Large card container with rounded corners (fills ~90vh)
  - Grainy gradient background (similar to CTA section style)
  - Two-column layout: 2/3 left, 1/3 right
  
- [ ] Left column (2/3 width):
  - Frosted glass effect card with rounded corners
  - Hero heading: Focus on BetterCapture being a native macOS screen recorder
  - Subheading: Emphasize free, open-source, native experience
  - Installation section below:
    - Homebrew installation command with copy button
    - Direct download button linking to latest GitHub Release
  
- [ ] Right column (1/3 width):
  - Screenshot placeholder (will be replaced with actual BetterCapture screenshot)
  - Ensure proper aspect ratio and responsive sizing

**Content to draft:**
- Hero heading (e.g., "The macOS Screen Recorder You Deserve")
- Subheading (emphasize free, open-source, native feel)
- CTA button text

### 3. Features Section - Content Update ✅
**Style:** Keep existing alternating layout from FeatureCard.svelte

**Tasks:**
- [ ] Update FeatureCard.svelte for light theme compatibility
- [ ] Update FeaturesSection.svelte with new content:
  - Draft 4 key features for BetterCapture
  - Suggested features:
    1. **Native macOS Experience** - Built with SwiftUI, follows Apple HIG
    2. **Instant Recording** - Quick access via menu bar, system-level integration
    3. **Privacy-First** - No tracking, no analytics, your recordings stay on your Mac
    4. **Open Source & Free** - MIT licensed, community-driven, always free
  
- [ ] For each feature:
  - Title
  - Description (2-3 sentences)
  - Bullet points (3-4 benefits)
  - Background image (use existing grainy-gradient-feat-*.jpg)
  - Screenshot placeholder (to be replaced later)

### 4. Pricing Section → Roadmap Section ✅
**Replacement:** Remove pricing entirely, create new Roadmap section

**Tasks:**
- [ ] Create new RoadmapSection.svelte component:
  - Similar card style to CTASection (grainy gradient background)
  - Large card with rounded corners
  - Content:
    - Heading: "What's Coming Next"
    - Subheading: Brief description about community-driven development
    - Button/Link: "View Roadmap on GitHub" → links to GitHub Milestones
  - Ensure light theme compatibility

- [ ] Update index.astro:
  - Replace `<PricingSection />` with `<RoadmapSection />`
  - Update imports

### 5. CTA Section - Content Update ✅
**Style:** Keep existing card style with grainy gradient

**Tasks:**
- [ ] Update CTASection.svelte:
  - Change background color to work with light theme
  - Update text colors for light background
  - New content:
    - Heading: "Ready to Start Recording?"
    - Subheading: Brief call-to-action
    - Installation instructions (same as hero: Homebrew + download button)
  - Update or remove the logo/branding section at bottom of card

### 6. Footer - Simplification ✅
**Changes:** Remove most navigation, keep essentials only

**Tasks:**
- [ ] Update Footer.svelte:
  - Update colors for light theme
  - Simplify to single column or two columns max
  - Keep only:
    - Logo/brand name
    - MIT License notice with link to LICENSE file
    - Changelog link (to GitHub Releases)
    - Remove: Company, Legal columns (except keep Privacy Policy if it exists)
  - Update copyright line
  - Remove social media icons (currently hidden anyway)

### 7. Metadata & Branding Updates ✅
- [ ] Update index.astro:
  - Page title
  - Meta description
  - Keywords (screen recording, macOS, SwiftUI, open source)
  - Structured data for BetterCapture
  - Remove old "deaper/betterASO" references

- [ ] Update BaseLayout.astro:
  - OG image reference
  - Site name in meta tags
  - Canonical URLs

### 8. Remove Unused Components ✅
- [ ] Delete PricingCard.svelte (no longer needed)
- [ ] Delete WaitlistForm.svelte (no longer needed)
- [ ] Delete DashboardPreview.svelte (no longer needed)
- [ ] Update index.astro to remove DashboardPreview

### 9. Assets & Images 📋
**Note:** Screenshot placeholders will be added later by user

- [ ] Verify grainy gradient images are suitable for light theme
- [ ] Update/verify favicon references
- [ ] Ensure all image paths are correct

### 10. Testing & Responsive Design ✅
- [ ] Test light theme across all sections
- [ ] Verify responsive layout on mobile/tablet
- [ ] Test all links (GitHub Releases, Milestones, etc.)
- [ ] Verify Homebrew installation command is correct
- [ ] Check color contrast for accessibility

---

## GitHub Workflow Notes

**Branch naming:** Use `gh issue develop 7 --checkout` to create branch  
**Commit format:** Use conventional commits (e.g., `feat(hero): implement new card-based layout`)

---

## Questions & Decisions Made

1. **Hero card styling:** Frosted glass effect for header/subheader card
2. **Installation methods:** Homebrew command + direct download button to GitHub Releases
3. **Feature content:** Draft placeholder text based on BetterCapture's focus (native, free, open-source)
4. **Roadmap section:** Prominent card section similar to CTA, linking to GitHub Milestones
5. **Screenshots:** Placeholders for now, to be replaced by user later

---

## Dependencies & Links

- GitHub Releases: `https://github.com/jsattler/BetterCapture/releases`
- GitHub Milestones: `https://github.com/jsattler/BetterCapture/milestones`
- Homebrew package name: TBD (verify with user or assume `bettercapture`)
