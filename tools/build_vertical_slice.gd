extends SceneTree
## Generates canonical .tres data resources and attaches MainGame.gd to Main.tscn.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GameCatalog.save_all_defaults_to_disk()
	print("Saved .tres data resources to res://data/")

	var main_root: Node2D = Node2D.new()
	main_root.name = "Main"
	var script_res: Script = load("res://scripts/core/MainGame.gd") as Script
	main_root.set_script(script_res)

	var packed: PackedScene = PackedScene.new()
	var err: Error = packed.pack(main_root)
	main_root.free()
	if err != OK:
		push_error("Failed to pack Main.tscn: %d" % err)
		quit(1)
		return

	err = ResourceSaver.save(packed, "res://scenes/main/Main.tscn")
	if err != OK:
		push_error("Failed to save Main.tscn: %d" % err)
		quit(1)
		return

	print("Updated res://scenes/main/Main.tscn successfully.")
	quit(0)
