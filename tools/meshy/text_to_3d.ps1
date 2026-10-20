# Generates an untextured 3D model with Meshy (text to 3D, preview mode, 20 credits) and
# downloads the .glb. Prints the task id, which rig_and_animate.ps1 takes to animate it.
# With -TexturePrompt the model is also textured (refine, 10 more credits) and the textured
# .glb is the one downloaded.
#
# Example:
#   powershell -File tools/meshy/text_to_3d.ps1 -Prompt "a low poly tree" -OutFile assets/props/tree/tree.glb

param(
	[Parameter(Mandatory = $true)][string]$Prompt,
	[Parameter(Mandatory = $true)][string]$OutFile,
	[int]$Polycount = 8000,
	[ValidateSet("", "a-pose", "t-pose")][string]$PoseMode = "",
	# Optional path for the preview picture Meshy renders of the model
	[string]$ThumbnailFile = "",
	# Describes the colours of the texture; empty leaves the model untextured
	[string]$TexturePrompt = "",
	[int]$TimeoutSeconds = 900
)

. "$PSScriptRoot\meshy_common.ps1"
$api = "https://api.meshy.ai/openapi/v2/text-to-3d"

$task = New-MeshyTask $api @{
	mode = "preview"
	prompt = $Prompt
	should_remesh = $true
	topology = "triangle"
	target_polycount = $Polycount
	pose_mode = $PoseMode
	target_formats = @("glb")
}
$info = Wait-MeshyTask $api $task $TimeoutSeconds
if ($TexturePrompt) {
	Write-Host "Texturizando (refine)..."
	$refine = New-MeshyTask $api @{ mode = "refine"; preview_task_id = $task; texture_prompt = $TexturePrompt; target_formats = @("glb") }
	$info = Wait-MeshyTask $api $refine $TimeoutSeconds
}
Save-MeshyFile $info.model_urls.glb $OutFile
if ($ThumbnailFile -and $info.thumbnail_url) {
	Save-MeshyFile $info.thumbnail_url $ThumbnailFile
}
