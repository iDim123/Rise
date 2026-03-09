# Dependencies — зависимости модулей

> Граф зависимостей серверных и клиентских модулей.
> `→` означает `require`. `(lazy)` — ленивая загрузка для разрыва циклов.

---

## Серверная сторона

### Точки входа

Main.server.luau └── require: HealthManager, LootManager, EnemySpawner (регистрация EventBus подписок)

PlayerLifecycle.server.luau └── require: DataService, InventoryManager, InventorySync, BloodManager, LevelManager, BossManager, ServantManager, HealthManager, StatsManager


### Боевые модули (`server/combat/`)

CombatManager.server.luau ├── WeaponUtil ├── MeleeHandler ├── RangedHandler ├── ProjectileManager └── AbilityManager

MeleeHandler ├── DamageCalc ├── TargetFinder ├── ResourceHit ├── StatsManager (lazy) └── HealthManager (lazy)

RangedHandler ├── ProjectileManager ├── CastManager (lazy) └── StatsManager (lazy)

ProjectileManager ├── TargetFinder ├── DamageCalc ├── HealthManager (lazy) └── StatsManager (lazy)

WeaponUtil └── InventoryManager (lazy)

DamageCalc ├── StatsManager (lazy) └── LevelManager (lazy)

TargetFinder └── (standalone, uses workspace queries)

ResourceHit ├── ResourceManager (lazy) └── StatsManager (lazy)


### Модули способностей и каста (`server/modules/`)

AbilityManager ├── WeaponUtil ├── DamageCalc ├── TargetFinder ├── ResourceHit ├── HealthManager ├── BuffManager ├── StatsManager └── ProjectileManager (lazy)

CastManager ├── StatsManager (lazy) ├── EventBus (lazy) └── Remotes


### Основные модули (`server/modules/`)

HealthManager ├── EventBus ├── Config ├── Remotes ├── StatsManager └── BossManager (lazy)

LevelManager ├── Config ├── Remotes ├── EventBus └── Players

LootManager ├── InventoryManager ├── Config └── EventBus

EnemySpawner ├── HealthManager ├── Config └── EventBus

BuffManager ├── Config ├── Remotes └── Players

ResourceManager ├── Config ├── InventoryManager ├── InventorySync ├── Remotes └── Players

StatsManager ├── Config ├── Remotes ├── InventoryManager ├── BloodManager └── BuffManager

BloodManager └── Config

DataService ├── Config ├── InventoryManager ├── LevelManager ├── BloodManager ├── BossManager └── ServantManager


### Боссы (`server/modules/boss/`)

BossManager ├── Config ├── Remotes ├── EventBus ├── HealthManager ├── BossPlayerData └── BossInteraction

BossPlayerData ├── Config └── Remotes

BossInteraction ├── Config ├── Remotes ├── LevelManager ├── LootManager (lazy) ├── ServantManager (lazy) └── BossPlayerData


### Слуги (`server/modules/servant/`)

ServantManager ├── Config ├── EventBus └── ServantEquipment

ServantEquipment └── Config


### Инвентарь (`server/inventory/`)

InventoryServer.server.luau ├── InventoryManager ├── InventorySync ├── HealthManager ├── LevelManager ├── WeaponHandler ├── CraftHandler └── UseItemHandler

WeaponHandler ├── InventoryManager └── Config

CraftHandler ├── InventoryManager ├── InventorySync ├── Remotes ├── Config └── BossManager (lazy)

UseItemHandler ├── InventoryManager ├── InventorySync ├── HealthManager ├── ServantManager ├── BuffManager ├── BloodManager ├── StatsManager └── Config


### Враги (`server/enemy/`)

EnemyAI.server.luau ├── EnemyBehaviors ├── BossBehaviors ├── EnemyStateManager └── BossAbilities

EnemyBehaviors ├── HealthManager ├── LevelManager ├── Config ├── EnemyStateManager └── EnemyTargeting

BossBehaviors ├── HealthManager ├── LevelManager ├── BossManager ├── Config ├── EnemyStateManager ├── EnemyTargeting └── BossAbilities

EnemyTargeting ├── Players └── EnemyStateManager

EnemyManager.server.luau ├── EnemySpawner └── Config

BossServer.server.luau ├── BossManager ├── Config └── Remotes

ServantServer.server.luau ├── ServantManager ├── InventoryManager ├── InventorySync ├── HealthManager ├── Config └── Remotes

ServantAI.server.luau ├── HealthManager ├── StatsManager └── Config


---

## Клиентская сторона

### Боевые модули (`client/combat/`)

CombatInput.client.luau ├── Config ├── MeleeInput └── RangedInput

MeleeInput ├── Config └── Remotes

RangedInput ├── Config └── Remotes

ProjectileVisuals.client.luau ├── Config ├── Remotes └── RunService

DamageNumbers.client.luau └── Remotes


### UI — Персонаж (`client/ui/character/`)

CharacterWindow.client.luau ├── UIConstants ← Config ├── SlotFactory ← UIConstants ├── SlotBehavior ← Config, UIConstants, DragManager, CooldownManager, ItemTooltip ├── DragManager ← UIConstants ├── EquipmentPanel ← Config, UIConstants, SlotFactory, ItemTooltip ├── CraftPanel ← Config, UIConstants, Remotes ├── InventoryGrid ← Config, UIConstants, SlotFactory, SlotBehavior, DragManager, │ CooldownManager, ItemTooltip, ActionBarHUD, Remotes ├── ActionBarHUD ← UIConstants, SlotFactory, SlotBehavior ├── CooldownManager (standalone, RenderStepped) ├── AttributesPanel ← Remotes, Config ├── BloodPoolPanel ← Config └── ItemTooltip (tooltip/)


### UI — Способности (`client/ui/abilities/`)

AbilitiesBar.client.luau ├── Config ├── Remotes ├── AbilityTooltip └── AbilityCooldowns

AbilityTooltip (standalone, ScreenGui DisplayOrder 900) AbilityCooldowns (standalone)


### UI — Боссы (`client/ui/boss/`)

BossJournalInit.client.luau └── BossJournal

BossJournal ├── Remotes ├── BossCard ├── ActTabs └── BossJournalConstants

BossCard ├── BossJournalConstants └── BossTooltip


### UI — Слуги (`client/ui/servant/`)

ServantWindow.client.luau ├── ServantCollection ├── ServantStatsPanel ├── ServantEquipPanel └── ServantActionBar


### UI — Остальное

PlayerHPBlock.client.luau ← Remotes, UIConstants ServantHPBlock.client.luau ← Remotes, UIConstants BloodPoolUI.client.luau ← Config, Remotes EnemyLabels.client.luau ← Config, EnemyUtil TargetInfo.client.luau ← LevelColorUtil EnemyHPBar.client.luau ← LevelColorUtil, EnemyUtil BuffBar.client.luau ← Remotes, Config ResourceNumbers.client.luau ← Remotes, Config CaptureUI.client.luau ← Config, Remotes CastBar.client.luau ← Remotes DeathScreen.client.luau ← Remotes Minimap.client.luau ← RunService, Players DayNightHUD.client.luau ← Config, Remotes ContainerUI.client.luau ← Config, Remotes ContainerAnimator.client.luau (standalone) IsometricCamera.client.luau (standalone) MouseLook.client.luau (standalone) MenuBar.luau ← BossJournal NotifyModule.luau (standalone) NotifyListener.client.luau ← Remotes, NotifyModule DebugKeys.client.luau ← Remotes CoreGuiSetup.client.luau (standalone) LootUI.client.luau ← Remotes