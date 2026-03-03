# Checklist 1.2 — Crafting & Consumables Update

## UI Refactoring
- [x] Split CharacterWindow.client.luau into modules
- [x] Created `src/client/ui/character/` folder structure
- [x] UIConstants.luau — centralized sizes, colors, layout calculations
- [x] SlotFactory.luau — unified slot creation and update
- [x] DragManager.luau — drag-and-drop ghost UI and state
- [x] EquipmentPanel.luau — equipment slots panel
- [x] CraftPanel.luau — crafting recipes panel with tooltip
- [x] InventoryGrid.luau — ActionBar row + inventory grid + sort button
- [x] ActionBarHUD.luau — bottom-screen ActionBar ScreenGui
- [x] CharacterWindow.client.luau — thin orchestrator with tabs and hotkeys

## Crafting System
- [x] Config.Crafting section with recipes
- [x] Recipe: Зелье восстановления (10 blood_essence → 1 health_potion, 1s)
- [x] Recipe: Зелье восстановления x5 (50 blood_essence → 5 health_potion, 3s)
- [x] CraftItem RemoteEvent on server
- [x] Craft queue system (multiple crafts queued sequentially)
- [x] Server-side ingredient validation and consumption
- [x] CraftTime delay with progress steps
- [x] CraftQueueUpdate RemoteEvent for client sync
- [x] Queue count display (yellow "xN") on recipe rows
- [x] Progress bar on recipe rows (green fill during craft)
- [x] InventoryManager.countItem() helper
- [x] InventoryManager.removeItemById() helper
- [x] InventoryManager.addItemFromConfig() helper

## Crafting UI
- [x] Crafting tab in CharacterWindow (second tab)
- [x] Scrollable recipe list with icons and names
- [x] Tooltip on hover — title, icon, type, craft time, description
- [x] Tooltip — ingredient list with have/cost colored (green/red)
- [x] Tooltip positioned to the right of character window, top-aligned
- [x] Click recipe row to queue craft

## Consumable System
- [x] Config.Items.health_potion with UseEffect (Heal, 50 HP, 5s cooldown)
- [x] UseItem RemoteEvent on server
- [x] Server-side cooldown tracking per player per item
- [x] Server-side heal via HealthManager.heal()
- [x] Item consumed on use (removeItem)
- [x] Right-click consumable in inventory to use
- [x] Right-click consumable in ActionBarHUD to use

## Hotkey Support for Consumables
- [x] Hotkeys 1-8 detect item type in slot
- [x] Consumable in slot → fires UseItem instead of SetActiveWeapon
- [x] ActionBarHUD click detects Consumable vs Weapon
- [x] Client-side cooldown check before firing UseItem

## Cooldown Visualization
- [x] CooldownManager.luau — new module for tracking cooldown timers
- [x] CooldownOverlay (dark curtain) on each slot via SlotFactory
- [x] CooldownText (white number with black stroke) centered on slot
- [x] Curtain sweeps top-to-bottom as cooldown expires
- [x] Registered on InventoryGrid slots (1-40)
- [x] Registered on ActionBarHUD slots (1-8)
- [x] Cooldown started on client immediately on use (responsive feel)
- [x] Server still enforces authoritative cooldown

## Config Updates
- [x] Player MaxHP changed to 200
- [x] Config.Items section added (blood_essence, health_potion)
- [x] Config.Crafting section added with Recipes array
- [x] Items define UseEffect for consumable behavior

## Bug Fixes
- [x] Fixed CraftItem RemoteEvent missing (infinite yield warning)
- [x] Fixed tooltip positioning (AbsolutePosition + GuiInset offset)
- [x] Fixed tooltip not appearing (Visible check in positionTooltip)
- [x] Fixed cooldown curtain direction (bottom-to-top → top-to-bottom)
- [x] Removed duplicate `local useItem` declaration in CharacterWindow