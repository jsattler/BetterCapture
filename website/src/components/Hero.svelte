<script lang="ts">
  const base = import.meta.env.BASE_URL;
  
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

<section class="relative pt-16 sm:pt-20 md:pt-24 lg:pt-28 pb-8 px-4 md:px-6 lg:px-8 min-h-screen flex items-center">
  <div class="mx-auto w-full">
    <!-- Main Hero Card -->
    <div class="relative w-full min-h-[70vh] sm:min-h-[75vh] md:min-h-[80vh] lg:min-h-[85vh] px-4 sm:px-6 md:px-8 lg:px-12 xl:px-16 rounded-2xl sm:rounded-3xl overflow-hidden flex items-center">
      <!-- Grainy gradient background -->
      <img 
        src="{base}hero-wallpaper-2.jpg" 
        alt="" 
        class="absolute inset-0 w-full h-full object-cover"
      />
      <div class="absolute inset-0"></div>
      
      <!-- Content -->
      <div class="relative w-full py-6 md:py-8 max-w-[1400px] mx-auto">
        <div class="flex flex-col lg:grid lg:grid-cols-7 2xl:grid-cols-3 gap-6 md:gap-8 lg:gap-12 w-full items-center">
          <!-- Left column - Frosted glass card -->
          <div class="w-full lg:col-span-5 2xl:col-span-2">
            <div class="bg-white/20 backdrop-blur-xl rounded-2xl p-6 sm:p-8 md:p-10 lg:p-12 text-center border border-white/30 shadow-2xl max-w-2xl mx-auto lg:max-w-none">
              <h1 class="text-2xl sm:text-3xl md:text-4xl lg:text-4xl xl:text-6xl 2xl:text-6xl text-white mb-4 md:mb-6">The macOS screen recorder for the rest of us</h1>
              <p class="text-sm sm:text-base md:text-lg text-white/90 mb-4 md:mb-6 lg:mb-8 max-w-xl mx-auto">
                Forever free and open-source. A lightweight, and intuitive screen recorder with a native look and feel.
              </p>
              
              <!-- Installation section -->
              <div class="space-y-3">
                <!-- Homebrew command -->
                <div class="flex flex-col sm:flex-row gap-3 max-w-md mx-auto">
                  <div class="flex-1 bg-black/40 backdrop-blur-sm rounded-xl px-3 sm:px-4 py-3 font-mono text-xs sm:text-sm text-white/90 flex items-center justify-between gap-2 sm:gap-3 border border-white/10">
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
                <p class="text-xs text-white/60 mt-2">
                  (Requires macOS 15.2 Sequoia or later)
                </p>
              </div>
            </div>
          </div>
          
          <!-- Right column - Screenshot (hidden on mobile) -->
          <div class="hidden lg:flex lg:col-span-2 2xl:col-span-1 items-center justify-center">
            <div class="w-full">
              <img 
                src="{base}screenshot-basic.png" 
                alt="Better Capture Screenshot"
                class="opacity-90 rounded-2xl w-full h-auto"
              />
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</section>
