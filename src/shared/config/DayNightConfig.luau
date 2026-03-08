return {
    DayNight = {
        CycleDuration = 1200, -- полный цикл 24 часа = 1200 реальных секунд (20 мин)
        TransitionTime = 30, -- длительность рассвета/заката в секундах

        -- Часы, определяющие фазы
        DawnHour = 6, -- рассвет начинается
        DayHour = 7, -- полный день
        DuskHour = 20, -- закат начинается
        NightHour = 21, -- полная ночь
        -- Ночь: 21 → 6, День: 7 → 20

        StartHour = 0, -- с какого часа начинается игра
        -- Lighting: День
        Day = {
            ClockTime = 14,
            Brightness = 2,
            Ambient = Color3.fromRGB(180, 180, 180),
            OutdoorAmbient = Color3.fromRGB(150, 150, 150),
            FogEnd = 10000,
            FogColor = Color3.fromRGB(180, 190, 210)
        },

        -- Lighting: Ночь
        Night = {
            ClockTime = 0,
            Brightness = 0.5,
            Ambient = Color3.fromRGB(130, 130, 150),
            OutdoorAmbient = Color3.fromRGB(60, 60, 60),
            FogEnd = 600,
            FogColor = Color3.fromRGB(60, 60, 120)
        },

        -- Lighting: Кровавая луна (переопределяет ночь)
        BloodMoon = {
            ClockTime = 0,
            Brightness = 0.3,
            Ambient = Color3.fromRGB(50, 20, 20),
            OutdoorAmbient = Color3.fromRGB(40, 15, 15),
            FogEnd = 500,
            FogColor = Color3.fromRGB(30, 10, 10)
        },

        -- Солнечный дебафф
        SunlightDebuff = {
            BuffId = "sunlight_exposure",
            ShelterGracePeriod = 3, -- секунд до снятия в тени
            CheckInterval = 1, -- частота проверки (сек)
            Duration = 3, -- длительность дебаффа (обновляется)
            RaycastHeight = 100 -- высота луча для тени
        }
    },

    LunarCycle = {
        FullCycleDuration = 18000, -- 5 реальных часов (секунды)
        Phases = {{
            Id = "new_moon",
            Name = "Новолуние",
            Duration = 0.15, -- доля от полного цикла
            Icon = "rbxassetid://0",
            PlayerBuffs = {},
            EnemyBuffs = {}
        }, {
            Id = "waxing",
            Name = "Растущая луна",
            Duration = 0.25,
            Icon = "rbxassetid://0",
            PlayerBuffs = {},
            EnemyBuffs = {}
        }, {
            Id = "full_moon",
            Name = "Полнолуние",
            Duration = 0.15,
            Icon = "rbxassetid://0",
            PlayerBuffs = {{
                BuffId = "full_moon_speed",
                Stat = "MoveSpeed",
                Value = 0.15
            }},
            EnemyBuffs = {{
                BuffId = "full_moon_enemy_hp",
                Stat = "MaxHP",
                Value = 0.10
            }}
        }, {
            Id = "waning",
            Name = "Убывающая луна",
            Duration = 0.25,
            Icon = "rbxassetid://0",
            PlayerBuffs = {},
            EnemyBuffs = {}
        }, {
            Id = "blood_moon",
            Name = "Кровавая луна",
            Duration = 0.20,
            Icon = "rbxassetid://0",
            PlayerBuffs = {{
                BuffId = "blood_moon_power",
                Stat = "PhysicalPower",
                Value = 0.20
            }, {
                BuffId = "blood_moon_magic",
                Stat = "MagicalPower",
                Value = 0.20
            }},
            EnemyBuffs = {{
                BuffId = "blood_moon_enemy_dmg",
                Stat = "Damage",
                Value = 0.30
            }, {
                BuffId = "blood_moon_enemy_aggro",
                Stat = "AggroRange",
                Value = 0.50
            }}
        }}
    }
}
