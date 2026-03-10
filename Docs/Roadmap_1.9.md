# Roadmap v1.9 — Castle Building

> Дорожная карта для версии 1.9.
> Система строительства замков с кооперативным режимом, разрушаемыми блоками и функциональными элементами.

## Фазы реализации

Phase 0: Refactoring (1 неделя) — подготовка систем к интеграции Phase 1: Castle Foundation (2 недели) — фундамент строительства Phase 2: Castle Interiors (1-2 недели) — функциональные блоки Phase 3: Integration & Polish (1 неделя) — UI, миникарта, stress test


---

## Phase 0: Refactoring (develop_1.9_phase0)

Цель: подготовить существующие системы (HealthManager, TargetFinder, LootManager, CraftHandler) к интеграции с замками. Создать ContainerManager.

### Задачи

| # | Задача | Сложность | Файлы |
|---|---|---|---|
| 0.1 | **HealthManager** — ветвь `IsStructure`: отдельный remote `StructureDamageEvent`, без DamageEvent для структур, `markCombat(attacker)` для атакующего, `StructureDestroyed` event | Medium | `server/modules/HealthManager.luau` |
| 0.2 | **TargetFinder** — `staticEntities` set, `addStaticEntity`/`removeStaticEntity`, обновлённый `isValidTarget` (BasePart + IsStructure), `getRootPosition` (BasePart fallback), порядок `rebuildGrid`: clear → enemies → players → static | Medium | `server/combat/TargetFinder.luau` |
| 0.3 | **LootManager** — рефакторинг: приватные `_createLootPart(position, itemId, itemName, amount)`, `_calcLootOffset(basePosition)`. Новый публичный метод `dropItemAtPosition(position, itemId, amount)`. **Намеренное изменение поведения:** `dropLoot` переходит с сетки `%3` на спиральное размещение через `_calcLootOffset` | Medium | `server/modules/LootManager.luau` |
| 0.4 | **CraftHandler** — опциональный параметр `context` в `onCraftItem`, поддержка `RequiresWorkbench` | Low | `server/inventory/CraftHandler.luau` |
| 0.7 | **Remotes** — добавить `StructureDamageEvent` | Low | `shared/Remotes.luau` |

### HealthManager — изменения в `takeDamage`

