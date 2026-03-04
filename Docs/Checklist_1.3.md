# Rise — Checklist v1.3

> Ветка: `develop_1.3`
> Всё что было сделано в версии 1.3.

---

## Фичи

- [x] **Drag-and-drop экипировки на персонажа** — перетаскивание предмета на панель экипировки → автоэкипировка в нужный слот.
- [x] **Drag-and-drop экипировки на слугу** — перетаскивание из инвентаря на слоты слуги с EquipServantItem.
- [x] **Debug Servant Egg** — тестовый consumable для быстрого получения случайного слуги.
- [x] **Модульный ItemTooltip** — разбит на init, TooltipHeader, TooltipAttributes, TooltipDescription, TooltipFooter, TooltipConstants.
- [x] **Tooltip на инвентаре** — при наведении на слот показывается tooltip с информацией о предмете.
- [x] **Tooltip на экипировке игрока** — при наведении на слот экипировки.
- [x] **Tooltip на ActionBar** — при наведении на слот ActionBar.
- [x] **Tooltip на экипировке слуги** — при наведении на слоты слуги.
- [x] **Позиционирование tooltip** — корректный clamp к границам экрана (через tooltipGui.AbsoluteSize).
- [x] **Дроп предметов на землю** — перетаскивание предмета за пределы инвентаря → выброс лута.
- [x] **Дроп из ActionBar** — drag-and-drop из ActionBar также поддерживает выброс.
- [x] **ПКМ → экипировка из ActionBar** — добавлен equipRemote в ActionBarHUD.

---

## Баг-фиксы

- [x] **Фикс activeWeaponSlot при swap** — рамка активного оружия следует за мечом при перестановке.
- [x] **Фикс EquipSlot при подборе лута** — подобранный предмет сохраняет все поля (EquipSlot, Stats, ItemLevel).
- [x] **Фикс мерцания ghost при drag** — ghost создаётся сразу в позиции курсора.
- [x] **Фикс CraftPanel.updateTooltip** — resultItem scope вынесен за пределы if/else блока.
- [x] **Фикс InventoryManager.addItem** — добавлено сохранение ItemLevel при создании нового слота.
- [x] **Фикс EnemySpawner.spawn** — убран ошибочный return nil при создании папки Enemies.

---

## Рефакторинг

- [x] **Серверные модули в ServerScriptService** — HealthManager, BloodManager, InventoryManager, InventorySync, LootManager, ServantManager, EnemySpawner перенесены из shared/ в server/modules/. Клиент больше не видит серверную логику.
- [x] **EventBus** — серверная event-шина (on/fire). HealthManager.die() больше не вызывает LootManager и EnemySpawner напрямую. События: EntityDying, EntityRemoved, PlayerDied.
- [x] **ServantManager.createFromEgg** — единая точка создания слуг. UseItemHandler больше не дублирует формулу recalcStats.
- [x] **SlotBehavior** — общий модуль поведения слотов. Убрано дублирование между InventoryGrid._connectSlot и ActionBarHUD.build (~60 строк).
- [x] **Rate-limit на DropItem** — 0.3 с между вызовами, предотвращает спам Part-ов.
- [x] **InventorySync.luau** — удалена мёртвая строка WaitForChild("modules"), которая вызывала infinite yield.
- [x] **Циклические зависимости** — разорваны ленивым require (HealthManager ↔ EnemySpawner, ServantManager → EnemySpawner) и заменены на EventBus подписки.

---

## Architecture.md

- [x] Обновлён: структура файлов, EventBus секция, зависимости модулей, конвенции (безопасность, SlotBehavior, createFromEgg), статусы техдолгов, версия 1.3 в таблице.

---

## Оставшиеся техдолги (не в scope 1.3)

- **ServantUI.client.luau** — монолит ~300 строк, разбить на модули.
- **WeaponManager** — жёсткая привязка к Config.Weapons.Sword. Отложено до переделки системы оружия.
- **EnemyHPBar** — обновляет все HP-бары каждый RenderStepped.
- **BloodUI / CaptureUI** — оба итерируют всех врагов каждый кадр.