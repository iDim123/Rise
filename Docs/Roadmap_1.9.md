# Roadmap v1.9 — P Castle Building

> Дорожная карта для версии 1.9.

## Фазы реализации

```
Phase 1: Castle Foundation   (2 недели)
Phase 2: Castle Interiors    (1-2 недели)
Phase 3: Integration & Polish (1 неделя)
```

---

## Phase 1: Castle Foundation — Фундамент строительства (develop_1.9_phase4)

Цель: игрок может разместить фундамент замка и строить базовые стены.

### Задачи

| # | Задача | Сложность | Файлы |
|---|---|---|---|
| 1.1 | **BuildingConfig** — типы строительных блоков | Low | `shared/config/BuildingConfig.luau` |
| 1.2 | **BuildingManager** — серверная логика размещения / удаления | High | `server/modules/building/BuildingManager.luau` |
| 1.3 | **BuildingValidator** — проверки: коллизии, грунт, лимиты | Medium | `server/modules/building/BuildingValidator.luau` |
| 1.4 | **BuildingPlacer (client)** — ghost preview, snap-to-grid | High | `client/ui/building/BuildingPlacer.luau` |
| 1.5 | **BuildingUI (client)** — меню строительства | Medium | `client/ui/building/BuildingMenu.client.luau` |
| 1.6 | **CastleBorder** — границы замка (claim area) | Medium | `server/modules/building/CastleBorder.luau` |
| 1.7 | **Remotes** — PlaceBlock, RemoveBlock, GetBuildings | Low | (интеграция с Remotes.luau) |
| 1.8 | **Интеграция с крафтом** — стройматериалы из ресурсов | Low | (интеграция с CraftConfig) |

### BuildingConfig — пример

```lua
return {
    Building = {
        GridSize = 4,          -- studs (snap)
        MaxBlocks = 500,       -- макс блоков на замок
        ClaimRadius = 64,      -- studs (территория замка)
        MaxCastlesPerWorld = 4, -- по одному на игрока

        BlockTypes = {
            stone_foundation = {
                Name = "Каменный фундамент",
                Size = Vector3.new(4, 1, 4),
                Material = Enum.Material.Slate,
                Color = Color3.fromRGB(120, 120, 120),
                HP = 500,
                Cost = { { Id = "stone", Amount = 10 } },
                PlacementRule = "Ground", -- только на землю
            },
            stone_wall = {
                Name = "Каменная стена",
                Size = Vector3.new(4, 4, 1),
                Material = Enum.Material.Slate,
                Color = Color3.fromRGB(140, 140, 140),
                HP = 300,
                Cost = { { Id = "stone", Amount = 8 } },
                PlacementRule = "OnFoundation",
            },
            wooden_floor = {
                Name = "Деревянный пол",
                Size = Vector3.new(4, 0.5, 4),
                Material = Enum.Material.Wood,
                Color = Color3.fromRGB(139, 90, 43),
                HP = 200,
                Cost = { { Id = "wooden_plank", Amount = 4 } },
                PlacementRule = "OnFoundation",
            },
            wooden_roof = {
                Name = "Деревянная крыша",
                Size = Vector3.new(4, 0.5, 4),
                Material = Enum.Material.Wood,
                Color = Color3.fromRGB(100, 60, 30),
                HP = 150,
                Cost = { { Id = "wooden_plank", Amount = 6 } },
                PlacementRule = "OnWall",
            },
        }
    }
}
```

### Snap-to-grid система

Все блоки размещаются на сетке GridSize (4 studs). Клиент показывает ghost-preview с привязкой к сетке. Зелёный = можно ставить, красный = нельзя (коллизия / нет фундамента / вне зоны).

### Критерии готовности Phase 1

- [ ] Игрок может разместить фундамент на ровной поверхности
- [ ] Стены ставятся на фундамент
- [ ] Ghost-preview с snap-to-grid
- [ ] Расход материалов при строительстве
- [ ] Удаление блоков (возврат части материалов)
- [ ] Лимит блоков на замок (500)
- [ ] Сохранение построек в DataStore

---

## Phase 2: Castle Interiors — Интерьер и функционал (develop_1.9_phase5)

Цель: замок имеет функциональные элементы.

### Задачи

| # | Задача | Сложность | Файлы |
|---|---|---|---|
| 2.1 | **Дверь** — открытие/закрытие, доступ для команды | Medium | building/DoorBlock.luau |
| 2.2 | **Сундук** — хранилище предметов (общий для команды) | Medium | building/ChestBlock.luau |
| 2.3 | **Верстак** — крафт-станция (расширенные рецепты) | Medium | building/WorkbenchBlock.luau |
| 2.4 | **Кровавый алтарь** — обработка крови, ритуалы | Medium | building/BloodAltarBlock.luau |
| 2.5 | **Гроб** — точка возрождения (замена стандартного респавна) | Low | building/CoffinBlock.luau |
| 2.6 | **Укрытие от солнца** — крыша защищает от sunlight_exposure | Low | (интеграция с DayNightManager) |

### Критерии готовности Phase 2

- [ ] 5+ функциональных блоков
- [ ] Замок защищает от солнца (крыша → нет дебаффа)
- [ ] Сундук хранит предметы между сессиями
- [ ] Гроб = точка респавна
- [ ] Верстак = расширенный крафт

---

## Phase 3: Integration & Polish (develop_1.9_phase6)

### Задачи

| # | Задача | Сложность |
|---|---|---|
| 3.3 | Миникарта: замка | Low |
| 3.4 | UI: кнопка строительства (B), категории блоков | Medium |
| 3.6 | DataStore stress test: 500 блоков + 100 врагов + 4 игрока | High |

---

## Техническая архитектура (v1.9)

### Новая структура файлов

```
src/
├── shared/
│   └── config/
│       └── BuildingConfig.luau   # Phase 1
├── server/
│   └── modules/
│       └── building/
│           ├── BuildingManager.luau      # Phase 1 — размещение
│           ├── BuildingValidator.luau    # Phase 1 — валидация
│           └── CastleBorder.luau        # Phase 1 — территория
├── client/
│   └── ui/
│       └── building/
│           ├── BuildingMenu.client.luau  # Phase 1 — UI
│           └── BuildingPlacer.luau       # Phase 1 — ghost preview
```

### Новые EventBus события

| Событие | Аргументы | Фаза |
|---|---|---|
| BlockPlaced | player, blockType, position | Phase 1 |
| BlockRemoved | player, position | Phase 1 |

### Новые Remotes

| Remote | Направление | Фаза |
|---|---|---|
| PlaceBlock | Client → Server | Phase 1 |
| RemoveBlock | Client → Server | Phase 1 |
| GetBuildings | Client → Server (Function) | Phase 1 |

---

