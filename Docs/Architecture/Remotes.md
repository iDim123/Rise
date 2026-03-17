# Remotes — полный список

> Все RemoteEvents и RemoteFunctions, зарегистрированные в `src/shared/Remotes.luau`.

---

## RemoteEvents

### Боевая система

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| AttackRequest | Client → Server | mousePos: Vector3, comboIndex: number | Запрос атаки (мили или начало каста дальнего боя) |
| RangedRelease | Client → Server | mousePos: Vector3 | Финальная позиция курсора после завершения каста |
| UseAbility | Client → Server | key: string, mousePos: Vector3 | Использовать способность (Q/E/Space/R/T/Z/X) |
| AbilityCooldown | Server → Client | key: string, duration: number | Уведомление о cooldown способности |
| DamageEvent | Server → Client | entity, hp, maxHP, damage, attackerName | Визуализация урона (DamageNumbers) |
| HealEvent | Server → Client | entity, hp, maxHP, healAmount | Визуализация хила |
| EntityDied | Server → Client | entity | Уведомление о смерти сущности |

### Снаряды

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| ProjectileFired | Server → All Clients | { id, origin, direction, projectileId, speed, gravity } | Создать визуал снаряда |
| ProjectileHit | Server → All Clients | { id, position, isCrit } | Эффект попадания |
| ProjectileRemoved | Server → All Clients | id: string | Удалить визуал снаряда |

### Каст-система

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| CastStart | Server → Client | { Duration, Label, Icon, MovementMode, SpeedMult, BaseSpeed, CancelKey, CancelOnStun, CancelOnDamage } | Начать отображение CastBar |
| CastCancel | Server → Client | — | Отменить CastBar |
| CastCancelRequest | Client → Server | — | Клиент запрашивает отмену каста |

### Инвентарь и экипировка

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| UpdateInventory | Server → Client | { slots, equipment, activeWeaponSlot, unlockedSlots } | Полное обновление инвентаря |
| SwapSlots | Client → Server | fromIndex: number, toIndex: number | Перестановка слотов |
| EquipItem | Client → Server | slotIndex: number | Экипировать предмет |
| UnequipItem | Client → Server | equipSlotId: string | Снять экипировку |
| SetActiveWeapon | Client → Server | slotIndex: number | Выбрать оружие в ActionBar |
| UseItem | Client → Server | slotIndex: number | Использовать Consumable |
| DropItem | Client → Server | slotIndex: number | Выбросить предмет (rate-limit 0.3с) |

### Крафт

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| CraftItem | Client → Server | recipeId: string | Поставить в очередь крафта |
| CraftQueueUpdate | Server → Client | queueData | Обновление очереди/прогресса |

### Кровь

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| DrinkBloodRequest | Client → Server | — | Выпить кровь ближайшего врага |

### Уровни и статы

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| UpdateLevel | Server → Client | level, xp, xpRequired | Обновление уровня/XP игрока |
| UpdateServantLevel | Server → Client | servantId, level, xp | Обновление уровня/XP слуги |
| UpdateStats | Server → Client | statsTable | Обновление статов игрока |

### Баффы

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| UpdateBuffs | Server → Client | buffsTable | Обновление списка баффов/дебаффов |

### Ресурсы

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| ResourceGathered | Server → Client | node, resourceId, amount | Уведомление о сборе ресурса |

### Лут

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| PickupLoot | Client → Server | lootPart: Instance | Подобрать лут |

### Смерть и респавн

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| PlayerDied | Server → Client | respawnTime: number | Уведомление о смерти игрока |
| PlayerRespawn | Client → Server | — | Запрос респавна |

### Захват

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| CaptureRequest | Client → Server | action: "start" / "cancel" | Начать/отменить захват врага |
| CaptureResult | Server → Client | success: bool, message: string | Результат захвата |

### Слуги

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| SummonServant | Client → Server | servantId: string | Призвать слугу |
| DismissServant | Client → Server | — | Отозвать слугу |
| SetServantMode | Client → Server | mode: string | Режим (Aggressive/Defensive/Passive) |
| ServantCommand | Client → Server | command: string | Команда (Follow/Stay/AttackTarget) |
| RenameServant | Client → Server | servantId: string, newName: string | Переименовать слугу |
| EquipServantItem | Client → Server | servantId, slotIndex | Экипировать предмет на слугу |
| UnequipServantItem | Client → Server | servantId, equipSlotId | Снять экипировку со слуги |
| ToggleServantFavorite | Client → Server | servantId: string | Переключить избранное |
| UpdateServantData | Server → Client | servantsData | Обновление данных слуг |

### Боссы

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| BossFinish | Client → Server | bossId: string | Добить босса |
| BossCapture | Client → Server | bossId: string | Захватить босса |
| BossFinishResult | Server → Client | result | Результат добивания |
| BossCaptureResult | Server → Client | result | Результат захвата босса |
| UnlockTech | Server → Client | bossId, techId | Разблокировка технологии |

### Уведомления и отладка

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| Notify | Server → Client | message: string, type: string | Toast-уведомление |
| DebugCommand | Client → Server | commandString: string | Отладочная команда (только Studio) |

### День/ночь

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| DayNightSync | Server → Client | timeData | Синхронизация цикла дня/ночи |

