<x-filament::section>
    <x-slot name="heading">Online players @if($roster['count'] !== null) &middot; {{ $roster['count'] }} / {{ $roster['max'] }} @endif</x-slot>
    <div class="space-y-3">
        @if(count($roster['names']))
            <ul class="space-y-2" aria-label="Connected players">
                @foreach($roster['names'] as $name)
                    <li class="rounded-lg bg-gray-50 px-4 py-3 font-medium dark:bg-white/5">{{ $name }}</li>
                @endforeach
            </ul>
        @endif
        <p class="text-sm text-gray-500 dark:text-gray-400">{{ $roster['message'] }}</p>
        <p class="text-xs text-gray-500 dark:text-gray-400">Checked {{ $roster['checked'] }} &middot; refreshes every 30 seconds</p>
    </div>
</x-filament::section>
