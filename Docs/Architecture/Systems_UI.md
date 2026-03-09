# UI Systems

> Все клиентские UI модули: HUD, окна, tooltip, уведомления.

---

## Архитектура

Каждый UI модуль — отдельный LocalScript или ModuleScript в `src/client/ui/`. Большинство создают собственный ScreenGui программно (без prefab). Обновление данных — event-driven через Remotes, не polling.

### ScreenGui иерархия (DisplayOrder)

| DisplayOrder | ScreenGui | Модуль |
|---|---|---|
| 1 | PlayerHUD | PlayerHPBlock, ServantHPBlock |
| 5 | BloodPoolGui | BloodPoolUI |
| 10 | EnemyHPBarGui | EnemyHPBar (Billboard) |
| 15 | EnemyLabelsGui | EnemyLabels (Billboard) |
| 20 | CastBarUI | CastBar |
| 30 | BuffBarGui | BuffBar |
| 40 | DamageNumbersGui | DamageNumbers |
| 50 | ResourceNumbersGui | ResourceNumbers |
| 100 | TargetInfoGui | TargetInfo |
| 200 | MinimapGui | Minimap |
| 300 | DayNightGui | DayNightHUD |
| 500 | DeathScreenGui | DeathScreen |
| 700 | LootGui | LootUI |
| 750 | NotifyGui | NotifyModule |
| 800 | CharacterWindowGui | CharacterWindow |
| 805 | ServantWindowGui | ServantWindow |
| 810 | AbilitiesBarGui | AbilitiesBar |
| 820 | ContainerGui | ContainerUI |
| 850 | CaptureGui | CaptureUI |
| 900 | AbilityTooltipGui | AbilityTooltip |
| 950 | BossJournalGui | BossJournal |
| 999 | ItemTooltipGui | ItemTooltip |

---

## HUD — постоянные элементы

### PlayerHPBlock

Файл: `PlayerHPBlock.client.luau`

HP bar, XP bar и круг уровня игрока. Расположен в левом нижнем углу. Обновляется через `DamageEvent`, `HealEvent`, `UpdateLevel` remotes. Tween-анимация при изменении HP.

### ServantHPBlock

Файл: `ServantHPBlock.client.luau`

HP bar, XP bar и круг уровня активного слуги. Расположен под PlayerHPBlock. Обновляется через `DamageEvent`, `UpdateServantLevel`. Скрывается если слуга не призван.

### BloodPoolUI

Файл: `BloodPoolUI.client.luau`

Колба крови справа от HP bar. Показывает тип крови (цвет), качество (tween fill), количество (убывающий уровень). Обновляется через `UpdateStats` remote.

### BuffBar

Файл: `BuffBar.client.luau`

Активные баффы/дебаффы в левом верхнем углу. Каждый слот: иконка, таймер обратного отсчёта, рамка (зелёная — бафф, красная — дебафф). Tooltip при наведении. Обновляется через `UpdateBuffs` remote.

### AbilitiesBar

Файл: `abilities/AbilitiesBar.client.luau`

8 слотов способностей внизу экрана: LMB, Q, E, Space, R, T, Z, X. Иконки привязаны к текущему оружию. Обновляется event-driven при смене Tool (ChildAdded/ChildRemoved). Нажатие Q/E/... отправляет `UseAbility` remote.

Зависимости:
- `AbilityTooltip.luau` — tooltip с описанием, уроном, cooldown (отдельный ScreenGui, DisplayOrder 900)
- `AbilityCooldowns.luau` — визуальный cooldown: шторка сверху вниз + число секунд

### ActionBarHUD

Файл: `character/ActionBarHUD.luau`

Нижняя панель слотов 1–8 из инвентаря. Отображает предметы, подсветку активного оружия, cooldown consumable. Интегрирован с CharacterWindow через SlotFactory и SlotBehavior.

### DayNightHUD

Файл: `DayNightHUD.client.luau`

Индикатор времени суток и фазы луны. Обновляется через Remotes или Lighting изменения.

### Minimap

Файл: `Minimap.client.luau`

Круглая карта с фиксированной ориентацией (север = вверх). Иконка игрока вращается по LookVector. Зум: кнопки +/− и скролл мыши (при наведении на миникарту).

