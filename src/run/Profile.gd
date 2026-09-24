class_name Profile
extends RefCounted
## What carries over between runs: totals, each chassis's record, and the unlocks earned. Saved as
## JSON, by default at [constant DEFAULT_PATH].
## The shape follows Slay-The-Robot's ProfileData (MIT, DesirePathGames): run totals and
## per-character records. See THIRD_PARTY_NOTICES.md.

const DEFAULT_PATH := "user://profile.json"
const VERSION := 1

## Where the profile saves; empty for one that never touches disk (tests).
var path := ""
var runs := 0
var wins := 0
var fights_won := 0
var bosses_beaten := 0
## Chassis id -> {"runs", "wins", "best_sector", "threat"}, where "threat" is the highest Threat
## level unlocked on that chassis.
var chassis_records: Dictionary = {}
## The ids of the unlocks earned.
var unlocked: Array[String] = []


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


## Returns the highest Threat level unlocked on the chassis with id [param chassis_id]: 0 until
## it wins a run, then one above the highest Threat it has won at.
func get_threat_unlocked(chassis_id: String) -> int:
	var record: Dictionary = chassis_records.get(chassis_id, {})
	return int(record.get("threat", 0))


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
## chassis. Returns the unlocks just earned.
func record_run(run: RunState, unlocks: Array[Unlock]) -> Array[Unlock]:
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
	chassis_records[chassis_id] = record
	var earned: Array[Unlock] = []
	for unlock in unlocks:
		if not is_unlocked(unlock.id) and unlock.is_met(self, sectors, chassis_id):
			unlocked.append(unlock.id)
			earned.append(unlock)
	return earned
