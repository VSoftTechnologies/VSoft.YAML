# Generate benchmark YAML file with single and double-quoted strings
# This tests string parsing with various escape sequences

$basePath = "I:\Github\VSoftTechnologies\VSoft.YAML\Tests\TestFiles"
$outputFile = "$basePath\benchmark_quoted_strings.yaml"

$content = @'
# Benchmark file for quoted string performance testing
# Tests single-quoted and double-quoted strings with escape sequences

strings:
'@

# Generate 1000 entries with various quoted strings
for ($i = 0; $i -lt 1000; $i++) {
    $quoteType = $i % 4

    switch ($quoteType) {
        0 {
            # Double-quoted with escape sequences
            $content += @"

  - id: $i
    type: "double_quoted_escapes"
    simple: "Simple double-quoted string $i"
    with_escapes: "Line 1\nLine 2\tTabbed\nLine 3"
    with_quotes: "She said \"Hello\" to me"
    with_backslash: "Path: C:\\Users\\test\\file.txt"
    with_unicode: "Unicode: \u00E9\u00E0\u00F6"
    multiline: "This is a very long string that would normally span multiple lines in the source but is kept as a single line with proper escaping and continuation"

"@
        }
        1 {
            # Single-quoted strings
            $content += @"

  - id: $i
    type: 'single_quoted'
    simple: 'Simple single-quoted string $i'
    with_quotes: 'It''s a beautiful day'
    literal_backslash: 'C:\Users\test\file.txt'
    no_escapes: 'Backslash \n is literal, not newline'
    apostrophes: 'Don''t worry, be happy'
    nested: 'She said ''Hello'' to me'

"@
        }
        2 {
            # Double-quoted with more complex escapes
            $content += @"

  - id: $i
    type: "double_quoted_complex"
    url: "https://example.com/path?query=value&other=value"
    json_like: "{\"key\": \"value\", \"number\": 123}"
    xml_like: "<tag attribute=\"value\">Content</tag>"
    regex: "\\d+\\.\\d+\\.\\d+\\.\\d+"
    special_chars: "!@#$%^&*()_+-=[]{}|;':\",./<>?"

"@
        }
        3 {
            # Mixed with nested structures
            $content += @"

  - id: $i
    type: "mixed"
    strings:
      double: "Double quoted $i"
      single: 'Single quoted $i'
    nested:
      level1: "Level 1 string"
      level2:
        deep: "Deeply nested string"
        escaped: "With\nescapes\tand\ttabs"

"@
        }
    }
}

# Add some edge cases
$content += @'

# Edge cases for string parsing
edge_cases:
  empty_double: ""
  empty_single: ''
  only_escapes: "\n\t\r"
  long_string: "This is an extremely long string that contains a lot of text to test the performance of string parsing when dealing with longer content that might stress the string builder implementation and memory allocation patterns in the lexer"
  unicode_heavy: "\u0041\u0042\u0043\u0044\u0045\u0046\u0047\u0048\u0049\u004A"
  many_escapes: "Line1\nLine2\nLine3\nLine4\nLine5\nLine6\nLine7\nLine8\nLine9\nLine10"

# Performance test cases
performance_strings:
'@

# Add 100 more complex strings
for ($i = 0; $i -lt 100; $i++) {
    $content += @"

  - "String with ID $i and escape sequences\nNewline\tTab\rCarriage\\ Backslash \" Quote"
"@
}

Set-Content -Path $outputFile -Value $content

$sizeKB = [math]::Round((Get-Item $outputFile).Length / 1KB, 2)
Write-Host "Generated quoted strings benchmark file: $sizeKB KB"
Write-Host "File: $outputFile"