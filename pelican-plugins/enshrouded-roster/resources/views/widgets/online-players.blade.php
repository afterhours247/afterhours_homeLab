<x-filament-widgets::widget>
    <div wire:poll.30s>
        @include('enshrouded-roster::roster', ['roster' => $this->roster()])
    </div>
</x-filament-widgets::widget>
