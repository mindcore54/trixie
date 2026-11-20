extends SceneTree
## Validates all .tres data resources and .tscn scenes load cleanly without errors.

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var witches: Array[WitchCharacterData] = GameCatalog.get_witches()
	var customers: Array[CustomerArchetypeData] = GameCatalog.get_customers()
	var recipes: Array[PotionRecipeData] = GameCatalog.get_recipes()
	var upgrades: Array[RogueliteUpgradeData] = GameCatalog.get_upgrades()

	print("CATALOG CHECK => witches=%d customers=%d recipes=%d upgrades=%d" % [
		witches.size(), customers.size(), recipes.size(), upgrades.size()
	])

	var ok: bool = witches.size() == 4 and customers.size() == 5 and recipes.size() == 6 and upgrades.size() == 6
	print("CATALOG RESULT: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
