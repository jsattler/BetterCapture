<script lang="ts">
  import FeatureCard from './FeatureCard.svelte';

  const base = import.meta.env.BASE_URL;

  const features = [
    {
      title: "Feels Like Home",
      description: "BetterCapture is built with native macOS technologies, giving you a familiar, polished experience that integrates seamlessly into your workflow without getting in the way.",
      features: [
        "Built with SwiftUI and ScreenCaptureKit for native performance",
        "Uses macOS native Content Picker for intuitive selection",
        "Lives in your menu bar for instant access",
        "Follows Apple's Human Interface Guidelines"
      ],
      imageUrl: `${base}grainy-gradient-feat-1.jpg`,
      screenshotUrl: `${base}screenshot-basic.png`
    },
    {
      title: "Professional Recording",
      description: "Capture high-quality audio and video with advanced encoding options and professional features that go beyond basic screen recording.",
      features: [
        "Multiple codec support: ProRes 4444, HEVC, H.264",
        "Alpha channel support for transparency",
        "Record system audio and microphone simultaneously",
        "Content filtering to exclude specific windows"
      ],
      imageUrl: `${base}grainy-gradient-feat-2.jpg`,
      badges: ["ProRes 4444", "HEVC", "H.264"]
    },
    {
      title: "Privacy-First",
      description: "Your recordings are yours alone. BetterCapture has no tracking, no analytics, no cloud uploads. Everything stays on your Mac, exactly where it should be.",
      features: [
        "No data collection or tracking whatsoever",
        "All recordings stored locally on your Mac",
        "No account required to use the app",
        "Open source so you can verify our claims"
      ],
      imageUrl: `${base}grainy-gradient-feat-3.jpg`,
      badges: ["No Tracking", "No Analytics", "100% Local"]
    },
    {
      title: "Open Source & Free",
      description: "BetterCapture is MIT licensed and completely free. No subscriptions, no trials, no premium tiers. Contribute to the project or simply enjoy a screen recorder that respects you.",
      features: [
        "100% free with no hidden costs",
        "MIT licensed for maximum freedom",
        "Community-driven development",
        "Contribute features or report bugs on GitHub"
      ],
      imageUrl: `${base}grainy-gradient-feat-4.jpg`,
      badges: ["MIT License", "100% Free", "Open Source"]
    }
  ];
</script>

<section id="features" class="py-20 px-6">
  <div class="max-w-3xl lg:max-w-4xl xl:max-w-5xl 2xl:max-w-6xl mx-auto">
    <div class="text-center mb-16">
      <h2 class="text-4xl md:text-5xl font-bold text-gray-900 mb-4">Simple, Powerful, Private</h2>
      <p class="text-xl text-gray-600 max-w-2xl mx-auto">
        Screen recording that respects your time and your privacy
      </p>
    </div>

    <div class="space-y-32">
      {#each features as feature, index}
        <FeatureCard {...feature} reverse={index % 2 === 1} />
      {/each}
    </div>
  </div>
</section>
