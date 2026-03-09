return {
    Projectiles = {
        arrow = {
            Speed = 120, -- studs/sec
            MaxDistance = 60, -- studs
            Gravity = 0, -- 0 = прямой полёт
            PierceCount = 0, -- 0 = останавливается при первом попадании
            Lifetime = 3, -- секунд
            ModelId = "rbxassetid://0", -- TODO: заменить на модель стрелы
            TrailColor = Color3.fromRGB(255, 220, 100),
            HitRadius = 2 -- радиус hitbox (sphere overlap)
        },
        power_arrow = {
            Speed = 160,
            MaxDistance = 80,
            Gravity = 0,
            PierceCount = 2, -- пробивает 2 врагов
            Lifetime = 3,
            ModelId = "rbxassetid://0",
            TrailColor = Color3.fromRGB(255, 100, 100),
            HitRadius = 2.5
        },
        rain_arrow = {
            Speed = 80,
            MaxDistance = 30,
            Gravity = 50, -- падает вниз
            PierceCount = 0,
            Lifetime = 2,
            ModelId = "rbxassetid://0",
            TrailColor = Color3.fromRGB(200, 200, 255),
            HitRadius = 3
        }
    }
}
