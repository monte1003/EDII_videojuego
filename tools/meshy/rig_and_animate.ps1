# Rigs a humanoid made with text_to_3d.ps1 and downloads it with one animation from the
# Meshy library (the .glb carries the mesh, the skeleton and the animation).
# Rigging needs a textured model, so by default the preview is textured first (refine).
# Costs: refine 10 + rigging 5 + animation 3 credits (failed tasks are refunded).
#
# Example (122 = "Texting Walk"):
#   powershell -File tools/meshy/rig_and_animate.ps1 -PreviewTaskId <id> -ActionId 122 -OutFile assets/x/x_walk.glb
#
# Library of animations (free): GET https://api.meshy.ai/openapi/v1/animations/library?search=walk

param(
	[Parameter(Mandatory = $true)][string]$PreviewTaskId,
	[Parameter(Mandatory = $true)][int]$ActionId,
	[Parameter(Mandatory = $true)][string]$OutFile,
	[double]$HeightMeters = 1.8,
	# Tries to rig the untextured preview directly (saves the refine, may be rejected)
	[switch]$SkipRefine,
	# Remeshes the preview to this many polygons first (5 credits); keeps the same model.
	# Implies -SkipRefine. The model must face +Z (Meshy models do)
	[int]$RemeshPolycount = 0
)

. "$PSScriptRoot\meshy_common.ps1"
$textApi = "https://api.meshy.ai/openapi/v2/text-to-3d"
$rigApi = "https://api.meshy.ai/openapi/v1/rigging"
$animationApi = "https://api.meshy.ai/openapi/v1/animations"

$rigInput = @{ input_task_id = $PreviewTaskId; height_meters = $HeightMeters }
if ($RemeshPolycount -gt 0) {
	Write-Host "Rehaciendo la malla con $RemeshPolycount polígonos (remesh)..."
	$remeshApi = "https://api.meshy.ai/openapi/v1/remesh"
	$remesh = New-MeshyTask $remeshApi @{ input_task_id = $PreviewTaskId; target_polycount = $RemeshPolycount; topology = "triangle"; target_formats = @("glb") }
	$remeshed = Wait-MeshyTask $remeshApi $remesh
	#Rigging does not take remesh tasks as input, but it takes the model's URL
	$rigInput = @{ model_url = $remeshed.model_urls.glb; height_meters = $HeightMeters }
} elseif (-not $SkipRefine) {
	Write-Host "Texturizando (refine)..."
	$refine = New-MeshyTask $textApi @{ mode = "refine"; preview_task_id = $PreviewTaskId; target_formats = @("glb") }
	[void](Wait-MeshyTask $textApi $refine)
	$rigInput.input_task_id = $refine
}

Write-Host "Creando el esqueleto (rigging)..."
$rig = New-MeshyTask $rigApi $rigInput
[void](Wait-MeshyTask $rigApi $rig)

Write-Host "Animando (accion $ActionId)..."
$animation = New-MeshyTask $animationApi @{ rig_task_id = $rig; action_id = $ActionId }
$info = Wait-MeshyTask $animationApi $animation
Save-MeshyFile $info.result.animation_glb_url $OutFile
