<script lang="ts">
  interface Props {
    title: string;
    description: string;
    features: string[];
    imageUrl: string;
    alt?: string;
    screenshotUrl?: string;
    screenshotAlt?: string;
    reverse?: boolean;
  }

  let { title, description, features, imageUrl, alt = "", screenshotUrl, screenshotAlt = "", reverse = false }: Props = $props();
</script>

<div class="grid md:grid-cols-2 rounded-2xl sm:rounded-3xl overflow-hidden shadow-lg max-w-lg md:max-w-3xl lg:max-w-4xl xl:max-w-none mx-auto border border-white/10">
  {#if reverse}
    <!-- Content first on mobile, image on left for desktop -->
    <!-- Content -->
    <div class="bg-white/5 p-5 sm:p-6 md:p-8 flex flex-col justify-center min-h-[200px] sm:min-h-[240px] order-1 md:order-2">
      <h3 class="text-xl sm:text-2xl md:text-3xl font-bold text-white mb-3 sm:mb-4">{title}</h3>
      <p class="text-sm sm:text-base text-white/60 mb-4 sm:mb-6">{description}</p>

      <ul class="space-y-2 sm:space-y-3">
        {#each features as feature}
          <li class="flex items-start gap-2 sm:gap-3">
            <svg class="w-4 h-4 sm:w-5 sm:h-5 text-green-400 mt-0.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
            </svg>
            <span class="text-sm sm:text-base text-white/70">{feature}</span>
          </li>
        {/each}
      </ul>
    </div>

    <!-- Image -->
    <div class="relative h-48 sm:h-64 md:h-96 xl:h-[32rem] order-2 md:order-1">
      <img src={imageUrl} alt={alt} class="w-full h-full object-cover" />
      <div class="absolute inset-0"></div>
      {#if screenshotUrl}
        <div class="absolute bottom-0 -right-2 sm:-right-4 md:-right-6 lg:-right-12 p-3 sm:p-4 md:p-6 translate-y-1/4 sm:translate-y-1/3 md:translate-y-1/2">
          <img 
            src={screenshotUrl} 
            alt={screenshotAlt} 
            class="w-32 sm:w-48 md:w-64 lg:w-80 xl:w-96 rounded-xl sm:rounded-2xl" 
          />
        </div>
      {/if}
    </div>
  {:else}
    <!-- Content first on mobile, content on left for desktop -->
    <!-- Content -->
    <div class="bg-white/5 p-5 sm:p-6 md:p-8 flex flex-col justify-center min-h-[200px] sm:min-h-[240px] order-1">
      <h3 class="text-xl sm:text-2xl md:text-3xl font-bold text-white mb-3 sm:mb-4">{title}</h3>
      <p class="text-sm sm:text-base text-white/60 mb-4 sm:mb-6">{description}</p>

      <ul class="space-y-2 sm:space-y-3">
        {#each features as feature}
          <li class="flex items-start gap-2 sm:gap-3">
            <svg class="w-4 h-4 sm:w-5 sm:h-5 text-green-400 mt-0.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
            </svg>
            <span class="text-sm sm:text-base text-white/70">{feature}</span>
          </li>
        {/each}
      </ul>
    </div>

    <!-- Image -->
    <div class="relative h-48 sm:h-64 md:h-96 xl:h-[32rem] order-2">
      <img src={imageUrl} alt={alt} class="w-full h-full object-cover" />
      <div class="absolute inset-0"></div>
      {#if screenshotUrl}
        <div class="absolute bottom-0 -right-2 sm:-right-4 md:-right-6 lg:-right-12 p-3 sm:p-4 md:p-6 translate-y-1/4 sm:translate-y-1/3 md:translate-y-1/2">
          <img 
            src={screenshotUrl} 
            alt={screenshotAlt} 
            class="w-32 sm:w-48 md:w-64 lg:w-80 xl:w-96 opacity-80 rounded-xl sm:rounded-2xl" 
          />
        </div>
      {/if}
    </div>
  {/if}
</div>
