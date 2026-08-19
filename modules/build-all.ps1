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
	$package = Get-Content -LiteralPath $packageJson.FullName -Raw | ConvertFrom-Json

	if (-not $package.scripts -or -not $package.scripts.build) {
		Write-Host "Skipping $moduleDir because it has no build script."
		continue
	}

	Write-Host "Building module in $moduleDir..."

	if ($WhatIf) {
		continue
	}

	Push-Location -LiteralPath $moduleDir
	try {
		& npm run build
		if ($LASTEXITCODE -ne 0) {
			throw "npm run build failed in $moduleDir with exit code $LASTEXITCODE."
		}
	}
	finally {
		Pop-Location
	}
}
