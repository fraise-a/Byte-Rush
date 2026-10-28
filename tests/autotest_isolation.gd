extends SceneTree
# Run with -- --autotest; seeded test preferences must not affect the known test baseline.
func _initialize() -> void:
	var settings:=ConfigFile.new()
	settings.set_value("game","difficulty",2)
	settings.save("user://validation_autotest_settings.cfg")
	var records:=ConfigFile.new()
	records.set_value("records","lap",0.1)
	records.set_value("records","total",0.3)
	records.save("user://validation_autotest_records.cfg")
	call_deferred("run")
func run() -> void:
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	var checks: Array[String]=[]
	var outcomes: Array[bool]=[game.test_mode and game.profile_prefix=="validation_autotest_",game.difficulty==1,game.records.get("lap",-1)==0 and game.records.get("total",-1)==0]
	var descriptions: Array[String]=["Autotest uses a separate profile from real settings and personal records","Autotest always starts its advertised Normal difficulty","Autotest starts fresh records independently of saved best times"]
	var passed:=true
	for i in range(outcomes.size()):
		passed=passed and outcomes[i]
		checks.append(("PASS " if outcomes[i] else "FAIL ")+descriptions[i])
		print(checks[-1])
	var report:=FileAccess.open("user://autotest_isolation_results.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"version":game.VERSION,"passed":passed,"checks":checks},"  "))
	print("ISOLATION_REPORT "+ProjectSettings.globalize_path("user://autotest_isolation_results.json"))
	game.free()
	quit(0 if passed else 1)
