# Generate benchmark YAML file with literal and folded block scalars
# This tests the ReadLiteralScalar and ReadFoldedScalar optimizations

$basePath = "I:\Github\VSoftTechnologies\VSoft.YAML\Tests\TestFiles"
$outputFile = "$basePath\benchmark_block_scalars.yaml"

$content = @'
# Benchmark file for block scalar performance testing
# Tests literal (|) and folded (>) block scalars

documents:
'@

# Generate 500 documents with alternating literal and folded scalars
for ($i = 0; $i -lt 500; $i++) {
    $docType = if ($i % 2 -eq 0) { "literal" } else { "folded" }

    if ($docType -eq "literal") {
        # Literal scalar preserves line breaks and indentation
        $content += "`r`n  - id: $i`r`n"
        $content += "    type: literal`r`n"
        $content += "    description: ""Document with literal block scalar""`r`n"
        $content += "    content: |`r`n"
        $content += "      This is a literal block scalar for document $i.`r`n"
        $content += "      It preserves line breaks exactly as written.`r`n"
        $content += "      Each line is preserved including leading spaces.`r`n"
        $content += "`r`n"
        $content += "      Empty lines are also preserved in the output.`r`n"
        $content += "      This is useful for code blocks ASCII art or`r`n"
        $content += "      any content where formatting matters.`r`n"
        $content += "    metadata:`r`n"
        $content += "      created: 2024-01-$(($i % 28) + 1)T10:30:00Z`r`n"
        $content += "      author: user_$i`r`n"
        $content += "      tags:`r`n"
        $content += "        - literal`r`n"
        $content += "        - block-scalar`r`n"
    } else {
        # Folded scalar folds line breaks into spaces
        $content += "`r`n  - id: $i`r`n"
        $content += "    type: folded`r`n"
        $content += "    description: ""Document with folded block scalar""`r`n"
        $content += "    content: >`r`n"
        $content += "      This is a folded block scalar for document $i.`r`n"
        $content += "      Line breaks are folded into spaces making it`r`n"
        $content += "      suitable for long paragraphs that need to wrap.`r`n"
        $content += "`r`n"
        $content += "      Empty lines create paragraph breaks like this.`r`n"
        $content += "    metadata:`r`n"
        $content += "      created: 2024-01-$(($i % 28) + 1)T14:45:00Z`r`n"
        $content += "      author: user_$i`r`n"
        $content += "      tags:`r`n"
        $content += "        - folded`r`n"
        $content += "        - block-scalar`r`n"
    }
}

# Add summary at end
$content += "`r`n`r`n"
$content += "# Summary`r`n"
$content += "total_documents: 500`r`n"
$content += "types:`r`n"
$content += "  literal: 250`r`n"
$content += "  folded: 250`r`n"

Set-Content -Path $outputFile -Value $content

$sizeKB = [math]::Round((Get-Item $outputFile).Length / 1KB, 2)
Write-Host "Generated block scalar benchmark file: $sizeKB KB"
Write-Host "File: $outputFile"