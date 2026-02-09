<script lang="ts">
  const currentYear = new Date().getFullYear();
  const base = import.meta.env.BASE_URL;
</script>

<footer class="bg-gray-50 border-t border-gray-200 py-8 sm:py-10 md:py-12 px-4 sm:px-6">
  <div class="max-w-7xl mx-auto">
    <div class="flex flex-col md:flex-row justify-between items-start gap-6 sm:gap-8 mb-6 sm:mb-8">
      <!-- Brand -->
      <div>
        <div class="flex items-center gap-2 mb-3 sm:mb-4">
          <img src="{base}favicon.svg" alt="BetterCapture logo" class="w-5 h-5 sm:w-6 sm:h-6" />
          <span class="text-lg sm:text-xl font-semibold text-gray-900">BetterCapture</span>
        </div>
        <p class="text-gray-600 text-xs sm:text-sm max-w-xs">
          A native, open-source screen recorder for macOS. Free forever.
        </p>
      </div>

      <!-- Links -->
      <div class="flex flex-wrap gap-6 sm:gap-8 md:gap-12">
        <div>
          <h4 class="text-gray-900 font-semibold mb-2 sm:mb-3 text-sm sm:text-base">Resources</h4>
          <ul class="space-y-1.5 sm:space-y-2">
            <li>
              <a 
                href="https://github.com/jsattler/BetterCapture/releases" 
                target="_blank"
                rel="noopener noreferrer"
                class="text-gray-600 hover:text-gray-900 transition-colors text-xs sm:text-sm"
              >
                Changelog
              </a>
            </li>
            <li>
              <a 
                href="https://github.com/jsattler/BetterCapture" 
                target="_blank"
                rel="noopener noreferrer"
                class="text-gray-600 hover:text-gray-900 transition-colors text-xs sm:text-sm"
              >
                GitHub
              </a>
            </li>
          </ul>
        </div>

        <div>
          <h4 class="text-gray-900 font-semibold mb-2 sm:mb-3 text-sm sm:text-base">Legal</h4>
          <ul class="space-y-1.5 sm:space-y-2">
            <li>
              <a 
                href="https://github.com/jsattler/BetterCapture/blob/main/LICENSE" 
                target="_blank"
                rel="noopener noreferrer"
                class="text-gray-600 hover:text-gray-900 transition-colors text-xs sm:text-sm"
              >
                MIT License
              </a>
            </li>
            <li>
              <a href="{base}privacy-policy" class="text-gray-600 hover:text-gray-900 transition-colors text-xs sm:text-sm">
                Privacy Policy
              </a>
            </li>
          </ul>
        </div>
      </div>
    </div>

    <!-- Bottom -->
    <div class="pt-6 sm:pt-8 border-t border-gray-200 flex flex-col sm:flex-row justify-between items-center gap-3 sm:gap-4">
      <p class="text-gray-500 text-xs sm:text-sm text-center sm:text-left">
        &copy; {currentYear} Joshua Sattler. Released under the MIT License.
      </p>
      <a 
        href="https://github.com/jsattler/BetterCapture" 
        target="_blank"
        rel="noopener noreferrer"
        class="text-gray-500 hover:text-gray-700 transition-colors"
      >
        <span class="sr-only">GitHub</span>
        <svg class="w-5 h-5 sm:w-6 sm:h-6" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
          <path fill-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" clip-rule="evenodd" />
        </svg>
      </a>
    </div>
  </div>
</footer>
