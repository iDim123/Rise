return {
    Buffs = {
        -- Существующие
        damage_boost = {
            Id = "damage_boost",
            Name = "Усиление урона",
            Description = "+30% к физической силе на время действия.",
            Icon = "rbxassetid://110176616320571",
            Type = "Buff",
            Stat = "PhysicalPower",
            Value = 0.30,
            Stackable = false
        },
        slow = {
            Id = "slow",
            Name = "Замедление",
            Description = "-40% скорости передвижения.",
            Icon = "rbxassetid://110176616320571",
            Type = "Debuff",
            Stat = "MoveSpeed",
            Value = -0.40,
            Stackable = false
        },
        damage_reduction = {
            Id = "damage_reduction",
            Name = "Укрепление",
            Description = "+20% физического сопротивления.",
            Icon = "rbxassetid://110176616320571",
            Type = "Buff",
            Stat = "PhysResistance",
            Value = 20,
            Stackable = false
        },
        speed_boost = {
            Id = "speed_boost",
            Name = "Ускорение",
            Description = "+25% скорости передвижения.",
            Icon = "rbxassetid://110176616320571",
            Type = "Buff",
            Stat = "MoveSpeed",
            Value = 0.25,
            Stackable = false
        },

        -- ═══ Фаза 3: День/Ночь ═══

        sunlight_exposure = {
            Id = "sunlight_exposure",
            Name = "Солнечный свет",
            Description = "Урон нанесённый ×0.5, получаемый урон ×2.0.",
            Icon = "rbxassetid://0",
            Type = "Debuff",
            Stat = "DamageDealt",
            Value = -0.50,
            Stackable = false,
            -- DamageTaken обрабатывается отдельно в DayNightManager
            ExtraStats = {{
                Stat = "DamageTaken",
                Value = 1.0
            } -- +100% = ×2
            }
        },

        full_moon_speed = {
            Id = "full_moon_speed",
            Name = "Полнолуние",
            Description = "+15% скорости передвижения.",
            Icon = "rbxassetid://0",
            Type = "Buff",
            Stat = "MoveSpeed",
            Value = 0.15,
            Stackable = false
        },

        blood_moon_power = {
            Id = "blood_moon_power",
            Name = "Кровавая луна: Сила",
            Description = "+20% физической силы.",
            Icon = "rbxassetid://0",
            Type = "Buff",
            Stat = "PhysicalPower",
            Value = 0.20,
            Stackable = false
        },
        blood_moon_magic = {
            Id = "blood_moon_magic",
            Name = "Кровавая луна: Магия",
            Description = "+20% магической силы.",
            Icon = "rbxassetid://0",
            Type = "Buff",
            Stat = "MagicalPower",
            Value = 0.20,
            Stackable = false
        },

        -- Вражеские лунные баффы
        full_moon_enemy_hp = {
            Id = "full_moon_enemy_hp",
            Name = "Лунная стойкость",
            Description = "+10% здоровья.",
            Icon = "rbxassetid://0",
            Type = "Buff",
            Stat = "MaxHP",
            Value = 0.10,
            Stackable = false
        },
        blood_moon_enemy_dmg = {
            Id = "blood_moon_enemy_dmg",
            Name = "Кровавая ярость",
            Description = "+30% урона.",
            Icon = "rbxassetid://0",
            Type = "Buff",
            Stat = "Damage",
            Value = 0.30,
            Stackable = false
        },
        blood_moon_enemy_aggro = {
            Id = "blood_moon_enemy_aggro",
            Name = "Кровавое чутьё",
            Description = "+50% дальности агрессии.",
            Icon = "rbxassetid://0",
            Type = "Buff",
            Stat = "AggroRange",
            Value = 0.50,
            Stackable = false
        }
    }
}
