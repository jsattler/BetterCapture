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

<section class="py-20 px-6">
  <div class="max-w-6xl mx-auto">
    <div class="bg-gray-50 rounded-3xl overflow-hidden">
      <div class="p-12 md:p-16 lg:p-20 text-center">
        <h2 class="text-3xl md:text-5xl font-bold text-gray-900 mb-6">
          Ready to Start Recording?
        </h2>
        <p class="text-lg md:text-xl text-gray-600 mb-10 max-w-2xl mx-auto">
          Install BetterCapture and experience screen recording the way it should be. Free, fast, and private.
        </p>
        
        <!-- Installation section -->
        <div class="flex flex-col items-center gap-4 max-w-lg mx-auto">
          <!-- Homebrew command -->
          <div class="w-full bg-black/40 backdrop-blur-sm rounded-xl px-4 py-3 font-mono text-sm text-white/90 flex items-center justify-between gap-3 border border-white/10">
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
      
      <!-- Bottom branding section -->
      <div class="relative h-48 md:h-72 overflow-hidden rounded-3xl m-3">
        <img
          src="{base}hero-wallpaper-2.jpg"
          alt=""
          class="w-full h-full object-cover"
        />
        <div class="absolute inset-0 flex items-center justify-center">
          <div class="flex items-center gap-4">
            <img src="{base}favicon.svg" alt="BetterCapture logo" class="w-12 h-12 md:w-16 md:h-16" />
            <span class="text-3xl md:text-5xl font-semibold text-white">BetterCapture</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</section>
