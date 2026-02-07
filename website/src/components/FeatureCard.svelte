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

<div class="grid md:grid-cols-2 rounded-3xl overflow-hidden shadow-lg md:max-w-3xl lg:max-w-4xl xl:max-w-none mx-auto">
  {#if reverse}
    <!-- Image on left -->
    <div class="relative h-64 md:h-96 xl:h-[32rem]">
      <img src={imageUrl} alt="" class="w-full h-full object-cover" />
      <div class="absolute inset-0"></div>
      {#if screenshotUrl}
        <div class="absolute bottom-0 -right-4 md:-right-6 lg:-right-12 p-4 md:p-6 translate-y-1/3 md:translate-y-1/2">
          <img 
            src={screenshotUrl} 
            alt="" 
            class="w-48 md:w-64 lg:w-80 xl:w-96 rounded-2xl" 
          />
        </div>
      {:else if badges && badges.length > 0}
        <div class="absolute inset-0 flex items-center justify-center p-12">
          <div class="flex flex-wrap gap-4 justify-center max-w-lg">
            {#each badges as badge}
              <span class="px-8 py-4 bg-white/10 backdrop-blur-md rounded-full text-white text-2xl font-bold shadow-lg inline-block">
                {badge}
              </span>
            {/each}
          </div>
        </div>
      {:else}
        <div class="absolute inset-0 flex items-center justify-center p-12">
          <div class="bg-white/10 backdrop-blur-sm rounded-xl p-8 border border-white/20">
            <div class="text-center text-white/60">
              <svg class="w-12 h-12 mx-auto mb-2 opacity-50" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              <p class="text-sm">Screenshot</p>
            </div>
          </div>
        </div>
      {/if}
    </div>

    <!-- Content on right -->
    <div class="bg-gray-50 p-6 md:p-8 flex flex-col justify-center min-h-[240px]">
      <h3 class="text-2xl md:text-3xl font-bold text-gray-900 mb-4">{title}</h3>
      <p class="text-gray-600 mb-6">{description}</p>

      <ul class="space-y-3">
        {#each features as feature}
          <li class="flex items-start gap-3">
            <svg class="w-5 h-5 text-green-600 mt-0.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
            </svg>
            <span class="text-gray-700">{feature}</span>
          </li>
        {/each}
      </ul>
    </div>
  {:else}
    <!-- Content on left -->
    <div class="bg-gray-50 p-6 md:p-8 flex flex-col justify-center min-h-[240px]">
      <h3 class="text-2xl md:text-3xl font-bold text-gray-900 mb-4">{title}</h3>
      <p class="text-gray-600 mb-6">{description}</p>

      <ul class="space-y-3">
        {#each features as feature}
          <li class="flex items-start gap-3">
            <svg class="w-5 h-5 text-green-600 mt-0.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
            </svg>
            <span class="text-gray-700">{feature}</span>
          </li>
        {/each}
      </ul>
    </div>

    <!-- Image on right -->
    <div class="relative h-64 md:h-96 xl:h-[32rem]">
      <img src={imageUrl} alt="" class="w-full h-full object-cover" />
      <div class="absolute inset-0"></div>
      {#if screenshotUrl}
        <div class="absolute bottom-0 -right-4 md:-right-6 lg:-right-12 p-4 md:p-6 translate-y-1/3 md:translate-y-1/2">
          <img 
            src={screenshotUrl} 
            alt="" 
            class="w-48 md:w-64 lg:w-80 xl:w-96 opacity-80 rounded-2xl" 
          />
        </div>
      {:else if badges && badges.length > 0}
        <div class="absolute inset-0 flex items-center justify-center p-12">
          <div class="flex flex-wrap gap-4 justify-center max-w-lg">
            {#each badges as badge}
              <span class="px-8 py-4 bg-white/10 backdrop-blur-md rounded-full text-white text-2xl font-bold shadow-lg inline-block">
                {badge}
              </span>
            {/each}
          </div>
        </div>
      {:else}
        <div class="absolute inset-0 flex items-center justify-center p-12">
          <div class="bg-white/10 backdrop-blur-sm rounded-xl p-8 border border-white/20">
            <div class="text-center text-white/60">
              <svg class="w-12 h-12 mx-auto mb-2 opacity-50" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
              </svg>
              <p class="text-sm">Screenshot</p>
            </div>
          </div>
        </div>
      {/if}
    </div>
  {/if}
</div>