### Контейнеры (сундуки)

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| ContainerOpen | Client → Server | containerId: string | Запрос открытия контейнера |
| ContainerClose | Client → Server | containerId: string | Закрытие контейнера |
| ContainerTakeItem | Client → Server | containerId: string, slotIndex: number | Забрать предмет из слота |
| ContainerTakeAll | Client → Server | containerId: string | Забрать всё |
| ContainerSort | Client → Server | containerId: string | Сортировка |
| ContainerDepositItem | Client → Server | containerId: string, slotIndex: number | Положить предмет из инвентаря |
| ContainerOpened | Server → Client | payload: table | Контейнер открыт (слоты, данные) |
| ContainerUpdate | Server → Client | payload: table | Обновление слотов контейнера |
| ContainerClosed | Server → Client | containerId: string | Контейнер закрыт |

### Строительство замков (v1.9)

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| PlaceCastleHeart | Client → Server | position: Vector3 | Разместить Castle Heart |
| UpgradeCastleHeart | Client → Server | — | Улучшить Castle Heart |
| DestroyCastle | Client → Server | — | Уничтожить замок |
| CastleHeartInfo | Server → Client | info: table | Данные Castle Heart (уровень, HP, BloodEssence, права) |
| PlaceBlock | Client → Server | blockTypeId: string, position: Vector3, rotation: number | Разместить блок |
| RemoveBlock | Client → Server | blockId: string | Удалить блок |
| BuildingSync | Server → Client | syncData | Синхронизация блоков замка |
| SetBuildPermission | Client → Server | permissionKey: string, value: bool | Установить право доступа |
| AddBuildAlly | Client → Server | allyUserId: number | Добавить союзника |
| RemoveBuildAlly | Client → Server | allyUserId: number | Удалить союзника |
| InteractBlock | Client → Server | blockId: string | Взаимодействие с функциональным блоком (F) |
| StructureDamageEvent | Server → Client | structureData | Визуализация урона по блоку |

### Перерабатывающие станции (v1.9)

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| StationOpened | Server → Client | payload: { StationId, StationType, StationName, InputSlots, OutputSlots, RecipeToggles, Recipes, Crafting } | Станция открыта — передать всё состояние |
| StationUpdate | Server → Client | payload: { StationId, StationType, InputSlots, OutputSlots, RecipeToggles, Crafting } | Обновление состояния станции (при крафте, deposit, take) |
| StationClosed | Server → Client | stationId: string | Станция закрыта сервером |
| StationDeposit | Client → Server | stationId: string, inventorySlotIndex: number | Положить предмет из инвентаря в input станции |
| StationTakeItem | Client → Server | stationId: string, slotIndex: number | Забрать предмет из output |
| StationTakeInput | Client → Server | stationId: string, slotIndex: number | Забрать предмет из input обратно в инвентарь |
| StationTakeAll | Client → Server | stationId: string | Забрать весь output |
| StationToggleRecipe | Client → Server | stationId: string, recipeId: string | Вкл/выкл рецепт |
| StationClose | Client → Server | stationId: string | Закрыть UI станции |

### Система магии

| Имя | Направление | Данные | Описание |
|---|---|---|---|
| CastSpell | Client → Server | slot: string, mousePosition: Vector3 | Использовать заклинание (R/G/Z) |
| LearnSpell | Client → Server | spellId: string | Изучить заклинание (тратит Spell Point) |
| EquipSpell | Client → Server | spellId: string, slot: string | Экипировать заклинание в слот |
| UnequipSpell | Client → Server | slot: string | Снять заклинание из слота |
| SpellCooldown | Server → Client | slot: string, cooldownTime: number | Кулдаун заклинания |
| SpellChargeUpdate | Server → Client | slot: string, charges: number, rechargeTimes: table | Обновление зарядов |
| SpellAim | Client → Server | mousePosition: Vector3 | Позиция курсора во время каста (~20/сек) |
| BeamStart | Server → Client | casterId: number, origin: Vector3, direction: Vector3, width: number, length: number, duration: number | Начало Beam заклинания |
| BeamUpdate | Client → Server | mousePosition: Vector3 | Обновление направления Beam (~10/сек) |
| BeamEnd | Server → Client | casterId: number | Конец Beam заклинания |
| SpellEffect | Server → Client | effectType: string, position: Vector3, data: table | VFX заклинания (School, radius, targets и т.д.) |
| UpdateSpellData | Server → Client | spellData: table | Обновление прогресса магии |

---

## RemoteFunctions

| Имя | Направление | Возвращает | Описание |
|---|---|---|---|
| GetInventory | Client → Server | { slots, equipment, activeWeaponSlot, unlockedSlots } | Полные данные инвентаря |
| GetServants | Client → Server | { captured, activeId } | Данные слуг |
| GetBossData | Client → Server | bossesTable | Данные боссов для журнала |
| GetPlayerStats | Client → Server | statsTable | Все статы игрока |
| GetSpellData | Client → Server | spellProgressData | Полные данные прогресса магии |
| GetBuildings | Client → Server | blocksArray | Блоки замка игрока |
| GetCastleHeartInfo | Client → Server | heartInfoTable | Данные Castle Heart (уровень, HP, BloodEssence, права, союзники) |