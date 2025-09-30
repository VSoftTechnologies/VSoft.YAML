# Convert YAML benchmark to JSON using TYAML
# This will be a simple Delphi program call

# For now, create a minimal JSON file manually with similar structure
$basePath = "I:\Github\VSoftTechnologies\VSoft.YAML\Tests\TestFiles"

# Just create a  large JSON with repetitive structure
$jsonContent = @'
{
  "users": [
'@

for ($i = 0; $i -lt 3000; $i++) {
    $comma = if ($i -lt 2999) { ',' } else { '' }
    $active = if ($i % 2 -eq 0) { 'true' } else { 'false' }
    $score = [math]::Round(0.70 + ($i % 30) / 100.0, 2)

    $jsonContent += @"

    {
      "id": $i,
      "username": "user$i",
      "email": "user$i@example.com",
      "active": $active,
      "score": $score,
      "tags": ["tag1", "tag2", "tag3"],
      "preferences": {
        "theme": "dark",
        "notifications": true,
        "language": "en-US"
      },
      "metadata": {
        "login_count": $(100 + $i),
        "ip_address": "192.168.1.$($i % 255)",
        "nested_level_1": {
          "key1": "value1_$i",
          "nested_level_2": {
            "key2": "value2_$i",
            "nested_level_3": {
              "key3": "value3_$i",
              "nested_level_4": {
                "key4": "value4_$i",
                "data": [1, 2, 3, 4, 5]
              }
            }
          }
        }
      }
    }$comma
"@
}

$jsonContent += @'

  ],
  "config": {
    "app_name": "Benchmark",
    "version": "1.0.0",
    "debug": false,
    "null_value": null,
    "settings": {
      "timeout": 30,
      "max_connections": 100,
      "rate_limit": 1000
    }
  }
}
'@

Set-Content -Path "$basePath\benchmark_large.json" -Value $jsonContent

$sizeKB = (Get-Item "$basePath\benchmark_large.json").Length / 1KB
Write-Host "Generated JSON file with size: $sizeKB KB"