<x-filament-panels::page>
    <div wire:poll.30s>
        @include('enshrouded-roster::roster', ['roster' => $this->roster()])
    </div>
    <x-filament::section heading="Kick and ban">
        <p class="text-sm text-gray-500 dark:text-gray-400">Join with a role that has Kick/Ban permission, then open the in-game Social tab and select the player. Live moderation from this panel is unavailable. Ban-list file edits require the game server to be stopped.</p>
    </x-filament::section>
</x-filament-panels::page>
