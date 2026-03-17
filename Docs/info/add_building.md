# Добавление новой крафтовой станции (CraftStation)

> Инструкция по добавлению крафтовых станций типа Workbench, Forge, Alchemy Lab и т.д.
> Все станции используют единую систему `CraftStationHandler` + `CraftStationUI`.
> Изменения кода **не требуются** — только конфиги.

---

## Архитектура

BuildingConfig → Functional = "CraftStation", FunctionalData.StationType = "Forge" ↓ FunctionalDispatcher → маршрут "CraftStation" → CraftStationHandler ↓ CraftStationHandler → серверный контейнер (N слотов) + очередь крафта + heartbeat ↓ CraftStationUI → универсальный UI: рецепты (2 колонки) + контейнер (1 ряд) ↓ CraftConfig → рецепты фильтруются по Station == StationType


### Отличие от Processing Station (Sawmill, Crusher)

| | Processing Station | CraftStation |
|---|---|---|
| Обработчик | `StationHandler` | `CraftStationHandler` |
| UI | `StationUI` | `CraftStationUI` |
| Слоты | Input (N) + Output (N) | Единый контейнер (N) |
| Крафт | Автоматический (heartbeat, toggle рецептов) | Ручной (клик по рецепту → очередь) |
| Ресурсы | Только из input-слотов | Контейнер → потом инвентарь игрока |
| Результат | В output-слоты | В контейнер (если нет места — дроп) |
| Functional | `"Station"` | `"CraftStation"` |

---

## Пошаговая инструкция

### Пример: добавляем Кузницу (Forge)

### Шаг 1. StationConfig — зарегистрировать станцию

**Файл:** `src/shared/config/StationConfig.luau`

В секцию `CraftStations` добавить:

