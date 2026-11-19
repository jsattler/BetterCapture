<script lang="ts">
  import type { FAQ } from '../data/faqs';

  let { faqs }: { faqs: FAQ[] } = $props();
</script>

<section id="faq" class="py-12 sm:py-16 md:py-20 px-4 sm:px-6">
  <div class="max-w-3xl mx-auto">
    <h2 class="text-2xl sm:text-3xl md:text-4xl lg:text-5xl font-bold text-white mb-8 sm:mb-12 text-center">Frequently Asked Questions</h2>

    <div class="space-y-3">
      {#each faqs as faq}
        <details class="group bg-white/5 rounded-xl border border-white/10 px-5 py-4">
          <summary class="flex items-center justify-between gap-4 cursor-pointer list-none">
            <h3 class="text-base sm:text-lg font-semibold text-white">{faq.question}</h3>
            <svg class="w-5 h-5 text-white/60 flex-shrink-0 transition-transform group-open:rotate-180" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
            </svg>
          </summary>
          <p class="mt-3 text-sm sm:text-base text-white/60">{faq.answer}</p>
        </details>
      {/each}
    </div>
  </div>
</section>
