--[[
    BuildingConfig.luau
    Конфигурация системы строительства замков (v1.9).

    Загружается автоматически через Config.luau → Config.Building.*

    КОНТРАКТ СЕРИАЛИЗАЦИИ (BuildingSerializer):
      Сохраняются в DataStore: CenterPos, HeartLevel, Permissions, Blocks[], Containers[]
      НЕ сохраняются (из конфига): Size, Material, Color, HP, Cost, PlacementRule и т.д.
      HP блоков НЕ персистится — полное HP при загрузке.
]] return {
    Building = {
        -- ═══ Настройки сетки ═══
        GridSize = 4,
        SnapTolerance = 0.1,

        -- ═══ Глобальные лимиты ═══
        MaxCastlesPerWorld = 4,

        -- ═══ Экономика ═══
        RemoveRefundRate = 0.5,

        -- ═══ Castle Heart ═══
        -- Центральный элемент замка. Ставится первым, определяет территорию.
        -- Уничтожить может ТОЛЬКО владелец → весь замок разрушается.
        -- Не потребляет blood_essence (v1.9).
        CastleHeart = {
            Name = "Сердце замка",
            Description = "Основа вашего замка. Определяет территорию и лимиты.",
            Size = Vector3.new(4, 4, 4),
            Material = Enum.Material.Basalt,
            Color = Color3.fromRGB(60, 15, 15),
            PlacementRule = "Ground",
            CanRotate = false,
            Icon = "rbxassetid://0",

            -- Уровни: 1 = базовый (при размещении), 2 и 3 = улучшения
            Levels = {
                [1] = {
                    HP = 1000,
                    MaxBlocks = 200,
                    ClaimRadius = 48,
                    MaxCoffins = 1,
                    UpgradeCost = nil -- бесплатно (начальный уровень)
                },
                [2] = {
                    HP = 2000,
                    MaxBlocks = 350,
                    ClaimRadius = 56,
                    MaxCoffins = 2,
                    UpgradeCost = {{
                        ItemId = "blood_essence",
                        Amount = 100
                    }}
                },
                [3] = {
                    HP = 3000,
                    MaxBlocks = 500,
                    ClaimRadius = 64,
                    MaxCoffins = 3,
                    UpgradeCost = {{
                        ItemId = "blood_essence",
                        Amount = 250
                    }}
                }
            },
            MaxLevel = 3
        },

        -- ═══ Permissions (кооперативное строительство) ═══
        DefaultPermissions = {
            AllowCoopBuild = false,
            AllowCoopRemove = false,
            AllowCoopInteract = true
        },

        -- ═══ Категории блоков (для UI) ═══
        BlockCategories = {{
            Id = "Foundation",
            Name = "Фундамент",
            Icon = "rbxassetid://0",
            Order = 1
        }, {
            Id = "Wall",
            Name = "Стены",
            Icon = "rbxassetid://0",
            Order = 2
        }, {
            Id = "Floor",
            Name = "Полы",
            Icon = "rbxassetid://0",
            Order = 3
        }, {
            Id = "Roof",
            Name = "Крыша",
            Icon = "rbxassetid://0",
            Order = 4
        }, {
            Id = "Functional",
            Name = "Интерьер",
            Icon = "rbxassetid://0",
            Order = 5
        }},

        -- ═══ Типы блоков ═══
        -- PlacementRule:
        --   "Ground"        — только на Baseplate / terrain
        --   "OnFoundation"  — верхняя грань фундамента или пола
        --   "OnWall"        — верхняя грань стены
        --   "Any"           — без ограничений
        --
        -- Functional (Phase 2):
        --   "Door", "Chest", "Workbench", "BloodAltar", "Coffin"

        BlockTypes = {
            -- ═══ Foundation ═══
            stone_foundation = {
                Name = "Каменный фундамент",
                Description = "Прочное основание замка.",
                Category = "Foundation",
                Size = Vector3.new(4, 1, 4),
                Material = Enum.Material.Slate,
                Color = Color3.fromRGB(120, 120, 120),
                HP = 500,
                Cost = {{
                    ItemId = "stone",
                    Amount = 10
                }},
                PlacementRule = "Ground",
                CanRotate = false,
                Icon = "rbxassetid://0"
            },

            wooden_foundation = {
                Name = "Деревянный фундамент",
                Description = "Лёгкое основание из дерева.",
                Category = "Foundation",
                Size = Vector3.new(4, 1, 4),
                Material = Enum.Material.WoodPlanks,
                Color = Color3.fromRGB(139, 90, 43),
                HP = 300,
                Cost = {{
                    ItemId = "wooden_plank",
                    Amount = 5
                }},
                PlacementRule = "Ground",
                CanRotate = false,
                Icon = "rbxassetid://0"
            },

            -- ═══ Wall ═══
            stone_wall = {
                Name = "Каменная стена",
                Description = "Крепкая стена из камня.",
                Category = "Wall",
                Size = Vector3.new(4, 4, 1),
                Material = Enum.Material.Slate,
                Color = Color3.fromRGB(130, 130, 130),
                HP = 400,
                Cost = {{
                    ItemId = "stone",
                    Amount = 8
                }},
                PlacementRule = "OnFoundation",
                CanRotate = true,
                Icon = "rbxassetid://0"
            },

            wooden_wall = {
                Name = "Деревянная стена",
                Description = "Стена из досок.",
                Category = "Wall",
                Size = Vector3.new(4, 4, 1),
                Material = Enum.Material.WoodPlanks,
                Color = Color3.fromRGB(150, 100, 50),
                HP = 250,
                Cost = {{
                    ItemId = "wooden_plank",
                    Amount = 4
                }},
                PlacementRule = "OnFoundation",
                CanRotate = true,
                Icon = "rbxassetid://0"
            },

            stone_pillar = {
                Name = "Каменная колонна",
                Description = "Колонна для поддержки крыши.",
                Category = "Wall",
                Size = Vector3.new(1, 4, 1),
                Material = Enum.Material.Slate,
                Color = Color3.fromRGB(140, 140, 140),
                HP = 600,
                Cost = {{
                    ItemId = "stone",
                    Amount = 6
                }},
                PlacementRule = "OnFoundation",
                CanRotate = false,
                Icon = "rbxassetid://0"
            },

            -- ═══ Floor ═══
            wooden_floor = {
                Name = "Деревянный пол",
                Description = "Пол из обработанных досок.",
                Category = "Floor",
                Size = Vector3.new(4, 0.5, 4),
                Material = Enum.Material.WoodPlanks,
                Color = Color3.fromRGB(160, 110, 60),
                HP = 200,
                Cost = {{
                    ItemId = "wooden_plank",
                    Amount = 3
                }},
                PlacementRule = "OnWall",
                CanRotate = false,
                Icon = "rbxassetid://0"
            },

            stone_floor = {
                Name = "Каменный пол",
                Description = "Холодный каменный пол.",
                Category = "Floor",
                Size = Vector3.new(4, 0.5, 4),
                Material = Enum.Material.Slate,
                Color = Color3.fromRGB(110, 110, 110),
                HP = 350,
                Cost = {{
                    ItemId = "stone",
                    Amount = 6
                }},
                PlacementRule = "OnWall",
                CanRotate = false,
                Icon = "rbxassetid://0"
            },

            -- ═══ Roof ═══
            wooden_roof = {
                Name = "Деревянная крыша",
                Description = "Крыша из досок. Защищает от солнца.",
                Category = "Roof",
                Size = Vector3.new(4, 0.5, 4),
                Material = Enum.Material.WoodPlanks,
                Color = Color3.fromRGB(100, 65, 30),
                HP = 200,
                Cost = {{
                    ItemId = "wooden_plank",
                    Amount = 4
                }},
                PlacementRule = "OnWall",
                CanRotate = false,
                IsShelter = true,
                Icon = "rbxassetid://0"
            },

            stone_roof = {
                Name = "Каменная крыша",
                Description = "Прочная каменная крыша.",
                Category = "Roof",
                Size = Vector3.new(4, 0.5, 4),
                Material = Enum.Material.Slate,
                Color = Color3.fromRGB(100, 100, 100),
                HP = 400,
                Cost = {{
                    ItemId = "stone",
                    Amount = 8
                }},
                PlacementRule = "OnWall",
                CanRotate = false,
                IsShelter = true,
                Icon = "rbxassetid://0"
            },

            -- ═══ Functional (Phase 2) ═══
            wooden_door = {
                Name = "Деревянная дверь",
                Description = "Открывается нажатием F.",
                Category = "Functional",
                Size = Vector3.new(4, 4, 0.5),
                Material = Enum.Material.Wood,
                Color = Color3.fromRGB(120, 80, 40),
                HP = 150,
                Cost = {{
                    ItemId = "wooden_plank",
                    Amount = 3
                }},
                PlacementRule = "OnFoundation",
                CanRotate = true,
                Functional = "Door",
                Icon = "rbxassetid://0"
            },

            castle_chest = {
                Name = "Сундук",
                Description = "Хранилище для предметов. 12 слотов.",
                Category = "Functional",
                Size = Vector3.new(2, 2, 2),
                Material = Enum.Material.WoodPlanks,
                Color = Color3.fromRGB(140, 95, 45),
                HP = 100,
                Cost = {{
                    ItemId = "wooden_plank",
                    Amount = 6
                }, {
                    ItemId = "stone",
                    Amount = 2
                }},
                PlacementRule = "OnFoundation",
                CanRotate = true,
                Functional = "Chest",
                FunctionalData = {
                    Slots = 12,
                    InteractRange = 5
                },
                Icon = "rbxassetid://0"
            },

            workbench = {
                Name = "Верстак",
                Description = "Позволяет создавать продвинутые предметы.",
                Category = "Functional",
                Size = Vector3.new(3, 2, 2),
                Material = Enum.Material.WoodPlanks,
                Color = Color3.fromRGB(130, 85, 40),
                HP = 150,
                Cost = {{
                    ItemId = "wooden_plank",
                    Amount = 8
                }, {
                    ItemId = "stone",
                    Amount = 4
                }},
                PlacementRule = "OnFoundation",
                CanRotate = true,
                Functional = "Workbench",
                Icon = "rbxassetid://0"
            },

            blood_altar = {
                Name = "Алтарь крови",
                Description = "Используйте эссенцию крови для улучшения качества крови.",
                Category = "Functional",
                Size = Vector3.new(3, 3, 3),
                Material = Enum.Material.Basalt,
                Color = Color3.fromRGB(80, 20, 20),
                HP = 300,
                Cost = {{
                    ItemId = "stone",
                    Amount = 15
                }, {
                    ItemId = "blood_essence",
                    Amount = 50
                }},
                PlacementRule = "OnFoundation",
                CanRotate = false,
                Functional = "BloodAltar",
                Icon = "rbxassetid://0"
            },

            coffin = {
                Name = "Гроб",
                Description = "Точка респавна. Лимит зависит от уровня сердца.",
                Category = "Functional",
                Size = Vector3.new(2, 1, 4),
                Material = Enum.Material.Wood,
                Color = Color3.fromRGB(60, 40, 25),
                HP = 200,
                Cost = {{
                    ItemId = "wooden_plank",
                    Amount = 10
                }, {
                    ItemId = "blood_essence",
                    Amount = 20
                }},
                PlacementRule = "OnFoundation",
                CanRotate = true,
                Functional = "Coffin",
                Icon = "rbxassetid://0"
                -- MaxPerCastle теперь определяется CastleHeart.Levels[n].MaxCoffins
            }
        }
    }
}
