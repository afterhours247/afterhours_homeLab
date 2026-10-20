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
        $names = []; $handles = []; $pendingHandle = null;
        $complete = false; $uncertain = false; $last = -1;
        foreach (preg_split('/\r?\n/', $log) as $line) {
            if (preg_match('/\[\w\s+(\d+):(\d+):(\d+),\d+\]/', $line, $m)) {
                $time = (int)$m[1] * 3600 + (int)$m[2] * 60 + (int)$m[3];
                if ($time < $last) { $names = []; $handles = []; $pendingHandle = null; $complete = false; $uncertain = false; }
                $last = $time;
            }
            if (str_contains($line, "[Session] 'HostOnline' (up)")) {
                $names = []; $handles = []; $pendingHandle = null; $complete = true; $uncertain = false;
            }
            if (preg_match("/\[server\] Machine '[^']+': Player '(\d+\(\d+\))' logged in/", $line, $m)) {
                $pendingHandle = $m[1];
            }
            if (preg_match("/\[server\] Player '(.*)' logged in with Permissions:/u", $line, $m)) {
                if (isset($names[$m[1]])) { $uncertain = true; }
                $names[$m[1]] = true;
                if ($pendingHandle !== null) { $handles[$pendingHandle] = $m[1]; $pendingHandle = null; }
            }
            if (preg_match("/\[server\] Remove Player '(.*)'/u", $line, $m)) { unset($names[$m[1]]); }
            // Unattributed departures cannot safely be matched to a character name.
            if (preg_match('/Player removed\. Player handle: (\d+\(\d+\))/', $line, $m)) {
                if (isset($handles[$m[1]])) { unset($names[$handles[$m[1]]], $handles[$m[1]]); }
                else { $uncertain = true; }
            }
        }
        return ['names' => array_keys($names), 'complete' => $complete && !$uncertain];
    }

    /** Only consider bounded, regular archives written during this game process. */
    public static function sessionArchives(array $entries, float $startedAt): array
    {
        $files = array_filter($entries, function ($entry) use ($startedAt) {
            $name = $entry['name'] ?? '';
            return ($entry['file'] ?? false) && !($entry['symlink'] ?? true)
                && basename($name) === $name && str_starts_with($name, 'enshrouded_server_')
                && str_ends_with($name, '.log') && ($entry['size'] ?? 0) > 0
                && $entry['size'] <= 2 * 1024 * 1024
                && strtotime($entry['modified'] ?? '') >= $startedAt;
        });
        usort($files, fn ($a, $b) => strtotime($b['modified']) <=> strtotime($a['modified']));
        return array_slice($files, 0, 3);
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
                $files = app(DaemonFileRepository::class)->setServer($server);
                $log = $files->getContent('/logs/enshrouded_server.log', 2 * 1024 * 1024);
                $parsed = static::parse($log);
                // A rotated log can omit the session start. Recover only from this
                // process's archives; never seed names from an earlier server run.
                if (!$parsed['complete'] && !str_contains($log, "[Session] 'HostOnline' (up)")) {
                    $uptime = (int) ($state['utilization']['uptime'] ?? 0);
                    if ($uptime > 0) {
                        $archives = static::sessionArchives($files->getDirectory('/logs/backup'), microtime(true) - $uptime / 1000);
                        foreach ($archives as $archive) {
                            $log = $files->getContent('/logs/backup/'.$archive['name'], 2 * 1024 * 1024)."\n".$log;
                            $parsed = static::parse($log);
                            if ($parsed['complete']) { break; }
                        }
                    }
                }
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
