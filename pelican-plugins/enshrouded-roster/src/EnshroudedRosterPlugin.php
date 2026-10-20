<?php
namespace Afterhours\EnshroudedRoster;

use Filament\Contracts\Plugin;
use Filament\Panel;

class EnshroudedRosterPlugin implements Plugin
{
    public function getId(): string { return 'enshrouded-roster'; }
    public function register(Panel $panel): void
    {
        $panel->discoverPages(plugin_path($this->getId(), 'src/Filament/Server/Pages'), 'Afterhours\\EnshroudedRoster\\Filament\\Server\\Pages');
        $panel->discoverWidgets(plugin_path($this->getId(), 'src/Filament/Server/Widgets'), 'Afterhours\\EnshroudedRoster\\Filament\\Server\\Widgets');
    }
    public function boot(Panel $panel): void {}
}
