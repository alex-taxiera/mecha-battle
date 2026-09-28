class_name Profile
extends RefCounted
## What carries over between runs: totals, each chassis's record, and the unlocks earned. Saved as
## JSON, by default at [constant DEFAULT_PATH].
## The shape follows Slay-The-Robot's ProfileData (MIT, DesirePathGames): run totals and
## per-character records. See THIRD_PARTY_NOTICES.md.

const DEFAULT_PATH := "user://profile.json"
## Mastery XP a frame needs for each mastery level: level 1 from the start, then 2, 3, and 4.
const MASTERY_XP: Array[int] = [0, 10, 25, 45]
## Mastery XP a run earns: a point per fight won, [constant XP_PER_SECTOR] per sector cleared, and
## [constant XP_FOR_WIN] more for a win.
const XP_PER_SECTOR := 5
const XP_FOR_WIN := 10
## Past runs kept in [member history]; older ones drop off (Slay-The-Robot kept every one).
const HISTORY_MAX := 20
const VERSION := 1

## Where the profile saves; empty for one that never touches disk (tests).
var path := ""
var runs := 0
var wins := 0
var fights_won := 0
var bosses_beaten := 0
## Chassis id -> {"runs", "wins", "best_sector", "threat", "xp"}, where "threat" is the highest
## Threat level unlocked on that chassis and "xp" its mastery XP.
var chassis_records: Dictionary = {}
## The ids of the unlocks earned.
var unlocked: Array[String] = []
## The last [constant HISTORY_MAX] runs, newest first, each a summary (see [method summarize]).
var history: Array[Dictionary] = []
## Daily run date -> the best that day's run did: {"sector", "won", "fights_won"}.
var daily_records: Dictionary = {}


## Returns the profile saved at [param from_path], or a fresh one there if there's none (or it
## can't be read).
static func load_from(from_path: String) -> Profile:
	var profile := Profile.new()
	profile.path = from_path
	if not FileAccess.file_exists(from_path):
		return profile
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(from_path))
	if not data is Dictionary:
		push_warning("Profile: can't read %s; starting fresh" % from_path)
		return profile
	profile.runs = int(data.get("runs", 0))
	profile.wins = int(data.get("wins", 0))
	profile.fights_won = int(data.get("fights_won", 0))
	profile.bosses_beaten = int(data.get("bosses_beaten", 0))
	var records: Variant = data.get("chassis", {})
	if records is Dictionary:
		profile.chassis_records = records
	for id: Variant in data.get("unlocked", []):
		profile.unlocked.append(str(id))
	for entry: Variant in data.get("history", []):
		if entry is Dictionary:
			profile.history.append(entry)
	var dailies: Variant = data.get("daily", {})
	if dailies is Dictionary:
		profile.daily_records = dailies
	return profile


## Writes the profile to [member path]. Does nothing for a profile without one.
func save() -> Error:
	if path.is_empty():
		return OK
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({
		"version": VERSION,
		"runs": runs,
		"wins": wins,
		"fights_won": fights_won,
		"bosses_beaten": bosses_beaten,
		"chassis": chassis_records,
		"unlocked": unlocked,
		"history": history,
		"daily": daily_records,
	}, "\t"))
	return OK


## Forgets every total, record, and unlock.
func reset() -> void:
	runs = 0
	wins = 0
	fights_won = 0
	bosses_beaten = 0
	chassis_records = {}
	unlocked = []
	history = []
	daily_records = {}


## Returns the highest Threat level unlocked on the chassis with id [param chassis_id]: 0 until
## it wins a run, then one above the highest Threat it has won at.
func get_threat_unlocked(chassis_id: String) -> int:
	var record: Dictionary = chassis_records.get(chassis_id, {})
	return int(record.get("threat", 0))


## Returns the mastery XP earned on the chassis with id [param chassis_id].
func get_mastery_xp(chassis_id: String) -> int:
	var record: Dictionary = chassis_records.get(chassis_id, {})
	return int(record.get("xp", 0))


## Returns the mastery level of the chassis with id [param chassis_id]: 1 to [constant MASTERY_XP]'s
## size, by its XP.
func get_mastery_level(chassis_id: String) -> int:
	var xp := get_mastery_xp(chassis_id)
	var level := 0
	for needed in MASTERY_XP:
		if xp >= needed:
			level += 1
	return level


## Returns the XP the next mastery level of [param chassis_id] needs in total, or -1 at the top.
func get_next_mastery_xp(chassis_id: String) -> int:
	var level := get_mastery_level(chassis_id)
	return MASTERY_XP[level] if level < MASTERY_XP.size() else -1


## Returns the mastery XP [param run] earns its chassis.
static func mastery_xp_for(run: RunState) -> int:
	var won := run.outcome == RunState.Outcome.VICTORY
	return run.fights_won + XP_PER_SECTOR * sectors_cleared(run) + (XP_FOR_WIN if won else 0)


func is_unlocked(unlock_id: String) -> bool:
	return unlock_id in unlocked