| Точка | Цвет | Описание |
|---|---|---|
| Игрок | Белый | Иконка с направлением |
| Враги | Красный | Все враги в радиусе |
| Боссы | Фиолетовый | Боссы |
| Игроки | Синий | Другие игроки |
| Ресурсы | Жёлтый | Ресурсные ноды |

Dot pool для производительности — переиспользование UI элементов вместо создания новых.

---

## Боевой HUD

### CastBar

Файл: `CastBar.client.luau`

Полоска каста с иконкой, названием и таймером. Показывается при получении `CastStart` remote. Tween-заполнение. Отмена: `CastCancel` remote, CancelKey, стан, урон (если CancelOnDamage). Применяет замедление движения по параметрам `MovementMode` и `SpeedMult`.

`CastComplete` — BindableEvent в ScreenGui "CastBarUI", используется `RangedInput` для определения завершения каста.

### DamageNumbers

Файл: `DamageNumbers.client.luau`

Всплывающие числа урона над целями. Красные — обычный урон, жёлтые — крит. Анимация: подъём вверх + fade out. Обновляется через `DamageEvent` remote.

### ResourceNumbers

Файл: `ResourceNumbers.client.luau`

Жёлтые числа "+N ресурс" над ресурсными нодами при сборе. Обновляется через `ResourceGathered` remote.

### ProjectileVisuals

Файл: `combat/ProjectileVisuals.client.luau`

Визуализация снарядов. Создаёт neon Part (0.4×0.4×1.5) с Trail. Цвет Trail из ProjectileConfig. Heartbeat обновляет позицию. Hit эффект: расширяющийся шар с fade out. Подробнее — `Systems_Combat.md`.

---

## Окна

### CharacterWindow

Файл: `character/CharacterWindow.client.luau`

Окно персонажа (клавиша C). Оркестратор, объединяющий панели:

| Панель | Модуль | Описание |
|---|---|---|
| Инвентарь | InventoryGrid.luau | Сетка слотов, drag-and-drop |
| Экипировка (левая) | EquipmentPanel.luau | Head, Chest, Legs, Feet, Hands |
| Экипировка (правая) | EquipmentPanel.luau | Cloak, Amulet, Ring1, Ring2, Bag |
| Крафт | CraftPanel.luau | Рецепты, материалы, прогресс |
| Атрибуты | AttributesPanel.luau | Таблица 20 статов |
| Кровь | BloodPoolPanel.luau | Тип, качество, бонусы |

Вспомогательные модули:
- `UIConstants.luau` — размеры, цвета, layout
- `SlotFactory.luau` — создание UI-слотов
- `SlotBehavior.luau` — клик, ПКМ, drag поведение
- `DragManager.luau` — drag-and-drop ghost-элемент
- `CooldownManager.luau` — визуальный cooldown (RenderStepped)

### ServantWindow

Файл: `servant/ServantWindow.client.luau`

Окно слуг (клавиша V). Оркестратор:

| Панель | Модуль | Описание |
|---|---|---|
| Коллекция | ServantCollection.luau | Список захваченных слуг |
| Статы | ServantStatsPanel.luau | Статы выбранного слуги |
| Экипировка | ServantEquipPanel.luau | Слоты экипировки слуги |
| Команды | ServantActionBar.luau | Призвать, отозвать, режим, команды |

### BossJournal

Файл: `boss/BossJournal.luau`

Журнал боссов (через MenuBar). Полноэкранное окно со скроллом и фильтрацией по актам.

| Модуль | Описание |
|---|---|
| BossJournalInit.client.luau | Точка входа |
| BossJournal.luau | Окно, скролл, фильтрация |
| BossCard.luau | Карточка босса: имя, уровень, эссенция, техники |
| BossTooltip.luau | Tooltip технологий |
| BossJournalConstants.luau | Константы и палитра |
| ActTabs.luau | Табы актов |

### ContainerUI

Файл: `ContainerUI.client.luau`

UI для контейнеров (сундуки, хранилища). Сетка слотов с drag-and-drop. `ContainerAnimator.client.luau` — анимация открытия/закрытия крышки контейнера.

