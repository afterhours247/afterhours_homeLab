<?php
namespace Afterhours\EnshroudedRoster\Services;

use App\Enums\SubuserPermission;
use App\Models\Server;
use App\Repositories\Daemon\DaemonFileRepository;
use App\Repositories\Daemon\DaemonServerRepository;
use Illuminate\Support\Facades\Cache;
use Throwable;
use xPaw\SourceQuery\SourceQuery;

class Roster
{
    public static function supports(?Server $server): bool
    {
        return $server && str_contains(strtolower($server->egg->name), 'enshrouded');
    }

    public static function authorized(?Server $server): bool
    {
        return static::supports($server) && (bool) user()?->can(SubuserPermission::FileReadContent, $server);
    }

    /** Only parse the current complete session; never retain a roster from an earlier request. */
    public static function parse(string $log): array
    {
        $names = []; $complete = false; $uncertain = false; $last = -1;
        foreach (preg_split('/\r?\n/', $log) as $line) {
            if (preg_match('/\[\w\s+(\d+):(\d+):(\d+),\d+\]/', $line, $m)) {
                $time = (int)$m[1] * 3600 + (int)$m[2] * 60 + (int)$m[3];
                if ($time < $last) { $names = []; $complete = false; $uncertain = false; }
                $last = $time;
            }
            if (str_contains($line, "[Session] 'HostOnline' (up)")) {
                $names = []; $complete = true; $uncertain = false;
            }
            if (preg_match("/\[server\] Player '(.*)' logged in with Permissions:/u", $line, $m)) {
                if (isset($names[$m[1]])) { $uncertain = true; }
                $names[$m[1]] = true;
            }
            if (preg_match("/Remove Player '([^']+)'/u", $line, $m)) { unset($names[$m[1]]); }
            // Unattributed departures cannot safely be matched to a character name.
            if (str_contains($line, 'Player removed. Player handle:')) { $uncertain = true; }
        }
        return ['names' => array_keys($names), 'complete' => $complete && !$uncertain];
    }

    public function read(Server $server): array
    {
        abort_unless(static::authorized($server), 403);
        return Cache::remember('enshrouded-roster:v1:'.$server->uuid, 15, function () use ($server) {
            $result = ['status' => 'unavailable', 'count' => null, 'max' => null, 'names' => [], 'checked' => now()->timezone(config('app.timezone', 'UTC'))->format('H:i:s T'), 'message' => 'Live player data is temporarily unavailable.'];
            try {
                $state = app(DaemonServerRepository::class)->setServer($server)->getDetails();
                if (($state['state'] ?? '') !== 'running') {
                    return array_replace($result, ['status' => 'offline', 'message' => 'Server is offline or starting.']);
                }
                $query = new SourceQuery();
                try {
                    $query->Connect($server->allocation->ip, $server->allocation->port, 2, SourceQuery::SOURCE);
                    $info = $query->GetInfo();
                } finally { $query->Disconnect(); }
                if ((int)($info['GameID'] ?? 0) !== 1203620) { return $result; }
                $result['count'] = (int)$info['Players']; $result['max'] = (int)$info['MaxPlayers'];
                if ($result['count'] === 0) {
                    return array_replace($result, ['status' => 'verified', 'message' => 'No players connected.']);
                }
                $log = app(DaemonFileRepository::class)->setServer($server)->getContent('/logs/enshrouded_server.log', 2 * 1024 * 1024);
                $parsed = static::parse($log);
                if (!$parsed['complete'] || count($parsed['names']) !== $result['count']) {
                    return array_replace($result, ['status' => 'count-only', 'message' => 'Names unavailable: session logs do not reliably match the live count.']);
                }
                return array_replace($result, ['status' => 'verified', 'names' => $parsed['names'], 'message' => 'Names from current-session logs; count checked live.']);
            } catch (Throwable $exception) {
                // Do not expose logs, tokens or internal exception details in the UI.
                if ($result['count'] !== null) { $result['status'] = 'count-only'; $result['message'] = 'Live count available; player names could not be verified.'; }
                return $result;
            }
        });
    }
}
