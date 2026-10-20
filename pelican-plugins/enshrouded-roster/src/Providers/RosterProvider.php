<?php
namespace Afterhours\EnshroudedRoster\Providers;

use App\Enums\ConsoleWidgetPosition;
use App\Filament\Server\Pages\Console;
use Afterhours\EnshroudedRoster\Filament\Server\Widgets\OnlinePlayersWidget;
use Illuminate\Support\ServiceProvider;

class RosterProvider extends ServiceProvider
{
    public function boot(): void
    {
        Console::registerCustomWidgets(ConsoleWidgetPosition::AboveConsole, [OnlinePlayersWidget::class]);
    }
}
