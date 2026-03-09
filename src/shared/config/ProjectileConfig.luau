return {
    Projectiles = {
        -- ═══ Existing (bow) ═══
        arrow = {
            Speed = 120,
            MaxDistance = 60,
            Gravity = 0,
            PierceCount = 0,
            Lifetime = 3,
            ModelId = "rbxassetid://0",
            TrailColor = Color3.fromRGB(255, 220, 100),
            HitRadius = 2
        },
        power_arrow = {
            Speed = 160,
            MaxDistance = 80,
            Gravity = 0,
            PierceCount = 2,
            Lifetime = 3,
            ModelId = "rbxassetid://0",
            TrailColor = Color3.fromRGB(255, 100, 100),
            HitRadius = 2.5
        },
        rain_arrow = {
            Speed = 80,
            MaxDistance = 30,
            Gravity = 50,
            PierceCount = 0,
            Lifetime = 2,
            ModelId = "rbxassetid://0",
            TrailColor = Color3.fromRGB(200, 200, 255),
            HitRadius = 3
        },

        -- ═══ Magic projectiles (Phase 5) ═══
        shadowbolt = {
            Speed = 100,
            MaxDistance = 60,
            Gravity = 0,
            PierceCount = 0,
            Lifetime = 3,
            ModelId = "rbxassetid://0",
            TrailColor = Color3.fromRGB(150, 0, 50),
            HitRadius = 2
        },
        chaos_bolt = {
            Speed = 110,
            MaxDistance = 50,
            Gravity = 0,
            PierceCount = 0,
            Lifetime = 3,
            ModelId = "rbxassetid://0",
            TrailColor = Color3.fromRGB(180, 50, 255),
            HitRadius = 1.8
        },
        void_bolt = {
            Speed = 140,
            MaxDistance = 55,
            Gravity = 0,
            PierceCount = 0,
            Lifetime = 3,
            ModelId = "rbxassetid://0",
            TrailColor = Color3.fromRGB(80, 0, 120),
            HitRadius = 2.2
        }
    }
}
