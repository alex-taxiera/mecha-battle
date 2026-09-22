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
- Pair every "rejects X" assertion with a positive control that must succeed. Otherwise a stub that always returns false passes.
- Hardcode expected values from `design_doc.md` instead of reading constants from the class under test.
- `contains_exactly_in_any_order` and `contains_same_exactly_in_any_order` ignore duplicates. Chain `.has_size(n)` when the count matters.
- Headless mode can't deliver InputEvents, so simulated mouse/keyboard input does nothing. Test UI by calling its handlers directly (e.g. `_can_drop_data` / `_drop_data`).

## Rules
1. Read the output of the test command. If it fails, fix the code and run it again.
2. Keep UI visuals separate from game logic so tests can run cleanly on scripts.
3. Use the Godot MCP tools to modify `.tscn` files—do not edit them directly as raw text.
4. Commit the `.uid` and `.import` files Godot generates next to scripts and assets. They hold resource UIDs and import settings, so never delete or gitignore them.
