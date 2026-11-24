class_name AttractSets
extends RefCounted

#The places of the fair screen's trailer, built once from the real pieces of the game: the night stage of the podium, La Plaza of the
#trend war, El Plató of the selfie and the SocialDrop board, each with its own sky and light. Only one is in the scene at a time: the
#others wait out of the tree, so they cost nothing to draw or to update

const STAGE := &"stage"
const PLAZA := &"plaza"
const PLATO := &"plato"
const DROP := &"drop"
const CHARACTERS: Array[StringName] = [&"fire", &"water", &"plant", &"lightning"]
#The made-up standings of the stage: each character on its own block, the first one in the middle
const STAGE_POINTS: Array[int] = [3920, 3310, 2740, 2105]
const ICONS: Array[String] = ["chat", "foto", "video", "me_gusta", "historia", "directo"]


class Place:
	var id: StringName
	var root := Node3D.new()
	#What moves with the clock (bars, blocks, belts), the layout of an arena map and the board of SocialDrop
	var ground: ArenaGround
	var layout: ArenaLayout
	var board: SocialDropWorld
	var podium: PodiumStage
	var entries: Array[PodiumPlan.Entry] = []


#Builds one place under "holder" (which must be in the tree) and takes it out again; one place per call, so the screen can breathe
#between them
static func build(id: StringName, holder: Node3D) -> Place:
	var place := Place.new()
	place.id = id
	place.root.name = String(id)
	holder.add_child(place.root)
	match id:
		STAGE:
			var tree := AVLTree.new()
			for index in CHARACTERS.size():
				tree.insert(STAGE_POINTS[index], index + 1, STAGE_POINTS[index])
			place.entries = PodiumPlan.build(tree, ScoreSheet.Medal.DIAMOND)
			place.podium = PodiumStage.new()
			place.root.add_child(place.podium)
			place.podium.build(place.entries)
		PLAZA:
			place.layout = TrendLayout.new()
			var world := ArenaWorld.new()
			place.root.add_child(world)
			world.build(place.layout)
			var stage_set := ArenaStage.new()
			world.add_child(stage_set)
			stage_set.build(place.layout.reach(), 47, place.layout.top_height())
			place.ground = world
		PLATO:
			place.layout = SelfieLayout.new()
			var studio := SelfieStage.new()
			place.root.add_child(studio)
			studio.build(place.layout)
			place.ground = studio
		DROP:
			var icons: Array[Texture2D] = []
			for icon in ICONS:
				icons.append(load("res://assets/social_icons/%s.png" % icon) as Texture2D)
			place.board = SocialDropWorld.new()
			place.root.add_child(place.board)
			var rng := RandomNumberGenerator.new()
			rng.seed = 2611
			place.board.build(icons, rng)
	holder.remove_child(place.root)
	return place


#The entry of the stage for one of the characters, in the order of CHARACTERS
static func entry_of(place: Place, index: int) -> PodiumPlan.Entry:
	for entry in place.entries:
		if entry.player_id == index + 1:
			return entry
	return place.entries[0]


#A path through La Plaza on foot: from a neighbour of the middle, through the middle, to the neighbour most across from it, every
#point on the ground (bridges included)
static func plaza_run(layout: ArenaLayout) -> Array[Vector3]:
	var middle := layout.position_of(TrendLayout.CORE)
	var neighbours: Array[Vector3] = []
	for link in layout.links:
		if link.kind != ArenaLayout.WALK:
			continue
		if link.a == TrendLayout.CORE:
			neighbours.append(layout.position_of(link.b))
		elif link.b == TrendLayout.CORE:
			neighbours.append(layout.position_of(link.a))
	var start := middle + Vector3(-14.0, 0.0, 0.0)
	var finish := middle + Vector3(14.0, 0.0, 0.0)
	var widest := -1.0
	for one in neighbours:
		for other in neighbours:
			var span := Vector2(one.x - other.x, one.z - other.z).length()
			if span > widest:
				widest = span
				start = one
				finish = other
	var path: Array[Vector3] = []
	for leg: Array in [[start, middle], [middle, finish]]:
		var from: Vector3 = leg[0]
		var to: Vector3 = leg[1]
		var steps := maxi(ceili(Vector2(to.x - from.x, to.z - from.z).length() / 0.75), 1)
		for step in steps + 1:
			var at := from.lerp(to, float(step) / steps)
			at.y = layout.height_at(at.x, at.z)
			path.append(at)
	return path
