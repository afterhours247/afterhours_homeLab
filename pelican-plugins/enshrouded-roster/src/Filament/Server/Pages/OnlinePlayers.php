<?php
namespace Afterhours\EnshroudedRoster\Filament\Server\Pages;

use Afterhours\EnshroudedRoster\Services\Roster;
use Filament\Facades\Filament;
use Filament\Pages\Page;

class OnlinePlayers extends Page
{
    protected static string|\BackedEnum|null $navigationIcon = 'tabler-users-group';
    protected static ?string $navigationLabel = 'Online players';
    protected static ?string $title = 'Online players';
    protected static ?string $slug = 'online-players';
    protected static ?int $navigationSort = 30;
    protected string $view = 'enshrouded-roster::pages.online-players';
    public static function canAccess(): bool { return Roster::authorized(Filament::getTenant()) && parent::canAccess(); }
    public function roster(): array { return app(Roster::class)->read(Filament::getTenant()); }
}
