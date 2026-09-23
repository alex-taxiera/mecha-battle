# Godot Development Instructions

## Testing Pipeline
We use GdUnit4 for all testing. Whenever you create or modify a script or scene, you MUST run the automated test suite to verify your changes.

Run the tests headlessly from the project root using this command:
`godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://test -c --ignoreHeadlessMode -rd user://reports`

- `-a res://test` is required. Without it the tool only prints help and exits 0, which looks like a pass but runs nothing.
- `--ignoreHeadlessMode` is required. Without it GdUnit4 refuses to run headless.
- `-c` reports every failure instead of stopping at the first one.
- `-rd user://reports` keeps HTML/XML reports out of the project. The default `res://reports/` contains a PNG the editor would import.
- After adding, renaming, or moving a `class_name` script, run `godot --headless --path . --import` before testing. Headless runs don't rescan the project, so without it you get `Parse Error: Identifier "X" not declared in the current scope`.

## Reading Test Results
- Treat any non-zero exit as a failure and read the output. GdUnit4 prints its own code: 100 test failures, 101 orphan (leaked) nodes, 103 headless refused, 105 parse/script errors. On parse errors the process itself may exit 139 instead.
- Exit 0 alone doesn't prove tests ran. Check that `Executed test cases : (n/n)` matches the number you expect.
- Failures report `file:line`. Assertions inside a helper function report the helper's line, so pass context with `append_failure_message()`.

## Writing Tests
- Game logic lives in `res://src/<area>/`; its tests go in `res://test/<area>/<ClassName>Test.gd` (GdUnit4 maps `/src/` to `/test/`).
- Content (`.tres` parts, chassis, adjacency rules) lives in `res://resources/<kind>/`. Tests don't load it: they build data with `test/TestFixtures.gd`, pinned to the design doc and mockup, so tuning content never breaks a test.
- Pair every "rejects X" assertion with a positive control that must succeed. Otherwise a stub that always returns false passes.
- Hardcode expected values from `design_doc.md` instead of reading constants from the class under test.
- `contains_exactly_in_any_order` and `contains_same_exactly_in_any_order` ignore duplicates. Chain `.has_size(n)` when the count matters.
- Headless mode can't deliver InputEvents, so simulated mouse/keyboard input does nothing. Test UI by calling its handlers directly (e.g. `_can_drop_data` / `_drop_data`).
- Nodes removed with `queue_free()` count as orphans (exit 101) until the frame ends. If a test triggers that, finish it with `await await_idle_frame()`.

## Godot MCP Notes
- `create_scene` names the root node `root`. Rename it with `manage_scene_structure`.
- `add_node` takes an engine class or a `class_name` script but can't instance a `.tscn`. To instance one, add a plain node, then set its `scene_file_path` to the `.tscn` with `modify_scene_node`. The MCP also saves a redundant `type`/`script` on that node; that's harmless.
- Property values: pass Vector2 as `{"x": .., "y": ..}`, Color as `"#rrggbb"`, and resources as `"res://..."` paths. Typed arrays can't be set.
- Anchors: the scene root only needs `anchors_preset: 15`. Any other node outside a container needs `layout_mode: 1` before `anchors_preset`, or the preset silently does nothing.
- `create_resource` only knows engine classes. Create custom-Resource `.tres` files (e.g. a `MechPart`) with a headless script that calls `ResourceSaver.save()`.
- `run_project` injects an `McpInteractionServer` autoload and script into the project. `stop_project` removes them but leaves an empty `[autoload]` section in `project.godot`; delete it.
- A script error in `game_eval` freezes the game at a `debug>` prompt. Call `stop_project`, then run it again.
- `game_mouse_drag` can't finish a drag-and-drop, because Godot 4.7 aims the drop at the real OS cursor. To test drops in a running game, `push_input()` events into a standalone `SubViewport` (not inside a `SubViewportContainer`).
- In that harness, call `game_wait` for a frame after anything that rebuilds or reveals controls (a refresh, a drag that shows a drop zone) before pushing input at them. Containers lay out on the next frame, so earlier input hits the old rects.
- `game_screenshot` returns a stale frame while the game window is minimized.

## Addons
- `addons/phantom_camera/` (Phantom Camera 0.11.0.3) is vendored for dynamic camera effects later: following and framing, tweened moves between shots, and shake from noise emitters (e.g. combat hits). Use it for camera work instead of hand-tweening a `Camera2D`/`Camera3D`.
- It isn't enabled yet. Enable it when first used, from the editor's Plugins tab, which also adds its `PhantomCameraManager` autoload. Adding it to `[editor_plugins]` in `project.godot` by hand skips that autoload; add `PhantomCameraManager="*res://addons/phantom_camera/scripts/managers/phantom_camera_manager.gd"` under `[autoload]` too.
- Setup: the scene's `Camera2D`/`Camera3D` gets a `PhantomCameraHost` child, and `PhantomCamera2D`/`PhantomCamera3D` nodes drive it by priority.
- Don't edit files under `addons/`. To update an addon, replace its folder.

## Rules
1. Read the output of the test command. If it fails, fix the code and run it again.
2. Keep UI visuals separate from game logic so tests can run cleanly on scripts.
3. Use the Godot MCP tools to modify `.tscn` files—do not edit them directly as raw text.
4. Commit the `.uid` and `.import` files Godot generates next to scripts and assets. They hold resource UIDs and import settings, so never delete or gitignore them.