## Returns whether the content of [param kind] with id [param target_id] can be used: it has no
## unlock among [param unlocks], or its unlock has been earned.
func is_available(kind: Unlock.Kind, target_id: String, unlocks: Array[Unlock]) -> bool:
	for unlock in unlocks:
		if unlock.kind == kind and unlock.target_id == target_id and not is_unlocked(unlock.id):
			return false
	return true


## Returns the unlock that locks the content of [param kind] with id [param target_id], or null
## when it's available.
func get_lock(kind: Unlock.Kind, target_id: String, unlocks: Array[Unlock]) -> Unlock:
	for unlock in unlocks:
		if unlock.kind == kind and unlock.target_id == target_id and not is_unlocked(unlock.id):
			return unlock
	return null


## Returns how many sectors [param run] cleared: all of them on a win, otherwise the ones before
## the sector it ended in, counting every sector of an endless run's finished loops.
static func sectors_cleared(run: RunState) -> int:
	return run.acts.size() if run.outcome == RunState.Outcome.VICTORY else run.acts.size() * run.loops + run.act_index


## Counts a finished [param run] into the totals and its chassis's record, then earns every one
## of [param unlocks] whose milestone is now met. A win also unlocks the next Threat level on its
## chassis, and every run earns its chassis mastery XP. Returns the unlocks just earned.
## Returns a finished [param run] as a history entry: its frame, Threat, how far it got and how it
## ended, its MVP part, relics, seed, and a snapshot of its grid ([x, y, part type] per cell).
static func summarize(run: RunState) -> Dictionary:
	var won := run.outcome == RunState.Outcome.VICTORY
	var cells: Array = []
	for placement in run.grid.get_placements():
		for cell in placement.cells:
			cells.append([cell.x, cell.y, placement.part.type])
	var mvp := run.get_mvp()
	var cause := "Cleared all %d sectors" % run.acts.size() if won else \
		("Destroyed by %s" % run.defeated_by if not run.defeated_by.is_empty() else "Destroyed")
	return {
		"date": Time.get_date_string_from_system(),
		"chassis": run.grid.chassis.id,
		"chassis_name": run.grid.chassis.chassis_name,
		"threat": run.get_threat(),
		"won": won,
		"sector": run.act_index + 1,
		"floor": run.get_floor_number(),
		"loop": run.loops,
		"fights_won": run.fights_won,
		"cause": cause,
		"mvp": mvp.get_display_name() if mvp else "",
		"mvp_damage": run.part_damage.get(mvp, 0) if mvp else 0,
		"relics": run.relics.map(func(relic: Relic) -> String: return relic.relic_name),
		"grid": cells,
		"seed": run.rng.run_seed,
		"daily": run.daily,
	}


## Puts [param entry] at the top of [member history], keeping [constant HISTORY_MAX].
func add_history(entry: Dictionary) -> void:
	history.push_front(entry)
	if history.size() > HISTORY_MAX:
		history.resize(HISTORY_MAX)


## Records a finished daily [param run]: its history entry and that day's best, and nothing else
## (a daily doesn't count toward totals, Threat, mastery, or unlocks).
func record_daily(run: RunState) -> void:
	add_history(summarize(run))
	var won := run.outcome == RunState.Outcome.VICTORY
	var best: Dictionary = daily_records.get(run.daily, {"sector": 0, "won": false, "fights_won": 0})
	var sector := sectors_cleared(run)
	if won or (not best["won"] and (sector > int(best["sector"]) or (sector == int(best["sector"]) and run.fights_won > int(best["fights_won"])))):
		daily_records[run.daily] = {"sector": sector, "won": won or bool(best["won"]), "fights_won": run.fights_won}


func record_run(run: RunState, unlocks: Array[Unlock]) -> Array[Unlock]:
	add_history(summarize(run))
	var sectors := sectors_cleared(run)
	var won := run.outcome == RunState.Outcome.VICTORY
	var chassis_id := run.grid.chassis.id
	runs += 1
	fights_won += run.fights_won
	bosses_beaten += sectors
	if won:
		wins += 1
	var record: Dictionary = chassis_records.get(chassis_id, {"runs": 0, "wins": 0, "best_sector": 0})
	record["runs"] = int(record["runs"]) + 1
	record["wins"] = int(record["wins"]) + (1 if won else 0)
	record["best_sector"] = maxi(int(record["best_sector"]), sectors)
	# A win unlocks the next Threat level (Slay-The-Robot unlocked only the one just beaten).
	record["threat"] = maxi(int(record.get("threat", 0)), run.get_threat() + 1 if won else 0)
	record["xp"] = int(record.get("xp", 0)) + mastery_xp_for(run)
	chassis_records[chassis_id] = record
	var earned: Array[Unlock] = []
	for unlock in unlocks:
		if not is_unlocked(unlock.id) and unlock.is_met(self, sectors, chassis_id):
			unlocked.append(unlock.id)
			earned.append(unlock)
	return earned
