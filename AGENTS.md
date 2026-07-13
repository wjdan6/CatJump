# Project Overview

This is a 2D vertical platforming game made with Godot 4 and GDScript.

The player moves left and right and automatically interacts with platforms while ascending vertically. The core mechanic is an acceleration jump: pressing the jump button at the correct timing when landing on a platform increases the player's speed and jump power. Consecutive successful jumps should gradually increase the pace of the game.

Platforms may include environmental objects such as window frames, outdoor air-conditioning units, clouds, birds, and other objects.

# Development Rules

* Use Godot 4 APIs and GDScript.
* Inspect `project.godot`, relevant scenes, and existing scripts before making changes.
* Preserve existing node names, node paths, scene hierarchy, and signal connections unless a change is necessary.
* Do not rename or delete existing nodes, scenes, scripts, or assets without explaining why.
* Avoid large refactors when a small focused change can solve the problem.
* Do not edit `.tscn` or `.tres` files manually unless necessary.
* Prefer making scene and node changes through scripts only when appropriate.
* Use typed GDScript where practical.
* Add type annotations to variables, parameters, and return values where they improve clarity.
* Put gameplay tuning values such as speed, jump force, timing windows, and acceleration limits in `@export` variables so they can be adjusted in the Godot Inspector.
* Keep gameplay logic separated into clearly named functions.
* Do not add unnecessary systems, plugins, dependencies, or design patterns.
* Do not modify visual assets unless explicitly requested.
* Before implementing a feature, briefly explain which files will be changed.
* After implementing a feature, report:

  * files changed
  * important logic added
  * Inspector values that can be adjusted
  * steps for testing the feature in Godot
* When uncertain about the intended game behavior, preserve the current behavior and make the smallest reasonable change.
* Do not commit or push Git changes unless explicitly requested.
