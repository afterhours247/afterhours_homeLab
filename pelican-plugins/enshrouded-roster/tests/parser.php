<?php
require __DIR__.'/../src/Services/Roster.php';
use Afterhours\EnshroudedRoster\Services\Roster;
function check(bool $condition, string $name): void { if (!$condition) { throw new RuntimeException($name); } echo "PASS: $name\n"; }
$start = "[I 00:00:04,954] [Session] 'HostOnline' (up)!\n";
$join = fn($name) => "[I 00:02:12,657] [server] Player '$name' logged in with Permissions:\n";
$r = Roster::parse($start.$join('RedZone').$join('ButeMeng'));
check($r['complete'] && $r['names'] === ['RedZone','ButeMeng'], 'current session joins');
$r = Roster::parse($start.$join('RedZone')."[I 00:03:00,000] Remove Player 'RedZone'\n");
check($r['complete'] && $r['names'] === [], 'named departure');
$r = Roster::parse($start.$join('RedZone')."[I 00:03:00,000] Player removed. Player handle: 0(0)\n");
check(!$r['complete'], 'unattributed departure suppresses names');
check(!Roster::parse($join('RedZone'))['complete'], 'partial log suppresses names');
check(!Roster::parse($start.$join('Same').$join('Same'))['complete'], 'duplicate character names suppress roster');
$r = Roster::parse($start.$join('Old').$start.$join('New'));
check($r['complete'] && $r['names'] === ['New'], 'restart resets roster');
$r = Roster::parse($start.$join("O'Brien <script>"));
check($r['names'] === ["O'Brien <script>"], 'names preserved for escaped Blade output');
