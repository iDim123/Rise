local Config = {}

Config.Containers = {
    wooden_chest = {
        Name = "Деревянный сундук",
        Slots = 6,
        CastTime = 0, -- 0 = мгновенно
        CastMovementMode = "CancelOnMove",
        CastCancelKey = "MMB",
        DespawnTime = 60, -- сек после открытия → исчезает
        RespawnTime = 300, -- сек до следующего появления
        RespawnJitter = 0.5, -- ±50% от RespawnTime
        SpawnChance = 0.8, -- вероятность появления предметов
        RetryInterval = 60, -- повтор если SpawnChance сработал «пусто»
        InteractRange = 5, -- studs
        Persistent = false, -- не сохраняется между сессиями
        LootTable = {{
            ItemId = "health_potion",
            Chance = 0.7,
            Amount = {
                Min = 1,
                Max = 3
            }
        }, {
            ItemId = "rugged_hide",
            Chance = 0.5,
            Amount = {
                Min = 5,
                Max = 20
            }
        }}
    },

    locked_chest = {
        Name = "Запертый сундук",
        Slots = 8,
        CastTime = 5, -- 5 сек вскрытие
        CastMovementMode = "CancelOnMove",
        CastCancelKey = "MMB",
        DespawnTime = 90,
        RespawnTime = 600,
        RespawnJitter = 0.3,
        SpawnChance = 0.5,
        RetryInterval = 120,
        InteractRange = 5,
        Persistent = true, -- сохраняется между сессиями
        LootTable = {{
            ItemId = "blood_ring",
            Chance = 0.1,
            Amount = {
                Min = 1,
                Max = 1
            }
        }, {
            ItemId = "health_potion",
            Chance = 0.9,
            Amount = {
                Min = 2,
                Max = 5
            }
        }}
    }
}

return Config
