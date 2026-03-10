Проблема
В обычной разработке ты руками расставляешь объекты в Workspace. Но с процедурной генерацией мир создаётся кодом при старте сервера — в Studio нечего расставлять руками. Возникает вопрос: как тестировать, итерировать и дизайнить?

Решение: гибридный подход
Не нужно выбирать между «всё руками» и «всё кодом». Используй оба:

1. Что генерируется кодом (runtime)
Элемент	Метод	Почему кодом
Terrain (рельеф)	Terrain:FillBlock() + math.noise()	Зависит от seed, воспроизводимость
Spawn Points врагов	Poisson disc по биому	Привязаны к биому и рельефу
Ресурсные ноды	Poisson disc + raycast	Должны стоять на земле
Деревья, камни (props)	Клонирование из шаблонов	Тысячи штук, нереально руками
2. Что делается руками в Studio (шаблоны и ассеты)
Элемент	Где хранится	Зачем
Шаблоны структур (лагерь, руина, алтарь)	ServerStorage/structures/	Генератор клонирует и расставляет
Шаблоны props (дерево, куст, скала)	ServerStorage/props/	Генератор клонирует по биому
Шаблоны врагов	ServerStorage/enemies/ (уже есть)	EnemySpawner клонирует
Материалы и цвета биомов	BiomeConfig.luau	Код красит terrain
UI, эффекты, оружие	Как сейчас	Не зависят от генерации
3. Как тестировать и итерировать в Studio
Вот ключевая часть — три режима работы, которые нужно заложить:

┌─────────────────────────────────────────────────────────┐
│                    WorldConfig.luau                       │
│                                                           │
│  Mode = "Generate"   -- полная генерация из seed          │
│  Mode = "Preview"    -- генерация + пауза для осмотра     │
│  Mode = "Manual"     -- БЕЗ генерации (ручной мир)        │
│                                                           │
│  DebugSeed = 12345   -- фиксированный seed для теста      │
│  DebugBiome = "DarkForest"  -- показать только один биом   │
│  DebugChunk = {X=0, Z=0}   -- сгенерировать один чанк     │
└─────────────────────────────────────────────────────────┘
Практический workflow
Шаг 1: Создай ассеты в Studio как обычно
Работай в Studio привычным способом. Строй модели структур, props, врагов:

ServerStorage/
├── structures/
│   ├── camp_small      ← Model: палатка + костёр + забор
│   ├── camp_medium     ← Model: несколько палаток + сундук
│   ├── blood_altar     ← Model: алтарь с эффектами
│   ├── ruin_tower      ← Model: разрушенная башня
│   └── sawmill         ← Model: лесопилка
├── props/
│   ├── tree_dark       ← Model: тёмное дерево (DarkForest)
│   ├── tree_blood      ← Model: красное дерево (BloodForest)
│   ├── bush_1          ← Model: куст
│   ├── rock_small      ← Model: камень малый
│   ├── rock_large      ← Model: камень большой
│   └── mushroom_glow   ← Model: светящийся гриб (Swamp)
├── enemies/            ← уже есть
│   ├── Warrior
│   ├── Wolf
│   └── TrainingDummy
Ты моделируешь один экземпляр каждого объекта. Генератор будет клонировать и расставлять их сотнями.

Шаг 2: Debug-генерация в Studio
Добавляем команду, которая генерирует мир прямо в Studio для просмотра:

Copy-- debug_commands: /generate [seed]
-- Генерирует мир с указанным seed, можно осмотреть камерой

-- debug_commands: /generate_chunk 0 0
-- Генерирует ОДИН чанк 64x64 для быстрого теста

-- debug_commands: /generate_biome DarkForest
-- Генерирует только один биом на всю карту (для теста props/врагов)

-- debug_commands: /clear_world
-- Удаляет всё сгенерированное (Terrain:Clear() + удаление props)
Это позволяет:

Сгенерировать → осмотреть → clear → подправить параметры → сгенерировать снова
Цикл итерации: 30 секунд вместо перезапуска сервера
Шаг 3: «Тестовая карта» для Studio
Для тестирования геймплея (бой, крафт, UI) оставь ручной режим:

Copy-- WorldConfig.luau
return {
    World = {
        Mode = RunService:IsStudio() and "Manual" or "Generate",
        -- ...
    }
}
Mode = "Manual": генератор НЕ запускается, используется то, что руками расставлено в Workspace. Все текущие SpawnPoints, ресурсные ноды — работают как сейчас.

Mode = "Generate": полная генерация. Только для production или явного теста.

Это значит: весь текущий код и ручная карта продолжают работать. Генерация — это надстройка, а не замена.

Шаг 4: Seed-viewer плагин (опционально)
Можно написать простой Studio Plugin, который:

Показывает heightmap цветом (preview без реального terrain)
Показывает карту биомов
Позволяет менять seed и видеть результат мгновенно
Это 2D-превью, не требует генерации terrain. Очень быстрый цикл итерации для настройки noise-параметров.

Архитектура кода
WorldManager (оркестратор)
    │
    ├── if Mode == "Manual" → return (ничего не делать)
    │
    ├── WorldSeed.get() → seed (загрузить или создать)
    │
    ├── TerrainGenerator.generate(seed, config)
    │   ├── для каждого чанка:
    │   │   ├── heightmap = noise(x, z, seed)
    │   │   ├── biome = BiomeMap.getBiome(x, z, seed)
    │   │   └── Terrain:FillBlock(material, position, size)
    │   └── task.wait() каждые N чанков (не фризить)
    │
    ├── StructureGenerator.place(seed, biomeMap)
    │   ├── для каждого биома:
    │   │   ├── определить позиции (Poisson disc)
    │   │   ├── Clone шаблон из ServerStorage/structures/
    │   │   └── разместить на terrain (raycast вниз)
    │
    ├── SpawnPointGenerator.generate(seed, biomeMap)
    │   └── создать Folder "SpawnPoints" с Part-ами
    │       (EnemyManager подхватит как обычно)
    │
    ├── PropGenerator.scatter(seed, biomeMap)
    │   └── Clone props из ServerStorage/props/
    │
    └── EventBus.fire("WorldReady", seed)
Ключевой принцип: EnemyManager, ResourceManager и остальные системы НЕ знают что мир сгенерирован. Они видят те же SpawnPoints, те же ресурсные ноды в Workspace — просто их создал не ты руками, а генератор кодом.

Резюме: как работать в Studio
Задача	Что делать
Моделировать ассеты	Как обычно — руками в Studio
Тестировать геймплей	Mode = "Manual" — ручная карта
Тестировать генерацию	Debug-команда /generate 12345
Настраивать noise	Debug-команда /generate_chunk 0 0 или seed-viewer
Тестировать биом	/generate_biome DarkForest
Production	Mode = "Generate" — автоматически
Ничего не ломается. Текущая карта и все системы работают как раньше. Генерация — параллельный путь, который заменяет ручную расстановку только в production.

Хочешь, чтобы я реализовал Phase 1 (WorldConfig + WorldSeed + TerrainGenerator + debug-команды)?