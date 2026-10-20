# Shared helpers of the Meshy scripts: API key from .env and task polling.
# Dot-source it: . "$PSScriptRoot\meshy_common.ps1"

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$MeshyRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path


function Get-MeshyHeaders {
	$envFile = Join-Path $MeshyRoot ".env"
	if (-not (Test-Path $envFile)) { throw "No se encontró $envFile con MESHY_API_KEY" }
	$line = Get-Content $envFile | Where-Object { $_ -match '^\s*MESHY_API_KEY\s*=' } | Select-Object -First 1
	$key = ($line -replace '^\s*MESHY_API_KEY\s*=\s*', '').Trim().Trim('"').Trim("'")
	if (-not $key) { throw "MESHY_API_KEY está vacío en $envFile" }
	return @{ Authorization = "Bearer $key" }
}


function New-MeshyTask([string]$Url, [hashtable]$Body) {
	$json = $Body | ConvertTo-Json -Depth 5
	$response = Invoke-RestMethod -Method Post -Uri $Url -Headers (Get-MeshyHeaders) `
		-ContentType "application/json; charset=utf-8" -Body ([Text.Encoding]::UTF8.GetBytes($json))
	Write-Host "  Tarea creada: $($response.result)"
	return $response.result
}


#Polls "$Url/$TaskId" until it succeeds; throws if it fails or takes too long
function Wait-MeshyTask([string]$Url, [string]$TaskId, [int]$TimeoutSeconds = 900) {
	$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
	while ($true) {
		$info = Invoke-RestMethod -Uri "$Url/$TaskId" -Headers (Get-MeshyHeaders)
		Write-Host ("  {0} {1}%" -f $info.status, $info.progress)
		if ($info.status -eq "SUCCEEDED") {
			Write-Host "  Créditos consumidos: $($info.consumed_credits)"
			return $info
		}
		if ($info.status -in @("FAILED", "CANCELED")) {
			throw "Meshy: la tarea $TaskId terminó en $($info.status): $($info.task_error.message)"
		}
		if ((Get-Date) -gt $deadline) { throw "Meshy: la tarea $TaskId no terminó en $TimeoutSeconds s" }
		Start-Sleep -Seconds 6
	}
}


function Save-MeshyFile([string]$Url, [string]$OutFile) {
	$target = if ([IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path $MeshyRoot $OutFile }
	New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
	Invoke-WebRequest -Uri $Url -OutFile $target -UseBasicParsing
	Write-Host "  Guardado en $target"
}
