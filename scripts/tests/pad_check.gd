extends SceneTree

#Checks the pad with simulated DualSense events, without a real one: every action keeps its keys and gains its button, the active device
#follows the last thing touched, a stick counts like a button (one press per push, while moving still reads the full tilt), the hints
#switch between keys and buttons, the vibration plays the table and stops, a menu gets a focused button, and a pad pulled out in the
#middle of a round pauses it with a notice until it comes back.
#Run: godot --headless --fixed-fps 60 --path . --script res://scripts/tests/pad_check.gd


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	var cases: Object = (load("res://scripts/tests/pad_check_cases.gd") as GDScript).new()
	var failures: int = await cases.call("run", self)
	print("pad_check: %s" % ("OK" if failures == 0 else "%d FALLOS" % failures))
	quit(1 if failures > 0 else 0)
