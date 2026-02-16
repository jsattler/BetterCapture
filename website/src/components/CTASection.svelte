<script lang="ts">
  let videoUrl = "https://github.com/jsattler/BetterCapture/releases/latest/download/BetterCapture.dmg";
  
  let copied = $state(false);
  
  async function copyToClipboard() {
    try {
      await navigator.clipboard.writeText('brew install jsattler/tap/bettercapture');
      copied = true;
      setTimeout(() => {
        copied = false;
      }, 2000);
    } catch (err) {
      console.error('Failed to copy:', err);
    }
  }
</script>

<section class="py-12 sm:py-16 md:py-20 px-4 sm:px-6">
  <div class="max-w-lg sm:max-w-2xl md:max-w-4xl lg:max-w-5xl xl:max-w-5xl 2xl:max-w-5xl mx-auto">
    <div class="bg-white/5 rounded-2xl sm:rounded-3xl overflow-hidden border border-white/10">
      <div class="p-6 sm:p-8 md:p-12 lg:p-16 xl:p-20 text-center">
        <h2 class="text-2xl sm:text-3xl md:text-4xl lg:text-5xl font-bold text-white mb-4 sm:mb-6">
          Ready to Start Recording?
        </h2>
        <p class="text-base sm:text-lg md:text-xl text-white/60 mb-6 sm:mb-8 md:mb-10 max-w-2xl mx-auto">
          Download BetterCapture for free and start recording your Mac screen with system audio, ProRes support, and zero watermarks. No sign-up required.
        </p>
        
        <!-- Installation section -->
        <div class="flex flex-col items-center gap-3 sm:gap-4 max-w-md sm:max-w-lg mx-auto">
          <!-- Homebrew command -->
          <div class="w-full bg-white/5 rounded-xl px-3 sm:px-4 py-2.5 sm:py-3 font-mono text-xs sm:text-sm text-white/90 flex items-center justify-between gap-2 sm:gap-3 border border-white/10">
            <code class="truncate">brew install jsattler/tap/bettercapture</code>
            <button 
              onclick={copyToClipboard}
              class="flex-shrink-0 p-1.5 sm:p-2 hover:bg-white/10 rounded-lg transition-colors"
              aria-label="Copy to clipboard"
            >
              {#if copied}
                <svg class="w-4 h-4 sm:w-5 sm:h-5 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                </svg>
              {:else}
                <svg class="w-4 h-4 sm:w-5 sm:h-5 text-white/70" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
              {/if}
            </button>
          </div>
          
          <!-- Download button -->
          <a 
            href="https://github.com/jsattler/BetterCapture/releases/latest"
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center gap-2 px-5 sm:px-6 py-2.5 sm:py-3 bg-white text-gray-900 font-semibold rounded-xl hover:bg-gray-100 transition-colors shadow-lg text-sm sm:text-base"
          >
            <svg class="w-4 h-4 sm:w-5 sm:h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
            </svg>
            Download from GitHub
          </a>
          
          <!-- System requirement note -->
          <p class="text-xs text-white/40 mt-1 sm:mt-2">
            (Requires macOS 15.2 Sequoia or later)
          </p>
        </div>
      </div>
      
      <!-- Bottom branding section -->
      <div class="relative h-36 sm:h-48 md:h-64 lg:h-72 overflow-hidden rounded-2xl sm:rounded-3xl m-2 sm:m-3">
        <img
          src="/hero-wallpaper-2.jpg"
          alt=""
          class="w-full h-full object-cover"
        />
        <div class="absolute inset-0 flex items-center justify-center">
          <div class="flex items-center gap-2 sm:gap-3 md:gap-4">
            <img src="/favicon.svg" alt="BetterCapture logo" class="w-8 h-8 sm:w-10 sm:h-10 md:w-12 md:h-12 lg:w-16 lg:h-16" />
            <span class="text-xl sm:text-2xl md:text-3xl lg:text-5xl font-semibold text-white">BetterCapture</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</section>
