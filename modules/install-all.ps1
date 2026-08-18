param(
	[switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$modulesDir = $PSScriptRoot
$modulePackageFiles = Get-ChildItem -LiteralPath $modulesDir -Directory |
	ForEach-Object {
		$packageJson = Join-Path $_.FullName "package.json"
		if (Test-Path -LiteralPath $packageJson -PathType Leaf) {
			Get-Item -LiteralPath $packageJson
		}
	}

if (-not $modulePackageFiles) {
	Write-Host "No module package.json files found under $modulesDir."
	exit 0
}

foreach ($packageJson in $modulePackageFiles) {
	$moduleDir = $packageJson.Directory.FullName
	$lockFile = Join-Path $moduleDir "package-lock.json"
	$command = if (Test-Path -LiteralPath $lockFile -PathType Leaf) { "ci" } else { "install" }

	Write-Host "Installing dependencies in $moduleDir using npm $command..."

	if ($WhatIf) {
		continue
	}

	Push-Location -LiteralPath $moduleDir
	try {
		& npm $command
		if ($LASTEXITCODE -ne 0) {
			throw "npm $command failed in $moduleDir with exit code $LASTEXITCODE."
		}
	}
	finally {
		Pop-Location
	}
}
