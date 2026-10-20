<?php
require __DIR__.'/../src/Services/Roster.php';
use Afterhours\EnshroudedRoster\Services\Roster;
function check(bool $condition, string $name): void { if (!$condition) { throw new RuntimeException($name); } echo "PASS: $name\n"; }
$start = "[I 00:00:04,954] [Session] 'HostOnline' (up)!\n";
$join = fn($name) => "[I 00:02:12,657] [server] Player '$name' logged in with Permissions:\n";
$r = Roster::parse($start.$join('RedZone').$join('ButeMeng'));
check($r['complete'] && $r['names'] === ['RedZone','ButeMeng'], 'current session joins');
$r = Roster::parse($start.$join('RedZone')."[I 00:03:00,000] [server] Remove Player 'RedZone'\n");
check($r['complete'] && $r['names'] === [], 'named departure');
$r = Roster::parse($start.$join('RedZone')."[I 00:03:00,000] Player removed. Player handle: 0(0)\n");
check(!$r['complete'], 'unattributed departure suppresses names');
check(!Roster::parse($join('RedZone'))['complete'], 'partial log suppresses names');
check(!Roster::parse($start.$join('Same').$join('Same'))['complete'], 'duplicate character names suppress roster');
$r = Roster::parse($start.$join('Old').$start.$join('New'));
check($r['complete'] && $r['names'] === ['New'], 'restart resets roster');
$r = Roster::parse($start.$join("O'Brien <script>"));
check($r['names'] === ["O'Brien <script>"], 'names preserved for escaped Blade output');
$machine = fn($handle) => "[I 00:02:12,650] [server] Machine '1': Player '$handle' logged in\n";
$r = Roster::parse($start.$machine('0(0)').$join('RedZone')."[I 00:03:00,000] [server] Remove Player 'RedZone'\n[I 00:03:00,100] [session] Player removed. Player handle: 0(0)\n");
check($r['complete'] && !$r['names'], 'named and handle departure remain verified');
$r = Roster::parse($start.$machine('0(0)').$join('RedZone')."[I 00:03:00,100] [session] Player removed. Player handle: 0(0)\n");
check($r['complete'] && !$r['names'], 'known handle departure identifies player');
$entry = fn ($name, $time) => ['name' => $name, 'file' => true, 'symlink' => false, 'size' => 100, 'modified' => gmdate('c', $time)];
$archives = Roster::sessionArchives([$entry('enshrouded_server_old.log', 100), $entry('enshrouded_server_current.log', 300), array_replace($entry('enshrouded_server_link.log', 400), ['symlink' => true])], 200);
check(count($archives) === 1 && $archives[0]['name'] === 'enshrouded_server_current.log', 'rotation recovery excludes prior sessions and symlinks');
$first = $start.$machine('0(0)').$join('RedZone');
$rotated = "[I 00:03:00,100] [session] Player removed. Player handle: 0(0)\n";
check(!Roster::parse($rotated)['complete'] && Roster::parse($first.$rotated)['complete'], 'same-session archive restores a rotated log baseline');
