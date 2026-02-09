<script lang="ts">
  interface Props {
    title: string;
    description: string;
    features: string[];
    imageUrl: string;
    screenshotUrl?: string;
    badges?: string[];
    reverse?: boolean;
  }

  let { title, description, features, imageUrl, screenshotUrl, badges, reverse = false }: Props = $props();
</script>

<div class="grid md:grid-cols-2 rounded-2xl sm:rounded-3xl overflow-hidden shadow-lg max-w-lg md:max-w-3xl lg:max-w-4xl xl:max-w-none mx-auto">
  {#if reverse}
    <!-- Content first on mobile, image on left for desktop -->
    <!-- Content -->
    <div class="bg-gray-50 p-5 sm:p-6 md:p-8 flex flex-col justify-center min-h-[200px] sm:min-h-[240px] order-1 md:order-2">
      <h3 class="text-xl sm:text-2xl md:text-3xl font-bold text-gray-900 mb-3 sm:mb-4">{title}</h3>
      <p class="text-sm sm:text-base text-gray-600 mb-4 sm:mb-6">{description}</p>

      <ul class="space-y-2 sm:space-y-3">
        {#each features as feature}
          <li class="flex items-start gap-2 sm:gap-3">
            <svg class="w-4 h-4 sm:w-5 sm:h-5 text-green-600 mt-0.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
            </svg>
            <span class="text-sm sm:text-base text-gray-700">{feature}</span>
          </li>
        {/each}
      </ul>
    </div>

    <!-- Image -->
    <div class="relative h-48 sm:h-64 md:h-96 xl:h-[32rem] order-2 md:order-1">
      <img src={imageUrl} alt="" class="w-full h-full object-cover" />
      <div class="absolute inset-0"></div>
      {#if screenshotUrl}
        <div class="absolute bottom-0 -right-2 sm:-right-4 md:-right-6 lg:-right-12 p-3 sm:p-4 md:p-6 translate-y-1/4 sm:translate-y-1/3 md:translate-y-1/2">
          <img 
            src={screenshotUrl} 
            alt="" 
            class="w-32 sm:w-48 md:w-64 lg:w-80 xl:w-96 rounded-xl sm:rounded-2xl" 
          />
        </div>
      {:else if badges && badges.length > 0}
        <div class="absolute inset-0 flex items-center justify-center p-4 sm:p-8 md:p-12">
          <div class="flex flex-wrap gap-2 sm:gap-4 justify-center max-w-lg">
            {#each badges as badge}
              <span class="px-4 py-2 sm:px-6 sm:py-3 md:px-8 md:py-4 bg-white/10 backdrop-blur-md rounded-full text-white text-sm sm:text-lg md:text-2xl font-bold shadow-lg inline-block">
                {badge}
              </span>
            {/each}
          </div>
        </div>
      {:else}
        <div class="absolute inset-0 flex items-center justify-center p-6 sm:p-8 md:p-12">
          <div class="bg-white/10 backdrop-blur-sm rounded-xl p-4 sm:p-6 md:p-8 border border-white/20">
            <div class="text-center text-white/60">
              <svg class="w-8 h-8 sm:w-10 sm:h-10 md:w-12 md:h-12 mx-auto mb-2 opacity-50" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              <p class="text-xs sm:text-sm">Screenshot</p>
            </div>
          </div>
        </div>
      {/if}
    </div>
  {:else}
    <!-- Content first on mobile, content on left for desktop -->
    <!-- Content -->
    <div class="bg-gray-50 p-5 sm:p-6 md:p-8 flex flex-col justify-center min-h-[200px] sm:min-h-[240px] order-1">
      <h3 class="text-xl sm:text-2xl md:text-3xl font-bold text-gray-900 mb-3 sm:mb-4">{title}</h3>
      <p class="text-sm sm:text-base text-gray-600 mb-4 sm:mb-6">{description}</p>

      <ul class="space-y-2 sm:space-y-3">
        {#each features as feature}
          <li class="flex items-start gap-2 sm:gap-3">
            <svg class="w-4 h-4 sm:w-5 sm:h-5 text-green-600 mt-0.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
            </svg>
            <span class="text-sm sm:text-base text-gray-700">{feature}</span>
          </li>
        {/each}
      </ul>
    </div>

    <!-- Image -->
    <div class="relative h-48 sm:h-64 md:h-96 xl:h-[32rem] order-2">
      <img src={imageUrl} alt="" class="w-full h-full object-cover" />
      <div class="absolute inset-0"></div>
      {#if screenshotUrl}
        <div class="absolute bottom-0 -right-2 sm:-right-4 md:-right-6 lg:-right-12 p-3 sm:p-4 md:p-6 translate-y-1/4 sm:translate-y-1/3 md:translate-y-1/2">
          <img 
            src={screenshotUrl} 
            alt="" 
            class="w-32 sm:w-48 md:w-64 lg:w-80 xl:w-96 opacity-80 rounded-xl sm:rounded-2xl" 
          />
        </div>
      {:else if badges && badges.length > 0}
        <div class="absolute inset-0 flex items-center justify-center p-4 sm:p-8 md:p-12">
          <div class="flex flex-wrap gap-2 sm:gap-4 justify-center max-w-lg">
            {#each badges as badge}
              <span class="px-4 py-2 sm:px-6 sm:py-3 md:px-8 md:py-4 bg-white/10 backdrop-blur-md rounded-full text-white text-sm sm:text-lg md:text-2xl font-bold shadow-lg inline-block">
                {badge}
              </span>
            {/each}
          </div>
        </div>
      {:else}
        <div class="absolute inset-0 flex items-center justify-center p-6 sm:p-8 md:p-12">
          <div class="bg-white/10 backdrop-blur-sm rounded-xl p-4 sm:p-6 md:p-8 border border-white/20">
            <div class="text-center text-white/60">
              <svg class="w-8 h-8 sm:w-10 sm:h-10 md:w-12 md:h-12 mx-auto mb-2 opacity-50" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              <p class="text-xs sm:text-sm">Screenshot</p>
            </div>
          </div>
        </div>
      {/if}
    </div>
  {/if}
</div>
