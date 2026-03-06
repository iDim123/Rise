return {
    Stats = {
        MaxHP = {
            Name = "Макс. здоровье",
            Base = 0,
            Format = "flat",
            Category = "Defensive",
            Description = "Максимальный запас здоровья. Складывается из базы по уровню, экипировки и бонусов."
        },
        PhysicalPower = {
            Name = "Физическая сила",
            Base = 10,
            Format = "flat",
            Category = "Offensive",
            Description = "Увеличивает урон физических атак."
        },
        MagicalPower = {
            Name = "Магическая сила",
            Base = 10,
            Format = "flat",
            Category = "Offensive",
            Description = "Увеличивает урон магических способностей."
        },
        PhysCritChance = {
            Name = "Шанс физ. крита",
            Base = 0.05,
            Format = "percent",
            Category = "Offensive",
            Description = "Вероятность нанести критический физический удар."
        },
        MagicCritChance = {
            Name = "Шанс маг. крита",
            Base = 0.05,
            Format = "percent",
            Category = "Offensive",
            Description = "Вероятность нанести критический магический удар."
        },
        PhysCritDamage = {
            Name = "Урон физ. крита",
            Base = 1.50,
            Format = "percent",
            Category = "Offensive",
            Description = "Множитель урона при критическом физическом ударе."
        },
        MagicCritDamage = {
            Name = "Урон маг. крита",
            Base = 1.50,
            Format = "percent",
            Category = "Offensive",
            Description = "Множитель урона при критическом магическом ударе."
        },
        AttackSpeed = {
            Name = "Скорость атаки",
            Base = 1.00,
            Format = "percent",
            Category = "Offensive",
            Description = "Множитель скорости атаки. Уменьшает задержку между ударами."
        },
        MoveSpeed = {
            Name = "Скорость передвижения",
            Base = 1.00,
            Format = "percent",
            Category = "Utility",
            Description = "Множитель скорости передвижения персонажа."
        },
        WeaponCDSpeed = {
            Name = "Перезарядка оружия",
            Base = 1.00,
            Format = "percent",
            Category = "Utility",
            Description = "Множитель скорости перезарядки оружейных навыков. Выше = быстрее."
        },
        MagicCDSpeed = {
            Name = "Перезарядка магии",
            Base = 1.00,
            Format = "percent",
            Category = "Utility",
            Description = "Множитель скорости перезарядки магических навыков."
        },
        FamiliarDamage = {
            Name = "Урон фамильяра",
            Base = 1.00,
            Format = "percent",
            Category = "Offensive",
            Description = "Множитель урона призванного слуги."
        },
        BloodDrainRate = {
            Name = "Расход крови",
            Base = 1.00,
            Format = "percent",
            Category = "Utility",
            Description = "Множитель скорости расхода крови. Ниже = медленнее расход."
        },
        BloodBonusPower = {
            Name = "Сила бонусов крови",
            Base = 1.00,
            Format = "percent",
            Category = "Utility",
            Description = "Множитель эффективности бонусов от типа крови."
        },
        ResourceDamage = {
            Name = "Урон по ресурсам",
            Base = 1.00,
            Format = "percent",
            Category = "Utility",
            Description = "Множитель урона по ресурсным жилам."
        },
        ResourceYield = {
            Name = "Получение ресурсов",
            Base = 1.00,
            Format = "percent",
            Category = "Utility",
            Description = "Множитель количества добываемых ресурсов."
        },
        PhysResistance = {
            Name = "Физическое сопротивление",
            Base = 0,
            Format = "resist",
            Category = "Defensive",
            Description = "Уменьшает входящий физический урон на данный процент."
        },
        MagicResistance = {
            Name = "Магическое сопротивление",
            Base = 0,
            Format = "resist",
            Category = "Defensive",
            Description = "Уменьшает входящий магический урон на данный процент."
        },
        HealthRegen = {
            Name = "Регенерация здоровья",
            Base = 1.00,
            Format = "percent",
            Category = "Defensive",
            Description = "Скорость восстановления HP вне боя. 100% = полное HP за 60 секунд."
        },
        HealingReceived = {
            Name = "Получение исцеления",
            Base = 1.00,
            Format = "percent",
            Category = "Defensive",
            Description = "Множитель эффективности всех источников исцеления."
        }
    },

    DisplayOrder = {"MaxHP", "PhysicalPower", "MagicalPower", "PhysCritChance", "MagicCritChance", "PhysCritDamage",
                    "MagicCritDamage", "AttackSpeed", "MoveSpeed", "WeaponCDSpeed", "MagicCDSpeed", "FamiliarDamage",
                    "BloodDrainRate", "BloodBonusPower", "ResourceDamage", "ResourceYield", "PhysResistance",
                    "MagicResistance", "HealthRegen", "HealingReceived"},

    CombatTimeout = 5 -- секунд без урона = "вне боя" для HealthRegen
}
