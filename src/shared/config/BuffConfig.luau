return {
    Buffs = {
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
        }
    }
}
