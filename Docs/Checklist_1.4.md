# Checklist v1.4

## WeaponManager рефакторинг + Axe
- [x] Динамическое определение оружия через getWeaponConfig(player)
- [x] Config.Weapons.Axe с комбо, уроном, дальностью, ResourceDamage
- [x] Config.Items.Axe
- [x] Модель топора с настроенным Grip в ServerStorage/weapons
- [x] SlotBehavior.luau — единая логика слотов (вместо дублирования в InventoryGrid и ActionBarHUD)

## Баффы и дебаффы
- [x] BuffManager.luau — applyBuff, removeBuff, getStatModifier, getActiveBuffs, _sendUpdate
- [x] Config.Buffs — определения баффов (damage_boost, slow и т.д.)
- [x] BuffBar.client.luau — UI баффов/дебаффов (иконки, таймеры, tooltip, clamp к экрану)
- [x] Remotes: UpdateBuffs
- [x] Интеграция в WeaponManager (DamageBonus, DamageReduction)
- [x] debug_buff_potion — тестовое зелье с UseEffect.Type = "ApplyBuffs"
- [x] UseItemHandler — обработка ApplyBuffs эффекта

## Система способностей (Abilities)
- [x] AbilityManager.luau — useAbility, cooldown, DirectDamage, AoEDamage, ApplyBuff, ApplyDebuff
- [x] Config.Weapons.Sword.Abilities (Q: Широкий замах, E: Выпад)
- [x] Config.Weapons.Axe.Abilities (Q/E)
- [x] Config.Weapons.*.ComboAbility (LMB описание)
- [x] AbilitiesBar.client.luau — 3 слота (LMB/Q/E), иконки, tooltip, cooldown overlay
- [x] Remotes: UseAbility, AbilityCooldown
- [x] Способности наносят урон ресурсным нодам (_hitResourceNodes)

## Сбор ресурсов (Resource Gathering)
- [x] ResourceManager.luau — init, hit, _destroyNode, _respawnNode
- [x] ResourceSpawner.server.luau — спавн нод из ServerStorage/resources
- [x] Config.ResourceNodes — Tree (wood), Rock (stone)
- [x] Config.Items — wood, stone (ресурсные предметы)
- [x] WeaponManager — удар по нодам (горизонтальная дистанция, ResourceDamage)
- [x] ResourceNumbers.client.luau — жёлтые числа "+N ресурс" над головой игрока
- [x] Remotes: ResourceGathered
- [x] Респавн нод с отключённым коллайдером (включается когда игроки отойдут)
- [x] Модели Tree и Rock в Workspace/Resources с атрибутом NodeType

## Камера
- [x] Вращение камеры по горизонтали (yaw) при зажатии ПКМ
- [x] Блокировка курсора при вращении

## Баг-фиксы
- [x] Drag-drop: предмет не выбрасывается при отпускании на bind labels ActionBar (+30px область)
- [x] Drag-drop: отмена при drop на тот же слот (ActionBar при закрытом инвентаре)