<?php
namespace Afterhours\EnshroudedRoster\Filament\Server\Widgets;

use Afterhours\EnshroudedRoster\Services\Roster;
use Filament\Facades\Filament;
use Filament\Widgets\Widget;

class OnlinePlayersWidget extends Widget
{
    protected string $view = 'enshrouded-roster::widgets.online-players';
    protected int|string|array $columnSpan = 'full';
    public static function canView(): bool { return Roster::authorized(Filament::getTenant()); }
    public function roster(): array { return app(Roster::class)->read(Filament::getTenant()); }
}
