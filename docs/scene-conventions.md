# Scene Conventions

House rules for scenes so new ones look like the old ones.

## Structure

- One scene per gameplay screen or level; keep reusable pieces as scenes nested inside.
- Node names are stable once referenced by scripts — renaming is a project-wide search.
- Scene settings (viewport, stretch mode) come from `project.godot`; scenes do not override them ad hoc.

## Hygiene

- Unused nodes get deleted, not hidden.
- Prefer exported script variables over magic values in node properties.
- `tests/` should be able to load any scene headlessly without side effects.

When a scene grows past a screenful of nodes, split it.
