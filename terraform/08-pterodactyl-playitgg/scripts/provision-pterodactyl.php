<?php
declare(strict_types=1);

require '/app/vendor/autoload.php';

$app = require '/app/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Pterodactyl\Models\Allocation;
use Pterodactyl\Models\ApiKey;
use Pterodactyl\Models\Egg;
use Pterodactyl\Models\Location;
use Pterodactyl\Models\Nest;
use Pterodactyl\Models\Node;
use Pterodactyl\Models\Server;
use Pterodactyl\Models\User;
use Pterodactyl\Repositories\Wings\DaemonPowerRepository;
use Pterodactyl\Services\Api\KeyCreationService;
use Pterodactyl\Services\Eggs\Sharing\EggImporterService;
use Pterodactyl\Services\Locations\LocationCreationService;
use Symfony\Component\Yaml\Yaml;

function ensure(bool $ok, string $message): void
{
    if (!$ok) {
        throw new RuntimeException($message);
    }
}

$location = Location::query()->where('short', 'ah')->first();
if (!$location) {
    $location = app(LocationCreationService::class)->handle([
        'short' => 'ah',
        'long' => 'Afterhours Home Lab',
    ]);
}

$node = Node::query()->where('name', 'pterodactyl01')->first();
if (!$node) {
    $options = [
        '--name' => 'pterodactyl01',
        '--description' => 'Terraform-managed game node',
        '--locationId' => (string) $location->id,
        '--fqdn' => '192.168.1.175',
        '--public' => '1',
        '--scheme' => 'http',
        '--proxy' => '0',
        '--maintenance' => '0',
        '--maxMemory' => '6144',
        '--overallocateMemory' => '0',
        '--maxDisk' => '40000',
        '--overallocateDisk' => '0',
        '--uploadSize' => '100',
        '--daemonListeningPort' => '8080',
        '--daemonSFTPPort' => '2022',
        '--daemonBase' => '/var/lib/pterodactyl/volumes',
    ];
    Illuminate\Support\Facades\Artisan::call('p:node:make', $options);
    $node = Node::query()->where('name', 'pterodactyl01')->first();
}
ensure((bool) $node, 'Could not create or find the Pterodactyl node.');

$ports = [2456, 2457];
$allocations = [];
foreach ($ports as $port) {
    $allocations[$port] = Allocation::query()->firstOrCreate(
        ['node_id' => $node->id, 'ip' => '192.168.1.175', 'port' => $port],
        ['ip_alias' => null, 'server_id' => null, 'notes' => 'Terraform-managed Valheim allocation'],
    );
}

$nest = Nest::query()->where('name', 'Valheim')->first();
if (!$nest) {
    $nest = Nest::query()->forceCreate([
        'uuid' => (string) Str::uuid(),
        'author' => 'support@pterodactyl.io',
        'name' => 'Valheim',
        'description' => 'Valheim dedicated servers',
    ]);
}

$egg = Egg::query()->where('nest_id', $nest->id)->where('name', 'Valheim')->first();
if (!$egg) {
    $eggPath = '/tmp/egg-valheim.json';
    ensure(is_file($eggPath), 'Terraform did not transfer the pinned Valheim egg JSON.');
    $uploadedEgg = new UploadedFile($eggPath, 'egg-valheim.json', 'application/json', UPLOAD_ERR_OK, true);
    $egg = app(EggImporterService::class)->handle($uploadedEgg, (int) $nest->id);
}
ensure((bool) $egg, 'Could not import or find the Valheim egg.');

$nodeConfiguration = $node->getConfiguration();
$nodeConfiguration['docker']['network'] = [
    'interface' => '172.21.0.1',
    'dns' => ['1.1.1.1', '1.0.0.1'],
    'name' => 'pterodactyl-wings',
    'ispn' => false,
    'driver' => 'bridge',
    'network_mode' => 'pterodactyl-wings',
    'is_internal' => false,
    'enable_icc' => true,
    'network_mtu' => 1500,
];
file_put_contents('/tmp/wings-config.yml', Yaml::dump($nodeConfiguration, 4, 2, Yaml::DUMP_EMPTY_ARRAY_AS_SEQUENCE));
$bootstrap = json_decode((string) file_get_contents('/tmp/pterodactyl-bootstrap.json'), true, 512, JSON_THROW_ON_ERROR);

if (!(bool) ($bootstrap['create_server'] ?? true)) {
    echo 'Pterodactyl location, node, Valheim egg, allocations, and Wings configuration are provisioned.' . PHP_EOL;
    exit(0);
}

$owner = User::query()->where('root_admin', true)->orderBy('id')->first();
ensure((bool) $owner, 'Create the first Pterodactyl admin account before applying this stack.');

$memo = 'Terraform Pterodactyl bootstrap';
$apiKey = ApiKey::query()->where('memo', $memo)->first();
if (!$apiKey) {
    $apiKey = app(KeyCreationService::class)
        ->setKeyType(ApiKey::TYPE_APPLICATION)
        ->handle([
            'user_id' => $owner->id,
        'memo' => $memo,
        'allowed_ips' => ['127.0.0.1'],
    ], [
            'r_users' => 0,
            'r_allocations' => 0,
            'r_database_hosts' => 0,
            'r_server_databases' => 0,
            'r_eggs' => 0,
            'r_locations' => 0,
            'r_nests' => 0,
            'r_nodes' => 0,
            'r_servers' => 2,
        ]);
}
$apiToken = $apiKey->identifier . decrypt($apiKey->token);

