return {
    Inventory = {
        Rows = 5,
        Columns = 8,
        SlotSize = 50,
        Padding = 4,
        ActionBarRow = 1,
        DefaultRows = 3,  -- без сумки доступно 3 ряда (24 слота)
        MaxRows = 5,       -- максимум 5 рядов (40 слотов)
    },
    Equipment = {
        Slots = {
            -- Левая панель (броня)
            { Id = "Head",   Name = "Head",   Side = "Left",  Row = 1 },
            { Id = "Chest",  Name = "Chest",  Side = "Left",  Row = 2 },
            { Id = "Legs",   Name = "Legs",   Side = "Left",  Row = 3 },
            { Id = "Feet",   Name = "Feet",   Side = "Left",  Row = 4 },
            { Id = "Hands",  Name = "Hands",  Side = "Left",  Row = 5 },
            -- Правая панель (аксессуары)
            { Id = "Cloak",  Name = "Cloak",  Side = "Right", Row = 1 },
            { Id = "Amulet", Name = "Amulet", Side = "Right", Row = 2 },
            { Id = "Ring1",  Name = "Ring",   Side = "Right", Row = 3 },
            { Id = "Ring2",  Name = "Ring",   Side = "Right", Row = 4 },
            { Id = "Bag",    Name = "Bag",    Side = "Right", Row = 5 },
        },
    },
    Bags = {
        small_bag = { ExtraRows = 1 },  -- 3+1 = 4 ряда (32 слота)
        large_bag = { ExtraRows = 2 },  -- 3+2 = 5 рядов (40 слотов)
    },
}