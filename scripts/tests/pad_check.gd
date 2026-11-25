extends SceneTree

#Checks the pad with simulated DualSense events: mapping, device switch, sticks, hints and rumble


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var cases: Object = (load("res://scripts/tests/pad_check_cases.gd") as GDScript).new()
	var failures: int = await cases.call("run", self)
	print("pad_check: %s" % ("OK" if failures == 0 else "%d FALLOS" % failures))
	quit(1 if failures > 0 else 0)
