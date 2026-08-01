# PC Creator 2 Reference Archive

This directory is the canonical local archive for PC Creator 2 visual and
interaction references. It is outside the Godot project so these files cannot be
imported or packaged as runtime assets by accident.

- The top-level PNG files and `item_icons/` are the canonical reference set.
- `legacy_godot_project_copy/` preserves the former Godot-project copy and its
  generated `.import` metadata for audit history.
- Public builds must use `GodotVersion/assets/original/` or another documented,
  commercially usable source instead of files from this archive.
