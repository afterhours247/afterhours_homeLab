<?php
namespace Afterhours\EnshroudedRoster\Filament\Server\Pages;

use Afterhours\EnshroudedRoster\Services\Roster;
use Filament\Facades\Filament;
use Filament\Pages\Page;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Concerns\InteractsWithTable;
use Filament\Tables\Contracts\HasTable;
use Filament\Tables\Table;
use Illuminate\Pagination\LengthAwarePaginator;

class OnlinePlayers extends Page implements HasTable
{
    use InteractsWithTable;
    protected static string|\BackedEnum|null $navigationIcon = 'tabler-users-group';
    protected static ?string $navigationLabel = 'Online players';
    protected static ?string $title = 'Online players';
    protected static ?string $slug = 'online-players';
    protected static ?int $navigationSort = 30;
    protected string $view = 'enshrouded-roster::pages.online-players';
    public static function canAccess(): bool { return Roster::authorized(Filament::getTenant()) && parent::canAccess(); }
    public function roster(): array { return app(Roster::class)->read(Filament::getTenant()); }
    public function table(Table $table): Table
    {
        return $table
            ->records(function (int $page, int $recordsPerPage) {
                $names = $this->roster()['names'];
                $page = max(1, min($page, (int) max(1, ceil(count($names) / $recordsPerPage))));
                $rows = array_map(fn ($name) => ['name' => $name], $names);
                return new LengthAwarePaginator(array_slice($rows, ($page - 1) * $recordsPerPage, $recordsPerPage), count($rows), $recordsPerPage, $page);
            })
            ->columns([TextColumn::make('name')->label('Player')])
            ->paginated([5, 10, 25])
            ->defaultPaginationPageOption(5)
            ->poll('30s')
            ->emptyStateHeading('No verified players to display')
            ->emptyStateDescription('Check the live count and roster status above.');
    }
}
