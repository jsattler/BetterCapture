<script lang="ts">
  let videoUrl = "https://github.com/jsattler/BetterCapture/releases/latest/download/BetterCapture.dmg";
  const base = import.meta.env.BASE_URL;
  
  let copied = $state(false);
  
  async function copyToClipboard() {
    try {
      await navigator.clipboard.writeText('brew install --cask bettercapture');
      copied = true;
      setTimeout(() => {
        copied = false;
      }, 2000);
    } catch (err) {
      console.error('Failed to copy:', err);
    }
  }
</script>

<section class="relative pt-8 md:pt-12 lg:pt-12 pb-8 px-4 md:px-8 lg:px-18 h-screen flex items-center">
  <div class="mx-auto w-full">
    <!-- Main Hero Card -->
    <div class="relative w-full h-[80vh] md:h-[75vh] lg:h-[90vh] px-6 md:px-12 lg:px-40 rounded-3xl overflow-hidden flex items-center">
      <!-- Grainy gradient background -->
      <img 
        src="{base}hero-wallpaper-2.jpg" 
        alt="" 
        class="absolute inset-0 w-full h-full object-cover"
      />
      <div class="absolute inset-0"></div>
      
      <!-- Content -->
      <div class="relative w-full py-6 md:py-8">
        <div class="grid md:grid-cols-3 lg:grid-cols-5 gap-6 md:gap-8 lg:gap-12 w-full items-center">
          <!-- Left column (3/5 width) - Frosted glass card -->
          <div class="md:col-span-2 lg:col-span-3">
            <div class="bg-white/20 backdrop-blur-xl rounded-2xl p-4 md:p-8 lg:p-12 2xl:p-24 text-center border border-white/30 shadow-2xl">
              <h1 class="text-2xl md:text-3xl lg:text-4xl xl:text-5xl 2xl:text-7xl text-white mb-4 md:mb-6">The screen recorder for macOS you always wanted</h1>
              <p class="text-sm md:text-base lg:text-lg 2xl:text-xl text-white/90 mb-4 md:mb-6 lg:mb-8 2xl:mb-10 max-w-xl mx-auto">
                Forever free and open-source. A lightweight, and intuitive screen recorder with a native look and feel.
              </p>
              
              <!-- Installation section -->
              <div class="space-y-3 2xl:space-y-4">
                <!-- Homebrew command -->
                <div class="flex flex-col sm:flex-row gap-3 max-w-md mx-auto">
                  <div class="flex-1 bg-black/40 backdrop-blur-sm rounded-xl px-4 py-3 font-mono text-sm text-white/90 flex items-center justify-between gap-3 border border-white/10">
                    <code class="truncate">brew install --cask bettercapture</code>
                    <button 
                      onclick={copyToClipboard}
                      class="flex-shrink-0 p-2 hover:bg-white/10 rounded-lg transition-colors"
                      aria-label="Copy to clipboard"
                    >
                      {#if copied}
                        <svg class="w-5 h-5 text-green-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                        </svg>
                      {:else}
                        <svg class="w-5 h-5 text-white/70" fill="none" viewBox="0 0 24 24" stroke="currentColor">
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
                  class="inline-flex items-center gap-2 px-6 py-3 bg-white text-gray-900 font-semibold rounded-xl hover:bg-gray-100 transition-colors shadow-lg"
                >
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                  </svg>
                  Download from GitHub
                </a>
              </div>
            </div>
          </div>
          
          <!-- Right column (2/5 width) - Screenshot placeholder -->
          <div class="md:col-span-1 lg:col-span-2 flex items-center justify-center">
            <div class="w-full max-w-[200px] md:max-w-[300px] lg:max-w-[320px] 2xl:max-w-md">
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
