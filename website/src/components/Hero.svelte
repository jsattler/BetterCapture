<script lang="ts">
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

<section class="relative pt-20 sm:pt-24 md:pt-28 lg:pt-40 xl:pt-44 pb-8 px-4 md:px-6 lg:px-12 xl:px-16">
  <div class="mx-auto w-full max-w-[1400px]">
    <div class="flex flex-col lg:grid lg:grid-cols-7 xl:grid-cols-5 2xl:grid-cols-3 gap-6 md:gap-8 lg:gap-12 w-full items-start">
      <!-- Left column - Content -->
      <div class="w-full lg:col-span-5 xl:col-span-3 2xl:col-span-2 text-center lg:text-left max-w-2xl mx-auto lg:max-w-none">
        <h1 class="text-2xl sm:text-3xl md:text-4xl lg:text-4xl xl:text-6xl 2xl:text-6xl text-white mb-4 md:mb-6">The macOS screen recorder <br class="hidden xl:inline" />for the rest of us</h1>
        <p class="text-sm sm:text-base md:text-lg text-white/70 mb-4 md:mb-6 lg:mb-8 max-w-xl mx-auto lg:mx-0">
          Forever free and open-source. A lightweight, and intuitive screen recorder with a native look and feel.
        </p>
        
        <!-- Installation section -->
        <div class="space-y-3">
          <!-- Homebrew command + Download button -->
          <div class="flex flex-col sm:flex-row items-center gap-3 max-w-xl mx-auto lg:mx-0">
            <div class="w-full sm:flex-1 bg-white/5 rounded-xl px-3 sm:px-4 py-3 font-mono text-xs sm:text-sm text-white/90 flex items-center justify-between gap-2 sm:gap-3 border border-white/10">
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
            <span class="text-xs text-white/30 hidden sm:block">or</span>
            <a 
              href="https://github.com/jsattler/BetterCapture/releases/latest"
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center gap-2 px-5 sm:px-6 py-2.5 sm:py-3 bg-white text-gray-900 font-semibold rounded-xl hover:bg-gray-100 transition-colors shadow-lg text-sm sm:text-base whitespace-nowrap"
            >
              <svg class="w-4 h-4 sm:w-5 sm:h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
              </svg>
              Download from GitHub
            </a>
          </div>
          
          <!-- System requirement note -->
          <p class="text-xs text-white/40 mt-2">
            (Requires macOS 15.2 Sequoia or later)
          </p>
        </div>
      </div>
      
      <!-- Right column - Screenshot (hidden on mobile) -->
      <div class="hidden lg:flex lg:col-span-2 xl:col-span-2 2xl:col-span-1 items-center justify-center lg:-mb-48 xl:-mb-56">
        <div class="relative w-full -translate-y-44 -translate-x-24 scale-90 xl:scale-100">
          <!-- Glow behind the image -->
          <div class="absolute inset-0 -z-10 translate-y-4 scale-95 rounded-3xl bg-black/40 blur-2xl"></div>
          <!-- 3D perspective container -->
          <div class="screenshot-perspective">
            <img 
              src="/screenshot-basic.png" 
              alt="Better Capture Screenshot"
              class="screenshot-tilt rounded-2xl w-full h-auto shadow-2xl"
            />
          </div>
        </div>
      </div>
    </div>
  </div>
</section>

<style>
  .screenshot-perspective {
    perspective: 800px;
    transform-style: preserve-3d;
  }

  .screenshot-tilt {
    transform: rotateY(-28deg) rotateX(32deg);
    transform-origin: center center;
    mask-image: linear-gradient(to bottom, black 50%, transparent 85%);
    -webkit-mask-image: linear-gradient(to bottom, black 50%, transparent 85%);
    backface-visibility: hidden;
  }
</style>
