<script lang="ts">
  const currentYear = new Date().getFullYear();
</script>

<svelte:head>
  <script type="text/javascript" src="https://cdnjs.buymeacoffee.com/1.0.0/button.prod.min.js" data-name="bmc-button" data-slug="jsattler" data-color="#FFDD00" data-emoji="☕" data-font="Cookie" data-text="Buy me a coffee" data-outline-color="#000000" data-font-color="#000000" data-coffee-color="#ffffff"></script>
</svelte:head>

<footer class="border-t border-white/10 py-8 sm:py-10 md:py-12 px-4 sm:px-6">
  <div class="max-w-7xl mx-auto">
    <div class="flex flex-col lg:flex-row justify-between items-start gap-6 sm:gap-8 mb-6 sm:mb-8">
      <!-- Brand -->
      <div class="flex-1">
        <div class="flex items-center gap-2 mb-3 sm:mb-4">
          <img src="/favicon.svg" alt="BetterCapture logo" class="w-5 h-5 sm:w-6 sm:h-6" />
          <span class="text-lg sm:text-xl font-semibold text-white">BetterCapture</span>
        </div>
        <p class="text-white/50 text-xs sm:text-sm max-w-xs">
          A native, open-source screen recorder for macOS. Free forever.
        </p>
      </div>

      <!-- Support Section -->
      <div class="flex-1 text-center">
        <p class="text-white/50 text-xs sm:text-sm mb-3">
          Enjoying BetterCapture? Consider supporting its development.
        </p>
        <div class="flex flex-col sm:flex-row items-center justify-center gap-2 sm:gap-3">
          <iframe 
            src="https://github.com/sponsors/jsattler/button" 
            title="Sponsor jsattler" 
            height="32" 
            width="114" 
            style="border: 0;"
          ></iframe>
          <a href="https://www.buymeacoffee.com/jsattler" target="_blank" rel="noopener noreferrer">
            <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 32px; width: auto; border-radius: 6px;">
          </a>
        </div>
      </div>

      <!-- Links -->
      <div class="flex-1 flex flex-wrap gap-6 sm:gap-8 md:gap-12 justify-end">
        <div>
          <h4 class="text-white font-semibold mb-2 sm:mb-3 text-sm sm:text-base">Resources</h4>
          <ul class="space-y-1.5 sm:space-y-2">
            <li>
              <a 
                href="https://github.com/jsattler/BetterCapture/releases" 
                target="_blank"
                rel="noopener noreferrer"
                class="text-white/50 hover:text-white transition-colors text-xs sm:text-sm"
              >
                Changelog
              </a>
            </li>
            <li>
              <a 
                href="https://github.com/jsattler/BetterCapture" 
                target="_blank"
                rel="noopener noreferrer"
                class="text-white/50 hover:text-white transition-colors text-xs sm:text-sm"
              >
                GitHub
              </a>
            </li>
          </ul>
        </div>

        <div>
          <h4 class="text-white font-semibold mb-2 sm:mb-3 text-sm sm:text-base">Legal</h4>
          <ul class="space-y-1.5 sm:space-y-2">
            <li>
              <a 
                href="https://github.com/jsattler/BetterCapture/blob/main/LICENSE" 
                target="_blank"
                rel="noopener noreferrer"
                class="text-white/50 hover:text-white transition-colors text-xs sm:text-sm"
              >
                MIT License
              </a>
            </li>
            <li>
              <a href="/privacy-policy" class="text-white/50 hover:text-white transition-colors text-xs sm:text-sm">
                Privacy Policy
              </a>
            </li>
          </ul>
        </div>
      </div>
    </div>

    <!-- Bottom -->
    <div class="pt-6 sm:pt-8 border-t border-white/10 flex flex-col sm:flex-row justify-between items-center gap-3 sm:gap-4">
      <p class="text-white/40 text-xs sm:text-sm text-center sm:text-left">
        &copy; {currentYear} Joshua Sattler. Released under the MIT License.
      </p>
      <a 
        href="https://github.com/jsattler/BetterCapture" 
        target="_blank"
        rel="noopener noreferrer"
        class="text-white/40 hover:text-white/70 transition-colors"
      >
        <span class="sr-only">GitHub</span>
        <svg class="w-5 h-5 sm:w-6 sm:h-6" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
          <path fill-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" clip-rule="evenodd" />
        </svg>
      </a>
    </div>
  </div>
</footer>
