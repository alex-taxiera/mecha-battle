class_name StartingLoadout
extends Resource
## Another way to start a run on a frame: a different starter kit, picked on the frame select once
## the frame's mastery reaches [member mastery_level] (see [method Profile.get_mastery_level]).

@export var id: String
@export var loadout_name: String
@export_multiline var description: String
@export var mastery_level := 2
## The parts the run starts with installed, in place of the frame's own starter kit.
@export var lineup: Array[LoadoutPart] = []
