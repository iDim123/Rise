return {
    Items = {
        debug_buff_potion = {
            Id = "debug_buff_potion",
            Name = "Debug Buff Potion",
            Description = "Test potion: +30% damage, -40% speed for 20s.",
            Icon = "rbxassetid://0",
            Type = "Consumable",
            ItemLevel = 0,
            Stackable = true,
            MaxStack = 20,
            UseEffect = {
                Type = "ApplyBuffs",
                Cooldown = 1,
                Buffs = {{
                    BuffId = "damage_boost",
                    Duration = 200
                }, {
                    BuffId = "slow",
                    Duration = 20
                }}
            }
        },
        debug_servant_egg = {
            Id = "debug_servant_egg",
            Name = "Debug Servant Egg",
            Description = "Use to add a random servant. Debug item.",
            Icon = "rbxassetid://0",
            Type = "Consumable",
            ItemLevel = 0,
            Stackable = true,
            MaxStack = 99,
            UseEffect = {
                Type = "AddServant",
                Cooldown = 1
            }
        },
        blood_essence = {
            Id = "blood_essence",
            Name = "Blood Essence",
            Description = "An energy source distilled from blood.",
            Icon = "rbxassetid://114549612188882",
            Category = "Alchemy",
            Type = "Resource",
            ItemLevel = 0,
            Stackable = true,
            MaxStack = 500
        },
        health_potion = {
            Id = "health_potion",
            Name = "Health Potion",
            Description = "Восстанавливает 50 HP при использовании.",
            Icon = "rbxassetid://111762549286435",
            Type = "Consumable",
            ItemLevel = 0,
            Stackable = true,
            MaxStack = 20,
            UseEffect = {
                Type = "Heal",
                Amount = 50,
                Cooldown = 5
            }
        },
        Sword = {
            Id = "Sword",
            Name = "Sword of Light",
            Description = "A shining blade.",
            Icon = "rbxassetid://119544363190700",
            Type = "Weapon",
            ItemLevel = 10,
            Stackable = false,
            MaxStack = 1
        },
        Axe = {
            Id = "Axe",
            Name = "Iron Axe",
            Description = "A sturdy one-handed axe.",
            Icon = "rbxassetid://127853105217094",
            Type = "Weapon",
            ItemLevel = 8,
            Stackable = false,
            MaxStack = 1
        },
        iron_helmet = {
            Id = "iron_helmet",
            Name = "Iron Helmet",
            Description = "Basic head protection.",
            Icon = "rbxassetid://130188795755158",
            Type = "Head",
            EquipSlot = "Head",
            ItemLevel = 5,
            Stackable = false,
            MaxStack = 1,
            Stats = {
                Defense = 5
            }
        },
        wood = {
            Id = "wood",
            Name = "Wood",
            Description = "Raw wood harvested from trees.",
            Icon = "rbxassetid://120841469219855",
            Type = "Resource",
            ItemLevel = 0,
            Stackable = true,
            MaxStack = 99
        },
        stone = {
            Id = "stone",
            Name = "Stone",
            Description = "Raw stone mined from rocks.",
            Icon = "rbxassetid://73029786735287",
            Type = "Resource",
            ItemLevel = 0,
            Stackable = true,
            MaxStack = 99
        },
        rugged_hide = {
            Id = "rugged_hide",
            Name = "Rugged Hide",
            Description = "Thick hide stripped from wild beasts.",
            Icon = "rbxassetid://122691562832137",
            Type = "Resource",
            ItemLevel = 0,
            Stackable = true,
            MaxStack = 500
        },
        rugged_hide_helmet = {
            Id = "rugged_hide_helmet",
            Name = "Hide Helmet",
            Description = "A rough helmet made from beast hides.",
            Icon = "rbxassetid://130188795755158",
            Type = "Head",
            ItemLevel = 1,
            Stackable = false,
            MaxStack = 1,
            EquipSlot = "Head",
            Stats = {
                HP = 10
            }
        },
        rugged_hide_chest = {
            Id = "rugged_hide_chest",
            Name = "Hide Chestplate",
            Description = "A sturdy chestpiece crafted from thick hides.",
            Icon = "rbxassetid://139222038886991",
            Type = "Chest",
            ItemLevel = 1,
            Stackable = false,
            MaxStack = 1,
            EquipSlot = "Chest",
            Stats = {
                HP = 10
            }
        },
        rugged_hide_legs = {
            Id = "rugged_hide_legs",
            Name = "Hide Leggings",
            Description = "Leggings stitched from layered beast hides.",
            Icon = "rbxassetid://112291375503087",
            Type = "Legs",
            ItemLevel = 1,
            Stackable = false,
            MaxStack = 1,
            EquipSlot = "Legs",
            Stats = {
                HP = 10
            }
        },
        rugged_hide_gauntlets = {
            Id = "rugged_hide_gauntlets",
            Name = "Hide Gauntlets",
            Description = "Gauntlets wrapped in tough animal hide.",
            Icon = "rbxassetid://102807820827058",
            Type = "Hands",
            ItemLevel = 1,
            Stackable = false,
            MaxStack = 1,
            EquipSlot = "Hands",
            Stats = {
                HP = 10
            }
        },
        rugged_hide_boots = {
            Id = "rugged_hide_boots",
            Name = "Hide Boots",
            Description = "Boots reinforced with beast hide.",
            Icon = "rbxassetid://89717071091346",
            Type = "Feet",
            ItemLevel = 1,
            Stackable = false,
            MaxStack = 1,
            EquipSlot = "Feet",
            Stats = {
                HP = 10
            }
        },
        small_bag = {
            Id = "small_bag",
            Name = "Small Bag",
            Description = "A small leather bag. Unlocks 1 extra inventory row.",
            Icon = "rbxassetid://133649527466179",
            Type = "Bag",
            ItemLevel = 1,
            Stackable = false,
            MaxStack = 1,
            EquipSlot = "Bag",
            BagData = {
                ExtraRows = 1
            }
        },
        large_bag = {
            Id = "large_bag",
            Name = "Large Bag",
            Description = "A spacious bag. Unlocks 2 extra inventory rows.",
            Icon = "rbxassetid://122047544255898",
            Type = "Bag",
            ItemLevel = 3,
            Stackable = false,
            MaxStack = 1,
            EquipSlot = "Bag",
            BagData = {
                ExtraRows = 2
            }
        },
        blood_vial_warrior = {
            Id = "blood_vial_warrior",
            Name = "Колба крови воина",
            Description = "Колба с кровью воина. Выпейте, чтобы сменить тип крови.",
            Icon = "rbxassetid://115847672921380",
            Type = "Consumable",
            ItemLevel = 0,
            Stackable = true,
            MaxStack = 30,
            UseEffect = {
                Type = "DrinkBloodVial",
                Cooldown = 1,
                BloodType = "Warrior",
                BloodQuality = 50
            }
        },

        blood_vial_creature = {
            Id = "blood_vial_creature",
            Name = "Колба крови существа",
            Description = "Колба с кровью существа. Выпейте, чтобы сменить тип крови.",
            Icon = "rbxassetid://115847672921380",
            Type = "Consumable",
            ItemLevel = 0,
            Stackable = true,
            MaxStack = 30,
            UseEffect = {
                Type = "DrinkBloodVial",
                Cooldown = 1,
                BloodType = "Creature",
                BloodQuality = 100
            }
        },
        blood_ring = {
            Id = "blood_ring",
            Name = "Кровавое кольцо",
            Description = "Кольцо, пропитанное кровавой эссенцией.",
            Icon = "rbxassetid://0",
            Type = "Ring",
            EquipSlot = "Ring",
            ItemLevel = 6,
            Stackable = false,
            MaxStack = 1,
            Stats = {
                PhysicalPower = 3,
                MagicalPower = 2
            }
        },

        blood_necklace = {
            Id = "blood_necklace",
            Name = "Кровавое ожерелье",
            Description = "Ожерелье, наполненное силой крови.",
            Icon = "rbxassetid://0",
            Type = "Amulet",
            EquipSlot = "Amulet",
            ItemLevel = 6,
            Stackable = false,
            MaxStack = 1,
            Stats = {
                MaxHP = 15,
                HealthRegen = 0.1
            }
        }
    },
    ItemTypes = {
        Weapon = "Weapon",
        HeadArmor = "Head",
        ChestArmor = "Chest",
        LegsArmor = "Legs",
        FeetArmor = "Feet",
        HandsArmor = "Hands",
        Amulet = "Amulet",
        Ring = "Ring",
        Consumable = "Consumable",
        Misc = "Misc",
        Resource = "Resource",
        Cloak = "Cloak",
        Bag = "Bag"
    }
}