$serverExternalId = 'afterhours-valheim';
$server = Server::query()->where('external_id', $serverExternalId)->first();
$environment = [];
foreach ($egg->variables as $variable) {
    $environment[$variable->env_variable] = $variable->default_value;
}
$environment['SERVER_NAME'] = $bootstrap['server_name'] ?? 'Afterhours Valheim';
$environment['PASSWORD'] = $bootstrap['server_password'] ?? '';
$environment['WORLD'] = $bootstrap['world_name'] ?? 'Afterhours';
$environment['PUBLIC_SERVER'] = '1';
$environment['ENABLE_CROSSPLAY'] = '0';

ensure(strlen($environment['PASSWORD']) >= 5 && strlen($environment['PASSWORD']) <= 20,
    'VALHEIM_SERVER_PASSWORD must be between 5 and 20 characters.');

$images = $egg->docker_images;
$image = is_array($images) ? reset($images) : null;
ensure(is_string($image) && $image !== '', 'Valheim egg has no Docker image.');

$payload = [
        'external_id' => $serverExternalId,
        'name' => $environment['SERVER_NAME'],
        'description' => 'Terraform-managed Valheim dedicated server',
        'user' => $owner->id,
        'egg' => $egg->id,
        'docker_image' => $image,
        'startup' => $egg->startup,
        'environment' => $environment,
        'limits' => [
            'memory' => 4096,
            'swap' => 0,
            'disk' => 25000,
            'io' => 500,
            'threads' => null,
            'cpu' => 200,
        ],
        'feature_limits' => [
            'databases' => 0,
            'allocations' => 2,
            'backups' => 2,
        ],
        'allocation' => [
            'default' => $allocations[2456]->id,
            'additional' => [$allocations[2457]->id],
        ],
        'start_on_completion' => true,
        'skip_scripts' => false,
        'oom_disabled' => false,
];

$headers = ['Accept' => 'application/vnd.pterodactyl.v1+json'];
if (!$server) {
    $response = Http::withToken($apiToken)
        ->withHeaders($headers)
        ->post('http://127.0.0.1/api/application/servers', $payload);
    ensure($response->successful(), 'Pterodactyl server creation failed (HTTP ' . $response->status() . ').');
} else {
    $buildResponse = Http::withToken($apiToken)
        ->withHeaders($headers)
        ->patch('http://127.0.0.1/api/application/servers/' . $server->id . '/build', [
            'allocation' => $allocations[2456]->id,
            'memory' => 4096,
            'swap' => 0,
            'disk' => 25000,
            'io' => 500,
            'threads' => null,
            'cpu' => 200,
            'feature_limits' => [
                'databases' => 0,
                'allocations' => 2,
                'backups' => 2,
            ],
            'add_allocations' => [$allocations[2456]->id],
            'remove_allocations' => [],
            'oom_disabled' => false,
        ]);
    ensure($buildResponse->successful(), 'Pterodactyl server allocation update failed (HTTP ' . $buildResponse->status() . ').');

    $response = Http::withToken($apiToken)
        ->withHeaders($headers)
        ->patch('http://127.0.0.1/api/application/servers/' . $server->id . '/startup', [
            'startup' => $egg->startup,
            'environment' => $environment,
            'egg' => $egg->id,
            'image' => $image,
            'skip_scripts' => false,
        ]);
    ensure($response->successful(), 'Pterodactyl server settings update failed (HTTP ' . $response->status() . ').');

    if (!$server->installed_at && $server->status !== Server::STATUS_INSTALLING) {
        $installResponse = Http::withToken($apiToken)
            ->withHeaders($headers)
            ->post('http://127.0.0.1/api/application/servers/' . $server->id . '/reinstall');
        ensure($installResponse->successful(), 'Pterodactyl Valheim installation request failed (HTTP ' . $installResponse->status() . ').');
    }
}

$server = Server::query()->where('external_id', $serverExternalId)->first();
ensure((bool) $server, 'Pterodactyl did not return the Valheim server record.');
for ($attempt = 0; $attempt < 180 && (!$server->installed_at || $server->status === Server::STATUS_INSTALLING); $attempt++) {
    sleep(5);
    $server->refresh();
}
ensure((bool) $server->installed_at && $server->status !== Server::STATUS_INSTALLING, 'Valheim installation did not finish within 15 minutes.');

if ($server->status !== 'running') {
    $powerResponse = app(DaemonPowerRepository::class)->setServer($server)->send('start');
    ensure($powerResponse->getStatusCode() >= 200 && $powerResponse->getStatusCode() < 300,
        'Wings rejected the Valheim start request.');
}

echo 'Pterodactyl location, node, Valheim egg, allocations, Wings configuration, and running server are provisioned.' . PHP_EOL;