# Generate large benchmark YAML and JSON files

$basePath = "I:\Github\VSoftTechnologies\VSoft.YAML\Tests\TestFiles"

# Read existing content
$baseContent = Get-Content "$basePath\benchmark_large.yaml" -Raw

# Template for a data batch
$batchTemplate = @'

data_batch_{0}:
  users:
    - id: {1}
      name: User{1} Name
      email: user{1}@example.com
      active: {2}
      score: {3}
      tags: [{4}]
      preferences:
        theme: {5}
        notifications: {6}
        language: en-US
        timezone: America/New_York
      metadata:
        last_login: 2024-01-{7:D2}T{8:D2}:30:00Z
        login_count: {9}
        ip_address: 192.168.{10}.{11}
      nested_level_1:
        key1: value1_{1}
        key2: value2_{1}
        nested_level_2:
          key3: value3_{1}
          key4: value4_{1}
          nested_level_3:
            key5: value5_{1}
            key6: value6_{1}
            nested_level_4:
              key7: value7_{1}
              data: [1, 2, 3, 4, 5]
    - id: {12}
      name: User{12} Name
      email: user{12}@example.com
      active: {13}
      score: {14}
      tags: [{15}]
  metrics:
    cpu_usage: {16}
    memory_usage: {17}
    disk_usage: {18}
    network_io: {19}
    requests_per_second: {20}
    error_rate: {21}
  special_types:
    null_val: null
    bool_true: true
    bool_false: false
    yaml_yes: yes
    yaml_no: no
    int_val: {22}
    float_val: {23}
    hex_val: 0x{24:X}
    timestamp: 2024-01-{7:D2}T10:30:00Z
'@

# Generate batches (more to reach 1MB+)
$batches = @()
for ($i = 4; $i -lt 604; $i++) {
    $baseId = $i * 10
    $baseId1 = $i * 10 + 1
    $active = if ($i % 2 -eq 0) { 'true' } else { 'false' }
    $active1 = if ($i % 3 -ne 0) { 'true' } else { 'false' }
    $score = [math]::Round(0.70 + ($i % 30) / 100.0, 2)
    $score1 = [math]::Round(0.65 + ($i % 25) / 100.0, 2)
    $tags = if ($i % 3 -eq 0) { 'premium, verified' } else { 'standard, contributor' }
    $tags1 = if ($i % 2 -eq 0) { 'developer, tester' } else { 'inactive' }
    $theme = if ($i % 2 -eq 0) { 'dark' } else { 'light' }
    $notifications = if ($i % 3 -eq 0) { 'true' } else { 'false' }
    $day = ($i % 28) + 1
    $hour = $i % 24
    $loginCount = 100 + $i * 10
    $subnet = $i % 255
    $ipHost = ($i * 7) % 255
    $cpu = [math]::Round(0.40 + ($i % 40) / 100.0, 2)
    $memory = [math]::Round(0.50 + ($i % 45) / 100.0, 2)
    $disk = [math]::Round(0.30 + ($i % 60) / 100.0, 2)
    $network = 500000 + $i * 1000
    $rps = 1000 + $i * 10
    $errorRate = [math]::Round(0.001 + ($i % 5) / 1000.0, 4)
    $intVal = 100 + $i
    $floatVal = [math]::Round(3.14 + $i / 100.0, 2)
    $hexVal = 255 + $i

    $batch = $batchTemplate -f $i, $baseId, $active, $score, $tags, $theme, $notifications, $day, $hour, $loginCount, $subnet, $ipHost, $baseId1, $active1, $score1, $tags1, $cpu, $memory, $disk, $network, $rps, $errorRate, $intVal, $floatVal, $hexVal
    $batches += $batch
}

# Write the complete file
$content = $baseContent + ($batches -join '')
Set-Content -Path "$basePath\benchmark_large.yaml" -Value $content

$sizeKB = (Get-Item "$basePath\benchmark_large.yaml").Length / 1KB
Write-Host "Generated YAML file with size: $sizeKB KB"