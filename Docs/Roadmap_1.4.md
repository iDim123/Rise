# Rise — Roadmap v1.4

> Ветка: `develop_1.4`
> Фокус: универсальная система оружия, абилки, баффы/дебаффы, добыча ресурсов.

---

## 1. Рефакторинг WeaponManager (универсальная система оружия)

### 1.1 Config.Weapons — универсальная структура
- [ ] Каждое оружие в Config.Weapons определяется по Id (совпадает с Config.Items[id]).
- [ ] Структура записи:
  ```lua
  Config.Weapons = {
      Sword = {
          Damage = 15,
          Range = 6,
          Cooldown = 0.4,
          ComboWindow = 1.2,
          ResourceDamage = 5,
          Combo = {
              [1] = { Damage = 25, AnimationId = "rbxassetid://..." },
              [2] = { Damage = 20, AnimationId = "rbxassetid://..." },
              [3] = { Damage = 30, AnimationId = "rbxassetid://..." },
          },
          Abilities = {
              Q = {
                  Id = "sword_slash",
                  Name = "Широкий замах",
                  Description = "Наносит урон всем врагам перед собой.",
                  Icon = "rbxassetid://...",
                  AnimationId = "rbxassetid://...",  -- ← анимация абилки
                  Cooldown = 8,
                  Effects = {
                      { Type = "AoEDamage", Damage = 40, Radius = 8, Angle = 180 },
                  },
              },
              E = {
                  Id = "sword_thrust",
                  Name = "Выпад",
                  Description = "Мощный удар по одной цели с дебаффом.",
                  Icon = "rbxassetid://...",
                  AnimationId = "rbxassetid://...",  -- ← анимация абилки
                  Cooldown = 12,
                  Effects = {
                      { Type = "DirectDamage", Damage = 60 },
                      { Type = "ApplyDebuff", BuffId = "slow", Duration = 3 },
                  },
              },
          },
      },
      Axe = {
          Damage = 20,
          Range = 5,
          Cooldown = 0.6,
          ComboWindow = 1.0,
          ResourceDamage = 12,
          Combo = {
              [1] = { Damage = 30, AnimationId = "rbxassetid://..." },
              [2] = { Damage = 25, AnimationId = "rbxassetid://..." },
              [3] = { Damage = 40, AnimationId = "rbxassetid://..." },
          },
          Abilities = {
              Q = {
                  Id = "axe_frenzy",
                  Name = "Бешенство",
                  Description = "Увеличивает урон на 30% на 5 секунд.",
                  Icon = "rbxassetid://...",
                  Cooldown = 10,
                  Effects = {
                      { Type = "ApplyBuff", BuffId = "damage_boost", Duration = 5 },
                  },
              },
              E = {
                  Id = "axe_whirlwind",
                  Name = "Вихрь",
                  Description = "AoE урон вокруг + замедление.",
                  Icon = "rbxassetid://...",
                  Cooldown = 14,
                  Effects = {
                      { Type = "AoEDamage", Damage = 35, Radius = 10, Angle = 360 },
                      { Type = "ApplyDebuff", BuffId = "slow", Duration = 3 },
                  },
              },
          },
      },
  }
Copy
 Config.Items.Axe — добавить запись для топора (Id, Name, Description, Icon, Type = "Weapon", ItemLevel).
1.2 WeaponManager.server.luau — рефакторинг
 Определять оружие через InventoryManager.getInventory(player).activeWeaponSlot → item.Id → Config.Weapons[item.Id].
 Cooldown, Range, Combo читаются из weaponConfig динамически.
 Убрать все упоминания Config.Weapons.Sword.
1.3 CombatInput.client.luau — рефакторинг
 ComboWindow читать через текущее оружие (запрос Config.Weapons[weaponId] или передача с сервера).
1.4 Модель топора
 Создать Tool модель Axe в ServerStorage/weapons/.
 Добавить тестовый топор в InventoryServer (PlayerAdded).
2. Система баффов / дебаффов
2.1 Config.Buffs — определения
 Новая секция в Config.luau:
CopyConfig.Buffs = {
    damage_boost = {
        Id = "damage_boost",
        Name = "Усиление урона",
        Description = "+30% к урону",
        Icon = "rbxassetid://...",
        Type = "Buff",        -- "Buff" или "Debuff"
        Stat = "DamageBonus",
        Value = 0.30,
        Stackable = false,
    },
    slow = {
        Id = "slow",
        Name = "Замедление",
        Description = "-40% скорости передвижения",
        Icon = "rbxassetid://...",
        Type = "Debuff",
        Stat = "Slow",
        Value = 0.40,
        Stackable = false,
    },
    damage_reduction = {
        Id = "damage_reduction",
        Name = "Укрепление",
        Description = "-20% получаемого урона",
        Icon = "rbxassetid://...",
        Type = "Buff",
        Stat = "DamageReduction",
        Value = 0.20,
        Stackable = false,
    },
    speed_boost = {
        Id = "speed_boost",
        Name = "Ускорение",
        Description = "+25% скорости передвижения",
        Icon = "rbxassetid://...",
        Type = "Buff",
        Stat = "SpeedBonus",
        Value = 0.25,
        Stackable = false,
    },
}
Copy
2.2 BuffManager.luau (серверный модуль)
 Создать src/server/modules/BuffManager.luau.
 Хранение: activeBuffs[entity] = { [buffId] = { config, startTime, duration, sourceEntity } }.
 applyBuff(entity, buffId, duration, source) — применить бафф/дебафф. Если не stackable и уже есть — обновить длительность.
 removeBuff(entity, buffId) — снять бафф.
 getActiveBuffs(entity) — вернуть список активных баффов с оставшимся временем.
 getStatModifier(entity, statName) — суммарный модификатор стата от всех активных баффов.
 tick(deltaTime) — проверка истёкших баффов, удаление, уведомление клиента.
 При изменении баффов → fire remote UpdateBuffs клиенту (entity, buffs list).
 Подписка на EventBus EntityDying → очистка баффов сущности.
 Подписка на EventBus PlayerDied → очистка баффов игрока.
2.3 Интеграция баффов в боевую систему
 WeaponManager: при расчёте урона вызывать BuffManager.getStatModifier(attacker, "DamageBonus") и BuffManager.getStatModifier(target, "DamageReduction").
 Скорость: при изменении Slow/SpeedBonus обновлять Humanoid.WalkSpeed цели.
 Баффы крови (BloodManager.getBuffs) продолжают работать отдельно — они не временные и не отображаются в UI баффов.
2.4 Remotes для баффов
 Добавить в Remotes.luau: UpdateBuffs (Server → Client), ResourceGathered (Server → Client).
2.5 BuffBar UI (клиент)
 Создать src/client/ui/BuffBar.client.luau.
 Позиция: правый верхний угол экрана.
 Верхняя строка — баффы (обычная рамка).
 Нижняя строка — дебаффы (красная рамка).
 Каждый бафф: иконка + оставшееся время (формат: 3с, 15м, 2ч).
 При наведении — tooltip с названием и описанием (использовать отдельный ScreenGui поверх, как ItemTooltip).
 Слушает remote UpdateBuffs → обновляет иконки.
3. Система абилок оружия
3.1 AbilityManager.luau (серверный модуль)
 Создать src/server/modules/AbilityManager.luau.
 useAbility(player, abilitySlot, mousePosition) — основная функция:
Получить текущее оружие из InventoryManager.
Найти абилку по слоту (Q/E) в Config.Weapons[weaponId].Abilities.
Проверить кулдаун (серверный, авторитетный).
Выполнить эффекты по списку Effects:
DirectDamage → найти ближайшую цель в Range, нанести урон через HealthManager.
AoEDamage → найти все цели в Radius (и опционально Angle), нанести урон.
ApplyBuff → вызвать BuffManager.applyBuff на caster.
ApplyDebuff → вызвать BuffManager.applyBuff на цель/цели.
Запустить кулдаун.
 AoE с Angle: 360 = вокруг, 180 = полукруг перед игроком (dot product > 0).
 Абилки наносят урон ресурсным нодам (проверять ResourceNodes так же как врагов).
3.2 Remotes для абилок
 Добавить в Remotes.luau: UseAbility (Client → Server), AbilityCooldown (Server → Client).
3.3 AbilitiesBar UI (клиент)
 Создать src/client/ui/AbilitiesBar.client.luau.
 Позиция: слева от ActionBar (как на скриншоте V Rising).
 2 слота: Q и E. Каждый показывает иконку абилки текущего оружия.
 При смене оружия (UpdateInventory с новым activeWeaponSlot) → обновить иконки и описания.
 Cooldown шторка + текст (переиспользовать CooldownManager).
 Hotkeys: Q и E → fire UseAbility:FireServer(slot, mousePosition).
 Tooltip при наведении: название, описание, кулдаун.
3.4 CombatInput.client.luau — интеграция
 Добавить обработку Q и E (с gameProcessed проверкой).
 Или вынести в AbilitiesBar обработку клавиш.
4. Добыча ресурсов
4.1 Config — ресурсные ноды и предметы
 Новые предметы в Config.Items:
Copywood = {
    Id = "wood", Name = "Wood", Description = "Basic building material.",
    Icon = "rbxassetid://...", Type = "Resource", ItemLevel = 0,
    Stackable = true, MaxStack = 999,
},
stone = {
    Id = "stone", Name = "Stone", Description = "Raw stone.",
    Icon = "rbxassetid://...", Type = "Resource", ItemLevel = 0,
    Stackable = true, MaxStack = 999,
},
 Новая секция Config.ResourceNodes:
CopyConfig.ResourceNodes = {
    Tree = {
        MaxHP = 50,
        ResourceId = "wood",
        RespawnTime = 60,
    },
    Rock = {
        MaxHP = 80,
        ResourceId = "stone",
        RespawnTime = 90,
    },
}
4.2 ResourceManager.luau (серверный модуль)
 Создать src/server/modules/ResourceManager.luau.
 Хранение: nodeData[node] = { CurrentHP, MaxHP, ResourceId, IsDead }.
 init(node, nodeType) — инициализация из Config.ResourceNodes.
 hit(node, resourceDamage, player) — нанести урон ноде:
Уменьшить HP на resourceDamage.
Добавить ресурсы в инвентарь: InventoryManager.addItemFromConfig(player, resourceId, resourceDamage).
Fire remote ResourceGathered → клиент показывает жёлтый "+N" над нодой.
Если HP <= 0 → нода "умирает": скрыть/уничтожить, запустить респавн таймер.
 respawn(node, nodeType, position) — через Config.ResourceNodes[type].RespawnTime.
 Очистка при уничтожении.
4.3 Интеграция с боевой системой
 WeaponManager: при атаке проверять не только Enemies и Players, но и ResourceNodes. Для нод использовать weaponConfig.ResourceDamage вместо Combo.Damage.
 AbilityManager: AoE/DirectDamage абилки тоже проверяют ResourceNodes и наносят урон (можно использовать тот же ResourceDamage оружия).
4.4 ResourceNode spawner
 Создать src/server/resource/ResourceManager.server.luau (серверный скрипт).
 Модели деревьев/камней в ServerStorage/resources/.
 Атрибуты на шаблонах: NodeType, SpawnPosition.
 Начальный спавн из ServerStorage аналогично EnemyManager.
 Папка workspace.Resources для активных нод.
4.5 ResourceGather UI (клиент)
 Модифицировать DamageNumbers.client.luau или создать отдельный скрипт.
 Слушать remote ResourceGathered(node, resourceId, amount).
 Показывать жёлтый "+N ResourceName" над нодой (BillboardGui, анимация как floating damage).
5. Финализация
5.1 Тестовые данные
 Добавить Axe в тестовые предметы (InventoryServer PlayerAdded).
 Разместить деревья и камни на карте (ServerStorage/resources/).
5.2 Architecture.md
 Обновить: новые модули (BuffManager, AbilityManager, ResourceManager), EventBus события, Remotes, Config секции, зависимости.
5.3 Checklist_1.4.md
 Составить итоговый чеклист по факту выполнения.
Зависимости задач
1. WeaponManager рефакторинг
   └── 1.4 Модель топора
       └── 3. Абилки (нужно оружие с абилками)
           └── 3.1 AbilityManager (нужен BuffManager для эффектов)
               └── 2. Система баффов (фундамент для абилок)

2. Система баффов (независима, можно делать параллельно с п.1)

4. Добыча ресурсов (нужен WeaponManager рефакторинг для ResourceDamage)
Рекомендуемый порядок
WeaponManager рефакторинг + топор в Config/Items
Система баффов (BuffManager + BuffBar UI)
Система абилок (AbilityManager + AbilitiesBar UI)
Добыча ресурсов (ResourceManager + UI)
Финализация