```lua
CraftStations = {
    Workbench = {
        Name = "Верстак",
        Slots = 9,
        InteractRange = 10,
    },
    -- ↓ НОВОЕ
    Forge = {
        Name = "Кузница",
        Slots = 9,
        InteractRange = 10,
    },
},
Параметры:

Поле	Тип	Описание
Name	string	Отображаемое название в UI (заголовок окна)
Slots	number	Количество слотов контейнера (1 ряд)
InteractRange	number	Дальность взаимодействия (F) в studs
Шаг 2. BuildingConfig — добавить блок
Файл: src/shared/config/BuildingConfig.luau

В BlockTypes добавить:

Copyforge = {
    Name = "Кузница",
    Description = "Позволяет ковать оружие и броню.",
    Category = "Functional",
    Size = Vector3.new(6, 4, 6),
    Material = Enum.Material.Slate,
    Color = Color3.fromRGB(100, 80, 70),
    HP = 200,
    Cost = {{
        ItemId = "stone",
        Amount = 20
    }, {
        ItemId = "wooden_plank",
        Amount = 10
    }},
    PlacementRule = "OnFoundation",
    CanRotate = true,
    Functional = "CraftStation",          -- ← обязательно "CraftStation"
    FunctionalData = {
        StationType = "Forge",            -- ← совпадает с ключом в StationConfig.CraftStations
    },
    Icon = "rbxassetid://0",
},
Ключевые поля:

Поле	Значение	Описание
Functional	"CraftStation"	Тип функционального блока (всегда одинаковый)
FunctionalData.StationType	"Forge"	Ключ станции — должен совпадать с StationConfig.CraftStations
Шаг 3. CraftConfig — добавить рецепты
Файл: src/shared/config/CraftConfig.luau

В массив Recipes добавить рецепты с Station = "Forge":

Copy-- ═══════════════════════════════════════
--  Кузница (Station = "Forge")
-- ═══════════════════════════════════════
{
    Id = "forge_iron_sword",
    Name = "Железный меч",
    Description = "Выковать меч из железа.",
    Icon = "rbxassetid://0",
    Station = "Forge",                    -- ← совпадает с StationType
    Result = { ItemId = "iron_sword", Amount = 1 },
    Ingredients = {
        { ItemId = "iron_ingot", Amount = 5 },
        { ItemId = "wood", Amount = 2 },
    },
    CraftTime = 6,
},
{
    Id = "forge_iron_helmet",
    Name = "Железный шлем",
    Description = "Выковать шлем из железа.",
    Icon = "rbxassetid://0",
    Station = "Forge",
    Result = { ItemId = "iron_helmet", Amount = 1 },
    Ingredients = {
        { ItemId = "iron_ingot", Amount = 8 },
    },
    CraftTime = 8,
},
Формат рецепта:

Поле	Тип	Обязательное	Описание
Id	string	Да	Уникальный идентификатор рецепта
Name	string	Да	Название (отображается в UI)
Description	string	Нет	Описание (в tooltip)
Icon	string	Нет	rbxassetid иконки
Station	string	Да	Тип станции ("Forge", "Workbench", ...)
Result	table	Да*	{ ItemId, Amount } — единственный результат
Results	array	Да*	{ { ItemId, Amount }, ... } — несколько результатов
Ingredients	array	Да	{ { ItemId, Amount }, ... }
CraftTime	number	Нет	Время крафта в секундах (0 = мгновенно)
RequiresTech	string	Нет	Требуется убить босса (bossId)
*Указать Result или Results, не оба.

Готово
После добавления трёх конфигов станция полностью работает:

Блок появляется в меню строительства (категория Functional)
Игрок ставит блок на фундамент
Нажатие F открывает UI с рецептами и контейнером
Рецепты фильтруются по Station == "Forge"
Крафт работает: ресурсы из контейнера → потом из инвентаря → результат в контейнер
Очередь крафта с прогресс-баром
Многопользовательский доступ (несколько игроков одновременно)
При разрушении блока или замка — содержимое дропается
Сериализация/восстановление через DataStore
Серверный цикл (для справки)
Игрок нажимает F → InteractBlock remote
    → FunctionalDispatcher.interact()
        → CraftStationHandler.interact()
            → viewers[userId] = player
            → CraftStationOpened:FireClient(payload)

Игрок кликает рецепт → CraftStationCraft remote
    → CraftStationHandler.craft()
        → проверка ресурсов (контейнер + инвентарь)
        → списание ингредиентов
        → craftQueue:insert({ recipeId, elapsed=0, duration })
        → CraftStationUpdate:FireClient(viewers)

RunService.Heartbeat → processCraftStation(dt)
    → elapsed += dt
    → если elapsed >= duration → результат в контейнер
    → CraftStationUpdate:FireClient(viewers)
Файлы системы
Файл	Роль
src/shared/config/StationConfig.luau	Конфиг станций (Slots, Name, InteractRange)
src/shared/config/BuildingConfig.luau	Определение блока (Functional, FunctionalData)
src/shared/config/CraftConfig.luau	Рецепты (Station field)
src/server/modules/building/CraftStationHandler.luau	Серверная логика (контейнер, крафт, viewers)
src/server/modules/building/FunctionalDispatcher.luau	Маршрутизация Functional → Handler
src/server/building/BuildingServer.server.luau	Remote-оркестратор
src/client/ui/building/CraftStationUI.client.luau	Клиентский UI
src/shared/Remotes.luau	Remote events
Remotes
Remote	Направление	Payload
CraftStationOpened	Server → Client	{ CsId, StationType, StationName, Slots, Recipes, Crafting, QueueCounts }
CraftStationUpdate	Server → Client	{ CsId, StationType, Slots, Crafting, QueueCounts }
CraftStationClosed	Server → Client	csId
CraftStationDeposit	Client → Server	csId, inventorySlotIndex
CraftStationTakeItem	Client → Server	csId, slotIndex
CraftStationCraft	Client → Server	csId, recipeId
CraftStationClose	Client → Server	csId