---

## Overlay-экраны

### DeathScreen

Файл: `DeathScreen.client.luau`

Экран смерти. Показывается при получении `PlayerDied` remote. Таймер обратного отсчёта, кнопка «Возродиться» (активируется после таймера). Нажатие отправляет `PlayerRespawn` remote.

### CaptureUI

Файл: `CaptureUI.client.luau`

Cast bar захвата врага. Показывается при начале захвата (`CaptureRequest`). Отменяется движением или повторным нажатием T.

### LootUI

Файл: `LootUI.client.luau`

Подсказка подбора лута. Показывает иконку и имя предмета при приближении к лут-дропу. Клавиша F — подобрать (`PickupLoot` remote).

---

## Уведомления

### NotifyModule

Файл: `NotifyModule.luau`

Система toast-уведомлений. Уведомления появляются в правой части экрана, автоматически исчезают через несколько секунд. Поддерживает типы: info, success, warning, error.

### NotifyListener

Файл: `NotifyListener.client.luau`

Слушает `Notify` remote и вызывает `NotifyModule.show(message, type)`.

---

## Tooltip

### ItemTooltip

Файл: `character/tooltip/init.luau`

Модульный tooltip предметов. ScreenGui с DisplayOrder 999 (поверх всех окон). Показывается при наведении на слот инвентаря или экипировки.

| Подмодуль | Описание |
|---|---|
| TooltipConstants.luau | Размеры, цвета, шрифты |
| TooltipHeader.luau | Иконка, имя, тип, уровень предмета, цвет рамки по типу |
| TooltipAttributes.luau | Бонусы статов (зелёный текст: "+20 HP", "+5% PhysResistance") |
| TooltipDescription.luau | Текст описания предмета |
| TooltipFooter.luau | Подсказка действия: "ПКМ — экипировать", "ПКМ — использовать" |

### AbilityTooltip

Файл: `abilities/AbilityTooltip.luau`

Tooltip способностей. Отдельный ScreenGui с DisplayOrder 900. Показывает имя, описание, урон, cooldown, тип урона. Появляется при наведении на слот AbilitiesBar.

### BossTooltip

Файл: `boss/BossTooltip.luau`

Tooltip технологий в Boss Journal. Показывает название технологии и что она разблокирует.

---

## Камера и ввод

### IsometricCamera

Файл: `camera/IsometricCamera.client.luau`

Изометрическая камера. Фиксированный угол, следует за персонажем. Зум: колесо мыши.

### MouseLook

Файл: `input/MouseLook.client.luau`

Вращение камеры при зажатии ПКМ. Перемещает курсор мыши для вращения, возвращает при отпускании.

### MenuBar

Файл: `MenuBar.luau` + `MenuBarInit.client.luau`

Иконки меню в правом нижнем углу. Открывают окна (Boss Journal и т.д.).

---

## Отладка

### DebugKeys

Файл: `debug/DebugKeys.client.luau`

Клиентские хоткеи для отладки (только Studio). Отправляет `DebugCommand` remote при нажатии F5–F9.

| Клавиша | Команда |
|---|---|
| F5 | save |
| F6 | data |
| F7 | addxp 500 |
| F8 | wipe |
| F9 | togglesave |

---

## Конвенции UI

### Создание

Все UI элементы создаются программно через `Instance.new()`. Prefab не используются. Каждый модуль создаёт свой ScreenGui с уникальным Name и DisplayOrder.

### Обновление данных

Event-driven через Remotes. Модули подписываются на `Remote.OnClientEvent:Connect(...)`. Polling (RenderStepped/Heartbeat) используется только для анимаций и визуальных эффектов (cooldown шторки, tween, позиционирование minimap точек).

### Стиль

Общие константы стиля в `UIConstants.luau`: размеры слотов, отступы, цвета фона, рамок, текста. Шрифт: `GothamBold` / `Gotham`. Скругление: `UICorner` с `CornerRadius = UDim.new(0, 6)`.

### ResetOnSpawn

Все ScreenGui имеют `ResetOnSpawn = false` — UI не пересоздаётся при респавне персонажа