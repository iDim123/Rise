# Checklist 1.1 — Blood & Servants Update

## Blood System
- [x] Blood config (types, drain rate, thresholds, buffs)
- [x] BloodManager server module
- [x] Blood types: Outcast (no buffs), Warrior (damage bonus 5-50%)
- [x] Blood quality 1-100% with linear buff scaling
- [x] Blood drain over time (2% per minute)
- [x] Drink blood from weakened enemies (<20% HP)
- [x] Hotkey F to drink blood
- [x] "Drink Blood [F]" label above weakened enemies
- [x] Blood type changes on drink, enemy dies
- [x] Fallback to Outcast 25% when current blood expires
- [x] HP drops to 1 when Outcast blood also expires
- [x] Blood damage buff applied to weapon attacks
- [x] Blood UI bar under HP bar (color-coded by type)
- [x] Blood quality % displayed on blood bar

## Servant System
- [x] Servant config (limits, capture range, cast time, AI settings)
- [x] ServantManager server module
- [x] Capture enemy with hotkey T (enemy <30% HP, within range, facing target)
- [x] 3-second cast with movement/action lock
- [x] Cancel cast by pressing T again
- [x] Cast progress bar UI
- [x] "Capture [T]" label above capturable enemies
- [x] Enemy disappears after successful capture
- [x] Servant stats calculated from enemy base stats + blood quality
- [x] Formula: Result = Base + Base * (BloodQuality / 100)
- [x] Servant collection storage (max 10)
- [x] Servant UI panel (hotkey V)
- [x] Servant list with ATK display
- [x] Servant detail panel (name, type, blood %, ATK, HP)
- [x] Rename servant (editable name field)
- [x] Summon servant (appears near player)
- [x] Dismiss servant (disappears)
- [x] Active servant limit: 1
- [x] Servant HP bar next to player HP bar
- [x] Servant AI: follow player
- [x] Servant AI: aggressive mode (attacks all enemies in range)
- [x] Servant AI: defensive mode (attacks enemies near owner)
- [x] Servant AI: passive mode (no attacks)
- [x] Servant commands: Follow, Stay, Attack Target
- [x] Mode buttons with active highlight
- [x] Weapon slot UI (placeholder)
- [x] Servants persist through player death
- [x] Enemy respawns after capture

## Combat Improvements
- [x] Floating damage numbers (white for enemy damage)
- [x] Floating damage numbers (red for player damage taken)
- [x] Floating heal numbers (green for healing received)
- [x] DamageEvent sends damage amount to clients
- [x] HealEvent remote for healing visualization

## Enemy Improvements
- [x] Blood quality % displayed before enemy name
- [x] Blood type and quality assigned on spawn
- [x] Blood type and quality assigned on respawn (HealthManager)

## Project Structure
- [x] Reorganized client scripts into subfolders (camera, combat, ui, input)
- [x] Reorganized server scripts into subfolders (combat, enemy, blood, servant, inventory)
- [x] Moved shared modules to shared/modules/
- [x] Updated all require paths to use ReplicatedStorage.modules
- [x] Fixed require path issues after reorganization
