<x-filament-panels::page>
    <div wire:poll.30s>
        @php($roster = $this->roster())
        <x-filament::section>
            <x-slot name="heading">Online players @if($roster['count'] !== null) &middot; {{ $roster['count'] }} / {{ $roster['max'] }} @endif</x-slot>
            <p class="text-sm text-gray-500 dark:text-gray-400">{{ $roster['message'] }}</p>
            <p class="text-xs text-gray-500 dark:text-gray-400">Checked {{ $roster['checked'] }} &middot; refreshes every 30 seconds</p>
        </x-filament::section>
    </div>
    {{ $this->table }}
    <x-filament::section heading="Kick and ban">
        <p class="text-sm text-gray-500 dark:text-gray-400">Join with a role that has Kick/Ban permission, then open the in-game Social tab and select the player. Live moderation from this panel is unavailable. Ban-list file edits require the game server to be stopped.</p>
    </x-filament::section>
</x-filament-panels::page>