```lua
local isStructure = entity:GetAttribute("IsStructure")

if isStructure then
    Remotes.StructureDamageEvent:FireAllClients(entity, data.CurrentHP, data.MaxHP, damage)
    -- Структура не входит в combat, но АТАКУЮЩИЙ входит (останавливаем реген)
    if attacker then
        local StatsManager = require(modules:WaitForChild("StatsManager"))
        StatsManager.markCombat(attacker)
    end
else
    local attackerName = attacker and attacker.Name or "Unknown"
    Remotes.DamageEvent:FireAllClients(entity, data.CurrentHP, data.MaxHP, damage, attackerName)
    local StatsManager = require(modules:WaitForChild("StatsManager"))
    StatsManager.markCombat(entity)
    if attacker then StatsManager.markCombat(attacker) end
end
HealthManager — изменения в die
Copyif entity:GetAttribute("IsStructure") then
    EventBus.fire("StructureDestroyed", entity, attacker)
    healthData[entity] = nil
    return
end
-- ... существующая логика без изменений ...
TargetFinder — rebuildGrid порядок
╔══════════════════════════════════════════════════════╗
║  ПОРЯДОК ВАЖЕН: clear → enemies → players → static  ║
║  staticEntities восстанавливаются ПОСЛЕДНИМИ,        ║
║  чтобы entityCell был актуален после clear.          ║
╚══════════════════════════════════════════════════════╝
TargetFinder — isValidTarget обновлённый
Copylocal function isValidTarget(entity)
    if not entity or not entity.Parent then return false end
    if entity:IsA("BasePart") and entity:GetAttribute("IsStructure") then
        return not entity:GetAttribute("IsDead")
    end
    return CharacterUtil.isAlive(entity) and entity:FindFirstChild("HumanoidRootPart") ~= nil
end
TargetFinder — getRootPosition обновлённый
Copylocal function getRootPosition(entity)
    if entity:IsA("BasePart") then
        return entity.Position
    end
    local rootPart = entity:FindFirstChild("HumanoidRootPart")
    return rootPart and rootPart.Position or nil
end
LootManager — рефакторинг
Copy-- Приватные функции
local function _createLootPart(position, itemId, itemName, amount)
    -- Единственное место создания лут-парта
    -- Part, атрибуты, папка Loot, activeLoot
end

local function _calcLootOffset(basePosition)
    -- Спиральное смещение на основе количества лута рядом
end

-- Публичные методы используют _createLootPart и _calcLootOffset:
-- dropLoot, dropItemFromPlayer, dropItemAtPosition (NEW)
Намеренное изменение поведения: dropLoot ранее использовал детерминированную сетку (dropIndex % 3, floor(dropIndex / 3)). Теперь использует _calcLootOffset — спиральное размещение с рандомом. Визуально лучше, но не идентично прежнему поведению.

ContainerManager API
Метод	Описание
registerContainer(containerId, slotCount, ownerPart?)	Создать контейнер
removeContainer(containerId)	Удалить контейнер
getContainer(containerId)	Получить данные
open(player, containerId)	Открыть (проверка дистанции)
close(player, containerId)	Закрыть
takeItem(player, containerId, slotIndex)	Забрать предмет
takeAll(player, containerId)	Забрать всё
putItem(player, containerId, invSlotIndex)	Положить предмет
sort(player, containerId)	Сортировка
serializeContainer(containerId)	Для DataStore
deserializeContainer(containerId, data)	Из DataStore
Критерии готовности Phase 0
 HealthManager корректно обрабатывает IsStructure (init, takeDamage без DamageEvent, die с StructureDestroyed)
 markCombat(attacker) вызывается при атаке структуры
 TargetFinder: addStaticEntity/removeStaticEntity работают, структуры находятся через inRadius
 TargetFinder: rebuildGrid не теряет статические объекты (порядок: clear → enemies → players → static)
 LootManager: _createLootPart переиспользуется в 3 публичных методах, dropItemAtPosition работает
 CraftHandler принимает context с hasWorkbench
 ContainerManager: register, open, takeItem, takeAll, close работают
 ContainerServer: remote-ы обрабатываются
 Все существующие системы не сломаны (регрессия: бой, лут, инвентарь)
Phase 1: Castle Foundation (develop_1.9_phase1)
Цель: игрок может основать замок, разместить фундамент, стены, полы, крыши. Поддержка кооперативного строительства. Блоки разрушаемы.

Задачи
#	Задача	Сложность	Файлы
1.1	BuildingConfig — типы блоков, настройки сетки, лимиты, DefaultPermissions	Low	shared/config/BuildingConfig.luau
1.2	CastleBorder — территории + permissions (canBuild, canRemove, canInteract, AllowedPlayers)	Medium	server/modules/building/CastleBorder.luau
1.3	BuildingValidator — проверки: коллизии, PlacementRule, лимиты, территория, CanRotate	Medium	server/modules/building/BuildingValidator.luau
1.4	BuildingSerializer — сериализация/десериализация с контрактом (Position, Rotation, TypeId; Size/Material/HP из конфига)	Medium	server/modules/building/BuildingSerializer.luau
1.5	BlockHealth — мост BuildingManager ↔ HealthManager: initBlock, подписка StructureDestroyed, вызов TargetFinder.addStaticEntity/removeStaticEntity	Medium	server/modules/building/BlockHealth.luau
1.6	BuildingManager — ядро: placeBlock (с coop permissions), removeBlock, onBlockDestroyedByDamage, initPlayer (синхронное восстановление), collect, cleanup	High	server/modules/building/BuildingManager.luau
1.7	BuildingServer — remote-оркестратор: PlaceBlock, RemoveBlock, GetBuildings, SetBuildPermission, AddBuildAlly, RemoveBuildAlly (rate-limit 0.3с)	Medium	server/building/BuildingServer.server.luau
1.8	Remotes — PlaceBlock, RemoveBlock, GetBuildings, BuildingSync, SetBuildPermission, AddBuildAlly, RemoveBuildAlly	Low	shared/Remotes.luau
1.9	DataService интеграция — BuildingData в getDefaultData, _applyData, collect	Low	server/modules/DataService.luau
1.10	PlayerLifecycle — BuildingManager.cleanup в onPlayerRemoving	Low	server/PlayerLifecycle.server.luau
1.11	Main.server — BuildingManager.init()	Low	server/Main.server.luau
1.12	BuildingPlacer (client) — ghost preview, snap-to-grid, поворот (R), клиентская превалидация, режим удаления (X) с Highlight и HP	High	client/ui/building/BuildingPlacer.luau
1.13	BuildingMenu (client) — UI строительства (B): сетка блоков, стоимость, секция permissions для владельца	Medium	client/ui/building/BuildingMenu.client.luau
1.14	BuildingConstants — цвета ghost (valid/invalid), размеры UI, клавиши	Low	client/ui/building/BuildingConstants.luau
1.15	BuildingDamageNumbers — floating damage над структурами через StructureDamageEvent	Low	client/ui/building/BuildingDamageNumbers.client.luau
BuildingConfig — содержание
Copyreturn {
    Building = {
        GridSize = 4,
        MaxBlocks = 500,
        ClaimRadius = 64,
        MaxCastlesPerWorld = 4,
        RemoveRefundRate = 0.5,

        DefaultPermissions = {
            AllowCoopBuild = false,
            AllowCoopRemove = false,
            AllowCoopInteract = true,
        },

        BlockCategories = { "Foundation", "Wall", "Floor", "Roof", "Functional" },

        BlockTypes = {
            stone_foundation = {
                Name = "Каменный фундамент",
                Category = "Foundation",
                Size = Vector3.new(4, 1, 4),
                Material = Enum.Material.Slate,
                Color = Color3.fromRGB(120, 120, 120),
                HP = 500,
                Cost = { { Id = "stone", Amount = 10 } },
                PlacementRule = "Ground",
                CanRotate = false,
            },
            stone_wall = { ... },      -- Category = "Wall", PlacementRule = "OnFoundation"
            wooden_wall = { ... },     -- Category = "Wall"
            wooden_floor = { ... },    -- Category = "Floor"
            wooden_roof = { ... },     -- Category = "Roof", PlacementRule = "OnWall"
            stone_pillar = { ... },    -- Category = "Wall"
            -- Phase 2: Functional (определяются здесь, используются в Phase 2)
            wooden_door = { ... Functional = "Door" },
            chest = { ... Functional = "Chest", FunctionalData = { Slots = 12 } },
            workbench = { ... Functional = "Workbench" },
            blood_altar = { ... Functional = "BloodAltar" },
            coffin = { ... Functional = "Coffin" },
        }
    }
}
Copy
CastleBorder — permissions API
Copy-- Внутреннее состояние:
-- claims[ownerId] = {
--     center, radius,
--     permissions = {
--         AllowCoopBuild, AllowCoopRemove, AllowCoopInteract,
--         AllowedPlayers = { [userId] = true }
--     }
-- }

-- Логика canBuild(actorId, ownerId):
-- actorId == ownerId → true
-- AllowCoopBuild == false → false
-- AllowedPlayers не пустой и actorId не в списке → false
-- иначе → true
BuildingSerializer — контракт
╔══════════════════════════════════════════════════════════════════╗
║  КОНТРАКТ СЕРИАЛИЗАЦИИ                                           ║
║                                                                  ║
║  Сохраняются: TypeId, Position ({x,y,z}), Rotation, ContainerId ║
║  НЕ сохраняются (из конфига при загрузке):                       ║
║    Size, Material, Color, Cost, PlacementRule, CanRotate         ║
║                                                                  ║
║  HP БЛОКОВ:                                                      ║
║    Текущее HP НЕ сохраняется. При загрузке — полное HP           ║
║    из конфига. Повреждённые блоки «лечатся» при перезаходе.      ║
║    Намеренное поведение v1.9. Для персистентности HP             ║
║    добавить поле H в формат (обратно совместимо).                ║
║                                                                  ║
║  Защита: неизвестные typeId пропускаются с warn.                 ║
║  Изменения конфига применяются к существующим постройкам.        ║
╚══════════════════════════════════════════════════════════════════╝
BuildingManager — синхронное восстановление
╔══════════════════════════════════════════════════════════════╗
║  СИНХРОННОЕ восстановление — НЕТ task.wait внутри цикла      ║
║  TargetFinder.addStaticEntity вызывается для каждого блока   ║
║  сразу. Luau однопоточный — rebuildGrid не вклинится.        ║
║  500 блоков ≈ 10-50мс — один кадр, приемлемо.               ║
╚══════════════════════════════════════════════════════════════╝
BuildingManager.placeBlock — логика с coop
1. Определить owner замка:
   - position внутри существующего claim → coop: CastleBorder.canBuild(actorId, ownerId)
   - position не в claim, у player нет замка → создать новый
   - position не в claim, у player есть замок → проверить ClaimRadius
2. BuildingValidator.validate(castle, blockTypeId, position, rotation)
3. Проверить ресурсы (из инвентаря СТРОИТЕЛЯ)
4. Списать ресурсы
5. Создать Part, BlockHealth.initBlock(part, blockType, ownerId)
6. InventorySync.sendFullUpdate(player)
7. EventBus.fire("BlockPlaced", player, blockTypeId, position)
Snap-to-grid система
Все блоки размещаются на сетке GridSize (4 studs). Клиент показывает ghost-preview с привязкой к сетке. Зелёный = можно ставить, красный = нельзя. Поворот: клавиша R (шаг 90°, только для CanRotate = true).

Новые EventBus события
Событие	Аргументы	Кто fire	Кто listen
StructureDestroyed	entity, attacker	HealthManager	BlockHealth → BuildingManager
BlockPlaced	player, blockTypeId, position	BuildingManager	—
BlockRemoved	player/nil, position	BuildingManager	—
Новые Remotes (Phase 0 + Phase 1)
Remote	Тип	Направление
StructureDamageEvent	Event	Server → All Clients
PlaceBlock	Event	Client → Server
RemoveBlock	Event	Client → Server
GetBuildings	Function	Client → Server
BuildingSync	Event	Server → Client
SetBuildPermission	Event	Client → Server
AddBuildAlly	Event	Client → Server
RemoveBuildAlly	Event	Client → Server
Критерии готовности Phase 1
 Игрок может основать замок (первый foundation = centerPos)
 Стены, полы, крыши ставятся по PlacementRule
 Ghost-preview с snap-to-grid, поворот R, отмена Esc
 Расход материалов при строительстве
 Удаление блоков (возврат 50% материалов)
 Лимит блоков на замок (500)
 Блоки разрушаемы (HealthManager + StructureDamageEvent)
 Floating damage numbers над повреждёнными блоками
 Кооперативное строительство (permissions: AllowCoopBuild, AllowedPlayers)
 Сохранение построек в DataStore (синхронное восстановление при входе)
 Территория замка (ClaimRadius, чужие территории не пересекаются)
Phase 2: Castle Interiors (develop_1.9_phase2)
Цель: замок имеет функциональные элементы — двери, сундуки, верстак, алтарь крови, гроб.

Задачи
#	Задача	Сложность	Файлы
2.1	DoorHandler — toggle open/close (F), canInteract permissions, TweenService поворот 90°, CanCollide toggle	Medium	server/modules/building/DoorHandler.luau
2.2	ChestHandler — onCreate → ContainerManager.registerContainer, onInteract → ContainerManager.open, onDestroy → dropItemAtPosition для содержимого + removeContainer	Medium	server/modules/building/ChestHandler.luau
2.3	ContainerConfig — добавить castle_chest тип (Slots=12, InteractRange=5, Persistent=true)	Low	shared/config/ContainerConfig.luau
2.4	ContainerUI — сканирование workspace.Castles в дополнение к workspace.Containers (scanFolders)	Low	client/ui/ContainerUI.client.luau
2.5	WorkbenchHandler — onInteract → OpenCraftStation remote с {hasWorkbench=true}, CraftPanel реагирует на remote	Medium	server/modules/building/WorkbenchHandler.luau
2.6	BloodAltarHandler — onInteract → OpenBloodAltar remote, механика: blood_essence → +Quality%, клиентский мини-UI	Medium	server/modules/building/BloodAltarHandler.luau
2.7	CoffinHandler — onCreate → castle.coffinPos, onDestroy → castle.coffinPos = nil, один гроб на замок	Low	server/modules/building/CoffinHandler.luau
2.8	HealthManager — respawnAtCoffin(): CharacterAdded:Wait() с защитой player.Parent, WaitForChild timeout 5с. Применяется в PlayerRespawn remote и страховочном task.delay	Medium	server/modules/HealthManager.luau
2.9	InteractBlock remote — маршрутизация в BuildingServer по Functional типу	Low	server/building/BuildingServer.server.luau
2.10	Укрытие от солнца — проверить что DayNightManager.isInShelter() Raycast работает с крышей замка (ожидание: работает из коробки, крыша = Anchored Part)	Low	—
CoffinHandler — респавн
Copy-- Утилитная функция в HealthManager:
local function respawnAtCoffin(player)
    local BuildingManager = require(...)
    local coffinPos = BuildingManager.getCoffinPos(player)
    if not coffinPos then return end

    task.spawn(function()
        local newChar = player.CharacterAdded:Wait()
        if not player.Parent then return end     -- игрок вышел
        local hrp = newChar:WaitForChild("HumanoidRootPart", 5)
        if hrp then
            hrp.CFrame = CFrame.new(coffinPos + Vector3.new(0, 3, 0))
        end
    end)
end

-- Вызывается в PlayerRespawn remote и страховочном task.delay
ChestHandler — уничтожение NPC
Copyfunction ChestHandler.onDestroy(part, blockData)
    local containerId = blockData.containerId
    if not containerId then return end
    local container = ContainerManager.getContainer(containerId)
    if not container then return end

    -- Дропнуть содержимое как лут рядом с позицией сундука
    for i = 1, container.slotCount do
        local slot = container.slots[i]
        if slot and slot ~= false then
            LootManager.dropItemAtPosition(part.Position, slot.Id, slot.Amount or 1)
        end
    end
    ContainerManager.removeContainer(containerId)
end
Новые Remotes (Phase 2)
Remote	Тип	Направление
InteractBlock	Event	Client → Server
OpenCraftStation	Event	Server → Client
OpenBloodAltar	Event	Server → Client
Критерии готовности Phase 2
 Дверь открывается/закрывается (F), анимация поворота, canInteract permissions
 Сундук хранит предметы, открывается через ContainerUI, данные сохраняются в DataStore
 При уничтожении сундука NPC — содержимое дропается как лут
 Верстак открывает расширенный крафт (RequiresWorkbench рецепты)
 Кровавый алтарь улучшает качество крови за blood_essence
 Гроб = точка респавна (CharacterAdded:Wait с защитой от выхода)
 Крыша замка защищает от sunlight_exposure (Raycast DayNightManager)
Phase 3: Integration & Polish (develop_1.9_phase3)
Задачи
#	Задача	Сложность
3.1	BlockCategoryTabs — категории блоков в BuildingMenu (Foundation/Wall/Floor/Roof/Functional)	Medium
3.2	MenuBar — кнопка Build (B)	Low
3.3	Minimap — отображение замков (цвет Castle, dot на центр замка)	Low
3.4	DataStore stress test — 500 блоков + 100 врагов + 4 игрока	High
3.5	Visual polish — эффекты размещения/удаления, звуки	Medium
3.6	Регрессионное тестирование — все системы	High
Критерии готовности Phase 3
 Категории блоков в меню строительства
 Кнопка B в MenuBar
 Замки видны на миникарте
 DataStore: save/load 500 блоков < 100мс, размер < 100КБ
 FPS: 500 блоков + 100 врагов + 4 игрока ≥ 30 FPS
 Все системы 1.0–1.8 работают без регрессий
Техническая архитектура (v1.9)
Структура файлов
src/
├── shared/
│   ├── Remotes.luau                              # MODIFY (Phase 0+1+2)
│   └── config/
│       ├── BuildingConfig.luau                   # NEW (Phase 1)
│       └── ContainerConfig.luau                  # MODIFY (Phase 2) — castle_chest
│
├── server/
│   ├── Main.server.luau                          # MODIFY (Phase 1)
│   ├── PlayerLifecycle.server.luau               # MODIFY (Phase 1)
│   ├── modules/
│   │   ├── HealthManager.luau                   # MODIFY (Phase 0, Phase 2)
│   │   ├── LootManager.luau                     # REFACTOR (Phase 0)
│   │   ├── DataService.luau                     # MODIFY (Phase 1)
│   │   ├── ContainerManager.luau                # NEW (Phase 0)
│   │   └── building/
│   │       ├── BuildingManager.luau              # NEW (Phase 1)
│   │       ├── BuildingValidator.luau            # NEW (Phase 1)
│   │       ├── CastleBorder.luau                 # NEW (Phase 1)
│   │       ├── BuildingSerializer.luau           # NEW (Phase 1)
│   │       ├── BlockHealth.luau                  # NEW (Phase 1)
│   │       ├── DoorHandler.luau                  # NEW (Phase 2)
│   │       ├── ChestHandler.luau                 # NEW (Phase 2)
│   │       ├── WorkbenchHandler.luau             # NEW (Phase 2)
│   │       ├── BloodAltarHandler.luau            # NEW (Phase 2)
│   │       └── CoffinHandler.luau                # NEW (Phase 2)
│   ├── building/
│   │   └── BuildingServer.server.luau            # NEW (Phase 1)
│   ├── combat/
│   │   └── TargetFinder.luau                    # MODIFY (Phase 0)
│   └── inventory/
│       ├── CraftHandler.luau                    # MODIFY (Phase 0)
│       └── ContainerServer.server.luau          # NEW (Phase 0)
│
└── client/
    └── ui/
        ├── ContainerUI.client.luau               # MODIFY (Phase 2)
        ├── Minimap.client.luau                   # MODIFY (Phase 3)
        ├── MenuBar.luau                          # MODIFY (Phase 3)
        └── building/
            ├── BuildingMenu.client.luau          # NEW (Phase 1)
            ├── BuildingPlacer.luau                # NEW (Phase 1)
            ├── BuildingConstants.luau             # NEW (Phase 1)
            ├── BuildingDamageNumbers.client.luau  # NEW (Phase 1)
            └── BlockCategoryTabs.luau             # NEW (Phase 3)
Зависимости новых модулей
BuildingServer.server.luau
├── BuildingManager
├── CastleBorder
└── Remotes

BuildingManager
├── BuildingValidator
├── BuildingSerializer
├── CastleBorder
├── BlockHealth
├── InventoryManager (lazy)
├── InventorySync (lazy)
├── ContainerManager (lazy, Phase 2)
├── EventBus
├── Config
└── Remotes

BuildingValidator
├── Config
└── CastleBorder (lazy)

CastleBorder
└── Config

BlockHealth
├── HealthManager
├── TargetFinder (addStaticEntity/removeStaticEntity)
├── EventBus (StructureDestroyed listener)
└── BuildingManager (lazy — через EventBus, без прямого require)

BuildingSerializer
└── Config

ContainerManager
├── InventoryManager (lazy)
├── InventorySync (lazy)
└── Remotes

BuildingMenu.client.luau
├── Config
├── BuildingPlacer
├── BuildingConstants
├── BlockCategoryTabs (Phase 3)
└── Remotes

BuildingPlacer
├── Config
├── BuildingConstants
├── Remotes
└── RunService
Полный список Remotes (v1.9)
Remote	Тип	Направление	Phase
StructureDamageEvent	Event	Server → All Clients	0
PlaceBlock	Event	Client → Server	1
RemoveBlock	Event	Client → Server	1
GetBuildings	Function	Client → Server	1
BuildingSync	Event	Server → Client	1
SetBuildPermission	Event	Client → Server	1
AddBuildAlly	Event	Client → Server	1
RemoveBuildAlly	Event	Client → Server	1
InteractBlock	Event	Client → Server	2
OpenCraftStation	Event	Server → Client	2
OpenBloodAltar	Event	Server → Client	2
Горячие клавиши (новые)
Клавиша	Действие	Контекст
B	Окно строительства / закрыть	Глобальная
R	Поворот блока 90°	Режим строительства
X	Режим удаления	Режим строительства
Escape	Отмена размещения	Режим строительства
LMB	Разместить / Удалить блок	Режим строительства
F	Взаимодействие (дверь/сундук/верстак/алтарь)	Рядом с функциональным блоком
Порядок реализации
Phase 0 (5 дней)
День	Задачи
1	HealthManager (IsStructure), Remotes (+StructureDamageEvent)
2	TargetFinder (staticEntities, add/remove, isValidTarget, getRootPosition, порядок rebuild)
3	LootManager рефакторинг (_createLootPart, _calcLootOffset, dropItemAtPosition)
4	ContainerManager + ContainerServer
5	CraftHandler (context), регрессионное тестирование
Phase 1 (10 дней)
День	Задачи
1	BuildingConfig
2	CastleBorder (с permissions)
3	BuildingValidator
4	BuildingSerializer (с контрактом)
5	BlockHealth
6-7	BuildingManager (placeBlock, removeBlock, onBlockDestroyedByDamage, initPlayer)
8	BuildingServer + DataService/PlayerLifecycle/Main интеграция
9	BuildingConstants + BuildingPlacer + BuildingDamageNumbers (клиент)
10	BuildingMenu (клиент) + тестирование
Phase 2 (7-10 дней)
День	Задачи
1	InteractBlock remote + маршрутизация в BuildingServer
2	DoorHandler
3-4	ChestHandler + ContainerConfig(castle_chest) + ContainerUI(scanFolders)
5	WorkbenchHandler + OpenCraftStation
6	BloodAltarHandler + OpenBloodAltar + мини-UI
7	CoffinHandler + HealthManager respawnAtCoffin
8	Проверка укрытия от солнца + тестирование
Phase 3 (5 дней)
День	Задачи
1	BlockCategoryTabs
2	MenuBar (B) + Minimap (замки)
3-4	DataStore stress test + оптимизация
5	Visual polish + регрессия