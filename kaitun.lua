if not game:IsLoaded() then game.Loaded:Wait() end
local RUNTIME_KEY = "__KAITUN_RUNTIME"

local function cloneTable(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[cloneTable(k, seen)] = cloneTable(v, seen)
    end
    return copy
end

local function disableLegacyActions(cfg)
    if type(cfg) ~= "table" then
        return
    end
    for _, section in pairs(cfg) do
        if type(section) == "table" and section.Enabled ~= nil then
            section.Enabled = false
        end
    end
end

local oldConfig = getgenv().ConfigsKaitun
local newConfig = cloneTable(oldConfig)
local oldRuntime = getgenv()[RUNTIME_KEY]

if oldRuntime and type(oldRuntime.Stop) == "function" then
    pcall(oldRuntime.Stop, "new kaitun loaded")
elseif oldConfig then
    disableLegacyActions(oldConfig)
    print("[KAITUN]", "Disabled legacy action config from older script.")
end

if newConfig then
    getgenv().ConfigsKaitun = newConfig
end

local Runtime = {
    Active = true,
    Tasks = {},
    Cleanups = {},
    TaskStatus = {},
    StartedAt = os.clock(),
}

function Runtime.Stop(reason)
    if not Runtime.Active then
        return
    end
    Runtime.Active = false
    print("[KAITUN]", "Stop runtime:", tostring(reason or "manual"))
    for _, thread in ipairs(Runtime.Tasks) do
        if type(thread) == "thread" and coroutine.status(thread) ~= "dead" then
            pcall(task.cancel, thread)
        end
    end
    for _, cleanup in ipairs(Runtime.Cleanups) do
        if type(cleanup) == "function" then
            pcall(cleanup)
        end
    end
end

getgenv()[RUNTIME_KEY] = Runtime
getgenv().StopKaitun = function(reason)
    local runtime = getgenv()[RUNTIME_KEY]
    if runtime and type(runtime.Stop) == "function" then
        runtime.Stop(reason or "manual")
    end
end

if getgenv().ConfigsKaitun == nil then
    getgenv().ConfigsKaitun = {
        ActionLogEnabled = true,

        -- Mua hạt giống ở Seed Shop
        AutoBuySeed = {
            Enabled = true,
            Delay   = 0.35,
            Mode    = "Smart", -- Smart: uu tien seed xin con stock va du tien; List: mua theo List
            MinRarity = "Common",
            KeepSheckles = 0,
            MaxPerSeedPerCycle = 50,
            List = {},
        },

        -- Tự trồng mọi hạt đang có trong túi vào ô PlantArea của plot mình
        AutoPlant = {
            Enabled        = true,
            Delay          = 0.25,
            PlantPerSeed   = 50,   -- số lần thử trồng tối đa cho mỗi tool hạt
            -- LỘ TRÌNH TRỒNG: mỗi loại seed chỉ trồng tối đa N cây trong plot. Đủ quota -> không
            -- trồng thêm loại đó. Seed không có trong bảng -> trồng bình thường. Chồng chỉnh số
            -- tuỳ ý ở đây. UsePlantQuota=false để trồng hết như cũ.
            UsePlantQuota  = true,
            PlantQuota = {
                ["Carrot"] = 10,
                ["Strawberry"] = 4,
                ["Blueberry"] = 4,
                ["Tulip"] = 4,
                ["Tomato"] = 4,
                ["Apple"] = 4,
                ["Bamboo"] = 50,
                ["Corn"] = 4,
                ["Cactus"] = 4,
                ["Pineapple"] = 4,
                ["Mushroom"] = 50,
                ["Green Bean"] = 50,
                ["Banana"] = 50,
                ["Grape"] = 50,
                ["Coconut"] = 50,
                ["Mango"] = 50,
                ["Dragon Fruit"] = 50,
                ["Acorn"] = 50,
                ["Cherry"] = 50,
                ["Sunflower"] = 50,
                ["Venus Fly Trap"] = 50,
                ["Pomegranate"] = 50,
                ["Poison Apple"] = 50,
                ["Moon Bloom"] = 50,
                ["Dragon's Breath"] = 50,
            },
        },

        -- Khi vườn ĐẦY mà trong túi có hạt xịn hơn cây đang trồng thì cầm Shovel
        -- đào cây dỏm nhất đi, để AutoPlant trồng cây xịn vào chỗ trống.
        -- Đào cây bằng remote thật Networking.Shovel.UseShovel (ShovelController).
        AutoShovelReplace = {
            Enabled          = false,  -- MẶC ĐỊNH TẮT: đào cây là KHÔNG hoàn lại được
            Delay            = 5,
            OnlyWhenPlotFull = true,   -- TOGGLE: true = chỉ đào-thay khi vườn đã đầy
            -- Số cây coi là "đầy". Source game (client) KHÔNG có hằng số max cây
            -- (server giữ logic đó), nên CHỒNG phải tự set theo plot của mình.
            -- 0 = chưa set -> module sẽ bỏ qua và nhắc set.
            PlotFullCount    = 0,
            -- Không bao giờ đào cây có mutation nằm trong danh sách này.
            -- "Gold"/"Rainbow" là mutation thật trong MutationData.
            KeepMutations    = { "Gold", "Rainbow" },
            MaxReplacePerCycle = 1,    -- mỗi vòng chỉ đào tối đa 1 cây dỏm (an toàn)
            -- Hạt mới phải xịn hơn cây dỏm ít nhất bao nhiêu LẦN giá thì mới đào.
            -- 1.0 = chỉ cần xịn hơn; 1.2 = phải hơn 20% giá mới đào.
            MinScoreGain     = 1.0,
            -- SAFE PLANT: [tên cây] = số cây tối thiểu LUÔN chừa lại khi đào.
            -- Nhập 1 = luôn để lại 1 cây loại đó. Nhập 0 = GIỮ TOÀN BỘ (không đào loại đó).
            -- Loại KHÔNG có trong bảng = đào tự do.
            SafePlants = {
                ["Moon Bloom"] = 1,
                ["Dragon's Breath"] = 1,
                ["Venus Fly Trap"] = 1,
                ["Sunflower"] = 1,
                ["Cherry"] = 1,
                ["Pomegranate"] = 1,
                ["Poison Apple"] = 1,
            },
        },

        -- Mua gear ở Gear Shop
        AutoBuyGear = {
            Enabled = true,
            Delay   = 0.5,
            Mode    = "Smart",
            MinRarity = "Rare",
            KeepSheckles = 0,
            MaxPerItemPerCycle = 10,
            PrioritizeSprinklers = true,
            AllowPriorityBelowMinRarity = true,
            PriorityList = {
                "Super Sprinkler",
                "Legendary Sprinkler",
                "Rare Sprinkler",
                "Uncommon Sprinkler",
                "Common Sprinkler",
            },
            ExcludeList = {
                "Jump Mushroom",
                "Speed Mushroom",
                "Shrink Mushroom",
            },
            List = {
                "Super Sprinkler",
                "Legendary Sprinkler",
                "Super Watering Can",
                "Rare Sprinkler",
            },
        },

        -- Equip 1 gear theo tên (đồ equippable: Carpet, Vine Wrapper, ...)
        AutoBuyCrate = {
            Enabled = true,
            Delay = 0.5,
            Mode = "Smart",
            MinRarity = "Epic",
            KeepSheckles = 0,
            MaxPerItemPerCycle = 3,
            List = {},
        },

        AutoEquipGear = {
            Enabled = false,
            Gear    = "",
        },

        -- Tự thu hoạch quả chín trong plot mình
        AutoCollect = {
            Enabled = true,
            Delay   = 1,
            RemoteOnly = true,
            TeleportToFruit = false,
            TeleportDistance = 4,
            TeleportYOffset = 2,
            TeleportWait = 0.05,
            TriggerPromptFallback = false,
            MaxPerCycle = 120,
            MaxTeleportsPerCycle = 0,
            ReturnHomeAfterCollect = false,
            StayInGarden = true,
            BetweenCollect = 0.03,
            PauseWhenFull = true,   -- đầy túi thì NGỪNG nhặt (nhặt nữa cũng phí), để đi bán
            -- Hái quả ĐÁNG TIỀN trước (theo giá bán thật FruitValueCalc), thay vì cứ hái quả gần.
            PrioritizeValuable = true,
            TeleportToValuable = false, -- mặc định KHÔNG teleport (remote hái được từ xa); bật nếu muốn chắc quả trên cao
            MaxValuableTeleports = 8,   -- nếu bật teleport: mỗi vòng tối đa bao nhiêu lần
            MinFruitScore = 0,          -- >0: bỏ qua quả rẻ dưới ngưỡng giá này (0 = hái hết)
        },

        NightNotifier = {
            Enabled = true,
            ShowGui = true,
            LogChanges = true,
            BlockSellAtNight = true,
        },

        AntiSteal = {
            Enabled = true,
            Delay = 0.3,
            OnlyAtNight = true,
            EquipShovel = true,
            RequireShovel = true,
            TeleportToIntruder = true,
            TeleportDistance = 5,        -- server yeu cau khoang cach <= 12 (ShovelController)
            TeleportYOffset = 0,
            HitsPerTarget = 3,           -- so cu danh moi lan vao ke trom
            BetweenHits = 0.6,           -- >= 0.5 de qua duoc cooldown moi-muc-tieu cua server
            TargetCooldown = 0.5,        -- re-engage nhanh: cu 0.5s lai danh lai neu con trong vuon
            ReturnAfterDefend = true,
        },

        Dashboard = {
            Enabled = true,
            Visible = true,
            ToggleKey = "RightShift",
            RefreshRate = 0.5,
            MaxLogs = 18,
        },

        AutoStartGame = {
            Enabled = true,
            Delay = 2,
            MaxReadyFires = 8,
            ForceLoadingAttributes = false,
            FireTutorialReady = true,
            TapToPlay = true,
            TapClickCount = 5,
            TapHold = 0.08,
            UseVirtualInput = true,
            UseTouchInput = true,
            UseVirtualUser = false,
            UseMouseFallback = false,
            StopWhenReady = true,
            ReadyStableSeconds = 3,
            InitialGraceDelay = 0.5,
            ForceLoadingAfter = 180,
            FireReadyAfter = 0.5,
            HideTapScreenAfter = 0,
            ForceHideLoadingAfter = 0,
            ForceTapWithoutText = false,   -- khong tap ep khi chua xac nhan prompt/load state
            ForceOnlyAfterPrompt = false,  -- KHÔNG chờ thấy prompt: tự set LoadingScreenDone + fire Tutorial.Ready
            SkipOfflineCutscene = true,    -- tự skip màn "Hold to skip" (cây mọc offline)
            OfflineSkipHold = 1.15,        -- thời gian giữ chuột để skip (game cần >= 1s)
        },

        -- Auto sell inventory; teleports to Steven before SellAll by default.
        AutoSell = {
            Enabled                    = true,
            Delay                      = 20,   -- nhịp bán tối thiểu (giây)
            DelayMax                   = 60,   -- nhịp bán tối đa; mỗi lần random trong [Delay, DelayMax]
            TeleportToStevenBeforeSell = false,
            TeleportDistance           = 5,
            TeleportWait               = 0.75,
            PostPreviewWait            = 0.25,
            PreSellWait                = 0.5,
            SellWhenFull               = true,   -- đầy túi thì bán ngay khỏi đợi Delay
            FullThreshold              = 0.95,   -- đầy >= 95% sức chứa là bán
            FullCheckDelay             = 1,      -- nhịp kiểm tra đầy túi
            SellAtNight                = true,   -- ĐÊM CŨNG BÁN (bán nhanh, không sợ bị trộm)
            ReturnHomeAfterSell        = false,  -- ban tu xa, khong teleport qua lai gay giat
        },

        -- Tự ấp trứng đang cầm trong túi (OpenEgg)
        AutoClaimMailbox = {
            Enabled = true,
            Delay = 10,
            MaxPerCycle = 20,
        },

        AutoSnapPets = {
            Enabled = true,
            Delay = 15,
        },

        AutoHatchEgg = {
            Enabled = true,
            Delay   = 0.5,
        },

        -- Tự equip pet theo tên
        AutoEquipPet = {
            Enabled = true,
            Delay   = 5,
            Mode    = "Smart",
            List = {
                -- "Starfish",
            },
        },

        -- Tự nhặt drop trong workspace.DroppedItems bằng prompt/teleport gần item
        AutoCollectDrops = {
            Enabled = true,
            Delay = 0.5,
            MaxPerCycle = 30,
            TeleportDistance = 3,
            TeleportYOffset = 2,
            TeleportWait = 0.05,
            IncludeSeedPackSpawns = true,
            PrioritizeRainbowSeed = true,
            SeedSpawnYOffset = 3,
            SeedSpawnWait = 0.12,
            SeedClaimNoPromptWait = 2.5,
            SeedClaimHoldExtra = 4,         -- giữ prompt THÊM cho seed thường
            SeedClaimHoldExtraRainbow = 4,   -- giữ LÂU HƠN khi claim Rainbow Seed (quý nhất)
            SeedClaimHoldExtraGold = 4,      -- giữ LÂU HƠN khi claim Gold Seed
            SeedClaimPostPromptWait = 1.5,
            SeedClaimGrace = 0.5,
            FreezeDuringSeedClaim = true,
            ReturnHomeAfterCollect = true,
        },

        -- Tự tưới nước cây trong plot (Networking.WateringCan.UseWateringCan)
        AutoWater = {
            Enabled  = true,
            Delay    = 2,
            PerCycle = 20,   -- số điểm tưới mỗi vòng
        },

        -- Tự đặt sprinkler đang có trong túi xuống ô PlantArea (Networking.Place.PlaceSprinkler)
        AutoSprinkler = {
            Enabled  = true,
            Delay    = 0.5,
            PerCycle = 5,
        },

        -- Tự mở Crate đang cầm (Networking.Crate.OpenCrate)
        AutoOpenCrate = {
            Enabled = true,
            Delay   = 0.5,
        },

        -- Tự mở Seed Pack đang cầm (Networking.SeedPack.OpenSeedPack)
        AutoOpenSeedPack = {
            Enabled = true,
            Delay   = 0.5,
        },

        -- Tự cộng điểm kỹ năng (Networking.SkillPoints.SpendSkillPoint)
        AutoSpendSkill = {
            Enabled  = true,
            Delay    = 0.3,
            Priority = { "MaxBackpack", "ShovelPower", "BaseSpeed", "BaseJump" },
        },

        -- Tự mở rộng vườn (Networking.Actions.ExpandGarden) - TỐN TIỀN, mặc định tắt
        AutoExpandGarden = {
            Enabled      = true,
            Delay        = 10,
            KeepSheckles = 0,
        },

        -- Tự mua thêm ô pet (Networking.Pets.RequestPurchasePetSlot) - TỐN TIỀN, mặc định tắt
        AutoPurchasePetSlot = {
            Enabled      = true,
            Delay        = 15,
            KeepSheckles = 0,
        },

        -- Tự tame/buy wild pet trong workspace.Map.WildPetRef
        AutoTameWildPet = {
            Enabled = true,
            Delay = 2,
            MinRarity = "Legendary",
            PriorityMinRarity = "Legendary",
            PriorityYieldSeconds = 1.5,
            KeepSheckles = 0,
            MaxPerCycle = 3,
            TeleportToPet = true,
            TeleportDistance = 5,
            TeleportYOffset = 1,
            ReturnHomeAfterTame = true,
        },

        -- ESP highlight (chỉ client, không remote)
        ESP = {
            ReadyPlants = false,   -- highlight cây có quả chín
            Players     = false,   -- highlight người chơi khác
            RefreshRate = 1,
        },

        -- Giảm đồ hoạ cho mượt (chỉ client)
        FpsBoost = {
            Enabled = true,
            TargetFPS = 10,
            CapRefreshDelay = 5,
            MuteAudio = true,
            DisableEffects = true,
            DisablePostEffects = true,
        },

        ClientLight = {
            Enabled = true,
            Delay = 10,
            HideOtherGardens = true,
            DisableOtherGardenEffects = true,
        },

        LowFpsMode = {
            Enabled = true,
            Threshold = 25,
            CriticalThreshold = 15,
            DelayMultiplier = 1.6,
            CriticalDelayMultiplier = 2.4,
            ImportantDelayMultiplier = 1.25,
            MinDelay = 0.2,
            StartupStagger = 0.12,
            WatchdogDelay = 8,
        },

        Webhook = {
            Enabled = true,
            Url = "https://discord.com/api/webhooks/1446104321757286471/r1b1AbDIk2EXQ8OW_X6k_1mtriZ3hU5NkZT72sTXYCI24GoxtXUZxllYlYId0LAe7ze9",
            Mention = "<@1378019320126509147>",
            Cooldown = 2,
            MaxQueue = 80,
        },

        ValuableWatcher = {
            Enabled = true,
            Delay = 2,
            MinPetRarity = "Legendary",
            NotifyHighPet = false,
            NotifyRainbowSeed = true,
            KeepRainbowSeed = true,
            PersistSeen = true, -- nhớ pet/seed đã báo xuống file, relog không gửi trùng
        },

        -- Phát hiện rainbow seed trong người -> gửi qua Mailbox cho 1 acc.
        -- Remote thật: Networking.Mailbox.SendBatch / LookupPlayer (Networking.lua:379-380).
        -- LƯU Ý: Mailbox trừ seed từ Inventory.Seeds (data), KHÔNG trừ Tool trong Backpack.
        KeepSeeds = {
            Enabled = true,
            List = {
                "Rainbow",
                "Gold",
                "Moon Bloom",
                "Dragon's Breath",
                "Bamboo",
            },
        },

        AutoMailSeeds = {
            Enabled           = true,
            RecipientUsername = "chuideptrai1209",
            RecipientUserId   = 0,
            Note              = "chuideptraiqua",
            SeedNames = {
                "Rainbow",
                "Gold",
                "Moon Bloom",
                "Dragon's Breath",
                "Bamboo",
            },
            MaxPerBatch       = 20,
            DelayBeforeSend   = 5,
            Delay             = 30,
        },

        AutoMailRainbow = {
            Enabled           = true,
            RecipientUsername = "chuideptrai1209", -- acc nhận seed
            RecipientUserId   = 0,                 -- >0: dùng luôn (bỏ qua LookupPlayer); 0: tự lookup theo username
            Note              = "chuideptraiqua",  -- ghi chú (tham số thứ 3 của SendBatch)
            SendCount         = 1,                 -- số lượng seed gửi mỗi lần
            DelayBeforeSend   = 30,                -- đợi bao nhiêu giây sau khi PHÁT HIỆN mới gửi
            Delay             = 30,                -- nhịp quét của vòng loop
            SkipResentKey     = true,              -- true: 1 key đã gửi thành công thì không gửi lại trong phiên này
        },

        -- Acc chỉ định: mỗi phút update 1 webhook RIÊNG, báo đang giữ bao nhiêu Rainbow Seed.
        RainbowAccountReport = {
            Enabled    = true,
            Username   = "chuideptrai1209", -- chỉ acc này mới gửi report ("" = mọi acc)
            WebhookUrl = "https://discord.com/api/webhooks/1506142435309391934/5F4iIYLiuhgbyq5zzamoIoXAPPXMOUunuNIUKxbbltGucYyHjTMb1bcL_49Yo9fpI0F8",                -- DÁN URL webhook riêng vào đây
            Mention    = "<@1378019320126509147>",
            Interval   = 60,                -- giây (mỗi phút)
        },

    }
end

local CFG = getgenv().ConfigsKaitun

local function setDefault(tbl, key, value)
    if type(tbl) == "table" and tbl[key] == nil then
        tbl[key] = value
    end
end

-- ============================================================
-- CONFIG VIẾT GỌN: cho phép Feature = true/false (thay cho { Enabled = ... }),
-- và gộp toàn bộ MAIL vào 1 mục CFG.Mail. Quy đổi về cấu trúc đầy đủ TRƯỚC setDefault.
-- (gói trong do/end nên không tốn local ở main scope)
-- ============================================================
do
    -- 1) Feature = true/false  ->  { Enabled = true/false }
    for _, k in ipairs({
        "AutoBuySeed","AutoPlant","AutoShovelReplace","AutoBuyGear","AutoBuyCrate",
        "AutoEquipGear","AutoCollect","NightNotifier","AntiSteal","Dashboard","AutoStartGame",
        "AutoSell","AutoSnapPets","AutoHatchEgg","AutoEquipPet","AutoCollectDrops","AutoWater",
        "AutoSprinkler","AutoOpenCrate","AutoOpenSeedPack","AutoSpendSkill","AutoExpandGarden",
        "AutoPurchasePetSlot","AutoTameWildPet","FpsBoost","ClientLight","LowFpsMode",
        "ValuableWatcher","AutoClaimMailbox","AutoMailRainbow","AutoMailSeeds","AutoMailPets",
        "RainbowAccountReport","TrimToQuota",
    }) do
        if type(CFG[k]) == "boolean" then
            CFG[k] = { Enabled = CFG[k] }
        end
    end

    -- 2) Gộp MAIL: CFG.Mail = { Recipient, ClaimMail, SendRainbow, SendSeeds={..}, SendPets={..} }
    --    -> map sang AutoClaimMailbox / AutoMailRainbow / AutoMailSeeds / AutoMailPets.
    local m = CFG.Mail
    if type(m) == "table" then
        local recip = type(m.Recipient) == "string" and m.Recipient ~= "" and m.Recipient or nil
        local function ensure(name)
            CFG[name] = type(CFG[name]) == "table" and CFG[name] or {}
            return CFG[name]
        end
        local claim = ensure("AutoClaimMailbox")
        claim.Enabled = m.ClaimMail ~= false

        local rb = ensure("AutoMailRainbow")
        rb.Enabled = m.SendRainbow ~= false
        if recip then rb.RecipientUsername = recip end

        local sd = ensure("AutoMailSeeds")
        local seeds = type(m.SendSeeds) == "table" and m.SendSeeds or nil
        sd.Enabled = seeds ~= nil and #seeds > 0
        if seeds then sd.SeedNames = seeds end
        if recip then sd.RecipientUsername = recip end

        local pt = ensure("AutoMailPets")
        local pets = type(m.SendPets) == "table" and m.SendPets or nil
        pt.Enabled = pets ~= nil and #pets > 0
        if pets then pt.PetNames = pets end
        if recip then pt.RecipientUsername = recip end
    end
end

-- ============================================================
-- SCHEMA GỌN ("bản chất kaitun"): chỉ để lộ thứ cần chỉnh, còn lại chạy mặc định NGẦM.
-- Dịch schema gọn -> cấu trúc internal (GIỮ NGUYÊN logic đã test). Mục không khai = mặc định.
-- (gói trong do/end nên không tốn local ở main scope)
-- ============================================================
do
    local function ensure(name)
        CFG[name] = type(CFG[name]) == "table" and CFG[name] or {}
        return CFG[name]
    end

    -- Cooldown_sell: bán khi đầy túi HOẶC mỗi N giây.
    local cd = tonumber(CFG.Cooldown_sell)
    if cd then
        local s = ensure("AutoSell")
        s.Enabled = true
        s.Delay = cd
        s.DelayMax = cd
    end

    -- Autobuyplot: tự mua mở rộng vườn.
    if type(CFG.Autobuyplot) == "boolean" then
        ensure("AutoExpandGarden").Enabled = CFG.Autobuyplot
    end

    -- Low Cpu: gộp FpsBoost + LowFpsMode + ClientLight.
    -- true/false = bật/tắt; HOẶC để 1 SỐ = bật + đặt luôn FPS Cap = số đó.
    local lowcpu = CFG["Low Cpu"]
    if type(lowcpu) == "boolean" then
        ensure("FpsBoost").Enabled = lowcpu
        ensure("LowFpsMode").Enabled = lowcpu
        ensure("ClientLight").Enabled = lowcpu
    elseif type(lowcpu) == "number" then
        ensure("FpsBoost").Enabled = true
        ensure("FpsBoost").TargetFPS = lowcpu
        ensure("LowFpsMode").Enabled = true
        ensure("ClientLight").Enabled = true
    end
    -- FPS Cap (Performance): trần khung hình. 3-10 lý tưởng để farm nhiều acc. Ưu tiên hơn mặc định 30.
    if tonumber(CFG["FPS Cap"]) then
        local fb = ensure("FpsBoost")
        fb.Enabled = true
        fb.TargetFPS = tonumber(CFG["FPS Cap"])
    end

    -- Limit Tree: chạm Limit cây -> đào cây TIER THẤP NHẤT xuống "Destroy Untill". Safe Tree giữ lại.
    local lt = CFG["Limit Tree"]
    if type(lt) == "table" then
        local sr = ensure("AutoShovelReplace")
        sr.Enabled = true
        sr.OnlyWhenPlotFull = true
        sr.PlotFullCount = tonumber(lt["Limit"]) or sr.PlotFullCount or 400
        sr.DestroyUntil = tonumber(lt["Destroy Untill"]) or tonumber(lt["Destroy Until"]) or sr.DestroyUntil
        -- Safe Tree: phần MẢNG (chuỗi tên trần) = giữ TOÀN BỘ (0); phần [tên]=N = giữ N cây.
        local st = lt["Safe Tree"]
        if type(st) == "table" then
            local safe = {}
            for k, v in pairs(st) do
                if type(k) == "number" and type(v) == "string" and v ~= "" then
                    safe[v] = 0
                elseif type(k) == "string" and k ~= "" then
                    safe[k] = tonumber(v) or 0
                end
            end
            sr.SafePlants = safe
        end
    end

    -- PlanQuota (mục 5,6): bảng quota DÙNG CHUNG cho trồng (AutoPlant) + cleanup (TrimToQuota) + GUI.
    if type(CFG.PlanQuota) == "table" and next(CFG.PlanQuota) then
        local ap = ensure("AutoPlant")
        ap.PlantQuota = CFG.PlanQuota
        ap.UsePlantQuota = true
        ensure("TrimToQuota").Quota = CFG.PlanQuota
    end
    -- Trim To Quota (mục 6): đào cây DƯ về quota. boolean = bật/tắt; table = chỉnh sâu (Limit/DestroyUntil hỗ trợ "%").
    local tq = CFG["Trim To Quota"]
    if type(tq) == "boolean" then
        ensure("TrimToQuota").Enabled = tq
    elseif type(tq) == "table" then
        local t = ensure("TrimToQuota")
        t.Enabled = tq.Enabled ~= false
        if tq.Quota ~= nil then t.Quota = tq.Quota end
        if tq["Limit"] ~= nil then t.Limit = tq["Limit"] end
        if tq["Destroy Untill"] ~= nil then t.DestroyUntil = tq["Destroy Untill"] end
        if tq["Destroy Until"] ~= nil then t.DestroyUntil = tq["Destroy Until"] end
        if tq.DestroyUntil ~= nil then t.DestroyUntil = tq.DestroyUntil end
        if tonumber(tq.MaxPerCycle) then t.MaxPerCycle = tonumber(tq.MaxPerCycle) end
        if type(tq.KeepMutations) == "table" then t.KeepMutations = tq.KeepMutations end
    end

    -- Seed.Buy (Auto=mua hết / Custom=mua theo list) + Seed.Place (Lock/Select hạt được trồng).
    if type(CFG.Seed) == "table" then
        local seed = CFG.Seed
        if type(seed.Buy) == "table" then
            local b = ensure("AutoBuySeed")
            b.Enabled = true
            if tostring(seed.Buy.Mode or "Auto"):lower() == "custom" then
                b.Mode = "List"
                b.List = type(seed.Buy.Custom) == "table" and seed.Buy.Custom or {}
            else
                b.Mode = "Smart"
            end
            -- Limit: số hạt tối đa SỞ HỮU mỗi loại (chung). Max = { [tên]=số } để cap riêng từng hạt.
            if tonumber(seed.Buy.Limit) then b.OwnLimit = tonumber(seed.Buy.Limit) end
            if type(seed.Buy.Max) == "table" then b.OwnLimitPerSeed = seed.Buy.Max end
        end
        if type(seed.Place) == "table" then
            local pl = ensure("AutoPlant")
            pl.Enabled = true
            if tostring(seed.Place.Mode or "Lock"):lower() == "select" then
                pl.OnlyPlant = type(seed.Place.Select) == "table" and seed.Place.Select or {}
            else
                local keep = ensure("KeepSeeds")
                keep.Enabled = true
                keep.List = type(seed.Place.Lock) == "table" and seed.Place.Lock or {}
            end
        end
    end

    -- Gear.Buy (mua theo list) + Gear.Lock (không mua/loại trừ).
    if type(CFG.Gear) == "table" then
        local g = ensure("AutoBuyGear")
        g.Enabled = true
        if type(CFG.Gear.Buy) == "table" and #CFG.Gear.Buy > 0 then
            g.Mode = "List"
            g.List = CFG.Gear.Buy
        end
        if type(CFG.Gear.Lock) == "table" then
            g.ExcludeList = CFG.Gear.Lock
        end
    end

    -- Pets.Buy: tame wild pet theo TÊN. Upgrade Slot: tự mua thêm ô pet.
    if type(CFG.Pets) == "table" then
        if type(CFG.Pets.Buy) == "table" then
            local t = ensure("AutoTameWildPet")
            local buy = CFG.Pets.Buy
            -- Dạng MAP { ["Tên"]=số } -> mua tới số đó (OwnLimit). Dạng LIST { "Tên" } -> mua không giới hạn số.
            local isMap = false
            for k in pairs(buy) do if type(k) == "string" then isMap = true break end end
            if isMap then
                t.OwnLimit = buy
                local names = {}
                for k in pairs(buy) do if type(k) == "string" then table.insert(names, k) end end
                t.PetNames = names
                t.Enabled = #names > 0
            else
                t.OwnLimit = nil
                t.PetNames = buy
                t.Enabled = #buy > 0
            end
        end
        if type(CFG.Pets["Upgrade Slot"]) == "boolean" then
            ensure("AutoPurchasePetSlot").Enabled = CFG.Pets["Upgrade Slot"]
        end
        -- Pets.Equip = { ["Tên pet"] = { soLuong, uuTien } }. Bung thành AutoEquipPet.List:
        -- xếp theo uuTien tăng dần (1 equip trước), mỗi pet lặp tên 'soLuong' lần.
        -- Dùng đúng List-mode có sẵn của AutoEquipPet (mỗi tên trong List = 1 lần equip).
        if type(CFG.Pets.Equip) == "table" then
            local arr = {}
            for name, spec in pairs(CFG.Pets.Equip) do
                if type(name) == "string" and name ~= "" and type(spec) == "table" then
                    local cnt = math.floor(tonumber(spec[1]) or 1)
                    local prio = tonumber(spec[2]) or 999
                    if cnt > 0 then
                        table.insert(arr, { name = name, count = cnt, prio = prio })
                    end
                end
            end
            table.sort(arr, function(a, b) return a.prio < b.prio end)
            local list = {}
            for _, e in ipairs(arr) do
                for _ = 1, e.count do
                    table.insert(list, e.name)
                end
            end
            if #list > 0 then
                local ep = ensure("AutoEquipPet")
                ep.Enabled = true
                ep.Mode = "List"
                ep.List = list
            end
        end
    end

    -- Automail: To + Seeds + Pets (theo tên). Claim mail luôn bật ngầm, loop mặc định.
    if type(CFG.Automail) == "table" then
        local am = CFG.Automail
        local to = type(am.To) == "string" and am.To ~= "" and am.To or nil
        ensure("AutoClaimMailbox").Enabled = true
        local sd2 = ensure("AutoMailSeeds")
        sd2.Enabled = type(am.Seeds) == "table" and #am.Seeds > 0
        if type(am.Seeds) == "table" then sd2.SeedNames = am.Seeds end
        if to then sd2.RecipientUsername = to end
        local pt = ensure("AutoMailPets")
        pt.Enabled = type(am.Pets) == "table" and #am.Pets > 0
        if type(am.Pets) == "table" then pt.PetNames = am.Pets end
        if to then pt.RecipientUsername = to end
        if to then ensure("AutoMailRainbow").RecipientUsername = to end
        -- Mail Fruits (trái cây): Fruits=true bật; Only Fruits=lọc tên; Min Fruits=đợi đủ; Instead Of Sell.
        local fr = ensure("AutoMailFruits")
        fr.Enabled = am.Fruits == true
        if to then fr.RecipientUsername = to end
        if am.Note ~= nil then fr.Note = am.Note end
        if type(am["Only Fruits"]) == "table" then fr.OnlyThese = am["Only Fruits"] end
        if tonumber(am["Min Fruits"]) then fr.MinFruits = tonumber(am["Min Fruits"]) end
        if type(am["Instead Of Sell"]) == "boolean" then fr.InsteadOfSell = am["Instead Of Sell"] end
    end

    -- Webhook: Url (rỗng = tắt) + Rarity (áp cho pet & seed báo về).
    if type(CFG.Webhook) == "table" then
        local w = CFG.Webhook
        if type(w.Url) == "string" then
            w.Enabled = w.Url ~= ""
        end
        if type(w.Rarity) == "string" and w.Rarity ~= "" then
            local vw = ensure("ValuableWatcher")
            vw.MinPetRarity = w.Rarity
            vw.NotifyHighPet = type(w.Url) == "string" and w.Url ~= ""
        end
    end

    -- ===== Các tính năng MỚI (gọn) =====
    -- Keep Money: SÀN tiền chung -> áp KeepSheckles cho mọi task tiêu tiền.
    local keepMoney = tonumber(CFG["Keep Money"])
    if keepMoney and keepMoney > 0 then
        for _, name in ipairs({ "AutoBuySeed", "AutoBuyGear", "AutoBuyCrate",
            "AutoExpandGarden", "AutoPurchasePetSlot", "AutoTameWildPet" }) do
            ensure(name).KeepSheckles = keepMoney
        end
    end
    -- Stop Buy Seed At: tiền >= mức này thì ngừng mua hạt.
    local stopBuy = tonumber(CFG["Stop Buy Seed At"])
    if stopBuy then ensure("AutoBuySeed").StopBuyAt = stopBuy end
    -- Anti AFK (chống treo máy)
    if type(CFG["Anti AFK"]) == "boolean" then ensure("AntiAfk").Enabled = CFG["Anti AFK"] end
    -- Codes: danh sách code -> AutoRedeemCode
    if type(CFG.Codes) == "table" then
        local rc = ensure("AutoRedeemCode")
        rc.List = CFG.Codes
        rc.Enabled = #CFG.Codes > 0
    end
    -- Wait Mutations: chỉ hái quả có mutation trong list
    if type(CFG["Wait Mutations"]) == "table" then
        ensure("AutoCollect").WaitForMutations = CFG["Wait Mutations"]
    end
    -- Gear.SprinklerStack: số sprinkler đặt chồng cùng vị trí
    if type(CFG.Gear) == "table" and tonumber(CFG.Gear.SprinklerStack) then
        ensure("AutoSprinkler").Stack = tonumber(CFG.Gear.SprinklerStack)
    end
    -- Pets: Max Slots / Unequip Others / Enable (công tắc tổng pet)
    if type(CFG.Pets) == "table" then
        if tonumber(CFG.Pets["Max Slots"]) then
            ensure("AutoPurchasePetSlot").MaxSlots = tonumber(CFG.Pets["Max Slots"])
        end
        if type(CFG.Pets["Unequip Others"]) == "boolean" then
            ensure("AutoEquipPet").UnequipOthers = CFG.Pets["Unequip Others"]
        end
        if CFG.Pets.Enable == false then
            for _, name in ipairs({ "AutoEquipPet", "AutoTameWildPet", "AutoHatchEgg",
                "AutoPurchasePetSlot", "AutoSnapPets" }) do
                ensure(name).Enabled = false
            end
        end
    end
end

setDefault(CFG, "ActionLogEnabled", true)

CFG.AutoBuySeed = CFG.AutoBuySeed or {}
setDefault(CFG.AutoBuySeed, "Enabled", true)
setDefault(CFG.AutoBuySeed, "Delay", 0.35)
setDefault(CFG.AutoBuySeed, "Mode", "Smart")
setDefault(CFG.AutoBuySeed, "MinRarity", "Common")
setDefault(CFG.AutoBuySeed, "KeepSheckles", 0)
setDefault(CFG.AutoBuySeed, "MaxPerSeedPerCycle", 50)
setDefault(CFG.AutoBuySeed, "List", {})

CFG.AutoPlant = CFG.AutoPlant or {}
setDefault(CFG.AutoPlant, "Enabled", true)
setDefault(CFG.AutoPlant, "Delay", 0.25)
setDefault(CFG.AutoPlant, "PlantPerSeed", 50)
setDefault(CFG.AutoPlant, "PauseWhenPlotFull", true)
-- LỘ TRÌNH TRỒNG (PlantQuota): mỗi loại seed chỉ trồng tối đa N cây trong plot.
-- Đếm cây đang trồng theo attribute SeedName của model trong plot.Plants (xác nhận kaitun.lua:4296).
-- Trồng nhiều cây xịn (cao cấp = 50), ít cây phổ thông (Carrot 10, đám common 4) -> tối ưu tiền.
-- Đủ quota thì KHÔNG trồng thêm loại đó (seed dư nằm lại trong túi). Bật/tắt bằng UsePlantQuota.
setDefault(CFG.AutoPlant, "UsePlantQuota", true)
setDefault(CFG.AutoPlant, "PlantQuota", {
    ["Carrot"] = 10,
    ["Strawberry"] = 4,
    ["Blueberry"] = 4,
    ["Tulip"] = 4,
    ["Tomato"] = 4,
    ["Apple"] = 4,
    ["Bamboo"] = 50,
    ["Corn"] = 4,
    ["Cactus"] = 4,
    ["Pineapple"] = 4,
    ["Mushroom"] = 50,
    ["Green Bean"] = 50,
    ["Banana"] = 50,
    ["Grape"] = 50,
    ["Coconut"] = 50,
    ["Mango"] = 50,
    ["Dragon Fruit"] = 50,
    ["Acorn"] = 50,
    ["Cherry"] = 50,
    ["Sunflower"] = 50,
    ["Venus Fly Trap"] = 50,
    ["Pomegranate"] = 50,
    ["Poison Apple"] = 50,
    ["Moon Bloom"] = 50,
    ["Dragon's Breath"] = 50,
})

CFG.AutoShovelReplace = CFG.AutoShovelReplace or {}
setDefault(CFG.AutoShovelReplace, "Enabled", false)
setDefault(CFG.AutoShovelReplace, "Delay", 5)
setDefault(CFG.AutoShovelReplace, "OnlyWhenPlotFull", true)
setDefault(CFG.AutoShovelReplace, "PlotFullCount", 0)
setDefault(CFG.AutoShovelReplace, "KeepMutations", { "Gold", "Rainbow" })
setDefault(CFG.AutoShovelReplace, "MaxReplacePerCycle", 1)
setDefault(CFG.AutoShovelReplace, "MinScoreGain", 1.0)
setDefault(CFG.AutoShovelReplace, "PlotFullSignalWindow", 30)
-- SAFE PLANT: [tên cây] = số cây tối thiểu LUÔN chừa lại khi đào. 0 = giữ TOÀN BỘ (không đào loại đó).
setDefault(CFG.AutoShovelReplace, "SafePlants", {
    ["Moon Bloom"] = 1,
    ["Dragon's Breath"] = 1,
    ["Venus Fly Trap"] = 1,
    ["Sunflower"] = 1,
    ["Cherry"] = 1,
    ["Pomegranate"] = 1,
    ["Poison Apple"] = 1,
})

CFG.AutoBuyGear = CFG.AutoBuyGear or {}
setDefault(CFG.AutoBuyGear, "Enabled", true)
setDefault(CFG.AutoBuyGear, "Delay", 0.5)
setDefault(CFG.AutoBuyGear, "Mode", "Smart")
setDefault(CFG.AutoBuyGear, "MinRarity", "Rare")
setDefault(CFG.AutoBuyGear, "KeepSheckles", 0)
setDefault(CFG.AutoBuyGear, "MaxPerItemPerCycle", 10)
setDefault(CFG.AutoBuyGear, "PrioritizeSprinklers", true)
setDefault(CFG.AutoBuyGear, "AllowPriorityBelowMinRarity", true)
setDefault(CFG.AutoBuyGear, "PriorityList", {
    "Super Sprinkler",
    "Legendary Sprinkler",
    "Rare Sprinkler",
    "Uncommon Sprinkler",
    "Common Sprinkler",
})
setDefault(CFG.AutoBuyGear, "ExcludeList", {
    "Jump Mushroom",
    "Speed Mushroom",
    "Shrink Mushroom",
})
setDefault(CFG.AutoBuyGear, "List", {})

CFG.AutoBuyCrate = CFG.AutoBuyCrate or {}
setDefault(CFG.AutoBuyCrate, "Enabled", true)
setDefault(CFG.AutoBuyCrate, "Delay", 0.5)
setDefault(CFG.AutoBuyCrate, "Mode", "Smart")
setDefault(CFG.AutoBuyCrate, "MinRarity", "Epic")
setDefault(CFG.AutoBuyCrate, "KeepSheckles", 0)
setDefault(CFG.AutoBuyCrate, "MaxPerItemPerCycle", 3)
setDefault(CFG.AutoBuyCrate, "List", {})

CFG.AutoEquipGear = CFG.AutoEquipGear or {}
setDefault(CFG.AutoEquipGear, "Enabled", false)
setDefault(CFG.AutoEquipGear, "Gear", "")

CFG.AutoCollect = CFG.AutoCollect or {}
setDefault(CFG.AutoCollect, "Enabled", true)
setDefault(CFG.AutoCollect, "Delay", 1)
setDefault(CFG.AutoCollect, "RemoteOnly", true)
setDefault(CFG.AutoCollect, "TeleportToFruit", false)
setDefault(CFG.AutoCollect, "TeleportDistance", 4)
setDefault(CFG.AutoCollect, "TeleportYOffset", 2)
setDefault(CFG.AutoCollect, "TeleportWait", 0.05)
setDefault(CFG.AutoCollect, "TriggerPromptFallback", false)
setDefault(CFG.AutoCollect, "MaxPerCycle", 120)
setDefault(CFG.AutoCollect, "MaxTeleportsPerCycle", 0)
setDefault(CFG.AutoCollect, "ReturnHomeAfterCollect", false)
setDefault(CFG.AutoCollect, "StayInGarden", true)
setDefault(CFG.AutoCollect, "BetweenCollect", 0.03)
setDefault(CFG.AutoCollect, "PauseWhenFull", true)
setDefault(CFG.AutoCollect, "PrioritizeValuable", true)
setDefault(CFG.AutoCollect, "TeleportToValuable", false)
setDefault(CFG.AutoCollect, "MaxValuableTeleports", 8)
setDefault(CFG.AutoCollect, "MinFruitScore", 0)
CFG.AutoCollect.RemoteOnly = true
CFG.AutoCollect.TeleportToFruit = false
CFG.AutoCollect.TriggerPromptFallback = false
CFG.AutoCollect.MaxTeleportsPerCycle = 0
CFG.AutoCollect.ReturnHomeAfterCollect = false

CFG.NightNotifier = CFG.NightNotifier or {}
setDefault(CFG.NightNotifier, "Enabled", true)
setDefault(CFG.NightNotifier, "ShowGui", true)
setDefault(CFG.NightNotifier, "LogChanges", true)
setDefault(CFG.NightNotifier, "BlockSellAtNight", true)

CFG.AntiSteal = CFG.AntiSteal or {}
setDefault(CFG.AntiSteal, "Enabled", true)
setDefault(CFG.AntiSteal, "Delay", 0.35)
setDefault(CFG.AntiSteal, "OnlyAtNight", true)
setDefault(CFG.AntiSteal, "EquipShovel", true)
setDefault(CFG.AntiSteal, "RequireShovel", true)
setDefault(CFG.AntiSteal, "TeleportToIntruder", true)
setDefault(CFG.AntiSteal, "TeleportDistance", 5)
setDefault(CFG.AntiSteal, "TeleportYOffset", 0)
setDefault(CFG.AntiSteal, "HitsPerTarget", 3)
setDefault(CFG.AntiSteal, "BetweenHits", 0.6)
setDefault(CFG.AntiSteal, "TargetCooldown", 0.5)
setDefault(CFG.AntiSteal, "ReturnAfterDefend", true)

CFG.Dashboard = CFG.Dashboard or {}
setDefault(CFG.Dashboard, "Enabled", true)
setDefault(CFG.Dashboard, "Visible", true)
setDefault(CFG.Dashboard, "ToggleKey", "RightShift")
setDefault(CFG.Dashboard, "RefreshRate", 0.5)
setDefault(CFG.Dashboard, "MaxLogs", 18)
CFG.Dashboard.MaxLogs = math.min(tonumber(CFG.Dashboard.MaxLogs) or 18, 24)

CFG.AutoStartGame = CFG.AutoStartGame or {}
setDefault(CFG.AutoStartGame, "Enabled", true)
setDefault(CFG.AutoStartGame, "Delay", 2)
setDefault(CFG.AutoStartGame, "MaxReadyFires", 8)
setDefault(CFG.AutoStartGame, "ForceLoadingAttributes", false)
setDefault(CFG.AutoStartGame, "FireTutorialReady", true)
setDefault(CFG.AutoStartGame, "TapToPlay", true)
setDefault(CFG.AutoStartGame, "TapClickCount", 5)
setDefault(CFG.AutoStartGame, "TapHold", 0.08)
setDefault(CFG.AutoStartGame, "UseVirtualInput", true)
setDefault(CFG.AutoStartGame, "UseTouchInput", true)
setDefault(CFG.AutoStartGame, "UseVirtualUser", false)
setDefault(CFG.AutoStartGame, "UseMouseFallback", false)
setDefault(CFG.AutoStartGame, "StopWhenReady", true)
setDefault(CFG.AutoStartGame, "ReadyStableSeconds", 3)
setDefault(CFG.AutoStartGame, "InitialGraceDelay", 0.5)
setDefault(CFG.AutoStartGame, "ForceLoadingAfter", 180)
setDefault(CFG.AutoStartGame, "FireReadyAfter", 0.5)
setDefault(CFG.AutoStartGame, "HideTapScreenAfter", 0)
setDefault(CFG.AutoStartGame, "ForceHideLoadingAfter", 0)
setDefault(CFG.AutoStartGame, "ForceTapWithoutText", false)
setDefault(CFG.AutoStartGame, "ForceOnlyAfterPrompt", false)
setDefault(CFG.AutoStartGame, "SkipOfflineCutscene", true)
setDefault(CFG.AutoStartGame, "OfflineSkipHold", 1.15)
CFG.AutoStartGame.ForceLoadingAttributes = false
CFG.AutoStartGame.ForceTapWithoutText = false
CFG.AutoStartGame.ForceHideLoadingAfter = 0

CFG.AutoSell = CFG.AutoSell or {}
setDefault(CFG.AutoSell, "Enabled", true)
setDefault(CFG.AutoSell, "Delay", 30)
setDefault(CFG.AutoSell, "DelayMax", 90)
setDefault(CFG.AutoSell, "TeleportToStevenBeforeSell", false)
setDefault(CFG.AutoSell, "TeleportDistance", 5)
setDefault(CFG.AutoSell, "TeleportWait", 0.75)
setDefault(CFG.AutoSell, "PostPreviewWait", 0.25)
setDefault(CFG.AutoSell, "PreSellWait", 0.5)
setDefault(CFG.AutoSell, "SellWhenFull", true)
setDefault(CFG.AutoSell, "FullThreshold", 0.95)
setDefault(CFG.AutoSell, "FullCheckDelay", 1)
setDefault(CFG.AutoSell, "UseDailyDeal", true)

CFG.AutoClaimMailbox = CFG.AutoClaimMailbox or {}
setDefault(CFG.AutoClaimMailbox, "Enabled", true)
setDefault(CFG.AutoClaimMailbox, "Delay", 10)
setDefault(CFG.AutoClaimMailbox, "MaxPerCycle", 20)

-- MAILBOX TUTORIAL GATE (mục 2): game chặn gift khi đang tutorial.
setDefault(CFG, "MailboxEnabled", true)          -- false = tắt cứng toàn bộ mailbox
setDefault(CFG, "AutoTutorialCheck", true)        -- true = thử bắn Tutorial.Complete khi đang tutorial
setDefault(CFG, "SkipMailboxIfTutorial", true)    -- true = bỏ qua mailbox khi chưa xong tutorial
-- TotalPlots (mục 1,4): tổng plots để tính %/hiển thị "Plants: x/total".
-- 0 = auto đếm part PlantArea (source KHÔNG có hằng số max cây thật -> chồng set số đúng của acc).
setDefault(CFG, "TotalPlots", 0)

-- TRIM TO QUOTA (mục 6): đào cây DƯ so với PlanQuota về đúng quota (KHÔNG xoá hết plot).
CFG.TrimToQuota = CFG.TrimToQuota or {}
setDefault(CFG.TrimToQuota, "Enabled", false)              -- mặc định TẮT (đào là mất vĩnh viễn)
setDefault(CFG.TrimToQuota, "Limit", 0)                     -- 0 = trim liên tục; "100%" hoặc số = chỉ trim khi tổng cây >= mức này
setDefault(CFG.TrimToQuota, "DestroyUntil", 0)             -- 0 = trim hết phần dư; "90%"/số = dừng khi tổng cây <= mức này
setDefault(CFG.TrimToQuota, "Delay", 8)
setDefault(CFG.TrimToQuota, "MaxPerCycle", 20)             -- mỗi vòng đào tối đa N cây
setDefault(CFG.TrimToQuota, "KeepMutations", { "Gold", "Rainbow" })

CFG.AutoSnapPets = CFG.AutoSnapPets or {}
setDefault(CFG.AutoSnapPets, "Enabled", true)
setDefault(CFG.AutoSnapPets, "Delay", 15)

CFG.AutoHatchEgg = CFG.AutoHatchEgg or {}
setDefault(CFG.AutoHatchEgg, "Enabled", true)
setDefault(CFG.AutoHatchEgg, "Delay", 0.5)

CFG.AutoEquipPet = CFG.AutoEquipPet or {}
setDefault(CFG.AutoEquipPet, "Enabled", true)
setDefault(CFG.AutoEquipPet, "Delay", 5)
setDefault(CFG.AutoEquipPet, "Mode", "Smart")
setDefault(CFG.AutoEquipPet, "List", {})
-- Smart: equip pet XỊN nhất trước (sort theo rarity*price). MinRarity = chỉ equip pet >= bậc này.
-- "Common" = equip mọi pet để lấp slot; đặt "Legendary" nếu chỉ muốn equip legendary+.
setDefault(CFG.AutoEquipPet, "MinRarity", "Common")
-- true: KHÔNG equip pet có tên trong AutoMailPets.PetNames -> để chúng nằm trong túi
-- (Equipped=false) cho AutoMailPets gửi đi. Pet đã equip thì game KHÔNG cho gift.
setDefault(CFG.AutoEquipPet, "SkipMailRarity", true)

setDefault(CFG.AutoSell, "SellAtNight", true)
setDefault(CFG.AutoSell, "ReturnHomeAfterSell", false)
CFG.AutoSell.TeleportToStevenBeforeSell = false
CFG.AutoSell.ReturnHomeAfterSell = false

CFG.AutoCollectDrops = CFG.AutoCollectDrops or {}
setDefault(CFG.AutoCollectDrops, "Enabled", true)
setDefault(CFG.AutoCollectDrops, "Delay", 0.5)
setDefault(CFG.AutoCollectDrops, "MaxPerCycle", 30)
setDefault(CFG.AutoCollectDrops, "TeleportDistance", 3)
setDefault(CFG.AutoCollectDrops, "TeleportYOffset", 2)
setDefault(CFG.AutoCollectDrops, "TeleportWait", 0.05)
setDefault(CFG.AutoCollectDrops, "IncludeSeedPackSpawns", true)
setDefault(CFG.AutoCollectDrops, "PrioritizeRainbowSeed", true)
setDefault(CFG.AutoCollectDrops, "SeedSpawnYOffset", 3)
setDefault(CFG.AutoCollectDrops, "SeedSpawnWait", 0.12)
setDefault(CFG.AutoCollectDrops, "SeedClaimNoPromptWait", 2.5)
setDefault(CFG.AutoCollectDrops, "SeedClaimHoldExtra", 0.35)
setDefault(CFG.AutoCollectDrops, "SeedClaimHoldExtraRainbow", 4)
setDefault(CFG.AutoCollectDrops, "SeedClaimHoldExtraGold", 4)
setDefault(CFG.AutoCollectDrops, "SeedClaimPostPromptWait", 1.5)
setDefault(CFG.AutoCollectDrops, "SeedClaimGrace", 0.5)
setDefault(CFG.AutoCollectDrops, "ReturnHomeAfterCollect", true)
setDefault(CFG.AutoCollectDrops, "FreezeDuringSeedClaim", true)
CFG.AutoCollectDrops.SeedClaimHoldExtraRainbow = math.max(tonumber(CFG.AutoCollectDrops.SeedClaimHoldExtraRainbow) or 0, 4)
CFG.AutoCollectDrops.SeedClaimHoldExtraGold = math.max(tonumber(CFG.AutoCollectDrops.SeedClaimHoldExtraGold) or 0, 4)

CFG.AutoWater = CFG.AutoWater or {}
setDefault(CFG.AutoWater, "Enabled", true)
setDefault(CFG.AutoWater, "Delay", 2)
setDefault(CFG.AutoWater, "PerCycle", 20)

CFG.AutoSprinkler = CFG.AutoSprinkler or {}
setDefault(CFG.AutoSprinkler, "Enabled", true)
setDefault(CFG.AutoSprinkler, "Delay", 0.5)
setDefault(CFG.AutoSprinkler, "PerCycle", 5)

CFG.AutoOpenCrate = CFG.AutoOpenCrate or {}
setDefault(CFG.AutoOpenCrate, "Enabled", true)
setDefault(CFG.AutoOpenCrate, "Delay", 0.5)

CFG.AutoOpenSeedPack = CFG.AutoOpenSeedPack or {}
setDefault(CFG.AutoOpenSeedPack, "Enabled", true)
setDefault(CFG.AutoOpenSeedPack, "Delay", 0.5)

CFG.AutoSpendSkill = CFG.AutoSpendSkill or {}
setDefault(CFG.AutoSpendSkill, "Enabled", true)
setDefault(CFG.AutoSpendSkill, "Delay", 0.3)
setDefault(CFG.AutoSpendSkill, "Priority", { "MaxBackpack", "ShovelPower", "BaseSpeed", "BaseJump" })

CFG.AutoExpandGarden = CFG.AutoExpandGarden or {}
setDefault(CFG.AutoExpandGarden, "Enabled", true)
setDefault(CFG.AutoExpandGarden, "Delay", 10)
setDefault(CFG.AutoExpandGarden, "KeepSheckles", 0)

CFG.AutoPurchasePetSlot = CFG.AutoPurchasePetSlot or {}
setDefault(CFG.AutoPurchasePetSlot, "Enabled", true)
setDefault(CFG.AutoPurchasePetSlot, "Delay", 15)
setDefault(CFG.AutoPurchasePetSlot, "KeepSheckles", 0)
setDefault(CFG.AutoPurchasePetSlot, "MaxSlots", 0)   -- 0 = mua tới max game; >0 = dừng ở số ô này

-- ===== Defaults cho các tính năng MỚI bổ sung =====
CFG.AutoRedeemCode = CFG.AutoRedeemCode or {}
setDefault(CFG.AutoRedeemCode, "Enabled", false)
setDefault(CFG.AutoRedeemCode, "Delay", 1.5)
setDefault(CFG.AutoRedeemCode, "List", {})
CFG.AntiAfk = CFG.AntiAfk or {}
setDefault(CFG.AntiAfk, "Enabled", true)             -- chống treo máy, mặc định BẬT
setDefault(CFG.AutoBuySeed, "StopBuyAt", 0)          -- 0 = không giới hạn trần tiền mua hạt
setDefault(CFG.AutoBuySeed, "OwnLimit", 0)           -- 0 = không cap số hạt sở hữu mỗi loại
setDefault(CFG.AutoEquipPet, "UnequipOthers", false) -- true = tháo pet ngoài List
setDefault(CFG.AutoSprinkler, "Stack", 1)            -- số sprinkler đặt chồng cùng vị trí
setDefault(CFG.AutoCollect, "WaitForMutations", {})  -- rỗng = hái hết
CFG.AutoMailFruits = CFG.AutoMailFruits or {}
setDefault(CFG.AutoMailFruits, "Enabled", false)
setDefault(CFG.AutoMailFruits, "InsteadOfSell", false) -- true = gửi quả thay vì bán
setDefault(CFG.AutoMailFruits, "MinFruits", 20)        -- đợi đủ bao nhiêu quả mới gửi
setDefault(CFG.AutoMailFruits, "MaxPerCycle", 20)
setDefault(CFG.AutoMailFruits, "Delay", 30)
setDefault(CFG.AutoMailFruits, "OnlyThese", {})        -- rỗng = mọi quả (trừ Keep Favorites)
setDefault(CFG.AutoMailFruits, "RecipientUserId", 0)

CFG.AutoTameWildPet = CFG.AutoTameWildPet or {}
setDefault(CFG.AutoTameWildPet, "Enabled", true)
setDefault(CFG.AutoTameWildPet, "Delay", 2)
setDefault(CFG.AutoTameWildPet, "MinRarity", "Legendary")
setDefault(CFG.AutoTameWildPet, "PriorityMinRarity", "Legendary")
setDefault(CFG.AutoTameWildPet, "PriorityYieldSeconds", 1.5)
setDefault(CFG.AutoTameWildPet, "KeepSheckles", 0)
setDefault(CFG.AutoTameWildPet, "MaxPerCycle", 3)
setDefault(CFG.AutoTameWildPet, "TeleportToPet", true)
setDefault(CFG.AutoTameWildPet, "TeleportDistance", 5)
setDefault(CFG.AutoTameWildPet, "TeleportYOffset", 1)
setDefault(CFG.AutoTameWildPet, "ReturnHomeAfterTame", true)

CFG.ESP = CFG.ESP or {}
setDefault(CFG.ESP, "ReadyPlants", false)
setDefault(CFG.ESP, "Players", false)
setDefault(CFG.ESP, "RefreshRate", 1)

CFG.FpsBoost = CFG.FpsBoost or {}
setDefault(CFG.FpsBoost, "Enabled", true)
setDefault(CFG.FpsBoost, "TargetFPS", 30)
setDefault(CFG.FpsBoost, "CapRefreshDelay", 1)  -- re-apply cap mỗi 1s để FPS đứng yên, không nhảy
setDefault(CFG.FpsBoost, "MuteAudio", true)
setDefault(CFG.FpsBoost, "DisableEffects", true)
setDefault(CFG.FpsBoost, "DisablePostEffects", true)

-- (AutoSteal đã bỏ theo yêu cầu - không liên quan)

-- ============================================================
-- SERVICES / REF  (đều check tồn tại, có log rõ ràng)
-- ============================================================
CFG.ClientLight = CFG.ClientLight or {}
setDefault(CFG.ClientLight, "Enabled", true)
setDefault(CFG.ClientLight, "Delay", 10)
setDefault(CFG.ClientLight, "HideOtherGardens", true)
setDefault(CFG.ClientLight, "DisableOtherGardenEffects", true)

CFG.LowFpsMode = CFG.LowFpsMode or {}
setDefault(CFG.LowFpsMode, "Enabled", true)
setDefault(CFG.LowFpsMode, "Threshold", 25)
setDefault(CFG.LowFpsMode, "CriticalThreshold", 15)
setDefault(CFG.LowFpsMode, "DelayMultiplier", 1.6)
setDefault(CFG.LowFpsMode, "CriticalDelayMultiplier", 2.4)
setDefault(CFG.LowFpsMode, "ImportantDelayMultiplier", 1.25)
setDefault(CFG.LowFpsMode, "MinDelay", 0.2)
setDefault(CFG.LowFpsMode, "StartupStagger", 0.12)
setDefault(CFG.LowFpsMode, "WatchdogDelay", 8)

CFG.Webhook = CFG.Webhook or {}
setDefault(CFG.Webhook, "Enabled", true)
setDefault(CFG.Webhook, "Url", "")
setDefault(CFG.Webhook, "Mention", "")
setDefault(CFG.Webhook, "Cooldown", 2)
setDefault(CFG.Webhook, "MaxQueue", 80)

CFG.ValuableWatcher = CFG.ValuableWatcher or {}
setDefault(CFG.ValuableWatcher, "Enabled", true)
setDefault(CFG.ValuableWatcher, "Delay", 2)
-- Báo pet từ Legendary trở lên (khớp ví dụ Robin = Legendary chồng muốn báo).
setDefault(CFG.ValuableWatcher, "MinPetRarity", "Legendary")
setDefault(CFG.ValuableWatcher, "NotifyHighPet", false)
setDefault(CFG.ValuableWatcher, "NotifyRainbowSeed", true)
setDefault(CFG.ValuableWatcher, "KeepRainbowSeed", true)
-- true: nhớ pet/seed đã báo XUỐNG FILE -> relog không gửi webhook trùng nữa.
setDefault(CFG.ValuableWatcher, "PersistSeen", true)
CFG.ValuableWatcher.NotifyHighPet = false

CFG.KeepSeeds = CFG.KeepSeeds or {}
setDefault(CFG.KeepSeeds, "Enabled", true)
setDefault(CFG.KeepSeeds, "List", { "Rainbow", "Gold", "Moon Bloom" })

CFG.AutoMailRainbow = CFG.AutoMailRainbow or {}
setDefault(CFG.AutoMailRainbow, "Enabled", true)
setDefault(CFG.AutoMailRainbow, "RecipientUsername", "chuideptrai1209")
setDefault(CFG.AutoMailRainbow, "RecipientUserId", 0)
setDefault(CFG.AutoMailRainbow, "Note", "chuideptraiqua")
setDefault(CFG.AutoMailRainbow, "SendCount", 1)
setDefault(CFG.AutoMailRainbow, "DelayBeforeSend", 30)
setDefault(CFG.AutoMailRainbow, "Delay", 30)
setDefault(CFG.AutoMailRainbow, "SkipResentKey", true)

CFG.AutoMailSeeds = CFG.AutoMailSeeds or {}
setDefault(CFG.AutoMailSeeds, "Enabled", true)
setDefault(CFG.AutoMailSeeds, "RecipientUsername", CFG.AutoMailRainbow.RecipientUsername or "chuideptrai1209")
setDefault(CFG.AutoMailSeeds, "RecipientUserId", tonumber(CFG.AutoMailRainbow.RecipientUserId) or 0)
setDefault(CFG.AutoMailSeeds, "Note", CFG.AutoMailRainbow.Note or "chuideptraiqua")
setDefault(CFG.AutoMailSeeds, "SeedNames", { "Rainbow" })
setDefault(CFG.AutoMailSeeds, "MaxPerBatch", 20)
setDefault(CFG.AutoMailSeeds, "DelayBeforeSend", 5)
setDefault(CFG.AutoMailSeeds, "Delay", 30)

-- Tự gửi pet SUPER + MYTHIC (rarity >= MinRarity) đang nằm TRONG TÚI (chưa equip) qua Mailbox.
-- Remote thật: Networking.Mailbox.SendBatch (Networking.lua:379).
-- item = { Category = "Pets", ItemKey = <petId>, Count = 1 } (MailboxController.lua:991-995).
-- Pet PHẢI chưa equip mới gift được (MailboxController.lua:650-659) -> AutoEquipPet.SkipMailRarity
-- để chúng ở lại túi. Super(7) > Mythic(6): MinRarity="Mythic" => gửi cả Mythic lẫn Super.
CFG.AutoMailPets = CFG.AutoMailPets or {}
setDefault(CFG.AutoMailPets, "Enabled", true)
setDefault(CFG.AutoMailPets, "RecipientUsername", "chuideptrai1209")
setDefault(CFG.AutoMailPets, "RecipientUserId", 0)
setDefault(CFG.AutoMailPets, "Note", "chuideptraiqua")
setDefault(CFG.AutoMailPets, "PetNames", { "Raccoon", })
setDefault(CFG.AutoMailPets, "MaxPerCycle", 2)
setDefault(CFG.AutoMailPets, "DelayBeforeSend", 5)
setDefault(CFG.AutoMailPets, "Delay", 30)
setDefault(CFG.AutoMailPets, "SkipResentKey", true)

CFG.RainbowAccountReport = CFG.RainbowAccountReport or {}
setDefault(CFG.RainbowAccountReport, "Enabled", false)  -- TẮT webhook Rainbow Seed Report
setDefault(CFG.RainbowAccountReport, "Username", "chuideptrai1209")
setDefault(CFG.RainbowAccountReport, "WebhookUrl", "")
setDefault(CFG.RainbowAccountReport, "Mention", "")
setDefault(CFG.RainbowAccountReport, "Interval", 60)

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local CollectionService  = game:GetService("CollectionService")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local HttpService        = game:GetService("HttpService")
local GuiService         = game:GetService("GuiService")
local VirtualInputManager
local VirtualUser
pcall(function()
    VirtualInputManager = game:GetService("VirtualInputManager")
end)
pcall(function()
    VirtualUser = game:GetService("VirtualUser")
end)

local LocalPlayer = Players.LocalPlayer

local function log(...)  print("[KAITUN]", ...) end
local function logw(...) warn("[KAITUN]", ...) end

local function isAlive()
    return Runtime.Active and getgenv()[RUNTIME_KEY] == Runtime
end

local function waitAlive(seconds)
    local finishAt = os.clock() + (seconds or 0)
    repeat
        if not isAlive() then
            return false
        end
        local remaining = finishAt - os.clock()
        if remaining <= 0 then
            break
        end
        task.wait(math.min(remaining, 0.25))
    until false
    return isAlive()
end

local State = {
    ActionLines = {},
    LastAction = "starting",
    LastSeedBuy = "-",
    LastSell = "-",
    LastCollect = "-",
    LastDrop = "-",
    LastCrate = "-",
    LastMailbox = "-",
    LastMailRainbow = "-",
    LastMailPets = "-",
    LastSnap = "-",
    LastClientLight = "-",
    LastWebhook = "-",
    LastValuable = "-",
    LastFps = "-",
    LastWatchdog = "-",
    LastPet = "-",
    LastStart = "-",
    LastShovelReplace = "-",
    LastAntiSteal = "-",
    LastIntruders = "-",
    IntruderCount = 0,
    SeedsBought = 0,
    FruitFill = "-",
    AntiStealEngaging = false,
    SellInProgress = false,
    SeedClaimInProgress = false,
    SeedClaimUntil = 0,
    PetTameInProgress = false,
    PetTameUntil = 0,
    DashboardVisible = CFG.Dashboard and CFG.Dashboard.Visible ~= false,
}

local ShortAction = {
    AutoBuySeed = "Seed",
    AutoPlant = "Plant",
    AutoShovelReplace = "Shovel",
    AutoBuyGear = "Gear",
    AutoBuyCrate = "BuyCrate",
    AutoEquipGear = "EqGear",
    AutoCollect = "Fruit",
    AutoCollectDrops = "Drop",
    AutoSell = "Sell",
    AutoHatchEgg = "Egg",
    AutoOpenCrate = "Crate",
    AutoOpenSeedPack = "Pack",
    AutoEquipPet = "EqPet",
    AutoTameWildPet = "Pet",
    AutoPurchasePetSlot = "PetSlot",
    AutoClaimMailbox = "Mail",
    AutoMailRainbow = "MailRB",
    AutoMailPets = "MailPet",
    AutoSnapPets = "SnapPet",
    ClientLight = "Lite",
    ValuableWatcher = "Watch",
    Webhook = "Hook",
    AutoSpendSkill = "Skill",
    AutoExpandGarden = "Garden",
    AutoWater = "Water",
    AutoSprinkler = "Sprinkler",
    AutoStartGame = "Start",
    AntiSteal = "Guard",
    Dashboard = "GUI",
    Night = "Night",
    FpsBoost = "FPS",
    FpsMonitor = "FPS",
    Watchdog = "Watch",
}

local ShortState = {
    START = "go",
    DONE = "ok",
    SKIP = "skip",
    BUY = "buy",
    PLAN = "plan",
    ERROR = "err",
    WARN = "warn",
    OPEN = "open",
    EQUIP = "equip",
    TELEPORTED = "tp",
    TELEPORT_FAILED = "tpFail",
    RETURN_HOME = "home",
    RETURNED = "home",
    SELL_RESULT = "sold",
    PAUSE_FULL = "full",
    FULL_TRIGGER = "full",
    NOTIFY_FULL = "full",
    DETECTED = "seen",
    HIT = "hit",
    HIT_FAIL = "miss",
    APPLIED = "on",
}

local function compactText(value, limit)
    local text = tostring(value)
    limit = tonumber(limit) or 120
    text = text:gsub("%s+", " ")
    if #text > limit then
        return text:sub(1, math.max(limit - 3, 1)) .. "..."
    end
    return text
end

local function buildActionLine(action, state, ...)
    local parts = {
        os.date("%H:%M:%S"),
        ShortAction[action] or tostring(action),
        ShortState[state] or tostring(state),
    }
    local count = select("#", ...)
    for i = 1, count do
        local item = select(i, ...)
        if item ~= nil and item ~= "" then
            table.insert(parts, compactText(item, 80))
        end
    end
    return compactText(table.concat(parts, " "), 140)
end

local function pushActionLine(action, state, ...)
    local line = buildActionLine(action, state, ...)
    State.LastAction = line
    table.insert(State.ActionLines, 1, line)
    local maxLogs = (CFG.Dashboard and tonumber(CFG.Dashboard.MaxLogs)) or 16
    while #State.ActionLines > math.max(maxLogs, 1) do
        table.remove(State.ActionLines)
    end
end

local function actionLog(action, state, ...)
    pushActionLine(action, state, ...)
    if CFG.ActionLogEnabled == false then
        return
    end
    print("[K]", buildActionLine(action, state, ...))
end

Runtime.ImportantLoopTasks = {
    AutoStartGame = true,
    AutoCollect = true,
    AutoCollectDrops = true,
    AutoSellFull = true,
    AutoSell = true,
    ValuableWatcher = true,
    AutoTameWildPet = true,
}

Runtime.DeferrableLowFpsTasks = {
    ESP = true,
    ClientLight = true,
    AutoSnapPets = true,
}

-- Task gửi/cập nhật webhook qua HTTP: PHẢI giữ đúng nhịp (vd RainbowReport mỗi 60s), KHÔNG
-- để LowFpsMode nhân delay lên (nếu không sẽ thành 96-144s -> "lúc gửi lúc không").
-- HTTP rất nhẹ, không ảnh hưởng FPS nên cho chạy đúng giờ kể cả khi FPS thấp.
Runtime.ExactDelayTasks = {
    RainbowReport = true,
    AutoMailRainbow = true,
    AutoMailPets = true,
}

Runtime.FpsModeLast = nil

Runtime.SetupFpsMonitor = function()
    local c = CFG.LowFpsMode
    if not (c and c.Enabled) then
        return
    end

    local avgFps = 60
    local function updateFps(dt)
        if not isAlive() then
            return
        end
        dt = tonumber(dt) or 0
        if dt <= 0 then
            return
        end

        local fps = math.clamp(1 / dt, 1, 240)
        avgFps = (avgFps * 0.9) + (fps * 0.1)
        local threshold = tonumber(c.Threshold) or 25
        local critical = tonumber(c.CriticalThreshold) or 15
        local mode = avgFps < critical and "critical" or (avgFps < threshold and "low" or "ok")

        State.Fps = avgFps
        State.LowFps = mode ~= "ok"
        State.CriticalFps = mode == "critical"
        State.LastFps = ("%dfps %s"):format(math.floor(avgFps + 0.5), mode)

        if mode ~= Runtime.FpsModeLast then
            Runtime.FpsModeLast = mode
            actionLog("FpsMonitor", "DONE", State.LastFps)
        end
    end

    local conn
    local ok = pcall(function()
        conn = RunService.RenderStepped:Connect(updateFps)
    end)
    if not ok or not conn then
        conn = RunService.Heartbeat:Connect(updateFps)
    end
    table.insert(Runtime.Cleanups, function()
        if conn then
            pcall(function() conn:Disconnect() end)
        end
    end)
end

Runtime.AdaptiveDelay = function(name, delay)
    local c = CFG.LowFpsMode
    delay = tonumber(delay) or 1
    if not (c and c.Enabled) then
        return delay
    end
    -- Task webhook giữ nhịp chính xác, không bị FPS thấp kéo dãn.
    if Runtime.ExactDelayTasks[name] then
        return delay
    end

    local multiplier = 1
    if State.CriticalFps then
        multiplier = Runtime.ImportantLoopTasks[name] and (tonumber(c.ImportantDelayMultiplier) or 1.25)
            or (tonumber(c.CriticalDelayMultiplier) or 2.4)
    elseif State.LowFps then
        multiplier = Runtime.ImportantLoopTasks[name] and 1
            or (tonumber(c.DelayMultiplier) or 1.6)
    end

    return math.max(delay * multiplier, tonumber(c.MinDelay) or 0.2)
end

Runtime.ShouldDeferForCriticalFps = function(name)
    return State.CriticalFps and Runtime.DeferrableLowFpsTasks[name] == true
end

local function summarizeResult(value)
    if type(value) ~= "table" then
        return tostring(value)
    end
    local parts = {}
    for _, key in ipairs({ "Success", "Reason", "FruitCount", "TotalValue", "SoldCount", "SellPrice" }) do
        if value[key] ~= nil then
            table.insert(parts, key .. "=" .. tostring(value[key]))
        end
    end
    if #parts == 0 then
        return "{table}"
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function getNightObject()
    local night = ReplicatedStorage:FindFirstChild("Night")
    if night and night:IsA("BoolValue") then
        return night
    end
    return nil
end

local function isNight()
    local night = getNightObject()
    return night and night.Value == true or false
end

-- Có đang bị chặn bán vì ban đêm không?
-- Mặc định AutoSell.SellAtNight = true (chồng cho bán đêm vì bán nhanh) -> KHÔNG chặn.
local function sellBlockedAtNight()
    if CFG.AutoSell and CFG.AutoSell.SellAtNight then
        return false
    end
    return CFG.NightNotifier and CFG.NightNotifier.BlockSellAtNight ~= false and isNight()
end

local function setupNightNotifier()
    local c = CFG.NightNotifier
    if not (c and c.Enabled) then
        return
    end

    local connections = {}
    local gui
    local label
    local lastState

    local function addConnection(conn)
        if conn then
            table.insert(connections, conn)
        end
        return conn
    end

    local function destroyGui()
        if gui then
            pcall(function()
                gui:Destroy()
            end)
            gui = nil
            label = nil
        end
    end

    local function ensureGui()
        if c.ShowGui == false then
            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
            local oldGui = playerGui and playerGui:FindFirstChild("NightNotifier")
            if oldGui then
                oldGui:Destroy()
            end
            destroyGui()
            return nil
        end
        if gui and gui.Parent then
            return label
        end

        local playerGui = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10)
        if not playerGui then
            return nil
        end

        local oldGui = playerGui:FindFirstChild("NightNotifier")
        if oldGui then
            oldGui:Destroy()
        end

        gui = Instance.new("ScreenGui")
        gui.Name = "NightNotifier"
        gui.ResetOnSpawn = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = playerGui

        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 230, 0, 50)
        frame.Position = UDim2.new(1, -240, 0, 10)
        frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        frame.BackgroundTransparency = 0.3
        frame.BorderSizePixel = 0
        frame.Parent = gui

        label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = "CHECKING NIGHT..."
        label.TextColor3 = Color3.new(1, 1, 1)
        label.TextScaled = true
        label.Font = Enum.Font.SourceSansBold
        label.Parent = frame

        return label
    end

    local function updateNight()
        local night = getNightObject()
        local nightKnown = night ~= nil
        local nightOn = nightKnown and night.Value == true or false
        local textLabel = ensureGui()

        if textLabel then
            if not nightKnown then
                textLabel.Text = "NIGHT VALUE MISSING"
                textLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
            elseif nightOn then
                textLabel.Text = (CFG.AutoSell and CFG.AutoSell.SellAtNight) and "NIGHT - SELL FAST" or "NIGHT - STAY HOME"
                textLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
            else
                textLabel.Text = "DAY - SELL OK"
                textLabel.TextColor3 = Color3.fromRGB(210, 210, 210)
            end
        end

        local state = nightKnown and (nightOn and "NIGHT" or "DAY") or "MISSING"
        if c.LogChanges ~= false and state ~= lastState then
            if nightOn then
                actionLog("Night", "NIGHT", (CFG.AutoSell and CFG.AutoSell.SellAtNight) and "sell ok" or "sell blocked")
            elseif nightKnown then
                actionLog("Night", "DAY", "AutoSell allowed")
            else
                actionLog("Night", "MISSING", "ReplicatedStorage.Night not found")
            end
            lastState = state
        end
    end

    local function bindNightObject(night)
        if not (night and night:IsA("BoolValue")) then
            return false
        end
        addConnection(night:GetPropertyChangedSignal("Value"):Connect(updateNight))
        updateNight()
        return true
    end

    if not bindNightObject(getNightObject()) then
        addConnection(ReplicatedStorage.ChildAdded:Connect(function(child)
            if child.Name == "Night" and child:IsA("BoolValue") then
                bindNightObject(child)
            end
        end))
        updateNight()
    end

    table.insert(Runtime.Cleanups, function()
        for _, conn in ipairs(connections) do
            pcall(function()
                conn:Disconnect()
            end)
        end
        destroyGui()
    end)
end

-- Lõi remote thật của game
local Networking
do
    local shared = ReplicatedStorage:WaitForChild("SharedModules", 10)
    if not shared then
        logw("Không thấy ReplicatedStorage.SharedModules -> dừng.")
        return
    end
    local netModule = shared:WaitForChild("Networking", 10)
    if not netModule then
        logw("Không thấy SharedModules.Networking -> dừng.")
        return
    end
    local ok, res = pcall(require, netModule)
    if not ok then
        logw("require(Networking) lỗi:", res)
        return
    end
    Networking = res
end

local SeedData
local GearShopData
local CrateData
local PetData
local PetSlotPrices
local ExpansionPrices
local PlayerStateClient
local FruitProxyUtil
do
    local shared = ReplicatedStorage:FindFirstChild("SharedModules")
    local sharedData = ReplicatedStorage:FindFirstChild("SharedData")
    local seedModule = shared and shared:FindFirstChild("SeedData")
    if seedModule then
        local ok, res = pcall(require, seedModule)
        if ok then
            SeedData = res
        else
            logw("require(SeedData) loi:", res)
        end
    else
        logw("Khong thay ReplicatedStorage.SharedModules.SeedData")
    end

    local gearModule = shared and shared:FindFirstChild("GearShopData")
    if gearModule then
        local ok, res = pcall(require, gearModule)
        if ok then
            GearShopData = res
        else
            logw("require(GearShopData) loi:", res)
        end
    else
        logw("Khong thay ReplicatedStorage.SharedModules.GearShopData")
    end

    local crateModule = shared and shared:FindFirstChild("CrateData")
    if crateModule then
        local ok, res = pcall(require, crateModule)
        if ok then
            CrateData = res
        else
            logw("require(CrateData) loi:", res)
        end
    else
        logw("Khong thay ReplicatedStorage.SharedModules.CrateData")
    end

    local petModule = sharedData and sharedData:FindFirstChild("PetData")
    if petModule then
        local ok, res = pcall(require, petModule)
        if ok then
            PetData = res
        else
            logw("require(PetData) loi:", res)
        end
    else
        logw("Khong thay ReplicatedStorage.SharedData.PetData")
    end

    local petSlotModule = sharedData and sharedData:FindFirstChild("PetSlotPrices")
    if petSlotModule then
        local ok, res = pcall(require, petSlotModule)
        if ok then
            PetSlotPrices = res
        else
            logw("require(PetSlotPrices) loi:", res)
        end
    else
        logw("Khong thay ReplicatedStorage.SharedData.PetSlotPrices")
    end

    local expansionModule = sharedData and sharedData:FindFirstChild("ExpansionPrices")
    if expansionModule then
        local ok, res = pcall(require, expansionModule)
        if ok then
            ExpansionPrices = res
        else
            logw("require(ExpansionPrices) loi:", res)
        end
    else
        logw("Khong thay ReplicatedStorage.SharedData.ExpansionPrices")
    end

    local fruitProxyModule = shared and shared:FindFirstChild("FruitProxyUtil")
    if fruitProxyModule then
        local ok, res = pcall(require, fruitProxyModule)
        if ok then
            FruitProxyUtil = res
        else
            logw("require(FruitProxyUtil) loi:", res)
        end
    else
        logw("Khong thay ReplicatedStorage.SharedModules.FruitProxyUtil")
    end

    -- Công thức GIÁ BÁN thật của game (xác nhận Sell_Steven.lua / StealController.lua):
    -- FruitValueCalc(FruitName, SizeMultiplier, Mutation, player, DecayAlpha). Module trả về 1 hàm.
    -- Dùng để AutoCollect ưu tiên hái quả ĐÁNG TIỀN trước (gắn Runtime để khỏi tốn local mới).
    local fruitValueModule = shared and shared:FindFirstChild("FruitValueCalc")
    if fruitValueModule then
        local ok, res = pcall(require, fruitValueModule)
        if ok and type(res) == "function" then
            Runtime.FruitValueCalc = res
        else
            logw("require(FruitValueCalc) loi:", res)
        end
    else
        logw("Khong thay ReplicatedStorage.SharedModules.FruitValueCalc")
    end

    local clientModules = ReplicatedStorage:FindFirstChild("ClientModules")
    local stateModule = clientModules and clientModules:FindFirstChild("PlayerStateClient")
    if stateModule then
        local ok, res = pcall(require, stateModule)
        if ok then
            PlayerStateClient = res
        else
            logw("require(PlayerStateClient) loi:", res)
        end
    else
        logw("Khong thay ReplicatedStorage.ClientModules.PlayerStateClient")
    end
end

-- Kiểm tra 1 packet tồn tại trước khi Fire (chống bịa / chống nil)
local function packet(path)
    local node = Networking
    for _, key in ipairs(path) do
        if type(node) ~= "table" then return nil end
        node = node[key]
    end
    return node
end

local function firePacket(path, ...)
    local p = packet(path)
    if not p or type(p.Fire) ~= "function" then
        logw("Thiếu remote:", table.concat(path, "."))
        return false
    end
    local ok, res = pcall(function(...) return p:Fire(...) end, ...)
    if not ok then
        logw("Fire lỗi", table.concat(path, "."), "->", res)
        return false
    end
    return true, res
end

Runtime.AutoStartReadyFires = 0
Runtime.AutoStartTapAttempts = 0
Runtime.AutoStartHiddenGuis = {}
Runtime.AutoStartWaitingLogged = false

local function getViewportCenter()
    local camera = workspace.CurrentCamera
    local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local inset = Vector2.new(0, 0)
    pcall(function()
        inset = GuiService:GetGuiInset()
    end)
    return math.floor(size.X * 0.5), math.floor(size.Y * 0.5 + inset.Y * 0.5)
end

Runtime.AddTapPoint = function(points, seen, x, y, label)
    x = tonumber(x)
    y = tonumber(y)
    if not (x and y) then return end
    x = math.floor(x)
    y = math.floor(y)
    local key = tostring(x) .. ":" .. tostring(y)
    if seen[key] then return end
    seen[key] = true
    table.insert(points, { X = x, Y = y, Label = label or "p" })
end

Runtime.GetTapPoints = function(targetGui)
    local camera = workspace.CurrentCamera
    local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local inset = Vector2.new(0, 0)
    pcall(function()
        inset = GuiService:GetGuiInset()
    end)

    local points = {}
    local seen = {}
    Runtime.AddTapPoint(points, seen, size.X * 0.5, size.Y * 0.5, "center")
    Runtime.AddTapPoint(points, seen, size.X * 0.5, size.Y * 0.5 + inset.Y, "center-inset")
    Runtime.AddTapPoint(points, seen, size.X * 0.5, size.Y * 0.62, "lower")

    if targetGui and targetGui:IsA("GuiObject") then
        local ok, pos, absSize = pcall(function()
            return targetGui.AbsolutePosition, targetGui.AbsoluteSize
        end)
        if ok and pos and absSize then
            Runtime.AddTapPoint(points, seen, pos.X + absSize.X * 0.5, pos.Y + absSize.Y * 0.5, "label")
        end
    end
    return points
end

Runtime.TapGuiButton = function(targetGui)
    if not (targetGui and targetGui:IsA("GuiButton")) then
        return false, nil
    end
    local ok = pcall(function()
        targetGui:Activate()
    end)
    return ok, ok and "activate" or nil
end

Runtime.SendTapAt = function(x, y, hold, c)
    hold = math.max(tonumber(hold) or 0.06, 0.03)
    c = type(c) == "table" and c or {}
    local okAny = false
    local used = {}

    if c.UseVirtualInput ~= false and VirtualInputManager and type(VirtualInputManager.SendMouseButtonEvent) == "function" then
        local ok = pcall(function()
            if type(VirtualInputManager.SendMouseMoveEvent) == "function" then
                pcall(function()
                    VirtualInputManager:SendMouseMoveEvent(x, y, game)
                end)
            end
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
            task.wait(hold)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
            task.wait(0.02)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
            task.wait(hold)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
        end)
        if ok then
            okAny = true
            table.insert(used, "vim")
        end
    end

    if c.UseTouchInput ~= false and VirtualInputManager and type(VirtualInputManager.SendTouchEvent) == "function" then
        local touchOk = false
        touchOk = pcall(function()
            VirtualInputManager:SendTouchEvent(0, Enum.UserInputState.Begin, x, y)
            task.wait(hold)
            VirtualInputManager:SendTouchEvent(0, Enum.UserInputState.End, x, y)
        end)
        if not touchOk then
            touchOk = pcall(function()
                VirtualInputManager:SendTouchEvent(x, y, Enum.UserInputState.Begin, game)
                task.wait(hold)
                VirtualInputManager:SendTouchEvent(x, y, Enum.UserInputState.End, game)
            end)
        end
        if not touchOk then
            touchOk = pcall(function()
                VirtualInputManager:SendTouchEvent(x, y, 0, true, game)
                task.wait(hold)
                VirtualInputManager:SendTouchEvent(x, y, 0, false, game)
            end)
        end
        if touchOk then
            okAny = true
            table.insert(used, "touch")
        end
    end

    if c.UseVirtualUser == true and VirtualUser and type(VirtualUser.Button1Down) == "function" and type(VirtualUser.Button1Up) == "function" then
        local ok = pcall(function()
            local camera = workspace.CurrentCamera
            local cf = camera and camera.CFrame or CFrame.new()
            VirtualUser:Button1Down(Vector2.new(x, y), cf)
            task.wait(hold)
            VirtualUser:Button1Up(Vector2.new(x, y), cf)
        end)
        if ok then
            okAny = true
            table.insert(used, "vu")
        end
    end

    if c.UseMouseFallback == true then
        if type(mousemoveabs) == "function" then
            pcall(mousemoveabs, x, y)
        end
        if type(mouse1press) == "function" and type(mouse1release) == "function" then
            local ok = pcall(function()
                mouse1press()
                task.wait(hold)
                mouse1release()
            end)
            if ok then
                okAny = true
                table.insert(used, "mouse")
            end
        elseif type(mouse1click) == "function" then
            local ok = pcall(mouse1click)
            if ok then
                okAny = true
                table.insert(used, "mouse")
            end
        end
    end

    return okAny, table.concat(used, "+")
end

Runtime.VirtualTapCenter = function(times, targetGui, c)
    times = math.max(tonumber(times) or 1, 1)
    local points = Runtime.GetTapPoints(targetGui)
    local hold = tonumber(c and c.TapHold) or 0.08
    local okAny = false
    local used = {}

    local okActivate, activateNote = Runtime.TapGuiButton(targetGui)
    if okActivate then
        okAny = true
        table.insert(used, activateNote)
    end

    for i = 1, times do
        for _, point in ipairs(points) do
            local okTap, tapMethod = Runtime.SendTapAt(point.X, point.Y, hold, c)
            if okTap then
                okAny = true
                table.insert(used, point.Label .. ":" .. tapMethod)
            end
            task.wait(0.04)
        end
        task.wait(0.08)
        if i >= 2 and okAny then
            break
        end
    end

    if not okAny then
        return false, "tap failed"
    end
    local x, y = getViewportCenter()
    return true, ("tap=%s,%s x%s %s"):format(tostring(x), tostring(y), tostring(times), compactText(table.concat(used, ","), 70))
end

local function isTapToPlayText(text)
    text = string.lower(tostring(text or ""))
    if text == "" then
        return false
    end
    if string.find(text, "tap anywhere", 1, true) then
        return true
    end
    return string.find(text, "tap", 1, true) and string.find(text, "play", 1, true)
end

local function findTapToPlayGui()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return nil, nil
    end

    local loadingGui = playerGui:FindFirstChild("LoadingGui")
    -- CHỐT CHÍNH chống chiếm chuột: LoadingGui phải CÒN ĐANG HIỆN (Enabled) mới tap.
    -- Trước đây chỉ cần còn CHỮ "tap to play" là tap -> dù đã vào game vẫn bấm chuột hoài.
    local loadingShown = loadingGui and loadingGui:IsA("ScreenGui") and loadingGui.Enabled ~= false
    local variant = loadingGui and loadingGui:FindFirstChild("Variant1Frame")
    local inner = variant and variant:FindFirstChild("InnerFrame")
    if loadingShown and inner then
        local pressAny = inner:FindFirstChild("PressAnyTxt")
        local counter = inner:FindFirstChild("CounterTxt")
        local skip = inner:FindFirstChild("SkipTxt")
        -- label tap phải CÒN VISIBLE thì mới coi là cần tap
        local function visibleTap(lbl)
            return lbl and lbl:IsA("TextLabel") and lbl.Visible ~= false and isTapToPlayText(lbl.Text)
        end
        local hit = (visibleTap(pressAny) and pressAny)
            or (visibleTap(counter) and counter)
            or (visibleTap(skip) and skip)
        if hit then
            return loadingGui, hit.Text, hit
        end
    end

    if loadingShown then
        local c = CFG.AutoStartGame or {}
        local forceAfter = tonumber(c.ForceHideLoadingAfter) or 8
        if c.ForceTapWithoutText ~= false and forceAfter > 0 and os.clock() - Runtime.StartedAt >= forceAfter then
            return loadingGui, "LoadingGui force", inner or loadingGui
        end
    end

    for _, obj in ipairs(playerGui:GetDescendants()) do
        -- chỉ tap label CÒN VISIBLE và nằm trong ScreenGui CÒN Enabled (bỏ GUI đã ẩn)
        if (obj:IsA("TextLabel") or obj:IsA("TextButton"))
            and obj.Visible ~= false
            and isTapToPlayText(obj.Text) then
            local screenGui = obj:FindFirstAncestorWhichIsA("ScreenGui")
            if screenGui and screenGui.Enabled ~= false
                and screenGui.Name ~= "KaitunDashboard"
                and screenGui.Name ~= "NightNotifier" then
                return screenGui, obj.Text, obj
            end
        end
    end
    return nil, nil
end

Runtime.IsGameReadyForAutomation = function(c)
    c = type(c) == "table" and c or (CFG.AutoStartGame or {})
    if LocalPlayer:GetAttribute("OfflineCutscenePlaying") == true then
        Runtime.GameReadySince = nil
        return false, "offline cutscene"
    end
    if LocalPlayer:GetAttribute("LoadingScreenActive") == true then
        Runtime.GameReadySince = nil
        return false, "loading active"
    end
    if LocalPlayer:GetAttribute("LoadingScreenDone") ~= true then
        Runtime.GameReadySince = nil
        return false, "loading not done"
    end

    local stableFor = math.max(tonumber(c.ReadyStableSeconds) or 3, 0)
    Runtime.GameReadySince = Runtime.GameReadySince or os.clock()
    local elapsed = os.clock() - Runtime.GameReadySince
    if elapsed < stableFor then
        return false, ("ready stable %.1fs/%.1fs"):format(elapsed, stableFor)
    end
    return true, "ready"
end

local function doTapToPlayBypass(c)
    if not (c and c.TapToPlay ~= false) then
        return false, nil
    end
    local ready = Runtime.IsGameReadyForAutomation(c)
    if ready then
        return false, nil
    end

    local screenGui, text, targetGui = findTapToPlayGui()
    if not screenGui then
        return false, nil
    end

    Runtime.AutoStartPromptSeen = true
    Runtime.AutoStartTapAttempts = (Runtime.AutoStartTapAttempts or 0) + 1
    local okTap, tapNote = Runtime.VirtualTapCenter(tonumber(c.TapClickCount) or 5, targetGui, c)
    local notes = { "screen=" .. tostring(screenGui.Name), "text=" .. compactText(text, 40), tostring(tapNote) }

    local hideAfter = tonumber(c.HideTapScreenAfter) or 0
    local forceAfter = tonumber(c.ForceHideLoadingAfter) or 0
    local forceHide = forceAfter > 0 and os.clock() - Runtime.StartedAt >= forceAfter
    local shouldHideByAttempts = hideAfter > 0 and Runtime.AutoStartTapAttempts >= hideAfter
    if (shouldHideByAttempts or forceHide) and not Runtime.AutoStartHiddenGuis[screenGui] then
        local okHide = pcall(function()
            screenGui.Enabled = false
        end)
        if okHide then
            Runtime.AutoStartHiddenGuis[screenGui] = true
            table.insert(notes, "hide=true")
        end
    end

    return okTap or Runtime.AutoStartHiddenGuis[screenGui] == true, table.concat(notes, " ")
end

-- Màn 2 của loading: "Hold to skip" (PlayerGui.OfflineAnimation - chiếu lại cây mọc
-- khi offline). Source: OfflineGrowthAnimationController - giữ MouseButton1/Touch,
-- khi (os.clock()-start)/1 >= 1 thì isSkipRequested=true -> break cutscene.
-- => giả lập GIỮ chuột ~1.15s giữa màn để skip.
local function doOfflineCutsceneSkip(c)
    if c.SkipOfflineCutscene == false then
        return false
    end
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local anim = playerGui and playerGui:FindFirstChild("OfflineAnimation")
    local playing = LocalPlayer:GetAttribute("OfflineCutscenePlaying") == true
    if not (anim or playing) then
        return false
    end
    -- chống spam: chỉ hold lại sau mỗi ~2s
    local now = os.clock()
    if (tonumber(Runtime.OfflineSkipLastAt) or 0) + 2 > now then
        return false
    end
    Runtime.OfflineSkipLastAt = now
    local x, y = getViewportCenter()
    -- giữ > 1s để thanh HoldProgressBar đầy (game chia cho 1 giây)
    local hold = math.max(tonumber(c.OfflineSkipHold) or 1.15, 1.05)
    local ok = Runtime.SendTapAt(x, y, hold, c)
    actionLog("AutoStartGame", ok and "DONE" or "SKIP", "offline hold-skip")
    return ok
end

local function doAutoStartGame()
    local c = CFG.AutoStartGame
    if not (c and c.Enabled) then
        return
    end
    if Runtime.AutoStartCompleted then
        return
    end

    local age = os.clock() - Runtime.StartedAt
    local grace = tonumber(c.InitialGraceDelay) or 5
    if age < grace then
        State.LastStart = ("wait %.1fs"):format(math.max(grace - age, 0))
        if not Runtime.AutoStartWaitingLogged then
            Runtime.AutoStartWaitingLogged = true
            actionLog("AutoStartGame", "SKIP", State.LastStart)
        end
        return
    end

    local changed = false
    local notes = {}

    local ready, readyNote = Runtime.IsGameReadyForAutomation(c)
    if ready then
        Runtime.AutoStartCompleted = true
        State.LastStart = os.date("%H:%M:%S") .. " ready"
        actionLog("AutoStartGame", "DONE", "game ready; stop input")
        if c.StopWhenReady ~= false then
            c.Enabled = false
        end
        return
    elseif readyNote then
        State.LastStart = os.date("%H:%M:%S") .. " " .. tostring(readyNote)
    end

    local tapped, tapNote = doTapToPlayBypass(c)
    if tapped then
        changed = true
        table.insert(notes, tapNote or "tap")
    elseif not Runtime.AutoStartPromptSeen then
        State.LastStart = os.date("%H:%M:%S") .. " wait prompt"
    end

    -- Màn 2: "Hold to skip" cutscene cây mọc offline -> giữ chuột để skip
    if doOfflineCutsceneSkip(c) then
        changed = true
        table.insert(notes, "offlineSkip")
    end

    -- Source-confirmed gates:
    -- TutorialController waits for LocalPlayer.LoadingScreenDone before Tutorial.Ready.
    -- Egg/Inventory/Plots skip actions while LocalPlayer.LoadingScreenActive is true.
    local forceLoadingAfter = tonumber(c.ForceLoadingAfter) or 9
    local promptReady = Runtime.AutoStartPromptSeen == true or c.ForceOnlyAfterPrompt == false
    if c.ForceLoadingAttributes ~= false and promptReady and age >= forceLoadingAfter then
        if LocalPlayer:GetAttribute("LoadingScreenActive") == true then
            local ok = pcall(function()
                LocalPlayer:SetAttribute("LoadingScreenActive", false)
            end)
            if ok then
                changed = true
                table.insert(notes, "active=false")
            end
        end
        if LocalPlayer:GetAttribute("LoadingScreenDone") ~= true then
            local ok = pcall(function()
                LocalPlayer:SetAttribute("LoadingScreenDone", true)
            end)
            if ok then
                changed = true
                table.insert(notes, "done=true")
            end
        end
    end

    local maxReady = tonumber(c.MaxReadyFires) or 8
    local fireReadyAfter = tonumber(c.FireReadyAfter) or forceLoadingAfter
    local loadingDone = LocalPlayer:GetAttribute("LoadingScreenDone") == true
    if c.FireTutorialReady ~= false and promptReady and loadingDone and age >= fireReadyAfter and Runtime.AutoStartReadyFires < maxReady then
        if firePacket({ "Tutorial", "Ready" }) then
            Runtime.AutoStartReadyFires = Runtime.AutoStartReadyFires + 1
            changed = true
            table.insert(notes, "ready=" .. tostring(Runtime.AutoStartReadyFires))
        end
    end

    if changed then
        local text = table.concat(notes, " ")
        State.LastStart = text
        actionLog("AutoStartGame", "DONE", text)
    end
end

-- ============================================================
-- HELPER: tiền, plot, ô trồng, túi đồ
-- ============================================================
local function getSheckles()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if not ls then return nil end
    local s = ls:FindFirstChild("Sheckles")
    return s and s.Value or nil
end

local RarityScore = {
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Epic = 4,
    Legendary = 5,
    Mythic = 6,
    Super = 7,
    Secret = 8,
}

local SeedPurchaseAssumed = {
    RestockKey = nil,
    Counts = {},
}

local function getPlayerReplica()
    if not PlayerStateClient then
        return nil
    end
    local ok, replica = pcall(function()
        return PlayerStateClient:GetLocalReplica() or PlayerStateClient:WaitForLocalReplica(1)
    end)
    if ok then
        return replica
    end
    return nil
end

local function getSeedShop()
    local stockValues = ReplicatedStorage:FindFirstChild("StockValues")
    return stockValues and stockValues:FindFirstChild("SeedShop")
end

local function getSeedRestockKey()
    local seedShop = getSeedShop()
    local lastRestock = seedShop and seedShop:FindFirstChild("UnixLastRestock")
    if not lastRestock then
        return "unknown"
    end
    local ok, value = pcall(function()
        return lastRestock.Value
    end)
    return ok and tostring(value) or "unknown"
end

local function resetSeedAssumptionsIfNeeded()
    local restockKey = getSeedRestockKey()
    if SeedPurchaseAssumed.RestockKey ~= restockKey then
        SeedPurchaseAssumed.RestockKey = restockKey
        SeedPurchaseAssumed.Counts = {}
    end
end

local function getSeedDataByName(seedName)
    if type(SeedData) ~= "table" then
        return nil
    end
    for _, data in ipairs(SeedData) do
        if type(data) == "table" and data.SeedName == seedName then
            return data
        end
    end
    return nil
end

local function getPurchasedSeedCount(seedName)
    local replica = getPlayerReplica()
    local data = replica and replica.Data
    local purchased = data and data.PurchasedThisRestock
    local seeds = purchased and purchased.Seeds
    if not seeds then
        return nil
    end
    return tonumber(seeds[seedName]) or 0
end

local function getSeedStockValue(seedName)
    local seedShop = getSeedShop()
    local items = seedShop and seedShop:FindFirstChild("Items")
    local item = items and items:FindFirstChild(seedName)
    if not item then
        return nil
    end
    local ok, value = pcall(function()
        return item.Value
    end)
    if not ok then
        return nil
    end
    return tonumber(value)
end

local function getRemainingSeedStock(seedName)
    resetSeedAssumptionsIfNeeded()
    local maxStock = getSeedStockValue(seedName)
    local purchased = getPurchasedSeedCount(seedName)
    if maxStock == nil then
        return nil, maxStock, purchased
    end
    purchased = purchased or 0
    local assumed = SeedPurchaseAssumed.Counts[seedName] or 0
    return math.max(maxStock - purchased - assumed, 0), maxStock, purchased
end

local function noteSeedPurchase(seedName)
    resetSeedAssumptionsIfNeeded()
    SeedPurchaseAssumed.Counts[seedName] = (SeedPurchaseAssumed.Counts[seedName] or 0) + 1
end

local function rarityAllowed(rarity, minRarity)
    return (RarityScore[rarity] or 0) >= (RarityScore[minRarity or "Common"] or 1)
end

local function buildSeedCandidates(c)
    local out = {}
    if type(SeedData) ~= "table" then
        return out, "missing SeedData"
    end
    local money = tonumber(getSheckles()) or 0
    local keep = tonumber(c.KeepSheckles) or 0
    local budget = math.max(money - keep, 0)
    local minRarity = c.MinRarity or "Common"

    for _, data in ipairs(SeedData) do
        if type(data) == "table" and data.RestockShop and type(data.SeedName) == "string" then
            local price = tonumber(data.PurchasePrice)
            local rarity = tostring(data.Rarity or "")
            if price and price <= budget and rarityAllowed(rarity, minRarity) then
                local remaining = getRemainingSeedStock(data.SeedName)
                if remaining and remaining > 0 then
                    table.insert(out, {
                        Name = data.SeedName,
                        Price = price,
                        Rarity = rarity,
                        RarityScore = RarityScore[rarity] or 0,
                        Order = tonumber(data.SeedShopDisplayOrder) or 0,
                        Stock = remaining,
                    })
                end
            end
        end
    end

    table.sort(out, function(a, b)
        if a.RarityScore ~= b.RarityScore then
            return a.RarityScore > b.RarityScore
        end
        if a.Order ~= b.Order then
            return a.Order > b.Order
        end
        return a.Price > b.Price
    end)

    return out
end

local function getPlot()
    local id = LocalPlayer:GetAttribute("PlotId")
    if not id then return nil end
    local gardens = workspace:FindFirstChild("Gardens")
    if not gardens then return nil end
    return gardens:FindFirstChild("Plot" .. tostring(id))
end

-- Lấy danh sách part "PlantArea" thuộc plot mình (xác nhận ở SprinklerController/PlantController)
local function getPlantAreaParts()
    local plot = getPlot()
    if not plot then return {} end
    local parts = {}
    for _, part in ipairs(plot:GetDescendants()) do
        if part:IsA("BasePart") and CollectionService:HasTag(part, "PlantArea") then
            table.insert(parts, part)
        end
    end
    return parts
end

-- Một điểm Vector3 ngẫu nhiên trên mặt 1 ô PlantArea (để gửi vào PlantSeed)
local function randomPlantPosition()
    local parts = getPlantAreaParts()
    if #parts == 0 then return nil end
    local part = parts[math.random(1, #parts)]
    local half = part.Size * 0.5
    local offX = (math.random() * 2 - 1) * (half.X * 0.85)
    local offZ = (math.random() * 2 - 1) * (half.Z * 0.85)
    -- điểm trên mặt trên của ô, đưa về world-space
    local localPoint = Vector3.new(offX, half.Y, offZ)
    return part.CFrame:PointToWorldSpace(localPoint)
end

local function getCharacter()
    return LocalPlayer.Character
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- Lấy mọi Tool (cả Backpack lẫn đang cầm) thỏa điều kiện attr
local function getToolsWithAttribute(attrName)
    local out = {}
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and t:GetAttribute(attrName) ~= nil then
                table.insert(out, t)
            end
        end
    end
    local char = getCharacter()
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and t:GetAttribute(attrName) ~= nil then
                table.insert(out, t)
            end
        end
    end
    return out
end

local function isFruitTool(tool)
    if not (tool and tool:IsA("Tool")) then
        return false
    end
    if FruitProxyUtil and type(FruitProxyUtil.IsFruitTool) == "function" then
        local ok, res = pcall(FruitProxyUtil.IsFruitTool, tool)
        if ok then
            return res == true
        end
    end
    return tool:GetAttribute("HarvestedFruit") == true
end

local function getAllTools()
    local out = {}
    local seen = {}
    local function scan(container)
        if not container then
            return
        end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") and not seen[item] then
                seen[item] = true
                table.insert(out, item)
            end
        end
    end
    scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
    scan(getCharacter())
    return out
end

local function hasRainbowText(value)
    if type(value) ~= "string" then
        return false
    end
    return string.find(string.lower(value), "rainbow", 1, true) ~= nil
end

local function isRainbowSeedTool(tool)
    if not (tool and tool:IsA("Tool")) then
        return false
    end
    local hasSeedSignal = tool:GetAttribute("SeedTool") ~= nil
        or tool:GetAttribute("SeedPack") ~= nil
        or tool:GetAttribute("RainbowSeed") == true
    if not hasSeedSignal then
        return false
    end
    if tool:GetAttribute("RainbowSeed") == true then
        return true
    end
    if hasRainbowText(tool.Name) then
        return true
    end
    if hasRainbowText(tool:GetAttribute("SeedTool")) then
        return true
    end
    if hasRainbowText(tool:GetAttribute("SeedPack")) then
        return true
    end
    return false
end

local function normalizeItemName(value)
    local text = string.lower(tostring(value or ""))
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function addConfiguredNames(target, list)
    if type(list) ~= "table" then
        return
    end
    for key, value in pairs(list) do
        if type(value) == "string" and value ~= "" then
            target[normalizeItemName(value)] = true
        elseif type(key) == "string" and value ~= false then
            target[normalizeItemName(key)] = true
        end
    end
end

local function nameMatchesConfiguredSet(value, names)
    local text = normalizeItemName(value)
    if text == "" or type(names) ~= "table" then
        return false
    end
    for name in pairs(names) do
        if name ~= "" and (text == name or string.find(text, name, 1, true)) then
            return true
        end
    end
    return false
end

Runtime.ShouldKeepSeed = function(seedName, tool)
    local c = CFG.KeepSeeds
    local names = {}
    if c and c.Enabled ~= false then
        addConfiguredNames(names, c.List or c.Seeds or c.SeedNames)
    end
    if CFG.ValuableWatcher and CFG.ValuableWatcher.KeepRainbowSeed ~= false then
        names[normalizeItemName("Rainbow")] = true
    end
    if next(names) == nil then
        return false
    end
    if nameMatchesConfiguredSet(seedName, names) then
        return true
    end
    if tool then
        return nameMatchesConfiguredSet(tool.Name, names)
            or nameMatchesConfiguredSet(tool:GetAttribute("SeedTool"), names)
            or nameMatchesConfiguredSet(tool:GetAttribute("SeedPack"), names)
            or (names[normalizeItemName("Rainbow")] and isRainbowSeedTool(tool))
    end
    return false
end

local function normalizeRarity(rarity)
    rarity = tostring(rarity or "Common")
    if rarity == "Mythical" then
        return "Mythic"
    end
    return rarity
end

local function getPetRarityFromSource(petName, tool)
    local attrRarity = tool and tool:GetAttribute("Rarity")
    if type(attrRarity) == "string" and attrRarity ~= "" then
        return normalizeRarity(attrRarity)
    end
    local data = PetData and PetData[petName]
    return normalizeRarity(data and data.Rarity or "Common")
end

local function isHighPetRarity(rarity, minRarity)
    rarity = normalizeRarity(rarity)
    minRarity = normalizeRarity(minRarity or "Mythic")
    return (RarityScore[rarity] or 0) >= (RarityScore[minRarity] or RarityScore.Mythic or 6)
end

Runtime.GetPrioritySeedSpawnLabel = function()
    local c = CFG.AutoCollectDrops
    if not (c and c.Enabled and c.IncludeSeedPackSpawns ~= false) then
        return nil
    end
    local map = workspace:FindFirstChild("Map")
    local folder = map and map:FindFirstChild("SeedPackSpawnServerLocations")
    if not folder then
        return nil
    end

    local bestLabel
    local bestPriority = -1
    for _, spawn in ipairs(folder:GetChildren()) do
        local seedPack = spawn:GetAttribute("SeedPack")
        local isRainbow = spawn:GetAttribute("RainbowSeed") == true
        local isGold = spawn:GetAttribute("GoldSeed") == true
        local label
        local priority = 0
        if isRainbow then
            label = "Rainbow Seed"
            priority = 300
        elseif isGold then
            label = "Gold Seed"
            priority = 200
        elseif type(seedPack) == "string" and seedPack ~= "" then
            label = seedPack
            priority = 100
        end
        if label and priority > bestPriority then
            bestLabel = label
            bestPriority = priority
        end
    end
    return bestLabel
end

Runtime.GetPriorityWildPetCandidate = function()
    local c = CFG.AutoTameWildPet
    if not (c and c.Enabled) then
        return nil
    end
    local map = workspace:FindFirstChild("Map")
    local folder = map and map:FindFirstChild("WildPetRef")
    if not folder then
        return nil
    end

    local keep = tonumber(c.KeepSheckles) or 0
    local budget = math.max((tonumber(getSheckles()) or 0) - keep, 0)
    local minRarity = normalizeRarity(c.PriorityMinRarity or c.MinRarity or "Legendary")
    local best

    for _, ref in ipairs(folder:GetChildren()) do
        if ref:IsA("BasePart") then
            local petName = ref:GetAttribute("PetName")
            local ownerUserId = ref:GetAttribute("OwnerUserId")
            local price = tonumber(ref:GetAttribute("Price")) or 0
            if type(petName) == "string" and petName ~= "" and ownerUserId ~= LocalPlayer.UserId and price <= budget then
                local rarity = normalizeRarity(ref:GetAttribute("Rarity") or (PetData and PetData[petName] and PetData[petName].Rarity) or "Common")
                if rarityAllowed(rarity, minRarity) then
                    local score = ((RarityScore[rarity] or 0) * 100000000) + price
                    if not best or score > best.Score then
                        best = {
                            Ref = ref,
                            Name = petName,
                            Rarity = rarity,
                            Price = price,
                            Score = score,
                        }
                    end
                end
            end
        end
    end
    return best
end

Runtime.ShouldYieldForSeedPriority = function(action)
    local now = os.clock()
    if State.SeedClaimInProgress or (tonumber(State.SeedClaimUntil) or 0) > now then
        return true
    end
    local label = Runtime.GetPrioritySeedSpawnLabel()
    if label then
        State.SeedClaimUntil = now + math.max((tonumber(CFG.AutoCollectDrops and CFG.AutoCollectDrops.Delay) or 0.5) + 0.75, 1)
        actionLog(action or "Priority", "SKIP", "seed first " .. tostring(label))
        return true
    end
    return false
end

Runtime.ShouldYieldForPetPriority = function(action)
    local now = os.clock()
    if State.PetTameInProgress or (tonumber(State.PetTameUntil) or 0) > now then
        return true
    end
    local pet = Runtime.GetPriorityWildPetCandidate()
    if pet then
        State.PetTameUntil = now + math.max(tonumber(CFG.AutoTameWildPet and CFG.AutoTameWildPet.PriorityYieldSeconds) or 1.5, 0.5)
        State.LastPet = os.date("%H:%M:%S") .. " priority " .. tostring(pet.Name) .. " " .. tostring(pet.Rarity)
        actionLog(action or "Priority", "SKIP", ("pet first %s %s $%s"):format(tostring(pet.Name), tostring(pet.Rarity), tostring(pet.Price)))
        return true
    end
    return false
end

local WebhookSeen = {}
local WebhookPending = {}
local WebhookLastAt = 0
local WebhookQueue = {}
local WebhookWorkerRunning = false

-- ============================================================
-- SeenStore: nhớ những key đã gửi webhook XUỐNG FILE (ổ đĩa executor),
-- lưu theo UserId từng acc -> relog / reload script vẫn không gửi TRÙNG.
-- Sửa lỗi: acc đã có pet/seed rồi, out ra vào lại, script tưởng mới -> báo lại.
-- Dùng pcall + type-check vì không phải executor nào cũng có file API.
-- ============================================================
Runtime.SeenStore = {}
do
    local SeenStore = Runtime.SeenStore
    local hasFs = type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
    local folder = "Kaitun"
    local userTag = tostring((LocalPlayer and LocalPlayer.UserId) or "unknown")
    local path = folder .. "/seen_" .. userTag .. ".json"
    local data = {}
    local loaded = false
    local dirty = false

    local function ensureFolder()
        if type(makefolder) == "function" and type(isfolder) == "function" then
            pcall(function()
                if not isfolder(folder) then
                    makefolder(folder)
                end
            end)
        end
    end

    function SeenStore.load()
        if loaded then return end
        loaded = true
        if not hasFs then return end
        ensureFolder()
        local ok, raw = pcall(function()
            if isfile(path) then
                return readfile(path)
            end
            return nil
        end)
        if ok and type(raw) == "string" and raw ~= "" then
            local okDecode, decoded = pcall(function()
                return HttpService:JSONDecode(raw)
            end)
            if okDecode and type(decoded) == "table" then
                data = decoded
            end
        end
    end

    function SeenStore.has(key)
        if not key then return false end
        return data[tostring(key)] == true
    end

    function SeenStore.flush()
        if not hasFs or not dirty then return end
        local okEncode, body = pcall(function()
            return HttpService:JSONEncode(data)
        end)
        if okEncode then
            local okWrite = pcall(function()
                writefile(path, body)
            end)
            if okWrite then
                dirty = false
            end
        end
    end

    function SeenStore.add(key)
        if not key then return end
        key = tostring(key)
        if data[key] == true then return end
        data[key] = true
        dirty = true
        SeenStore.flush()
    end
end
Runtime.SeenStore.load()
local WebhookNoRequestLogged = false

local function getWebhookRequest()
    if type(request) == "function" then
        return request
    end
    if type(http_request) == "function" then
        return http_request
    end
    if type(syn) == "table" and type(syn.request) == "function" then
        return syn.request
    end
    if type(http) == "table" and type(http.request) == "function" then
        return http.request
    end
    return nil
end

local function getAccountName()
    return tostring(LocalPlayer and LocalPlayer.Name or "unknown")
end

Runtime.HideBlockingPopups = function()
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then
        return
    end
    local needles = {
        "pet info",
        "dig this up",
        "shovel will permanently",
    }
    for _, gui in ipairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui")
            and gui.Name ~= "KaitunDashboard"
            and gui.Name ~= "NightNotifier" then
            local shouldHide = gui.Name == "EquipPet"
                or string.find(normalizeItemName(gui.Name), "petinfo", 1, true) ~= nil
            if not shouldHide then
                for _, obj in ipairs(gui:GetDescendants()) do
                    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
                        local text = normalizeItemName(obj.Text)
                        for _, needle in ipairs(needles) do
                            if string.find(text, needle, 1, true) then
                                shouldHide = true
                                break
                            end
                        end
                    end
                    if shouldHide then
                        break
                    end
                end
            end
            if shouldHide then
                pcall(function()
                    gui.Enabled = false
                end)
            end
        end
    end
end

-- Đếm tổng Rainbow Seed đang có: ưu tiên kho thật (Inventory.Seeds), fallback tool trong người.
function Runtime.CountRainbowSeeds()
    local total = 0
    local counted = false
    local replica = getPlayerReplica()
    if replica and replica.Data and type(replica.Data.Inventory) == "table" then
        local seeds = replica.Data.Inventory.Seeds
        if type(seeds) == "table" then
            counted = true
            for key, count in pairs(seeds) do
                if type(key) == "string" and hasRainbowText(key) then
                    total = total + (tonumber(count) or 0)
                end
            end
        end
    end
    if not counted then
        for _, t in ipairs(getAllTools()) do
            if isRainbowSeedTool(t) then
                total = total + 1
            end
        end
    end
    return total
end

-- Gửi/sửa payload tới 1 webhook URL bất kỳ (riêng, khác CFG.Webhook). Trả ok, response.
function Runtime.HttpSend(method, url, payload)
    if type(url) ~= "string" or url == "" then
        return false, "no url"
    end
    local httpRequest = getWebhookRequest()
    if not httpRequest then
        return false, "no request"
    end
    local okEncode, body = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not okEncode then
        return false, "encode"
    end
    local ok, res = pcall(function()
        return httpRequest({
            Url = url,
            Method = method,
            Headers = { ["Content-Type"] = "application/json" },
            Body = body,
        })
    end)
    if not ok then
        return false, tostring(res)
    end
    return true, res
end

-- Acc chỉ định (mặc định chuideptrai1209): mỗi phút UPDATE 1 message webhook riêng,
-- cho biết acc đang giữ bao nhiêu Rainbow Seed. Edit lại đúng 1 message thay vì spam.
function Runtime.DoRainbowAccountReport()
    local c = CFG.RainbowAccountReport
    if not (c and c.Enabled) then return end
    if type(c.Username) == "string" and c.Username ~= "" and getAccountName() ~= c.Username then
        return -- chỉ acc được chỉ định mới báo
    end
    if type(c.WebhookUrl) ~= "string" or c.WebhookUrl == "" then
        if not Runtime.RainbowReportNoUrlLogged then
            Runtime.RainbowReportNoUrlLogged = true
            actionLog("RainbowReport", "SKIP", "chua dien CFG.RainbowAccountReport.WebhookUrl")
        end
        return
    end

    local count = Runtime.CountRainbowSeeds()
    local payload = {
        content = tostring(c.Mention or ""),
        embeds = { {
            title = "🌈 Rainbow Seed Report",
            description = ("Acc **%s** đang giữ **%d** Rainbow Seed."):format(getAccountName(), count),
            color = 0x9B59B6,
            fields = {
                { name = "👤 Tài khoản", value = getAccountName(), inline = true },
                { name = "🆔 UserId", value = tostring(LocalPlayer.UserId), inline = true },
                { name = "🌈 Rainbow Seed", value = "x" .. tostring(count), inline = true },
            },
            footer = { text = "Kaitun Rainbow Report • cập nhật mỗi phút" },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        } },
    }

    -- Đã có message -> PATCH để update. Hỏng (message bị xóa) -> tạo mới.
    local id = Runtime.RainbowReportMsgId
    if id then
        local ok, res = Runtime.HttpSend("PATCH", c.WebhookUrl .. "/messages/" .. id, payload)
        local code = type(res) == "table" and tonumber(res.StatusCode) or nil
        if ok and (code == nil or code < 300) then
            State.LastRainbowReport = os.date("%H:%M:%S") .. " upd=" .. tostring(count)
            return
        end
        Runtime.RainbowReportMsgId = nil -- patch fail -> sẽ tạo lại
    end

    -- Tạo mới với ?wait=true để lấy message id (để lần sau edit).
    local sep = string.find(c.WebhookUrl, "?", 1, true) and "&" or "?"
    local ok, res = Runtime.HttpSend("POST", c.WebhookUrl .. sep .. "wait=true", payload)
    if ok then
        local rawBody = type(res) == "table" and res.Body
        if type(rawBody) == "string" and rawBody ~= "" then
            local okD, decoded = pcall(function() return HttpService:JSONDecode(rawBody) end)
            if okD and type(decoded) == "table" and decoded.id then
                Runtime.RainbowReportMsgId = tostring(decoded.id)
            end
        end
        State.LastRainbowReport = os.date("%H:%M:%S") .. " new=" .. tostring(count)
        actionLog("RainbowReport", "DONE", "count=" .. tostring(count))
    else
        actionLog("RainbowReport", "ERROR", tostring(res))
    end
end

local startWebhookWorker
local function enqueueWebhook(payload, title, key, persist)
    local c = CFG.Webhook
    if not (c and c.Enabled ~= false and type(c.Url) == "string" and c.Url ~= "") then
        return false
    end
    local maxQueue = tonumber(c.MaxQueue) or 80
    while #WebhookQueue >= maxQueue do
        local dropped = table.remove(WebhookQueue, 1)
        if dropped and dropped.Key then
            WebhookPending[dropped.Key] = nil
        end
    end
    table.insert(WebhookQueue, {
        Payload = payload,
        Title = tostring(title or "Webhook"),
        Tries = 0,
        Key = key,
        Persist = persist == true,
    })
    State.LastWebhook = os.date("%H:%M:%S") .. " queued=" .. tostring(#WebhookQueue)
    if startWebhookWorker then
        startWebhookWorker()
    end
    return true
end

startWebhookWorker = function()
    if WebhookWorkerRunning then
        return
    end
    WebhookWorkerRunning = true
    task.spawn(function()
        while isAlive() and #WebhookQueue > 0 do
            local job = table.remove(WebhookQueue, 1)
            local c = CFG.Webhook or {}
            local cooldown = math.max(tonumber(c.Cooldown) or 2, 0)
            local waitFor = cooldown - (os.clock() - WebhookLastAt)
            if waitFor > 0 and not waitAlive(waitFor) then
                table.insert(WebhookQueue, 1, job)
                break
            end

            local ok, res = Runtime.HttpSend("POST", c.Url, job.Payload)
            local code = type(res) == "table" and tonumber(res.StatusCode) or nil
            if ok and (not code or code < 300) then
                WebhookLastAt = os.clock()
                State.LastWebhook = os.date("%H:%M:%S") .. " sent"
                if job.Key then
                    WebhookSeen[job.Key] = true
                    WebhookPending[job.Key] = nil
                    if job.Persist then
                        Runtime.SeenStore.add(job.Key)
                    end
                end
                actionLog("Webhook", "DONE", job.Title)
            else
                job.Tries = (tonumber(job.Tries) or 0) + 1
                if job.Tries < 3 then
                    table.insert(WebhookQueue, job)
                    State.LastWebhook = os.date("%H:%M:%S") .. " retry=" .. tostring(job.Tries)
                    if not waitAlive(math.min(2 * job.Tries, 6)) then
                        break
                    end
                else
                    State.LastWebhook = os.date("%H:%M:%S") .. " send fail"
                    if job.Key then
                        WebhookPending[job.Key] = nil
                    end
                    actionLog("Webhook", "ERROR", compactText(res, 90))
                end
            end
        end
        WebhookWorkerRunning = false
        if isAlive() and #WebhookQueue > 0 then
            startWebhookWorker()
        end
    end)
end

local function sendWebhookOnce(key, title, description, fields, color, opts)
    local c = CFG.Webhook
    if not (c and c.Enabled ~= false and type(c.Url) == "string" and c.Url ~= "") then
        return false
    end
    -- CHỈ gửi 2 loại webhook: MUA PET thành công ("petbuy:") + lấy RAINBOW/GOLD SEED ("seed:"/"gold:").
    -- Mọi loại khác (mail gửi "mailseed:/mailrb:/mailpet:", mail nhận "mailclaim:", high pet "pet:")
    -- -> KHÔNG gửi.
    if not (type(key) == "string"
        and (key:sub(1, 7) == "petbuy:" or key:sub(1, 5) == "seed:" or key:sub(1, 5) == "gold:")) then
        return false
    end
    opts = type(opts) == "table" and opts or {}
    if key then
        if WebhookSeen[key] or WebhookPending[key] then
            return false
        end
        -- persist=true: đã gửi ở phiên TRƯỚC (lưu file) thì không gửi lại sau relog.
        if opts.persist and Runtime.SeenStore.has(key) then
            WebhookSeen[key] = true
            return false
        end
    end

    local embed = {
        title = tostring(title or "Kaitun Alert"),
        description = tostring(description or ""),
        color = tonumber(color) or 5814783,
        fields = fields or {},
        footer = { text = tostring(opts.footer or "Kaitun Valuable Watcher") },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    if type(opts.footerIcon) == "string" and opts.footerIcon ~= "" then
        embed.footer.icon_url = opts.footerIcon
    end
    if type(opts.author) == "string" and opts.author ~= "" then
        embed.author = { name = opts.author }
        if type(opts.authorIcon) == "string" and opts.authorIcon ~= "" then
            embed.author.icon_url = opts.authorIcon
        end
    end
    if type(opts.thumbnail) == "string" and opts.thumbnail ~= "" then
        embed.thumbnail = { url = opts.thumbnail }
    end
    if type(opts.image) == "string" and opts.image ~= "" then
        embed.image = { url = opts.image }
    end
    local payload = {
        content = tostring(opts.content ~= nil and opts.content or (c.Mention or "")),
        embeds = { embed },
    }

    local okEncode = pcall(function()
        return HttpService:JSONEncode(payload)
    end)
    if not okEncode then
        State.LastWebhook = os.date("%H:%M:%S") .. " encode fail"
        actionLog("Webhook", "ERROR", "encode")
        return false
    end

    if key then
        WebhookPending[key] = true
    end

    if not enqueueWebhook(payload, title, key, opts.persist == true) then
        if key then
            WebhookPending[key] = nil
        end
        return false
    end

    actionLog("Webhook", "QUEUE", tostring(title or "alert"))
    return true
end

local function countFruitTools()
    local count = 0
    local function scan(container)
        if not container then
            return
        end
        for _, item in ipairs(container:GetChildren()) do
            if isFruitTool(item) then
                count = count + 1
            end
        end
    end
    scan(LocalPlayer:FindFirstChildOfClass("Backpack"))
    scan(getCharacter())
    return count
end

-- Sức chứa quả THẬT của game (xác nhận InventoryController/Main.lua dòng 2687:
-- UI hiện "{FruitCount}/{MaxFruitCapacity} Fruits"). Đầy = FruitCount >= MaxFruitCapacity.
local function getFruitCount()
    return tonumber(LocalPlayer:GetAttribute("FruitCount"))
end

local function getMaxFruitCapacity()
    return tonumber(LocalPlayer:GetAttribute("MaxFruitCapacity")) or 100
end

-- Tỉ lệ đầy túi (0..1) kèm count, max. nil nếu game chưa set FruitCount.
local function getFruitFill()
    local count = getFruitCount()
    if not count then
        return nil
    end
    local max = getMaxFruitCapacity()
    if max <= 0 then
        return nil
    end
    return count / max, count, max
end

-- Túi đã đầy chưa (theo ngưỡng FullThreshold của AutoSell). nil-safe.
local function isInventoryFull()
    local ratio = getFruitFill()
    if not ratio then
        return false
    end
    local threshold = tonumber(CFG.AutoSell and CFG.AutoSell.FullThreshold) or 0.95
    return ratio >= threshold
end

-- Log-focused dashboard remake: no module ON/OFF grid, just important state
-- and a large readable action log.
local function setupKaitunDashboard()
    local c = CFG.Dashboard
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10)
    if not playerGui then
        return
    end

    local oldGui = playerGui:FindFirstChild("KaitunDashboard")
    if oldGui then
        oldGui:Destroy()
    end

    if not (c and c.Enabled) then
        return
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "KaitunDashboard"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 500
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = playerGui

    local COL_BG = Color3.fromRGB(10, 12, 16)
    local COL_TOP = Color3.fromRGB(18, 22, 29)
    local COL_PANEL = Color3.fromRGB(24, 29, 38)
    local COL_PANEL2 = Color3.fromRGB(31, 37, 48)
    local COL_LINE = Color3.fromRGB(68, 80, 100)
    local COL_TEXT = Color3.fromRGB(236, 241, 248)
    local COL_SUB = Color3.fromRGB(156, 169, 188)
    local COL_GREEN = Color3.fromRGB(74, 222, 128)
    local COL_BLUE = Color3.fromRGB(96, 165, 250)
    local COL_YELLOW = Color3.fromRGB(250, 204, 21)
    local COL_RED = Color3.fromRGB(248, 113, 113)

    local function corner(inst, radius)
        local u = Instance.new("UICorner")
        u.CornerRadius = UDim.new(0, radius or 8)
        u.Parent = inst
        return u
    end

    local function stroke(inst, color, transparency)
        local u = Instance.new("UIStroke")
        u.Color = color or COL_LINE
        u.Transparency = transparency == nil and 0.5 or transparency
        u.Thickness = 1
        u.Parent = inst
        return u
    end

    local function pad(inst, l, t, r, b)
        local p = Instance.new("UIPadding")
        p.PaddingLeft = UDim.new(0, l or 12)
        p.PaddingTop = UDim.new(0, t or 12)
        p.PaddingRight = UDim.new(0, r or 12)
        p.PaddingBottom = UDim.new(0, b or 12)
        p.Parent = inst
        return p
    end

    local function text(parent, name, value, size, bold)
        local label = Instance.new("TextLabel")
        label.Name = name
        label.BackgroundTransparency = 1
        label.Text = value or ""
        label.TextColor3 = COL_TEXT
        label.TextSize = size or 14
        label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Top
        label.TextWrapped = true
        label.Parent = parent
        return label
    end

    local function panel(parent, name)
        local frame = Instance.new("Frame")
        frame.Name = name
        frame.BackgroundColor3 = COL_PANEL
        frame.BorderSizePixel = 0
        frame.Parent = parent
        corner(frame, 8)
        stroke(frame, COL_LINE, 0.5)
        return frame
    end

    local function formatMoney(value)
        value = tonumber(value)
        if not value then
            return "-"
        end
        if value >= 1000000000 then
            return string.format("%.2fb", value / 1000000000)
        elseif value >= 1000000 then
            return string.format("%.2fm", value / 1000000)
        elseif value >= 1000 then
            return string.format("%.1fk", value / 1000)
        end
        return tostring(value)
    end

    local root = Instance.new("Frame")
    root.Name = "Root"
    root.Size = UDim2.fromScale(1, 1)
    root.BackgroundColor3 = COL_BG
    root.BackgroundTransparency = 0.05
    root.BorderSizePixel = 0
    root.Visible = State.DashboardVisible
    root.Parent = gui

    local top = Instance.new("Frame")
    top.Name = "Top"
    top.Size = UDim2.new(1, 0, 0, 76)
    top.BackgroundColor3 = COL_TOP
    top.BorderSizePixel = 0
    top.Parent = root
    stroke(top, COL_LINE, 0.65)

    local title = text(top, "Title", "KAITUN LOG", 24, true)
    title.Position = UDim2.fromOffset(20, 12)
    title.Size = UDim2.new(0, 260, 0, 28)

    local sub = text(top, "Sub", "important actions only - RightShift to hide/show", 12, false)
    sub.TextColor3 = COL_SUB
    sub.Position = UDim2.fromOffset(22, 43)
    sub.Size = UDim2.new(0, 420, 0, 18)

    local toggle = Instance.new("TextButton")
    toggle.Name = "Toggle"
    toggle.AnchorPoint = Vector2.new(1, 0)
    toggle.Position = UDim2.new(1, -16, 0, 18)
    toggle.Size = UDim2.fromOffset(108, 36)
    toggle.BackgroundColor3 = COL_BLUE
    toggle.BorderSizePixel = 0
    toggle.AutoButtonColor = true
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 14
    toggle.TextColor3 = Color3.fromRGB(10, 14, 20)
    toggle.Text = "HIDE"
    toggle.Parent = gui
    corner(toggle, 8)

    local statRoot = Instance.new("Frame")
    statRoot.Name = "Stats"
    statRoot.Position = UDim2.new(0, 470, 0, 12)
    statRoot.Size = UDim2.new(1, -610, 0, 52)
    statRoot.BackgroundTransparency = 1
    statRoot.Parent = top

    local statLayout = Instance.new("UIGridLayout")
    statLayout.CellSize = UDim2.new(0.2, -8, 1, 0)
    statLayout.CellPadding = UDim2.fromOffset(8, 0)
    statLayout.SortOrder = Enum.SortOrder.LayoutOrder
    statLayout.Parent = statRoot

    local statValues = {}
    local function makeStat(key, caption)
        local box = Instance.new("Frame")
        box.Name = key
        box.BackgroundColor3 = COL_PANEL2
        box.BorderSizePixel = 0
        box.Parent = statRoot
        corner(box, 7)
        stroke(box, COL_LINE, 0.6)

        local cap = text(box, "Cap", caption, 10, true)
        cap.TextColor3 = COL_SUB
        cap.Position = UDim2.fromOffset(9, 5)
        cap.Size = UDim2.new(1, -18, 0, 12)

        local val = text(box, "Val", "-", 16, true)
        val.Position = UDim2.fromOffset(9, 20)
        val.Size = UDim2.new(1, -18, 0, 26)
        val.TextTruncate = Enum.TextTruncate.AtEnd
        statValues[key] = val
    end

    makeStat("Money", "SHECKLES")
    makeStat("Fruit", "FRUIT")
    makeStat("Time", "TIME")
    makeStat("Players", "PLAYERS")
    makeStat("Guard", "GUARD")

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.Position = UDim2.fromOffset(16, 92)
    body.Size = UDim2.new(1, -32, 1, -108)
    body.BackgroundTransparency = 1
    body.Parent = root

    local statusPanel = panel(body, "Status")
    statusPanel.Position = UDim2.new(0, 0, 0, 0)
    statusPanel.Size = UDim2.new(0.27, -6, 1, 0)
    pad(statusPanel, 14, 12, 14, 12)

    local statusTitle = text(statusPanel, "Title", "IMPORTANT", 14, true)
    statusTitle.TextColor3 = COL_SUB
    statusTitle.Size = UDim2.new(1, 0, 0, 20)

    local statusText = text(statusPanel, "Lines", "", 14, false)
    statusText.Font = Enum.Font.Code
    statusText.Position = UDim2.fromOffset(0, 30)
    statusText.Size = UDim2.new(1, 0, 1, -30)

    -- PLAN QUOTA panel (mục 5,11): hiện count/quota từng loại + OK/NEED/EXTRA.
    local quotaPanel = panel(body, "Quota")
    quotaPanel.Position = UDim2.new(0.27, 6, 0, 0)
    quotaPanel.Size = UDim2.new(0.30, -6, 1, 0)
    pad(quotaPanel, 12, 12, 6, 12)

    local quotaTitle = text(quotaPanel, "Title", "PLAN QUOTA (cay/quota)", 13, true)
    quotaTitle.TextColor3 = COL_SUB
    quotaTitle.Size = UDim2.new(1, 0, 0, 18)

    local quotaScroll = Instance.new("ScrollingFrame")
    quotaScroll.Name = "List"
    quotaScroll.BackgroundTransparency = 1
    quotaScroll.BorderSizePixel = 0
    quotaScroll.Position = UDim2.fromOffset(0, 26)
    quotaScroll.Size = UDim2.new(1, 0, 1, -26)
    quotaScroll.ScrollBarThickness = 5
    quotaScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    quotaScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    quotaScroll.Parent = quotaPanel
    local quotaLayout = Instance.new("UIListLayout")
    quotaLayout.Padding = UDim.new(0, 1)
    quotaLayout.SortOrder = Enum.SortOrder.LayoutOrder
    quotaLayout.Parent = quotaScroll
    local quotaRows = {}

    local logPanel = panel(body, "Log")
    logPanel.Position = UDim2.new(0.57, 6, 0, 0)
    logPanel.Size = UDim2.new(0.43, -6, 1, 0)
    pad(logPanel, 14, 12, 14, 12)

    local logTitle = text(logPanel, "Title", "ACTION LOG", 14, true)
    logTitle.TextColor3 = COL_SUB
    logTitle.Size = UDim2.new(1, 0, 0, 20)

    local logText = text(logPanel, "Lines", "", 16, false)
    logText.Font = Enum.Font.Code
    logText.TextColor3 = COL_TEXT
    logText.Position = UDim2.fromOffset(0, 34)
    logText.Size = UDim2.new(1, 0, 1, -34)

    local connections = {}
    local function setVisible(value)
        State.DashboardVisible = value == true
        root.Visible = State.DashboardVisible
        toggle.Text = State.DashboardVisible and "HIDE" or "SHOW"
        toggle.BackgroundColor3 = State.DashboardVisible and COL_BLUE or COL_GREEN
    end

    local function getToggleKey()
        local keyName = tostring(c.ToggleKey or "RightShift")
        local ok, key = pcall(function()
            return Enum.KeyCode[keyName]
        end)
        if ok and key then
            return key
        end
        return Enum.KeyCode.RightShift
    end

    table.insert(connections, toggle.Activated:Connect(function()
        setVisible(not State.DashboardVisible)
        actionLog("Dashboard", State.DashboardVisible and "SHOW" or "HIDE")
    end))
    table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end
        if input.KeyCode == getToggleKey() then
            setVisible(not State.DashboardVisible)
            actionLog("Dashboard", State.DashboardVisible and "SHOW" or "HIDE", "key=" .. tostring(input.KeyCode.Name))
        end
    end))

    local function update()
        local night = isNight()
        local ratio, fruitCount, fruitMax = getFruitFill()
        local money = getSheckles()
        local players = #Players:GetPlayers()
        local intruders = tonumber(State.IntruderCount) or 0

        statValues.Money.Text = formatMoney(money)
        statValues.Fruit.Text = fruitCount and (tostring(fruitCount) .. "/" .. tostring(fruitMax)) or "-"
        statValues.Time.Text = night and "NIGHT" or "DAY"
        statValues.Time.TextColor3 = night and COL_YELLOW or COL_GREEN
        statValues.Players.Text = tostring(players)
        statValues.Guard.Text = intruders > 0 and ("ALERT " .. tostring(intruders)) or "OK"
        statValues.Guard.TextColor3 = intruders > 0 and COL_RED or COL_GREEN

        -- Runtime HH:MM:SS (mục 9) tính từ lúc script chạy.
        local rt = math.max(math.floor(os.clock() - (Runtime.StartedAt or os.clock())), 0)
        local rtStr = ("%02d:%02d:%02d"):format(math.floor(rt / 3600), math.floor((rt % 3600) / 60), rt % 60)

        -- Đếm cây THẬT trong plot.Plants theo loại + tổng (mục 4, refresh mỗi vòng, không cache).
        local plantTotal, plantCounts = 0, {}
        local myPlot = getPlot()
        local pf = myPlot and myPlot:FindFirstChild("Plants")
        if pf then
            for _, m in ipairs(pf:GetChildren()) do
                if m:IsA("Model") then
                    plantTotal = plantTotal + 1
                    local s = m:GetAttribute("SeedName")
                    if type(s) == "string" and s ~= "" then plantCounts[s] = (plantCounts[s] or 0) + 1 end
                end
            end
        end
        -- Total plots: CFG.TotalPlots (chồng set) hoặc đếm part PlantArea (source không có max cây thật).
        local totalPlots = tonumber(CFG.TotalPlots) or 0
        if totalPlots <= 0 then totalPlots = #getPlantAreaParts() end

        local fillPct = ratio and (tostring(math.floor(math.clamp(ratio, 0, 1) * 100)) .. "%") or "-"
        statusText.Text = table.concat({
            "Acc   : " .. getAccountName(),
            "Run   : " .. rtStr,
            "Plants: " .. tostring(plantTotal) .. " / " .. (totalPlots > 0 and tostring(totalPlots) or "?"),
            "Money : " .. formatMoney(money),
            "Bag   : " .. (fruitCount and (tostring(fruitCount) .. "/" .. tostring(fruitMax) .. " (" .. fillPct .. ")") or "-"),
            "Time  : " .. (night and "NIGHT" or "DAY"),
            "FPS   : " .. tostring(State.LastFps or "-"),
            "Pet   : " .. tostring(State.LastPet or "-"),
            "Mail  : " .. tostring(State.LastMailbox or "-"),
            "Seed  : " .. tostring(State.LastValuable or "-"),
            "Sell  : " .. tostring(State.LastSell or "-"),
            "Guard : " .. tostring(State.LastAntiSteal or "-"),
            "Hook  : " .. tostring(State.LastWebhook or "-"),
        }, "\n")

        -- ===== PLAN QUOTA panel: count/quota từng loại (mục 5,11) =====
        -- Nguồn quota: CFG.PlanQuota -> TrimToQuota.Quota -> AutoPlant.PlantQuota.
        local quota = (type(CFG.PlanQuota) == "table" and next(CFG.PlanQuota) and CFG.PlanQuota)
            or (CFG.TrimToQuota and type(CFG.TrimToQuota.Quota) == "table" and next(CFG.TrimToQuota.Quota) and CFG.TrimToQuota.Quota)
            or (CFG.AutoPlant and type(CFG.AutoPlant.PlantQuota) == "table" and CFG.AutoPlant.PlantQuota)
            or {}
        local qnames, qseen = {}, {}
        for name in pairs(quota) do if not qseen[name] then qseen[name] = true; table.insert(qnames, name) end end
        for name in pairs(plantCounts) do if not qseen[name] then qseen[name] = true; table.insert(qnames, name) end end
        table.sort(qnames)
        local qlive = {}
        for idx, name in ipairs(qnames) do
            qlive[name] = true
            local row = quotaRows[name]
            if not row then
                row = Instance.new("TextLabel")
                row.BackgroundTransparency = 1
                row.Font = Enum.Font.Code
                row.TextSize = 12
                row.TextXAlignment = Enum.TextXAlignment.Left
                row.Size = UDim2.new(1, -4, 0, 15)
                row.Parent = quotaScroll
                quotaRows[name] = row
            end
            row.LayoutOrder = idx
            local cur = plantCounts[name] or 0
            local q = tonumber(quota[name])
            if q == nil then
                row.Text = ("%s: %d / -"):format(name, cur)
                row.TextColor3 = Color3.fromRGB(150, 150, 160)
            elseif cur > q then
                row.Text = ("%s: %d / %d EXTRA"):format(name, cur, q)
                row.TextColor3 = Color3.fromRGB(245, 170, 90)
            elseif cur == q then
                row.Text = ("%s: %d / %d OK"):format(name, cur, q)
                row.TextColor3 = COL_GREEN
            else
                row.Text = ("%s: %d / %d NEED"):format(name, cur, q)
                row.TextColor3 = COL_BLUE
            end
        end
        for name, row in pairs(quotaRows) do
            if not qlive[name] then pcall(function() row:Destroy() end); quotaRows[name] = nil end
        end

        local lines = {}
        for i, line in ipairs(State.ActionLines) do
            lines[#lines + 1] = string.format("%02d  %s", i, line)
        end
        logText.Text = #lines > 0 and table.concat(lines, "\n") or "waiting..."
    end

    setVisible(State.DashboardVisible)
    update()

    local thread = task.spawn(function()
        while isAlive() do
            update()
            if not waitAlive(tonumber(c.RefreshRate) or 0.5) then
                break
            end
        end
    end)
    table.insert(Runtime.Tasks, thread)

    table.insert(Runtime.Cleanups, function()
        for _, conn in ipairs(connections) do
            pcall(function()
                conn:Disconnect()
            end)
        end
        pcall(function()
            gui:Destroy()
        end)
    end)
end

local function equipTool(tool)
    local hum = getHumanoid()
    if not hum then return false end
    if tool.Parent ~= getCharacter() then
        local ok = pcall(function() hum:EquipTool(tool) end)
        if not ok then return false end
        waitAlive(0.05)
    end
    return true
end

local function getRootPart()
    local char = getCharacter()
    if not char then
        return nil
    end
    return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end

local function getGardenHomeCFrame()
    local root = getRootPart()
    local parts = getPlantAreaParts()
    local bestPart
    local bestDistance = math.huge
    for _, part in ipairs(parts) do
        if part and part:IsA("BasePart") then
            local distance = root and (root.Position - part.Position).Magnitude or 0
            if not bestPart or distance < bestDistance then
                bestPart = part
                bestDistance = distance
            end
        end
    end
    if bestPart then
        local y = math.max((bestPart.Size.Y * 0.5) + 4, 5)
        return bestPart.CFrame * CFrame.new(0, y, 0)
    end

    local plot = getPlot()
    if plot then
        local ok, cf = pcall(function()
            local boxCf, boxSize = plot:GetBoundingBox()
            return boxCf * CFrame.new(0, math.max((boxSize.Y * 0.5) + 4, 6), 0)
        end)
        if ok and cf then
            return cf
        end
    end
    return nil
end

local function teleportToGardenHome(reason, waitSeconds)
    local root = getRootPart()
    local homeCF = getGardenHomeCFrame()
    if not (root and homeCF) then
        return false
    end
    local minMove = tonumber(CFG.HomeTeleportMinDistance) or 8
    if (root.Position - homeCF.Position).Magnitude <= minMove then
        return true
    end
    root.CFrame = homeCF
    if reason then
        actionLog(reason, "RETURN_HOME")
    end
    return waitAlive(waitSeconds or 0.08)
end

local function teleportNearPosition(pos, c)
    local root = getRootPart()
    if not (root and pos) then
        return false
    end
    local distance = tonumber(c and c.TeleportDistance) or 4
    local yOffset = tonumber(c and c.TeleportYOffset) or 2
    local direction = root.Position - pos
    if direction.Magnitude < 0.001 then
        direction = Vector3.new(0, 0, -1)
    end
    local targetPos = pos + direction.Unit * distance + Vector3.new(0, yOffset, 0)
    root.CFrame = CFrame.lookAt(targetPos, pos)
    return waitAlive(tonumber(c and c.TeleportWait) or 0.05)
end

local function getStevenRootPart()
    -- Path chuẩn: workspace.NPCS.Steven.HumanoidRootPart (xác nhận Sell_Steven.lua:3-4).
    local npcs = workspace:FindFirstChild("NPCS")
    local steven = npcs and npcs:FindFirstChild("Steven")
    if steven then
        local hrp = steven:FindFirstChild("HumanoidRootPart")
        if hrp then return hrp end
    end
    -- Fallback: 1 số server NPC stream chậm / nằm lồng sâu -> tìm đệ quy theo tên "Steven".
    local found = workspace:FindFirstChild("Steven", true)
    if found then
        if found:IsA("BasePart") then return found end
        local hrp = found:FindFirstChild("HumanoidRootPart")
            or found:FindFirstChild("HumanoidRootPart", true)
        if hrp then return hrp end
    end
    return nil
end

local function teleportToStevenForSell()
    local c = CFG.AutoSell or {}
    if c.TeleportToStevenBeforeSell == false then
        actionLog("AutoSell", "TELEPORT_SKIPPED", "disabled")
        return true
    end

    local root = getRootPart()
    if not root then
        actionLog("AutoSell", "TELEPORT_FAILED", "missing character root")
        return false
    end

    local stevenRoot = getStevenRootPart()
    if not stevenRoot then
        actionLog("AutoSell", "TELEPORT_FAILED", "missing workspace.NPCS.Steven.HumanoidRootPart")
        return false
    end

    local distance = tonumber(c.TeleportDistance) or 5
    root.CFrame = stevenRoot.CFrame * CFrame.new(0, 0, -distance)
    actionLog("AutoSell", "TELEPORTED", "to Steven")
    return waitAlive(tonumber(c.TeleportWait) or 0.35)
end

local AntiStealCooldown = {}

local function getGardenZoneData()
    return ReplicatedStorage:FindFirstChild("GardenZoneData")
end

local function isPlayerInMyGarden(player)
    if not player or player == LocalPlayer then
        return false
    end
    local plotId = LocalPlayer:GetAttribute("PlotId")
    if not plotId then
        return false
    end
    local zoneData = getGardenZoneData()
    local value = zoneData and zoneData:FindFirstChild(player.Name)
    if not value then
        return false
    end
    local ok, zoneValue = pcall(function()
        return value.Value
    end)
    return ok and zoneValue == plotId or false
end

local function getPlayersInMyGarden()
    local intruders = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if isPlayerInMyGarden(player) then
            table.insert(intruders, player)
        end
    end
    return intruders
end

local function getPlayerRoot(player)
    local char = player and player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getShovelTool()
    local tools = getToolsWithAttribute("Shovel")
    return tools[1]
end

local function teleportToIntruder(player)
    local c = CFG.AntiSteal or {}
    if c.TeleportToIntruder == false then
        return true
    end

    local root = getRootPart()
    local targetRoot = getPlayerRoot(player)
    if not root or not targetRoot then
        actionLog("AntiSteal", "SKIP", "missing root for " .. tostring(player and player.Name))
        return false
    end

    local distance = tonumber(c.TeleportDistance) or 5
    local offsetY = tonumber(c.TeleportYOffset) or 0
    local targetPos = targetRoot.Position
    local direction = targetRoot.CFrame.LookVector
    if direction.Magnitude < 0.001 then
        direction = Vector3.new(0, 0, -1)
    end
    local myPos = targetPos - direction.Unit * distance + Vector3.new(0, offsetY, 0)
    root.CFrame = CFrame.lookAt(myPos, targetPos)
    actionLog("AntiSteal", "TELEPORTED", tostring(player.Name))
    return waitAlive(0.08)
end

local function equipShovelForAntiSteal()
    local c = CFG.AntiSteal or {}
    if c.EquipShovel == false then
        return true
    end

    local shovel = getShovelTool()
    if not shovel then
        actionLog("AntiSteal", c.RequireShovel == false and "WARN" or "SKIP", "missing shovel tool")
        return c.RequireShovel == false
    end

    if not equipTool(shovel) then
        actionLog("AntiSteal", "SKIP", "cannot equip shovel")
        return false
    end
    return waitAlive(0.05)
end

local function hitIntruderWithShovel(player)
    local c = CFG.AntiSteal or {}
    if not packet({ "Shovel", "HitPlayer" }) then
        actionLog("AntiSteal", "ERROR", "missing Networking.Shovel.HitPlayer")
        c.Enabled = false
        return false
    end

    if not equipShovelForAntiSteal() then
        return false
    end
    if not teleportToIntruder(player) then
        return false
    end

    local hits = math.max(tonumber(c.HitsPerTarget) or 2, 1)
    for i = 1, hits do
        if not isAlive() then
            return false
        end
        if not isPlayerInMyGarden(player) then
            actionLog("AntiSteal", "DONE", tostring(player.Name) .. " left garden")
            return true
        end

        local targetRoot = getPlayerRoot(player)
        local root = getRootPart()
        if root and targetRoot then
            root.CFrame = CFrame.lookAt(root.Position, targetRoot.Position)
        end

        if packet({ "Shovel", "SwingShovel" }) then
            firePacket({ "Shovel", "SwingShovel" })
        end
        local ok = firePacket({ "Shovel", "HitPlayer" }, player.UserId)
        actionLog("AntiSteal", ok and "HIT" or "HIT_FAIL", tostring(player.Name) .. " #" .. tostring(i))
        State.LastAntiSteal = os.date("%H:%M:%S") .. " hit " .. tostring(player.Name)
        if not waitAlive(tonumber(c.BetweenHits) or 0.55) then
            return false
        end
    end
    return true
end

-- ============================================================
-- CÁC TÁC VỤ
-- ============================================================

-- Mua hạt
function Runtime.doAutoBuySeed()
    local c = CFG.AutoBuySeed
    if not (c and c.Enabled) then return end
    if Runtime.ShouldYieldForSeedPriority("AutoBuySeed") or Runtime.ShouldYieldForPetPriority("AutoBuySeed") then
        return
    end
    actionLog("AutoBuySeed", "START")
    if not packet({ "SeedShop", "PurchaseSeed" }) then
        logw("AutoBuySeed: thiếu Networking.SeedShop.PurchaseSeed -> tắt.")
        c.Enabled = false
        return
    end

    if type(SeedData) ~= "table" then
        actionLog("AutoBuySeed", "SKIP", "missing SeedData")
        return
    end
    -- Stop Buying Seeds At: tiền hiện tại >= ngưỡng -> ngừng mua hạt (0 = tắt).
    local stopAt = tonumber(c.StopBuyAt) or 0
    if stopAt > 0 and (tonumber(getSheckles()) or 0) >= stopAt then
        actionLog("AutoBuySeed", "SKIP", "money >= StopBuyAt " .. tostring(stopAt))
        return
    end
    local spentThisCycle = 0
    local keep = tonumber(c.KeepSheckles) or 0
    local maxPerSeed = math.max(tonumber(c.MaxPerSeedPerCycle) or 50, 1)

    local function availableMoney()
        return math.max((tonumber(getSheckles()) or 0) - spentThisCycle - keep, 0)
    end

    local function buySeed(seedName, data)
        if type(seedName) ~= "string" or seedName == "" then
            return false
        end
        data = data or getSeedDataByName(seedName)
        if not (data and data.RestockShop) then
            actionLog("AutoBuySeed", "SKIP", tostring(seedName) .. " not in RestockShop SeedData")
            return false
        end

        local price = tonumber(data.PurchasePrice)
        if not price then
            actionLog("AutoBuySeed", "SKIP", tostring(seedName) .. " missing PurchasePrice")
            return false
        end

        -- Seeds To Buy LIMIT: đã SỞ HỮU đủ số hạt này thì không mua thêm (chống mua dư cháy túi).
        -- OwnLimitPerSeed[tên] ưu tiên; nếu không có thì dùng OwnLimit (áp chung mọi hạt). 0 = không cap.
        local cap = 0
        if type(c.OwnLimitPerSeed) == "table" and tonumber(c.OwnLimitPerSeed[seedName]) then
            cap = tonumber(c.OwnLimitPerSeed[seedName])
        elseif tonumber(c.OwnLimit) then
            cap = tonumber(c.OwnLimit)
        end
        if cap > 0 then
            local rep = getPlayerReplica()
            local inv = rep and rep.Data and rep.Data.Inventory
            local ownedSeeds = inv and inv.Seeds
            local have = ownedSeeds and tonumber(ownedSeeds[seedName]) or 0
            if have >= cap then
                actionLog("AutoBuySeed", "SKIP", ("%s owned %d >= limit %d"):format(seedName, have, cap))
                return false
            end
        end

        local remaining = getRemainingSeedStock(seedName)
        if not remaining then
            actionLog("AutoBuySeed", "SKIP", tostring(seedName) .. " missing stock")
            return false
        end
        if remaining < 1 then
            actionLog("AutoBuySeed", "SKIP", tostring(seedName) .. " no stock")
            return false
        end

        local money = availableMoney()
        if money < price then
            actionLog("AutoBuySeed", "SKIP", ("%s need=%s have=%s"):format(seedName, tostring(price), tostring(money)))
            return false
        end

        actionLog("AutoBuySeed", "BUY", ("%s rarity=%s price=%s stock=%s money=%s"):format(
            seedName,
            tostring(data.Rarity),
            tostring(price),
            tostring(remaining),
            tostring(money)
        ))
        local ok = firePacket({ "SeedShop", "PurchaseSeed" }, seedName)
        if ok then
            noteSeedPurchase(seedName)
            spentThisCycle = spentThisCycle + price
            State.SeedsBought = (State.SeedsBought or 0) + 1
            State.LastSeedBuy = os.date("%H:%M:%S") .. " " .. seedName .. " $" .. tostring(price)
            return true
        end
        actionLog("AutoBuySeed", "ERROR", "PurchaseSeed failed: " .. tostring(seedName))
        return false
    end

    local mode = string.lower(tostring(c.Mode or "Smart"))
    local bought = 0

    if mode == "list" or mode == "custom" then
        for _, seedName in ipairs(c.List or {}) do
            if buySeed(seedName) then
                bought = bought + 1
                if not waitAlive(tonumber(c.Delay) or 0.35) then return end
            end
        end
        actionLog("AutoBuySeed", "DONE", "bought=" .. tostring(bought))
        return
    end

    local candidates, reason = buildSeedCandidates(c)
    if #candidates == 0 then
        actionLog("AutoBuySeed", "SKIP", tostring(reason or ("no affordable stocked seeds; money=" .. tostring(getSheckles()))))
        return
    end

    actionLog("AutoBuySeed", "PLAN", ("candidates=%s money=%s keep=%s minRarity=%s"):format(
        tostring(#candidates),
        tostring(getSheckles()),
        tostring(keep),
        tostring(c.MinRarity or "Common")
    ))

    for _, seed in ipairs(candidates) do
        local boughtThisSeed = 0
        while boughtThisSeed < maxPerSeed do
            local remaining = getRemainingSeedStock(seed.Name)
            if not remaining or remaining < 1 then
                break
            end
            if availableMoney() < seed.Price then
                break
            end
            local data = getSeedDataByName(seed.Name)
            if not buySeed(seed.Name, data) then
                break
            end
            bought = bought + 1
            boughtThisSeed = boughtThisSeed + 1
            if not waitAlive(tonumber(c.Delay) or 0.35) then return end
        end
    end

    actionLog("AutoBuySeed", "DONE", "bought=" .. tostring(bought))
end

-- Trồng mọi hạt trong túi
-- Cờ "vườn đầy" theo TÍN HIỆU THẬT của game (server bắn Notification "can't plant more").
-- PlotFullWatcher set; AutoPlant ngừng trồng; AutoShovelReplace đào xong xoá cờ để trồng lại.
Runtime.PlotFullAt = 0
function Runtime.MarkPlotFull()
    Runtime.PlotFullAt = os.clock()
end
function Runtime.ClearPlotFull()
    Runtime.PlotFullAt = 0
end
function Runtime.IsPlotFullSignal()
    local win = tonumber(CFG.AutoShovelReplace and CFG.AutoShovelReplace.PlotFullSignalWindow) or 30
    return (os.clock() - (tonumber(Runtime.PlotFullAt) or 0)) < win
end

function Runtime.doAutoPlant()
    local c = CFG.AutoPlant
    if not (c and c.Enabled) then return end
    if Runtime.ShouldYieldForSeedPriority("AutoPlant") or Runtime.ShouldYieldForPetPriority("AutoPlant") then
        return
    end
    actionLog("AutoPlant", "START")
    if not packet({ "Plant", "PlantSeed" }) then
        logw("AutoPlant: thiếu Networking.Plant.PlantSeed -> tắt.")
        c.Enabled = false
        return
    end
    if not getPlot() then
        actionLog("AutoPlant", "SKIP", "missing plot")
        return
    end

    -- Vườn ĐẦY (game báo "can't plant more") -> ngừng trồng để khỏi spam remote + spam thông báo.
    -- Bật AutoShovelReplace thì nó sẽ đào cây dỏm rồi xoá cờ -> vòng sau trồng tiếp.
    if c.PauseWhenPlotFull ~= false and Runtime.IsPlotFullSignal() then
        actionLog("AutoPlant", "SKIP", "plot full (game: can't plant more)")
        return
    end

    local seeds = getToolsWithAttribute("SeedTool")
    if #seeds == 0 then
        actionLog("AutoPlant", "SKIP", "no seed tools")
        return
    end

    -- LỘ TRÌNH TRỒNG: đếm số cây ĐANG trồng mỗi loại (attribute SeedName của model trong plot.Plants,
    -- xác nhận kaitun.lua:4296) để không trồng quá quota mỗi loại.
    local useQuota = c.UsePlantQuota ~= false and type(c.PlantQuota) == "table"
    local plantedCounts = {}
    if useQuota then
        local plot = getPlot()
        local plantsFolder = plot and plot:FindFirstChild("Plants")
        if plantsFolder then
            for _, m in ipairs(plantsFolder:GetChildren()) do
                if m:IsA("Model") then
                    local sName = m:GetAttribute("SeedName")
                    if type(sName) == "string" and sName ~= "" then
                        plantedCounts[sName] = (plantedCounts[sName] or 0) + 1
                    end
                end
            end
        end
    end
    local plantedThisRun = {}

    -- Seed.Place "Select": CHỈ trồng hạt có tên trong OnlyPlant. Rỗng = trồng tất cả (trừ KeepSeeds).
    local onlyPlant = nil
    if type(c.OnlyPlant) == "table" and next(c.OnlyPlant) ~= nil then
        onlyPlant = {}
        addConfiguredNames(onlyPlant, c.OnlyPlant)
    end

    for _, tool in ipairs(seeds) do
        local seedName = tool:GetAttribute("SeedTool")
        if Runtime.ShouldKeepSeed(seedName, tool) then
            actionLog("AutoPlant", "SKIP", "keep seed " .. tostring(seedName or tool.Name))
            State.LastValuable = os.date("%H:%M:%S") .. " keep seed " .. tostring(seedName or tool.Name)
        elseif onlyPlant and not nameMatchesConfiguredSet(seedName, onlyPlant) then
            actionLog("AutoPlant", "SKIP", "not in Select " .. tostring(seedName or tool.Name))
        else
            -- Quota cho loại này (chỉ giới hạn khi seedName có trong bảng PlantQuota).
            local maxTry = tonumber(c.PlantPerSeed) or 50
            if useQuota and type(seedName) == "string" then
                local quota = tonumber(c.PlantQuota[seedName])
                if quota then
                    local already = (plantedCounts[seedName] or 0) + (plantedThisRun[seedName] or 0)
                    local allowed = quota - already
                    if allowed <= 0 then
                        actionLog("AutoPlant", "SKIP", ("quota %s %d/%d"):format(tostring(seedName), already, quota))
                        maxTry = 0
                    else
                        maxTry = math.min(maxTry, allowed)
                    end
                end
            end

            if maxTry > 0 then
                if not equipTool(tool) then break end
                actionLog("AutoPlant", "TOOL", tostring(tool.Name), "seed=" .. tostring(seedName))
                for _ = 1, maxTry do
                    -- tool có thể bị huỷ khi hết hạt
                    if not (tool and tool.Parent) then break end
                    local pos = randomPlantPosition()
                    if not pos then break end
                    firePacket({ "Plant", "PlantSeed" }, pos, seedName, tool)
                    if type(seedName) == "string" then
                        plantedThisRun[seedName] = (plantedThisRun[seedName] or 0) + 1
                    end
                    if not waitAlive(c.Delay or 0.25) then return end
                end
            end
        end
    end
    actionLog("AutoPlant", "DONE")
end

-- Điểm "xịn" của 1 hạt/cây theo SeedName: lấy giá mua thật trong SeedData.
-- Không có giá thì fallback theo bậc Rarity. Không có gì -> 0.
function Runtime.SeedValueScore(seedName)
    if type(seedName) ~= "string" or seedName == "" then
        return 0
    end
    local data = getSeedDataByName(seedName)
    if not data then
        return 0
    end
    local price = tonumber(data.PurchasePrice)
    if price then
        return price
    end
    local rarity = tostring(data.Rarity or "Common")
    return (RarityScore[rarity] or 0) * 1000
end

-- Vườn đầy mà có hạt xịn hơn cây dỏm -> đào cây dỏm bằng Shovel (UseShovel),
-- để vòng AutoPlant kế tiếp trồng cây xịn vào chỗ trống. KHÔNG đào cây Gold/Rainbow.
function Runtime.doAutoShovelReplace()
    local c = CFG.AutoShovelReplace
    if not (c and c.Enabled) then return end
    if State.AntiStealEngaging or State.SellInProgress then return end
    if Runtime.ShouldYieldForSeedPriority("AutoShovelReplace")
        or Runtime.ShouldYieldForPetPriority("AutoShovelReplace") then
        return
    end

    -- remote thật để đào cây (ShovelController dòng 465/487)
    if not packet({ "Shovel", "UseShovel" }) then
        logw("AutoShovelReplace: thiếu Networking.Shovel.UseShovel -> tắt.")
        c.Enabled = false
        return
    end

    local plot = getPlot()
    if not plot then
        actionLog("AutoShovelReplace", "SKIP", "missing plot")
        return
    end
    local plantsFolder = plot:FindFirstChild("Plants")
    if not plantsFolder then
        actionLog("AutoShovelReplace", "SKIP", "missing Plants folder")
        return
    end

    -- mỗi child trong Plants là 1 cây đã trồng (PlantVisualizerController)
    local plantModels = {}
    for _, m in ipairs(plantsFolder:GetChildren()) do
        if m:IsA("Model") then
            table.insert(plantModels, m)
        end
    end
    local plantCount = #plantModels

    -- LIMIT TREE mode: chạm Limit (PlotFullCount) cây -> đào cây TIER THẤP NHẤT xuống DestroyUntil,
    -- KHÔNG cần hạt xịn trong túi (chỉ dọn bớt cho nhẹ + chừa cây xịn). Chỉ scan nặng khi đã chạm Limit.
    local destroyUntil = tonumber(c.DestroyUntil)
    local limitTarget = tonumber(c.PlotFullCount) or 0
    local limitMode = destroyUntil ~= nil and limitTarget > 0 and plantCount >= limitTarget and plantCount > destroyUntil

    -- Xác định "vườn đầy". Client source KHÔNG có hằng số max cây nên dùng 2 nguồn:
    --   (1) TÍN HIỆU THẬT game: server bắn "can't plant more" -> Runtime.IsPlotFullSignal()
    --   (2) ngưỡng tay PlotFullCount (>0). PlotFullCount=0 => chỉ dựa vào tín hiệu game.
    if c.OnlyWhenPlotFull ~= false and not limitMode then
        local threshold = tonumber(c.PlotFullCount) or 0
        local fullByCount = threshold > 0 and plantCount >= threshold
        local fullBySignal = Runtime.IsPlotFullSignal()
        if not (fullByCount or fullBySignal) then
            if threshold > 0 then
                actionLog("AutoShovelReplace", "SKIP", "not full " .. tostring(plantCount) .. "/" .. tostring(threshold))
            else
                actionLog("AutoShovelReplace", "SKIP", "cho tin hieu 'can't plant more'")
            end
            return
        end
    end

    -- hạt xịn nhất trong túi mà AutoPlant sẽ trồng (bỏ qua rainbow seed nếu đang giữ)
    local bestSeedScore, bestSeedName = -1, nil
    for _, tool in ipairs(getToolsWithAttribute("SeedTool")) do
        local seedName = tool:GetAttribute("SeedTool")
        if not Runtime.ShouldKeepSeed(seedName, tool) then
            local score = Runtime.SeedValueScore(seedName)
            if score > bestSeedScore then
                bestSeedScore = score
                bestSeedName = seedName
            end
        end
    end
    -- Replace mode cần hạt xịn để trồng vào; Limit mode chỉ dọn bớt nên không cần.
    if not bestSeedName and not limitMode then
        actionLog("AutoShovelReplace", "SKIP", "no seed to plant")
        return
    end

    -- tập mutation cần GIỮ (không đào)
    local keepMut = {}
    for _, name in ipairs(c.KeepMutations or {}) do
        keepMut[tostring(name)] = true
    end

    -- SAFE PLANT: chừa lại tối thiểu mỗi loại khi đào. [tên]=N -> luôn để lại >= N cây.
    -- N = 0 -> GIỮ TOÀN BỘ (không đào loại đó). Loại không có trong bảng -> đào tự do.
    local safe = {}
    for k, v in pairs(c.SafePlants or {}) do
        if type(k) == "string" then safe[k] = tonumber(v) or 0 end
    end
    local dugSpecies = {}  -- đếm số cây mỗi loại đã đào trong vòng này

    -- tìm các cây dỏm nhất (đủ điều kiện đào), bỏ cây Gold/Rainbow.
    -- đồng thời đếm TỔNG số cây mỗi loại đang trồng (để biết còn được đào bao nhiêu).
    local speciesCount = {}
    local diggable = {}
    for _, plant in ipairs(plantModels) do
        local sName = plant:GetAttribute("SeedName")
        if type(sName) == "string" and sName ~= "" then
            speciesCount[sName] = (speciesCount[sName] or 0) + 1
        end
        local mut = plant:GetAttribute("Mutation")
        if not (type(mut) == "string" and keepMut[mut]) then
            table.insert(diggable, {
                Plant = plant,
                Name = plant.Name,
                Score = Runtime.SeedValueScore(sName),
                SeedName = sName,
            })
        end
    end
    if #diggable == 0 then
        actionLog("AutoShovelReplace", "SKIP", "no diggable plant (all kept)")
        return
    end
    table.sort(diggable, function(a, b) return a.Score < b.Score end)

    local minGain = tonumber(c.MinScoreGain) or 1.0
    local shovel = getShovelTool()
    if not shovel then
        actionLog("AutoShovelReplace", "SKIP", "missing shovel tool")
        return
    end
    local shovelAttr = shovel:GetAttribute("Shovel")

    -- Limit mode: đào tới khi còn DestroyUntil cây (plantCount - DestroyUntil con). Replace mode: 1 cây/vòng.
    local maxReplace
    if limitMode then
        maxReplace = math.max(plantCount - destroyUntil, 0)
    else
        maxReplace = math.max(tonumber(c.MaxReplacePerCycle) or 1, 1)
    end
    local dug = 0
    for _, entry in ipairs(diggable) do
        if dug >= maxReplace then break end
        -- Replace mode: chỉ đào nếu hạt mới xịn hơn cây dỏm (MinScoreGain). Limit mode: đào để dọn,
        -- không cần hạt xịn -> bỏ qua điều kiện này.
        if not limitMode and bestSeedScore <= entry.Score * minGain then
            break -- danh sách đã sort tăng dần -> các cây sau còn xịn hơn
        end

        -- SAFE PLANT: kiểm tra còn được đào loại này không (giữ tối thiểu).
        local canDig = true
        local keep = entry.SeedName and safe[entry.SeedName]
        if keep ~= nil then
            local remain = (speciesCount[entry.SeedName] or 0) - (dugSpecies[entry.SeedName] or 0)
            if keep <= 0 or remain <= keep then
                canDig = false  -- 0 = giữ toàn bộ; hoặc đào nữa là dưới mức chừa
                actionLog("AutoShovelReplace", "SAFE", ("keep %s (con %d, chua %d)"):format(
                    tostring(entry.SeedName), remain, keep <= 0 and remain or keep))
            end
        end

        if canDig and entry.Plant and entry.Plant.Parent then
            if not equipTool(shovel) then
                actionLog("AutoShovelReplace", "SKIP", "cannot equip shovel")
                return
            end
            -- fruitId = "" -> đào cả cây (ShovelController truyền u99 = fruitId or "")
            local ok = firePacket({ "Shovel", "UseShovel" }, entry.Name, "", shovelAttr, shovel)
            dug = dug + 1
            if entry.SeedName then
                dugSpecies[entry.SeedName] = (dugSpecies[entry.SeedName] or 0) + 1
            end
            local target = limitMode and ("limit->" .. tostring(destroyUntil)) or tostring(bestSeedName)
            State.LastShovelReplace = os.date("%H:%M:%S")
                .. (" dig %s($%s)->%s"):format(
                    tostring(entry.SeedName or "?"), tostring(math.floor(entry.Score)), target)
            actionLog("AutoShovelReplace", ok and "DONE" or "ERROR",
                ("dig %s -> %s"):format(tostring(entry.SeedName or "?"), target))
            if not waitAlive(0.3) then return end
        end
    end

    if dug > 0 then
        -- Đã đào -> còn chỗ trống, xoá cờ đầy để AutoPlant trồng cây xịn vào ngay vòng sau.
        Runtime.ClearPlotFull()
    else
        actionLog("AutoShovelReplace", "SKIP", limitMode and "all remaining safe" or "seed not better than weakest plant")
    end
end

-- ============================================================
-- TỔNG PLOTS + parse "%" (mục 1). Source client KHÔNG có hằng số max cây thật -> dùng:
--   CFG.TotalPlots (chồng set) HOẶC số part PlantArea (tag PlantArea, raycast trồng).
-- ============================================================
Runtime.GetTotalPlots = function()
    local n = tonumber(CFG.TotalPlots) or 0
    if n > 0 then return n end
    return #getPlantAreaParts()
end
-- "X%" -> làm tròn X% * totalPlots ; số -> số ; khác -> nil. Resolve lúc RUNTIME (plot đã load).
Runtime.ResolvePlotCount = function(value, totalPlots)
    if type(value) == "string" then
        local pct = value:match("^%s*([%d%.]+)%s*%%%s*$")
        if pct then
            totalPlots = totalPlots or Runtime.GetTotalPlots()
            if totalPlots and totalPlots > 0 then
                return math.floor((tonumber(pct) / 100) * totalPlots + 0.5)
            end
            return nil
        end
    end
    return tonumber(value)
end

-- ============================================================
-- TRIM TO QUOTA (mục 6): loại nào ĐANG trồng VƯỢT PlanQuota -> đào DƯ cho về đúng quota.
-- KHÔNG xoá hết plot. Gate tuỳ chọn bằng Limit/DestroyUntil (số HOẶC "%", tính theo TotalPlots):
--   - Limit: chỉ bắt đầu cleanup khi tổng cây >= Limit (0/nil = trim liên tục).
--   - DestroyUntil: dừng cleanup khi tổng cây <= DestroyUntil.
-- Quota: CFG.PlanQuota -> TrimToQuota.Quota -> AutoPlant.PlantQuota. KHÔNG đào cây Gold/Rainbow.
-- Remote thật: Shovel.UseShovel (giống AutoShovelReplace).
-- ============================================================
function Runtime.doTrimToQuota()
    local c = CFG.TrimToQuota
    if not (c and c.Enabled) then return end
    if State.AntiStealEngaging or State.SellInProgress then return end
    if Runtime.ShouldYieldForSeedPriority and Runtime.ShouldYieldForSeedPriority("TrimToQuota") then return end
    if not packet({ "Shovel", "UseShovel" }) then
        logw("TrimToQuota: thieu Networking.Shovel.UseShovel -> tat.")
        c.Enabled = false
        return
    end

    local quota = (type(CFG.PlanQuota) == "table" and next(CFG.PlanQuota) and CFG.PlanQuota)
        or (type(c.Quota) == "table" and next(c.Quota) and c.Quota)
        or (CFG.AutoPlant and type(CFG.AutoPlant.PlantQuota) == "table" and CFG.AutoPlant.PlantQuota)
    if not (quota and next(quota)) then
        actionLog("TrimToQuota", "SKIP", "khong co PlanQuota")
        return
    end

    local plot = getPlot()
    local plantsFolder = plot and plot:FindFirstChild("Plants")
    if not plantsFolder then
        actionLog("TrimToQuota", "SKIP", "missing Plants folder")
        return
    end

    -- mutation cần GIỮ (không bao giờ đào)
    local keepMut = {}
    local kmList = (type(c.KeepMutations) == "table" and c.KeepMutations)
        or (CFG.AutoShovelReplace and CFG.AutoShovelReplace.KeepMutations)
        or { "Gold", "Rainbow" }
    for _, name in ipairs(kmList) do keepMut[tostring(name)] = true end

    -- đếm tổng + theo loại + gom cây ĐÀO ĐƯỢC (không phải mutation giữ)
    local plantTotal, bySpecies = 0, {}
    for _, m in ipairs(plantsFolder:GetChildren()) do
        if m:IsA("Model") then
            local sName = m:GetAttribute("SeedName")
            if type(sName) == "string" and sName ~= "" then
                plantTotal = plantTotal + 1
                local b = bySpecies[sName]
                if not b then b = { count = 0, diggable = {} }; bySpecies[sName] = b end
                b.count = b.count + 1
                local mut = m:GetAttribute("Mutation")
                if not (type(mut) == "string" and keepMut[mut]) then
                    table.insert(b.diggable, m)
                end
            end
        end
    end

    -- Gate Limit/DestroyUntil (số hoặc "%").
    local totalPlots = Runtime.GetTotalPlots()
    local limit = Runtime.ResolvePlotCount(c.Limit, totalPlots) or 0
    local destroyUntil = Runtime.ResolvePlotCount(c.DestroyUntil, totalPlots)
    if limit > 0 and plantTotal < limit then
        actionLog("TrimToQuota", "SKIP", ("chua cham Limit %d/%d"):format(plantTotal, limit))
        return
    end

    local shovel = getShovelTool()
    if not shovel then
        actionLog("TrimToQuota", "SKIP", "missing shovel tool")
        return
    end
    local shovelAttr = shovel:GetAttribute("Shovel")

    local maxPerCycle = math.max(tonumber(c.MaxPerCycle) or 20, 1)
    local liveTotal = plantTotal
    local dug = 0
    for sName, b in pairs(bySpecies) do
        if dug >= maxPerCycle then break end
        if destroyUntil and liveTotal <= destroyUntil then break end   -- đã về DestroyUntil -> dừng
        local cap = tonumber(quota[sName])
        if cap and b.count > cap then
            local excess = math.min(b.count - cap, #b.diggable)   -- chỉ đào phần DƯ, chừa cây mutation
            for i = 1, excess do
                if dug >= maxPerCycle then break end
                if destroyUntil and liveTotal <= destroyUntil then break end
                local plant = b.diggable[i]
                if plant and plant.Parent then
                    if not equipTool(shovel) then
                        actionLog("TrimToQuota", "SKIP", "cannot equip shovel")
                        return
                    end
                    -- fruitId="" -> đào cả cây
                    local ok = firePacket({ "Shovel", "UseShovel" }, plant.Name, "", shovelAttr, shovel)
                    if ok then
                        dug = dug + 1
                        liveTotal = liveTotal - 1
                        State.LastShovelReplace = os.date("%H:%M:%S") .. (" trim %s ->%d"):format(tostring(sName), cap)
                        actionLog("TrimToQuota", "DIG", ("%s con %d/%d"):format(tostring(sName), b.count - i, cap))
                    end
                    if not waitAlive(0.3) then return end
                end
            end
        end
    end

    if dug > 0 then
        Runtime.ClearPlotFull()   -- còn chỗ trống -> AutoPlant trồng lại đúng quota
        actionLog("TrimToQuota", "DONE", ("dug=%d plants=%d/%s"):format(dug, liveTotal, tostring(totalPlots)))
    end
end

-- Mua gear

local GearPurchaseAssumed = {
    RestockKey = nil,
    Counts = {},
}

local function getGearShop()
    local stockValues = ReplicatedStorage:FindFirstChild("StockValues")
    return stockValues and stockValues:FindFirstChild("GearShop")
end

local function getGearRestockKey()
    local gearShop = getGearShop()
    local lastRestock = gearShop and gearShop:FindFirstChild("UnixLastRestock")
    if not lastRestock then
        return "unknown"
    end
    local ok, value = pcall(function()
        return lastRestock.Value
    end)
    return ok and tostring(value) or "unknown"
end

local function resetGearAssumptionsIfNeeded()
    local restockKey = getGearRestockKey()
    if GearPurchaseAssumed.RestockKey ~= restockKey then
        GearPurchaseAssumed.RestockKey = restockKey
        GearPurchaseAssumed.Counts = {}
    end
end

local function getPurchasedRestockCount(key, itemName)
    local replica = getPlayerReplica()
    local data = replica and replica.Data
    local purchased = data and data.PurchasedThisRestock
    local bucket = purchased and purchased[key]
    if not bucket then
        return nil
    end
    return tonumber(bucket[itemName]) or 0
end

local function getGearStockValue(itemName)
    local gearShop = getGearShop()
    local items = gearShop and gearShop:FindFirstChild("Items")
    local item = items and items:FindFirstChild(itemName)
    if not item then
        return nil
    end
    local ok, value = pcall(function()
        return item.Value
    end)
    return ok and tonumber(value) or nil
end

local function getRemainingGearStock(itemName)
    resetGearAssumptionsIfNeeded()
    local maxStock = getGearStockValue(itemName)
    local purchased = getPurchasedRestockCount("Gears", itemName)
    if maxStock == nil then
        return nil
    end
    purchased = purchased or 0
    local assumed = GearPurchaseAssumed.Counts[itemName] or 0
    return math.max(maxStock - purchased - assumed, 0)
end

local function noteGearPurchase(itemName)
    resetGearAssumptionsIfNeeded()
    GearPurchaseAssumed.Counts[itemName] = (GearPurchaseAssumed.Counts[itemName] or 0) + 1
end

local function getEquippableGearState()
    if not packet({ "GearShop", "RequestEquippableState" }) then
        return nil
    end
    local ok, state = firePacket({ "GearShop", "RequestEquippableState" })
    if ok and type(state) == "table" then
        return state
    end
    return nil
end

local function listToSet(list)
    local set = {}
    if type(list) == "table" then
        for _, name in ipairs(list) do
            if type(name) == "string" and name ~= "" then
                set[name] = true
            end
        end
    end
    return set
end

local function listToPriority(list)
    local priority = {}
    if type(list) == "table" then
        local total = #list
        for index, name in ipairs(list) do
            if type(name) == "string" and name ~= "" then
                priority[name] = (total - index + 1) * 100
            end
        end
    end
    return priority
end

local function isSprinklerGear(data)
    if type(data) ~= "table" then
        return false
    end
    return string.find(tostring(data.ItemName or ""), "Sprinkler", 1, true) ~= nil
        or string.find(tostring(data.ItemType or ""), "Sprinkler", 1, true) ~= nil
end

local function getGearPriority(data, priorityMap, c)
    local itemName = data and data.ItemName
    local priority = itemName and priorityMap[itemName] or 0
    if c and c.PrioritizeSprinklers ~= false and isSprinklerGear(data) then
        priority = math.max(priority, 50)
    end
    return priority
end

local function buildGearCandidates(c, gearState)
    local out = {}
    if not (GearShopData and type(GearShopData.Data) == "table") then
        return out, "missing GearShopData"
    end
    local money = tonumber(getSheckles()) or 0
    local keep = tonumber(c.KeepSheckles) or 0
    local budget = math.max(money - keep, 0)
    local minRarity = c.MinRarity or "Common"
    local owned = gearState and gearState.OwnedEquippableGears
    local excluded = listToSet(c.ExcludeList)
    local priorityMap = listToPriority(c.PriorityList)

    for _, data in ipairs(GearShopData.Data) do
        if type(data) == "table" and not data.RobuxOnly and type(data.ItemName) == "string" and not excluded[data.ItemName] then
            local price = tonumber(data.Cost)
            local rarity = tostring(data.Rarity or "")
            local priority = getGearPriority(data, priorityMap, c)
            local rarityOk = rarityAllowed(rarity, minRarity)
            local priorityOk = priority > 0 and c.AllowPriorityBelowMinRarity ~= false
            if price and price <= budget and (rarityOk or priorityOk) then
                local remaining = nil
                if data.EquippableGear == true then
                    if type(owned) == "table" then
                        remaining = owned[data.ItemName] and 0 or 1
                    end
                elseif data.RestockChance then
                    remaining = getRemainingGearStock(data.ItemName)
                end
                if remaining and remaining > 0 then
                    table.insert(out, {
                        Name = data.ItemName,
                        Price = price,
                        Rarity = rarity,
                        RarityScore = RarityScore[rarity] or 0,
                        Stock = remaining,
                        Equippable = data.EquippableGear == true,
                        Priority = priority,
                    })
                end
            end
        end
    end

    table.sort(out, function(a, b)
        if a.Priority ~= b.Priority then
            return a.Priority > b.Priority
        end
        if a.RarityScore ~= b.RarityScore then
            return a.RarityScore > b.RarityScore
        end
        return a.Price > b.Price
    end)
    return out
end

function Runtime.doAutoBuyGear()
    local c = CFG.AutoBuyGear
    if not (c and c.Enabled) then return end
    if Runtime.ShouldYieldForSeedPriority("AutoBuyGear") or Runtime.ShouldYieldForPetPriority("AutoBuyGear") then
        return
    end
    if not packet({ "GearShop", "PurchaseGear" }) then
        logw("AutoBuyGear: thieu Networking.GearShop.PurchaseGear -> tat.")
        c.Enabled = false
        return
    end
    if CFG.AutoBuySeed and CFG.AutoBuySeed.Enabled then
        local seedCandidates = buildSeedCandidates(CFG.AutoBuySeed)
        if type(seedCandidates) == "table" and #seedCandidates > 0 then
            actionLog("AutoBuyGear", "SKIP", "seed first " .. tostring(seedCandidates[1].Name))
            return
        end
    end

    local spentThisCycle = 0
    local keep = tonumber(c.KeepSheckles) or 0
    local maxPerItem = math.max(tonumber(c.MaxPerItemPerCycle) or 10, 1)
    local excludedGear = listToSet(c.ExcludeList)
    local function availableMoney()
        return math.max((tonumber(getSheckles()) or 0) - spentThisCycle - keep, 0)
    end
    local function buyGear(name, price)
        if type(name) ~= "string" or name == "" then return false end
        if excludedGear[name] then
            actionLog("AutoBuyGear", "SKIP", "blocked " .. tostring(name))
            return false
        end
        price = tonumber(price) or 0
        if price > 0 and availableMoney() < price then
            return false
        end
        actionLog("AutoBuyGear", "BUY", price > 0 and (name .. " $" .. tostring(price)) or name)
        local ok = firePacket({ "GearShop", "PurchaseGear" }, name)
        if ok then
            noteGearPurchase(name)
            spentThisCycle = spentThisCycle + price
            return true
        end
        return false
    end

    local mode = string.lower(tostring(c.Mode or "Smart"))
    local bought = 0
    if mode == "list" or mode == "custom" then
        for _, gearName in ipairs(c.List or {}) do
            if buyGear(gearName, 0) then
                bought = bought + 1
                if not waitAlive(tonumber(c.Delay) or 0.5) then return end
            end
        end
        actionLog("AutoBuyGear", "DONE", "b=" .. tostring(bought))
        return
    end

    local candidates, reason = buildGearCandidates(c, getEquippableGearState())
    if #candidates == 0 then
        actionLog("AutoBuyGear", "SKIP", tostring(reason or "no gear"))
        return
    end
    actionLog("AutoBuyGear", "PLAN", ("n=%s money=%s"):format(tostring(#candidates), tostring(getSheckles())))

    for _, gear in ipairs(candidates) do
        local boughtThis = 0
        while boughtThis < maxPerItem do
            local remaining = gear.Equippable and (boughtThis == 0 and 1 or 0) or getRemainingGearStock(gear.Name)
            if not remaining or remaining < 1 then break end
            if availableMoney() < gear.Price then break end
            if not buyGear(gear.Name, gear.Price) then break end
            bought = bought + 1
            boughtThis = boughtThis + 1
            if gear.Equippable then break end
            if not waitAlive(tonumber(c.Delay) or 0.5) then return end
        end
    end

    actionLog("AutoBuyGear", "DONE", "b=" .. tostring(bought))
end

local CratePurchaseAssumed = {
    RestockKey = nil,
    Counts = {},
}

local function getCrateShop()
    local stockValues = ReplicatedStorage:FindFirstChild("StockValues")
    return stockValues and stockValues:FindFirstChild("CrateShop")
end

local function getCrateRestockKey()
    local crateShop = getCrateShop()
    local lastRestock = crateShop and crateShop:FindFirstChild("UnixLastRestock")
    if not lastRestock then
        return "unknown"
    end
    local ok, value = pcall(function()
        return lastRestock.Value
    end)
    return ok and tostring(value) or "unknown"
end

local function resetCrateAssumptionsIfNeeded()
    local restockKey = getCrateRestockKey()
    if CratePurchaseAssumed.RestockKey ~= restockKey then
        CratePurchaseAssumed.RestockKey = restockKey
        CratePurchaseAssumed.Counts = {}
    end
end

local function getCrateStockValue(crateName)
    local crateShop = getCrateShop()
    local items = crateShop and crateShop:FindFirstChild("Items")
    local item = items and items:FindFirstChild(crateName)
    if not item then
        return nil
    end
    local ok, value = pcall(function()
        return item.Value
    end)
    return ok and tonumber(value) or nil
end

local function getRemainingCrateStock(crateName)
    resetCrateAssumptionsIfNeeded()
    local maxStock = getCrateStockValue(crateName)
    local purchased = getPurchasedRestockCount("Crates", crateName)
    if maxStock == nil then
        return nil
    end
    purchased = purchased or 0
    local assumed = CratePurchaseAssumed.Counts[crateName] or 0
    return math.max(maxStock - purchased - assumed, 0)
end

local function noteCratePurchase(crateName)
    resetCrateAssumptionsIfNeeded()
    CratePurchaseAssumed.Counts[crateName] = (CratePurchaseAssumed.Counts[crateName] or 0) + 1
end

local function getCrateDataByName(crateName)
    if not (CrateData and type(CrateData.GetData) == "function") then
        return nil
    end
    local ok, data = pcall(CrateData.GetData, crateName)
    if ok then
        return data
    end
    return nil
end

local function buildCrateCandidates(c)
    local out = {}
    if not (CrateData and type(CrateData.GetAllCrates) == "function") then
        return out, "missing CrateData"
    end
    local ok, crates = pcall(CrateData.GetAllCrates)
    if not ok or type(crates) ~= "table" then
        return out, "bad CrateData"
    end

    local money = tonumber(getSheckles()) or 0
    local keep = tonumber(c.KeepSheckles) or 0
    local budget = math.max(money - keep, 0)
    local minRarity = c.MinRarity or "Common"

    for _, data in ipairs(crates) do
        if type(data) == "table" and data.RestockChance and type(data.Name) == "string" then
            local price = tonumber(data.Cost)
            local rarity = tostring(data.Rarity or "")
            if price and price <= budget and rarityAllowed(rarity, minRarity) then
                local remaining = getRemainingCrateStock(data.Name)
                if remaining and remaining > 0 then
                    table.insert(out, {
                        Name = data.Name,
                        Price = price,
                        Rarity = rarity,
                        RarityScore = RarityScore[rarity] or 0,
                        Stock = remaining,
                        RestockChance = tonumber(data.RestockChance) or 0,
                    })
                end
            end
        end
    end

    table.sort(out, function(a, b)
        if a.RarityScore ~= b.RarityScore then
            return a.RarityScore > b.RarityScore
        end
        if a.RestockChance ~= b.RestockChance then
            return a.RestockChance < b.RestockChance
        end
        return a.Price > b.Price
    end)
    return out
end

function Runtime.doAutoBuyCrate()
    local c = CFG.AutoBuyCrate
    if not (c and c.Enabled) then return end
    if Runtime.ShouldYieldForSeedPriority("AutoBuyCrate") or Runtime.ShouldYieldForPetPriority("AutoBuyCrate") then
        return
    end
    if not packet({ "CrateShop", "PurchaseCrate" }) then
        logw("AutoBuyCrate: thieu Networking.CrateShop.PurchaseCrate -> tat.")
        c.Enabled = false
        return
    end

    if CFG.AutoBuySeed and CFG.AutoBuySeed.Enabled then
        local seedCandidates = buildSeedCandidates(CFG.AutoBuySeed)
        if type(seedCandidates) == "table" and #seedCandidates > 0 then
            actionLog("AutoBuyCrate", "SKIP", "seed first " .. tostring(seedCandidates[1].Name))
            return
        end
    end
    if CFG.AutoBuyGear and CFG.AutoBuyGear.Enabled then
        local gearCandidates = buildGearCandidates(CFG.AutoBuyGear, getEquippableGearState())
        if type(gearCandidates) == "table" and #gearCandidates > 0 then
            actionLog("AutoBuyCrate", "SKIP", "gear first " .. tostring(gearCandidates[1].Name))
            return
        end
    end

    local spentThisCycle = 0
    local keep = tonumber(c.KeepSheckles) or 0
    local maxPerItem = math.max(tonumber(c.MaxPerItemPerCycle) or 3, 1)
    local function availableMoney()
        return math.max((tonumber(getSheckles()) or 0) - spentThisCycle - keep, 0)
    end
    local function buyCrate(crateName, price)
        if type(crateName) ~= "string" or crateName == "" then return false end
        local data = getCrateDataByName(crateName)
        price = tonumber(price) or tonumber(data and data.Cost) or 0
        if price > 0 and availableMoney() < price then
            return false
        end
        local remaining = getRemainingCrateStock(crateName)
        if remaining and remaining < 1 then
            return false
        end
        actionLog("AutoBuyCrate", "BUY", price > 0 and (crateName .. " $" .. tostring(price)) or crateName)
        local ok = firePacket({ "CrateShop", "PurchaseCrate" }, crateName)
        if ok then
            noteCratePurchase(crateName)
            spentThisCycle = spentThisCycle + price
            State.LastCrate = os.date("%H:%M:%S") .. " " .. crateName
            return true
        end
        return false
    end

    local bought = 0
    local mode = string.lower(tostring(c.Mode or "Smart"))
    if mode == "list" or mode == "custom" then
        for _, crateName in ipairs(c.List or {}) do
            if buyCrate(crateName, 0) then
                bought = bought + 1
                if not waitAlive(tonumber(c.Delay) or 0.5) then return end
            end
        end
        if bought > 0 then
            actionLog("AutoBuyCrate", "DONE", "b=" .. tostring(bought))
        end
        return
    end

    local candidates, reason = buildCrateCandidates(c)
    if #candidates == 0 then
        actionLog("AutoBuyCrate", "SKIP", tostring(reason or "no crate"))
        return
    end
    actionLog("AutoBuyCrate", "PLAN", ("n=%s money=%s"):format(tostring(#candidates), tostring(getSheckles())))

    for _, crate in ipairs(candidates) do
        local boughtThis = 0
        while boughtThis < maxPerItem do
            local remaining = getRemainingCrateStock(crate.Name)
            if not remaining or remaining < 1 then break end
            if availableMoney() < crate.Price then break end
            if not buyCrate(crate.Name, crate.Price) then break end
            bought = bought + 1
            boughtThis = boughtThis + 1
            if not waitAlive(tonumber(c.Delay) or 0.5) then return end
        end
    end

    if bought > 0 then
        actionLog("AutoBuyCrate", "DONE", "b=" .. tostring(bought))
    end
end

-- Equip 1 gear
function Runtime.doAutoEquipGear()
    local c = CFG.AutoEquipGear
    if not (c and c.Enabled) then return end
    if type(c.Gear) ~= "string" or c.Gear == "" then return end
    actionLog("AutoEquipGear", "START", c.Gear)
    if not packet({ "GearShop", "EquipGear" }) then
        logw("AutoEquipGear: thiếu Networking.GearShop.EquipGear -> tắt.")
        c.Enabled = false
        return
    end
    firePacket({ "GearShop", "EquipGear" }, c.Gear)
    actionLog("AutoEquipGear", "DONE", c.Gear)
end

local function getHarvestPromptModel(prompt)
    local parent = prompt and prompt.Parent
    return parent and parent:FindFirstAncestorWhichIsA("Model") or nil
end

local function getHarvestPromptPosition(prompt)
    if not prompt then
        return nil
    end
    local parent = prompt.Parent
    if parent and parent:IsA("BasePart") then
        return parent.Position
    end
    local model = getHarvestPromptModel(prompt)
    if model then
        local ok, pivot = pcall(function()
            return model:GetPivot()
        end)
        if ok and pivot then
            return pivot.Position
        end
    end
    return nil
end

local function teleportToHarvestPrompt(prompt, c)
    if c.TeleportToFruit == false then
        return false
    end

    local root = getRootPart()
    local pos = getHarvestPromptPosition(prompt)
    if not root or not pos then
        return false
    end

    local maxDistance = tonumber(prompt.MaxActivationDistance) or 10
    if (root.Position - pos).Magnitude <= math.max(maxDistance - 1, 3) then
        return false
    end

    local direction = root.Position - pos
    if direction.Magnitude < 0.001 then
        direction = Vector3.new(0, 0, -1)
    end
    local distance = tonumber(c.TeleportDistance) or 4
    local yOffset = tonumber(c.TeleportYOffset) or 2
    local targetPos = pos + direction.Unit * distance + Vector3.new(0, yOffset, 0)
    root.CFrame = CFrame.lookAt(targetPos, pos)
    return waitAlive(tonumber(c.TeleportWait) or 0.05)
end

local function triggerHarvestPrompt(prompt, extraHold)
    if not (prompt and prompt:IsA("ProximityPrompt") and prompt:IsDescendantOf(workspace)) then
        return false
    end
    -- ƯU TIÊN fireproximityprompt (executor): claim TỨC THÌ ĐÚNG 1 prompt được truyền vào,
    -- KHÔNG đụng prompt khác (đây là method chồng test "ấn 1 cái claim luôn"). Vì script đã chọn
    -- sẵn ĐÚNG prompt của seed/quả rồi nên fire 1 cái này là an toàn, không kích nhầm mua pet/UI.
    if type(fireproximityprompt) == "function" then
        local ok = pcall(fireproximityprompt, prompt)
        if ok then
            -- nhịp nhỏ cho server xử lý (seed quý đặt extraHold lớn nhưng fireproximityprompt là
            -- instant nên chỉ cần chờ ngắn; verify item biến mất do vòng claim lo).
            waitAlive(math.min(math.max(tonumber(extraHold) or 0.05, 0.05), 0.3))
            return true
        end
    end
    -- Fallback: giả lập GIỮ phím (InputHoldBegin/End) nếu executor không có fireproximityprompt.
    local ok = pcall(function()
        prompt:InputHoldBegin()
    end)
    if not ok then
        return false
    end
    local hold = tonumber(prompt.HoldDuration) or 0
    waitAlive(math.max(hold, 0) + (tonumber(extraHold) or 0.05))
    pcall(function()
        prompt:InputHoldEnd()
    end)
    return true
end

-- Thu hoạch quả chín trong plot mình

-- Chấm "điểm giá trị" 1 quả còn trên cây để AutoCollect ưu tiên hái quả đáng tiền trước.
-- Dùng đúng công thức bán thật của game: Runtime.FruitValueCalc(FruitName, SizeMultiplier, Mutation, player, DecayAlpha)
-- (ReplicatedStorage SharedModules.FruitValueCalc -> load tại Runtime.FruitValueCalc).
-- Attribute trên model quả (xác nhận FruitVisualizerController + HarvestPromptLabelController):
--   CorePartName = tên cây/quả ; SizeMulti = hệ số kích thước ; Mutation = chuỗi mutation ; DecayAlpha = độ héo (có thể nil).
-- Thiếu data hoặc module chưa load -> trả 0 (an toàn: chỉ mất ưu tiên, KHÔNG crash vòng AutoCollect).
Runtime.FruitCollectScore = function(model)
    local calc = Runtime.FruitValueCalc
    if type(calc) ~= "function" or not model then
        return 0
    end
    local fruitName = model:GetAttribute("CorePartName")
        or model:GetAttribute("FruitName")
        or model:GetAttribute("SeedName")
    if type(fruitName) ~= "string" or fruitName == "" then
        return 0
    end
    -- SizeMulti phải là số (FruitValueCalc làm size^2.65, nil sẽ văng lỗi) -> mặc định 1 như game.
    local sizeMult = tonumber(model:GetAttribute("SizeMulti"))
        or tonumber(model:GetAttribute("SizeMultiplier"))
        or 1
    local mutation = model:GetAttribute("Mutation")
    local decay = tonumber(model:GetAttribute("DecayAlpha"))
    local ok, value = pcall(calc, fruitName, sizeMult, mutation, LocalPlayer, decay)
    if ok and type(value) == "number" then
        return value
    end
    return 0
end

-- Override collect flow: stay in own garden, batch CollectFruit remote fires, no fruit teleport.
function Runtime.doAutoCollect()
    local c = CFG.AutoCollect
    if not (c and c.Enabled) then return end
    if Runtime.ShouldYieldForSeedPriority("AutoCollect") or Runtime.ShouldYieldForPetPriority("AutoCollect") then
        return
    end
    -- Wait For Mutations: nếu có list, CHỈ hái quả mang 1 trong các mutation này (chờ quả thường mutate).
    -- Rỗng = hái bình thường. So khớp dạng "chứa" để bắt cả combo (vd "Gold+Wet").
    local wantMutList, waitMutActive = {}, false
    for _, m in ipairs(type(c.WaitForMutations) == "table" and c.WaitForMutations or {}) do
        if type(m) == "string" and m ~= "" then
            table.insert(wantMutList, string.lower(m))
            waitMutActive = true
        end
    end
    if not packet({ "Garden", "CollectFruit" }) then
        logw("AutoCollect: thieu Networking.Garden.CollectFruit -> tat.")
        c.Enabled = false
        return
    end

    local plot = getPlot()
    if not plot then
        actionLog("AutoCollect", "SKIP", "no plot")
        return
    end
    if State.AntiStealEngaging or State.SellInProgress then
        actionLog("AutoCollect", "SKIP", State.SellInProgress and "selling" or "guard")
        return
    end
    if c.StayInGarden ~= false and LocalPlayer:GetAttribute("IsInOwnGarden") ~= true then
        teleportToGardenHome("AutoCollect", 0.1)
    end
    if isInventoryFull() and c.PauseWhenFull ~= false then
        local _, cnt, mx = getFruitFill()
        actionLog("AutoCollect", "PAUSE_FULL", cnt and (tostring(cnt) .. "/" .. tostring(mx)) or "full")
        return
    end

    local tagged = CollectionService:GetTagged("HarvestPrompt")
    local candidates = {}
    local root = getRootPart()
    local inPlot = 0
    for _, prompt in ipairs(tagged) do
        if prompt:IsA("ProximityPrompt") and prompt:IsDescendantOf(plot) then
            inPlot = inPlot + 1
            local model = getHarvestPromptModel(prompt)
            if model then
                local pos = getHarvestPromptPosition(prompt)
                local promptParent = prompt.Parent
                local plantId = model:GetAttribute("PlantId")
                    or prompt:GetAttribute("PlantId")
                    or (promptParent and promptParent:GetAttribute("PlantId"))
                local fruitId = model:GetAttribute("FruitId")
                    or prompt:GetAttribute("FruitId")
                    or (promptParent and promptParent:GetAttribute("FruitId"))
                local mutOk = not waitMutActive
                if waitMutActive then
                    local mut = model:GetAttribute("Mutation")
                    if type(mut) == "string" then
                        local ml = string.lower(mut)
                        for _, w in ipairs(wantMutList) do
                            if ml:find(w, 1, true) then mutOk = true break end
                        end
                    end
                end
                if mutOk then
                table.insert(candidates, {
                    Prompt = prompt,
                    -- PlantId có thể nil (quả trên cây cao to) -> không bắn remote được,
                    -- vẫn hái được bằng cách teleport tới + kích prompt thật.
                    PlantId = plantId,
                    FruitId = fruitId,
                    Pos = pos,
                    Distance = root and pos and (root.Position - pos).Magnitude or 999999,
                    Score = Runtime.FruitCollectScore(model),
                })
                end
            end
        end
    end

    -- Ưu tiên hái quả GIÁ TRỊ CAO trước; cùng giá trị thì hái quả gần trước.
    table.sort(candidates, function(a, b)
        if c.PrioritizeValuable ~= false and a.Score ~= b.Score then
            return a.Score > b.Score
        end
        return a.Distance < b.Distance
    end)

    local collected = 0
    local prompted = 0
    local teleported = 0
    local maxPerCycle = math.max(tonumber(c.MaxPerCycle) or 120, 1)
    local maxTeleports = math.max(tonumber(c.MaxTeleportsPerCycle) or 4, 0)
    local maxValuableTp = math.max(tonumber(c.MaxValuableTeleports) or 8, 0)
    local minScore = tonumber(c.MinFruitScore) or 0

    for _, item in ipairs(candidates) do
        if collected >= maxPerCycle then break end
        -- Bỏ quả quá rẻ nếu chồng đặt MinFruitScore > 0. Danh sách đã sort giá-giảm-dần
        -- nên gặp quả dưới ngưỡng là các quả sau còn rẻ hơn -> dừng luôn.
        if minScore > 0 and item.Score < minScore then
            break
        end
        if item.Prompt and item.Prompt:IsDescendantOf(workspace) then
            local pos = item.Pos or getHarvestPromptPosition(item.Prompt)
            local promptRange = tonumber(item.Prompt.MaxActivationDistance) or 10
            local rootNow = getRootPart()
            local dist = rootNow and pos and (rootNow.Position - pos).Magnitude or 999999
            local valuable = (item.Score or 0) > 0
            local farFromFruit = dist > math.max(promptRange - 1, 3)

            -- Quả xịn ở xa/trên cao (cây cao to) -> teleport lại gần để chắc chắn hái được.
            -- Đường này độc lập với TeleportToFruit (đang bị tắt cứng), bật bằng TeleportToValuable.
            if c.TeleportToValuable ~= false and valuable and teleported < maxValuableTp and farFromFruit then
                if teleportToHarvestPrompt(item.Prompt, c) then
                    teleported = teleported + 1
                    rootNow = getRootPart()
                    dist = rootNow and pos and (rootNow.Position - pos).Magnitude or 999999
                end
            elseif c.TeleportToFruit ~= false and teleported < maxTeleports and farFromFruit then
                if teleportToHarvestPrompt(item.Prompt, c) then
                    teleported = teleported + 1
                    rootNow = getRootPart()
                    dist = rootNow and pos and (rootNow.Position - pos).Magnitude or 999999
                end
            end

            if item.PlantId and firePacket({ "Garden", "CollectFruit" }, item.PlantId, item.FruitId or "") then
                collected = collected + 1
            end

            -- Đứng gần thì kích prompt thật (chắc ăn, kể cả khi remote trượt quả trên cao).
            local nearNow = dist <= (promptRange + 1)
            local allowPrompt = c.TriggerPromptFallback ~= false or (c.TeleportToValuable ~= false and valuable)
            if allowPrompt and nearNow and triggerHarvestPrompt(item.Prompt) then
                prompted = prompted + 1
            end

            if not waitAlive(tonumber(c.BetweenCollect) or 0.03) then
                return
            end
        end
    end

    local summary = ("tag=%s plot=%s id=%s ok=%s pr=%s tp=%s"):format(
        tostring(#tagged),
        tostring(inPlot),
        tostring(#candidates),
        tostring(collected),
        tostring(prompted),
        tostring(teleported)
    )
    State.LastCollect = os.date("%H:%M:%S") .. " " .. summary
    actionLog("AutoCollect", "DONE", summary)
    if collected > 0 and c.ReturnHomeAfterCollect ~= false then
        teleportToGardenHome("AutoCollect", 0.03)
    end
end

local function getDroppedItemPosition(item)
    if not item then return nil end
    if item:IsA("BasePart") then
        return item.Position
    end
    local anchor = item:FindFirstChild("PromptAnchor", true)
    if anchor and anchor:IsA("BasePart") then
        return anchor.Position
    end
    local visual = item:FindFirstChild("Visual", true)
    if visual then
        if visual:IsA("BasePart") then
            return visual.Position
        elseif visual:IsA("Model") then
            local primary = visual.PrimaryPart or visual:FindFirstChildWhichIsA("BasePart")
            if primary then return primary.Position end
        end
    end
    if item:IsA("Model") then
        local primary = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
        if primary then return primary.Position end
        local ok, pivot = pcall(function()
            return item:GetPivot()
        end)
        if ok and pivot then
            return pivot.Position
        end
    end
    return nil
end

local function beginTemporaryMovementFreeze()
    local root = getRootPart()
    local hum = getHumanoid()
    local saved = {
        Root = root,
        Humanoid = hum,
        Anchored = root and root.Anchored,
        WalkSpeed = hum and hum.WalkSpeed,
        JumpPower = hum and hum.JumpPower,
        JumpHeight = hum and hum.JumpHeight,
        AutoRotate = hum and hum.AutoRotate,
    }
    pcall(function()
        if root then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
            root.Anchored = true
        end
        if hum then
            hum.WalkSpeed = 0
            hum.JumpPower = 0
            hum.JumpHeight = 0
            hum.AutoRotate = false
        end
    end)
    return function()
        pcall(function()
            if saved.Root and saved.Root.Parent then
                saved.Root.Anchored = saved.Anchored == true
                saved.Root.AssemblyLinearVelocity = Vector3.zero
                saved.Root.AssemblyAngularVelocity = Vector3.zero
            end
            if saved.Humanoid and saved.Humanoid.Parent then
                if saved.WalkSpeed ~= nil then saved.Humanoid.WalkSpeed = saved.WalkSpeed end
                if saved.JumpPower ~= nil then saved.Humanoid.JumpPower = saved.JumpPower end
                if saved.JumpHeight ~= nil then saved.Humanoid.JumpHeight = saved.JumpHeight end
                if saved.AutoRotate ~= nil then saved.Humanoid.AutoRotate = saved.AutoRotate end
            end
        end)
    end
end

local function getDropText(item, attr)
    local value = item and item:GetAttribute(attr)
    if type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

local function getDroppedItemInfo(item)
    local display = getDropText(item, "DisplayName")
        or getDropText(item, "ItemName")
        or getDropText(item, "SeedPack")
        or getDropText(item, "SeedTool")
        or (item and item.Name)
        or "drop"
    local category = getDropText(item, "ItemCategory") or ""
    local isRainbow = item and item:GetAttribute("RainbowSeed") == true
        or hasRainbowText(display)
        or hasRainbowText(category)
        or hasRainbowText(getDropText(item, "SeedPack"))
        or hasRainbowText(getDropText(item, "SeedTool"))
    local isSeed = item and (item:GetAttribute("SeedPack") ~= nil or item:GetAttribute("SeedTool") ~= nil)
        or category == "Seeds"
        or category == "SeedPacks"
        or string.find(string.lower(display), "seed", 1, true) ~= nil
    local priority = 0
    if isSeed then
        priority = priority + 1000
    end
    if category == "SeedPacks" then
        priority = priority + 500
    end
    if isRainbow then
        priority = priority + 10000
    end
    return display, priority, isRainbow, isSeed
end

local function getSeedPackSpawnFolder()
    local map = workspace:FindFirstChild("Map")
    return map and map:FindFirstChild("SeedPackSpawnServerLocations")
end

local function getSeedPackSpawnInfo(spawn)
    if not spawn then
        return nil
    end
    local seedPack = spawn:GetAttribute("SeedPack")
    local isRainbow = spawn:GetAttribute("RainbowSeed") == true
    local isGold = spawn:GetAttribute("GoldSeed") == true
    if not (isRainbow or isGold or (type(seedPack) == "string" and seedPack ~= "")) then
        return nil
    end

    local label
    local priority = 4000
    if isRainbow then
        label = "Rainbow Seed"
        priority = 20000
    elseif isGold then
        label = "Gold Seed"
        priority = 8000
    else
        label = tostring(seedPack)
    end
    return label, priority, isRainbow, isGold
end

local function teleportToSeedPackSpawn(pos, c)
    local root = getRootPart()
    if not (root and pos) then
        return false
    end
    local yOffset = tonumber(c and c.SeedSpawnYOffset) or 3
    root.CFrame = CFrame.new(pos + Vector3.new(0, yOffset, 0))
    return waitAlive(tonumber(c and c.SeedSpawnWait) or 0.12)
end

function Runtime.doAutoCollectDrops()
    local c = CFG.AutoCollectDrops
    if not (c and c.Enabled) then return end
    if State.AntiStealEngaging or State.SellInProgress then return end
    if not Runtime.GetPrioritySeedSpawnLabel() and Runtime.ShouldYieldForPetPriority("AutoCollectDrops") then
        return
    end

    local root = getRootPart()
    local items = {}
    local folder = workspace:FindFirstChild("DroppedItems")
    if folder then
        for _, item in ipairs(folder:GetChildren()) do
            if item:GetAttribute("OwnerRestricted") ~= true or item:GetAttribute("DroppedBy") == LocalPlayer.UserId then
                local pos = getDroppedItemPosition(item)
                if pos then
                    local label, priority, isRainbow, isSeed = getDroppedItemInfo(item)
                    table.insert(items, {
                        Item = item,
                        Pos = pos,
                        Distance = root and (root.Position - pos).Magnitude or 999999,
                        Priority = priority,
                        Label = label,
                        Source = "Drop",
                        Rainbow = isRainbow,
                        Seed = isSeed,
                    })
                end
            end
        end
    end

    if c.IncludeSeedPackSpawns ~= false then
        local spawnFolder = getSeedPackSpawnFolder()
        if spawnFolder then
            for _, spawn in ipairs(spawnFolder:GetChildren()) do
                local label, priority, isRainbow, isGold = getSeedPackSpawnInfo(spawn)
                if label then
                    local pos = getDroppedItemPosition(spawn)
                    if pos then
                        table.insert(items, {
                            Item = spawn,
                            Pos = pos,
                            Distance = root and (root.Position - pos).Magnitude or 999999,
                            Priority = priority,
                            Label = label,
                            Source = "SeedSpawn",
                            Rainbow = isRainbow,
                            Gold = isGold,
                            Seed = true,
                        })
                    end
                end
            end
        end
    end

    if #items == 0 then
        State.LastDrop = os.date("%H:%M:%S") .. (folder and " none" or " no folder")
        return
    end

    local hasSeedSpawn = false
    for _, entry in ipairs(items) do
        if entry.Source == "SeedSpawn" then
            hasSeedSpawn = true
            break
        end
    end
    if hasSeedSpawn then
        State.SeedClaimUntil = math.max(
            tonumber(State.SeedClaimUntil) or 0,
            os.clock() + math.max((tonumber(c.Delay) or 0.5) + 0.75, 1)
        )
    end

    table.sort(items, function(a, b)
        if c.PrioritizeRainbowSeed ~= false and a.Priority ~= b.Priority then
            return a.Priority > b.Priority
        end
        return a.Distance < b.Distance
    end)

    local picked = 0
    local promptedDrops = 0
    local seedSpawns = 0
    local rainbowSpawns = 0
    local maxPerCycle = math.max(tonumber(c.MaxPerCycle) or 30, 1)
    for _, entry in ipairs(items) do
        if picked >= maxPerCycle then break end
        local item = entry.Item
        if item and item.Parent then
            if entry.Source == "SeedSpawn" then
                State.SeedClaimInProgress = true
                State.SeedClaimUntil = os.clock() + math.max(tonumber(c.SeedClaimNoPromptWait) or 2.5, 1)
                State.LastDrop = os.date("%H:%M:%S") .. " claim " .. tostring(entry.Label or "seed")
                actionLog("AutoCollectDrops", "CLAIM", tostring(entry.Label or "seed"))
                teleportToSeedPackSpawn(entry.Pos, c)
                local unfreezeSeedClaim = c.FreezeDuringSeedClaim ~= false and beginTemporaryMovementFreeze() or nil
                local function finishSeedClaimLock()
                    State.SeedClaimInProgress = false
                    if unfreezeSeedClaim then
                        unfreezeSeedClaim()
                        unfreezeSeedClaim = nil
                    end
                end
                seedSpawns = seedSpawns + 1
                if entry.Rainbow then
                    rainbowSpawns = rainbowSpawns + 1
                end

                -- Rainbow/Gold quý hơn -> giữ prompt LÂU HƠN cho chắc ăn claim được.
                -- Script tự detect qua attribute RainbowSeed/GoldSeed của spawn.
                local holdExtra = tonumber(c.SeedClaimHoldExtra) or 0.35
                if entry.Rainbow then
                    holdExtra = tonumber(c.SeedClaimHoldExtraRainbow) or holdExtra
                elseif entry.Gold then
                    holdExtra = tonumber(c.SeedClaimHoldExtraGold) or holdExtra
                end

                local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt and triggerHarvestPrompt(prompt, holdExtra) then
                    promptedDrops = promptedDrops + 1
                    local postUntil = os.clock() + (tonumber(c.SeedClaimPostPromptWait) or 1.5)
                    State.SeedClaimUntil = postUntil
                    while item.Parent and os.clock() < postUntil do
                        if not waitAlive(0.08) then
                            finishSeedClaimLock()
                            return
                        end
                    end
                else
                    local waitUntil = os.clock() + (tonumber(c.SeedClaimNoPromptWait) or 2.5)
                    while item.Parent and os.clock() < waitUntil do
                        if not waitAlive(0.1) then
                            finishSeedClaimLock()
                            return
                        end
                    end
                end

                local grace = tonumber(c.SeedClaimGrace) or 0.5
                finishSeedClaimLock()
                local claimed = not item.Parent
                if claimed then
                    State.SeedClaimUntil = os.clock() + grace
                else
                    State.SeedClaimUntil = os.clock() + math.max(grace, (tonumber(c.Delay) or 0.5) + 0.75)
                end
                if grace > 0 and not waitAlive(grace) then
                    return
                end
                picked = picked + 1
                local summary = ("try=%s pr=%s spawn=%s rainbow=%s %s"):format(
                    tostring(picked),
                    tostring(promptedDrops),
                    tostring(seedSpawns),
                    tostring(rainbowSpawns),
                    claimed and "claimed" or "retry"
                )
                State.LastDrop = os.date("%H:%M:%S") .. " " .. summary
                actionLog("AutoCollectDrops", claimed and "DONE" or "RETRY", summary)
                return
            else
                teleportNearPosition(entry.Pos, c)
                local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt and triggerHarvestPrompt(prompt) then
                    promptedDrops = promptedDrops + 1
                end
            end
            picked = picked + 1
            if not waitAlive(0.04) then return end
        end
    end

    if picked > 0 then
        local summary = ("try=%s pr=%s spawn=%s rainbow=%s"):format(
            tostring(picked),
            tostring(promptedDrops),
            tostring(seedSpawns),
            tostring(rainbowSpawns)
        )
        State.LastDrop = os.date("%H:%M:%S") .. " " .. summary
        actionLog("AutoCollectDrops", "DONE", summary)
        if c.ReturnHomeAfterCollect ~= false then
            teleportToGardenHome("AutoCollectDrops", 0.03)
        end
    end
end

-- Bán hết túi. force=true (bán do ĐẦY túi) -> bỏ qua nhường ưu tiên pet/seed: đầy túi là phải
-- bán ngay kẻo phí harvest, không đợi tame pet/claim seed nữa.
local function doAutoSell(force)
    local c = CFG.AutoSell
    if not (c and c.Enabled) then return end
    if not force and (Runtime.ShouldYieldForSeedPriority("AutoSell") or Runtime.ShouldYieldForPetPriority("AutoSell")) then
        return
    end
    actionLog("AutoSell", "START")
    if sellBlockedAtNight() then
        actionLog("AutoSell", "STAY_HOME_NIGHT", "Night.Value=true & SellAtNight=false; collect only")
        return
    end
    if not packet({ "NPCS", "SellAll" }) then
        actionLog("AutoSell", "ERROR", "missing Networking.NPCS.SellAll")
        logw("AutoSell: thiếu Networking.NPCS.SellAll -> tắt.")
        c.Enabled = false
        return
    end

    local hasPreview = packet({ "NPCS", "PreviewSellAll" }) ~= nil
    local fruitCount
    local preview
    if hasPreview then
        local ok
        ok, preview = firePacket({ "NPCS", "PreviewSellAll" })
        actionLog("AutoSell", "PREVIEW_HOME", summarizeResult(preview))
        if not ok then
            actionLog("AutoSell", "ERROR", "PreviewSellAll failed")
        elseif type(preview) == "table" then
            fruitCount = tonumber(preview.FruitCount) or 0
        end
    else
        actionLog("AutoSell", "WARN", "missing PreviewSellAll, fallback to local fruit tools")
    end

    if fruitCount == nil then
        fruitCount = countFruitTools()
        actionLog("AutoSell", "LOCAL_FRUIT_TOOLS", "count=" .. tostring(fruitCount))
    end

    if fruitCount <= 0 then
        actionLog("AutoSell", "STAY_HOME", "no fruit to sell")
        return
    end

    -- QUAN TRỌNG: trước đây teleport tới Steven fail (vd không thấy Steven.HumanoidRootPart trên
    -- 1 số server) sẽ return luôn -> KHÔNG BAO GIỜ bán dù full bag -> acc không có tiền.
    -- PreviewSellAll/SellAll bắn được từ xa (preview ở nhà đã ra FruitCount/TotalValue), nên
    -- teleport CHỈ là best-effort: fail thì vẫn thử bán, không chặn nữa.
    if not teleportToStevenForSell() then
        actionLog("AutoSell", "WARN", "khong teleport duoc toi Steven -> van thu SellAll tu xa")
    end

    if hasPreview and type(preview) ~= "table" then
        local ok, previewNear = firePacket({ "NPCS", "PreviewSellAll" })
        actionLog("AutoSell", "PREVIEW_STEVEN", summarizeResult(previewNear))
        if not ok then
            return
        end
        if type(previewNear) == "table" then
            fruitCount = tonumber(previewNear.FruitCount) or fruitCount
            if fruitCount <= 0 then
                actionLog("AutoSell", "SKIP", "no fruit after teleport")
                return
            end
        end
    end

    if fruitCount > 100 then
        if not waitAlive(0.5) then return end
    end

    if not waitAlive(tonumber(c.PostPreviewWait) or 0.25) then return end
    if not waitAlive(tonumber(c.PreSellWait) or 0.5) then return end

    if c.UseDailyDeal ~= false and packet({ "NPCS", "CheckDailyDeal" }) and packet({ "NPCS", "UseDailyDealAll" }) then
        local okDeal, deal = firePacket({ "NPCS", "CheckDailyDeal" })
        if okDeal and type(deal) == "table" and deal.Available then
            local okDaily, daily = firePacket({ "NPCS", "UseDailyDealAll" })
            actionLog("AutoSell", "SELL_RESULT", "daily " .. summarizeResult(daily))
            if okDaily and type(daily) == "table" and daily.Success then
                State.LastSell = os.date("%H:%M:%S") .. " daily sold=" .. tostring(daily.SoldCount) .. " price=" .. tostring(daily.SellPrice)
                actionLog("AutoSell", "DONE", ("daily sold=%s price=%s"):format(tostring(daily.SoldCount), tostring(daily.SellPrice)))
                return
            end
        end
    end

    local ok, res = firePacket({ "NPCS", "SellAll" })
    actionLog("AutoSell", "SELL_RESULT", summarizeResult(res))
    if ok and type(res) == "table" and res.Success then
        State.LastSell = os.date("%H:%M:%S") .. " sold=" .. tostring(res.SoldCount) .. " price=" .. tostring(res.SellPrice)
        actionLog("AutoSell", "DONE", ("sold=%s price=%s"):format(tostring(res.SoldCount), tostring(res.SellPrice)))
        log(("Đã bán %s món, +%s"):format(tostring(res.SoldCount), tostring(res.SellPrice)))
    else
        State.LastSell = os.date("%H:%M:%S") .. " failed"
        actionLog("AutoSell", "ERROR", "SellAll failed or returned no Success")
    end
end

-- Bán an toàn: chặn 2 luồng bán cùng lúc (timer + đầy túi gọi chung 1 chỗ)
-- Bán xong tự teleport về chỗ cũ (về nhà) để anti-steal làm việc liền.
local function runSellSafe(reason, force)
    -- Mail Instead Of Sell: đang bật gửi trái cây kiểu "gửi thay vì bán" -> KHÔNG bán,
    -- để dồn trái cây cho AutoMailFruits gửi đi.
    if CFG.AutoMailFruits and CFG.AutoMailFruits.Enabled and CFG.AutoMailFruits.InsteadOfSell then
        actionLog("AutoSell", "SKIP", "mail instead of sell")
        return
    end
    if not force and (Runtime.ShouldYieldForSeedPriority("AutoSell") or Runtime.ShouldYieldForPetPriority("AutoSell")) then
        return
    end
    if State.SellInProgress then
        actionLog("AutoSell", "BUSY", tostring(reason or ""))
        return
    end
    State.SellInProgress = true
    local c = CFG.AutoSell or {}
    local root = getRootPart()
    local homeCF = getGardenHomeCFrame() or (root and root.CFrame)
    local ok, err = pcall(doAutoSell, force)
    if c.ReturnHomeAfterSell ~= false and homeCF then
        local rootAfter = getRootPart()
        if rootAfter then
            rootAfter.CFrame = homeCF
            actionLog("AutoSell", "RETURN_HOME", "garden")
        end
    end
    State.SellInProgress = false
    if not ok then
        logw("AutoSell", err)
    end
end

-- Đầy túi (FruitCount/MaxFruitCapacity) thì bán NGAY, khỏi đợi hết Delay
local function doSellWhenFull()
    local c = CFG.AutoSell
    if not (c and c.Enabled and c.SellWhenFull ~= false) then return end
    -- ĐẦY túi -> bán ngay, KHÔNG nhường ưu tiên pet/seed (force) để khỏi kẹt "full bag mà ko sell".
    if sellBlockedAtNight() then return end
    local ratio, count, max = getFruitFill()
    if not ratio then return end
    State.FruitFill = tostring(count) .. "/" .. tostring(max)
    if ratio >= (tonumber(c.FullThreshold) or 0.95) then
        actionLog("AutoSell", "FULL_TRIGGER", State.FruitFill)
        runSellSafe("inventory full", true)
    end
end

-- Theo dõi túi đầy bằng tín hiệu THẬT của game:
--   1) attribute FruitCount / MaxFruitCapacity đổi (InventoryController/Main.lua dòng 2687)
--   2) server bắn notification "Your inventory is full" (NotificationController.lua dòng 217+833)
-- -> phản ứng TỨC THÌ, không phải chờ vòng lặp poll.
local function setupInventoryWatcher()
    local c = CFG.AutoSell or {}
    local connections = {}

    local function triggerSell(reason)
        if c.SellWhenFull == false then return end
        -- ĐẦY túi -> bán ngay (force), không nhường ưu tiên pet/seed.
        if sellBlockedAtNight() then
            actionLog("AutoSell", "FULL_NIGHT", "đầy túi nhưng đêm, chờ sáng (" .. tostring(reason) .. ")")
            return
        end
        task.spawn(function()
            runSellSafe(reason, true)
        end)
    end

    -- cập nhật GUI + bán ngay khi quả chạm ngưỡng đầy
    local function onFruitChanged()
        local ratio, count, max = getFruitFill()
        if count then
            State.FruitFill = tostring(count) .. "/" .. tostring(max)
        end
        if ratio and ratio >= (tonumber(c.FullThreshold) or 0.95) then
            triggerSell("đầy túi (FruitCount)")
        end
    end

    table.insert(connections, LocalPlayer:GetAttributeChangedSignal("FruitCount"):Connect(onFruitChanged))
    table.insert(connections, LocalPlayer:GetAttributeChangedSignal("MaxFruitCapacity"):Connect(onFruitChanged))

    -- tín hiệu CHUẨN nhất: server tự báo đầy túi
    local note = packet({ "Notification" })
    local hooked = false
    if note then
        local ok, conn = pcall(function()
            return note.OnClientEvent:Connect(function(message)
                if type(message) == "string" and string.find(message, "Your inventory is full", 1, true) then
                    actionLog("AutoSell", "NOTIFY_FULL", "server báo đầy túi -> đi bán")
                    triggerSell("server báo đầy túi")
                end
            end)
        end)
        if ok and conn then
            table.insert(connections, conn)
            hooked = true
        end
    end
    if not hooked then
        logw("InventoryWatcher: không hook được Networking.Notification.OnClientEvent (vẫn còn poll FruitCount)")
    end

    onFruitChanged()

    table.insert(Runtime.Cleanups, function()
        for _, conn in ipairs(connections) do
            pcall(function()
                conn:Disconnect()
            end)
        end
    end)
end

-- Server báo "You can't plant more" (hoặc tương tự) -> đánh dấu vườn đầy (tín hiệu THẬT).
-- Remote thật: Networking.Notification ("Notify", String, Any) - Networking.lua:16.
-- LƯU Ý: chuỗi text do SERVER gửi, KHÔNG có trong client source nên khớp tương đối
-- (message chứa "plant" + một trong more/full/room/space/limit). An toàn vì chỉ set 1 cờ.
Runtime.SetupPlantFullWatcher = function()
    local note = packet({ "Notification" })
    if not note then
        logw("PlantFullWatcher: không thấy Networking.Notification")
        return
    end
    local ok, conn = pcall(function()
        return note.OnClientEvent:Connect(function(message)
            if type(message) ~= "string" then return end
            local m = string.lower(message)
            if string.find(m, "plant", 1, true)
                and (string.find(m, "more", 1, true)
                    or string.find(m, "full", 1, true)
                    or string.find(m, "room", 1, true)
                    or string.find(m, "space", 1, true)
                    or string.find(m, "limit", 1, true)) then
                Runtime.MarkPlotFull()
                State.LastShovelReplace = os.date("%H:%M:%S") .. " plot full (server)"
                actionLog("AutoPlant", "PLOT_FULL", compactText(message, 60))
            end
        end)
    end)
    if ok and conn then
        table.insert(Runtime.Cleanups, function() pcall(function() conn:Disconnect() end) end)
    else
        logw("PlantFullWatcher: connect lỗi")
    end
end

-- Chống người vào vườn mình ban đêm bằng shovel
function Runtime.doAntiSteal()
    local c = CFG.AntiSteal
    if not (c and c.Enabled) then return end
    if Runtime.ShouldYieldForSeedPriority("AntiSteal") or Runtime.ShouldYieldForPetPriority("AntiSteal") then
        return
    end
    if #Players:GetPlayers() <= 1 then
        State.IntruderCount = 0
        State.LastIntruders = "solo"
        State.AntiStealEngaging = false
        return
    end
    if State.SellInProgress then return end  -- đang đi bán thì để bán xong đã
    if c.OnlyAtNight ~= false and not isNight() then
        State.IntruderCount = 0
        State.LastIntruders = "-"
        return
    end

    local intruders = getPlayersInMyGarden()
    State.IntruderCount = #intruders
    if #intruders == 0 then
        State.LastIntruders = "-"
        return
    end

    local names = {}
    for _, player in ipairs(intruders) do
        table.insert(names, player.Name)
    end
    local intruderText = table.concat(names, ", ")
    local changed = State.LastIntruders ~= intruderText
    State.LastIntruders = intruderText
    if changed then
        actionLog("AntiSteal", "DETECTED", State.LastIntruders)
    end

    local cooldown = tonumber(c.TargetCooldown) or 0.5
    local now = os.clock()
    local rootBefore = getRootPart()
    local savedCF = rootBefore and rootBefore.CFrame
    local didDefend = false
    State.AntiStealEngaging = true
    local okDefend, errDefend = pcall(function()
        for _, player in ipairs(intruders) do
            local lastHit = AntiStealCooldown[player.UserId] or 0
            if now - lastHit >= cooldown then
                AntiStealCooldown[player.UserId] = now
                State.LastAntiSteal = os.date("%H:%M:%S") .. " defending " .. tostring(player.Name)
                didDefend = true
                hitIntruderWithShovel(player)
            end
        end
    end)
    -- Đánh xong quay lại vị trí cũ để không bị kẹt ở chỗ kẻ trộm (cải thiện flow farm)
    if didDefend and savedCF and c.ReturnAfterDefend ~= false then
        local rootAfter = getRootPart()
        if rootAfter then
            rootAfter.CFrame = savedCF
            actionLog("AntiSteal", "RETURNED", "back to farming spot")
        end
    end
    State.AntiStealEngaging = false
    if not okDefend then
        logw("AntiSteal defend lỗi:", errDefend)
    end
end

-- Ấp trứng đang cầm trong túi
function Runtime.doAutoHatchEgg()
    local c = CFG.AutoHatchEgg
    if not (c and c.Enabled) then return end
    actionLog("AutoHatchEgg", "START")
    if not packet({ "Egg", "OpenEgg" }) then
        logw("AutoHatchEgg: thiếu Networking.Egg.OpenEgg -> tắt.")
        c.Enabled = false
        return
    end
    local eggs = getToolsWithAttribute("Egg")
    for _, tool in ipairs(eggs) do
        local eggName = tool:GetAttribute("Egg")
        if eggName then
            if equipTool(tool) then
                actionLog("AutoHatchEgg", "OPEN", tostring(eggName))
                firePacket({ "Egg", "OpenEgg" }, eggName)
                if not waitAlive(c.Delay or 0.5) then return end
            end
        end
    end
    actionLog("AutoHatchEgg", "DONE")
end

-- Equip pet theo tên

local function getPetInventory()
    local replica = getPlayerReplica()
    local data = replica and replica.Data
    local inventory = data and data.Inventory
    local pets = inventory and inventory.Pets
    return type(pets) == "table" and pets or nil
end

-- Đọc ĐÚNG cấu trúc kho pet: Data.Inventory.Pets = { [petId] = {Id,Name,Equipped,Type,...} }
-- (xác nhận MailboxController.lua:773 + u177; PetListController.lua:324).
-- Trả về mảng entry chuẩn hoá để equip/gửi mail (mỗi entry là 1 con pet riêng).
-- Gắn vào Runtime để không thêm local ở main scope (Lua giới hạn 200 local).
Runtime.GetPetInventoryEntries = function()
    local pets = getPetInventory()
    local out = {}
    if not pets then
        return out, "no pet inventory"
    end
    for key, entry in pairs(pets) do
        if type(entry) == "table" and type(entry.Name) == "string" then
            local petId = entry.Id
            if type(petId) ~= "string" or petId == "" then
                petId = type(key) == "string" and key or nil
            end
            local data = PetData and PetData[entry.Name]
            table.insert(out, {
                Id = petId,
                Name = entry.Name,
                Equipped = entry.Equipped == true,
                Type = entry.Type,
                Rarity = normalizeRarity(data and data.Rarity or "Common"),
            })
        end
    end
    return out
end

local function getEquippedPetCounts()
    local counts = {}
    local total = 0
    if not packet({ "Pets", "GetEquippedPets" }) then
        return counts, total
    end
    local ok, equipped = firePacket({ "Pets", "GetEquippedPets" })
    if ok and type(equipped) == "table" then
        for _, pet in pairs(equipped) do
            if type(pet) == "table" and type(pet.Name) == "string" then
                counts[pet.Name] = (counts[pet.Name] or 0) + 1
                total = total + 1
            end
        end
    end
    return counts, total
end

local function getMaxEquippedPets()
    local attr = tonumber(LocalPlayer:GetAttribute("MaxEquippedPets"))
    if attr and attr > 0 then
        return math.floor(attr)
    end
    return (PetSlotPrices and tonumber(PetSlotPrices.BaseMax)) or 3
end

local function getPetScore(petName)
    local data = PetData and PetData[petName]
    local rarity = data and data.Rarity or "Common"
    local price = data and tonumber(data.BasePrice) or 0
    return ((RarityScore[rarity] or 0) * 100000000) + price
end

local function buildPetEquipCandidates()
    local entries, reason = Runtime.GetPetInventoryEntries()
    local out = {}
    if #entries == 0 then
        return out, reason or "no pets"
    end
    local cEq = CFG.AutoEquipPet or {}
    local minRarity = normalizeRarity(cEq.MinRarity or "Common")
    -- Pet nằm trong danh sách gửi mailbox (AutoMailPets.PetNames) thì KHÔNG equip
    -- (để Equipped=false cho AutoMailPets gửi đi). Pet đã equip thì game không cho gift.
    local mail = CFG.AutoMailPets
    local mailActive = cEq.SkipMailRarity ~= false and mail and mail.Enabled
    local mailNames = {}
    if mailActive then
        for _, w in ipairs(type(mail.PetNames) == "table" and mail.PetNames or {}) do
            if type(w) == "string" and w ~= "" then mailNames[string.lower(w)] = true end
        end
    end

    for _, e in ipairs(entries) do
        if not e.Equipped then
            local allowed = rarityAllowed(e.Rarity, minRarity)
            if allowed and mailActive and type(e.Name) == "string" and mailNames[string.lower(e.Name)] then
                allowed = false -- để dành gửi mail
            end
            if allowed then
                table.insert(out, {
                    Name = e.Name,
                    Id = e.Id,
                    Count = 1,
                    Rarity = e.Rarity,
                    Score = getPetScore(e.Name),
                })
            end
        end
    end
    table.sort(out, function(a, b)
        if a.Score ~= b.Score then
            return a.Score > b.Score
        end
        return a.Name < b.Name
    end)
    return out
end

function Runtime.doAutoEquipPet()
    local c = CFG.AutoEquipPet
    if not (c and c.Enabled) then return end
    if not packet({ "Pets", "RequestEquipByName" }) then
        logw("AutoEquipPet: thieu Networking.Pets.RequestEquipByName -> tat.")
        c.Enabled = false
        return
    end

    local maxEquipped = getMaxEquippedPets()
    -- want = số con MUỐN equip theo tên (List = RequiredPets). Rỗng -> Smart mode.
    local listMode = type(c.List) == "table" and #c.List > 0
    local want = {}
    if listMode then
        for _, n in ipairs(c.List) do
            if type(n) == "string" and n ~= "" then
                local k = string.lower(n)
                want[k] = (want[k] or 0) + 1
            end
        end
    end

    -- ===== BƯỚC 1: UNEQUIP pet SAI/THỪA TRƯỚC (giải phóng slot) =====
    -- List mode: LUÔN tháo pet KHÔNG nằm trong want, hoặc VƯỢT số want (không cần UnequipOthers).
    -- Đây là fix cho bug: account đang equip Dog + 2 Deer mà yêu cầu 3 Deer -> phải tháo Dog trước.
    if listMode and packet({ "Pets", "RequestUnequipByName" }) then
        local kept = {}
        for _, e in ipairs(Runtime.GetPetInventoryEntries()) do
            if e.Equipped and type(e.Name) == "string" then
                local k = string.lower(e.Name)
                if (kept[k] or 0) < (want[k] or 0) then
                    kept[k] = (kept[k] or 0) + 1   -- đúng pet & còn trong hạn -> GIỮ
                else
                    actionLog("AutoEquipPet", "UNEQUIP", "Wrong equipped pet: " .. tostring(e.Name))
                    firePacket({ "Pets", "RequestUnequipByName" }, e.Name)
                    if not waitAlive(0.25) then return end
                end
            end
        end
    end

    -- ===== BƯỚC 2: đọc lại kho SAU khi tháo -> đếm đang equip / chưa equip / slot trống =====
    local equippedTotal, haveEq, avail = 0, {}, {}
    for _, e in ipairs(Runtime.GetPetInventoryEntries()) do
        if type(e.Name) == "string" then
            local k = string.lower(e.Name)
            if e.Equipped then
                equippedTotal = equippedTotal + 1
                haveEq[k] = (haveEq[k] or 0) + 1
            else
                avail[k] = (avail[k] or 0) + 1
            end
        end
    end
    local freeSlots = math.max(maxEquipped - equippedTotal, 0)
    if freeSlots <= 0 and not listMode then
        State.LastPet = os.date("%H:%M:%S") .. " slots full " .. tostring(equippedTotal) .. "/" .. tostring(maxEquipped)
        return
    end

    -- ===== BƯỚC 3: EQUIP phần CÒN THIẾU (want - số đang equip cùng tên) =====
    local equipped = 0
    if listMode then
        local added = {}
        for _, petName in ipairs(c.List) do
            if equipped >= freeSlots then break end
            local k = string.lower(tostring(petName))
            local already = (haveEq[k] or 0) + (added[k] or 0)
            if already >= (want[k] or 0) then
                -- đã đủ số con tên này -> bỏ qua
            elseif (avail[k] or 0) > 0 then
                actionLog("AutoEquipPet", "EQUIP", ("%s %d/%d"):format(tostring(petName), already + 1, want[k] or 1))
                if firePacket({ "Pets", "RequestEquipByName" }, petName) then
                    equipped = equipped + 1
                    avail[k] = avail[k] - 1
                    added[k] = (added[k] or 0) + 1
                    Runtime.HideBlockingPopups()
                end
                if not waitAlive(0.3) then return end
            else
                actionLog("AutoEquipPet", "SKIP", "chua co pet " .. tostring(petName))
            end
        end
        -- log "final equipped valid": <tên> x<final>/<want>
        local parts = {}
        for k, n in pairs(want) do
            table.insert(parts, ("%s x%d/%d"):format(k, (haveEq[k] or 0) + (added[k] or 0), n))
        end
        if #parts > 0 then
            actionLog("AutoEquipPet", "DONE", "Final valid: " .. table.concat(parts, ", "))
        end
    else
        local candidates, reason = buildPetEquipCandidates()
        if #candidates == 0 then
            actionLog("AutoEquipPet", "SKIP", tostring(reason or "no pets"))
            return
        end
        for _, pet in ipairs(candidates) do
            while pet.Count > 0 and equipped < freeSlots do
                actionLog("AutoEquipPet", "EQUIP", pet.Name .. " " .. tostring(pet.Rarity))
                if firePacket({ "Pets", "RequestEquipByName" }, pet.Name) then
                    equipped = equipped + 1
                    pet.Count = pet.Count - 1
                    Runtime.HideBlockingPopups()
                else
                    pet.Count = 0
                end
                if not waitAlive(0.3) then return end
            end
            if equipped >= freeSlots then break end
        end
    end

    if equipped > 0 then
        State.LastPet = os.date("%H:%M:%S") .. " equip=" .. tostring(equipped)
    end
end

-- Tưới nước cây trong plot mình (xác nhận WateringcanController.lua:576)
local ValuableLastSummary = nil

local function webhookField(name, value, inline)
    return {
        name = tostring(name),
        value = tostring(value == nil and "-" or value),
        inline = inline ~= false,
    }
end

-- Màu embed theo độ hiếm (nhìn pro hơn, mỗi rarity 1 màu riêng).
-- Gắn vào Runtime để không tốn thêm local ở main chunk (Lua giới hạn 200 local).
do
    local COLORS = {
        common    = 0x95A5A6, -- xám
        uncommon  = 0x2ECC71, -- xanh lá
        rare      = 0x3498DB, -- xanh dương
        epic      = 0x9B59B6, -- tím
        legendary = 0xF1C40F, -- vàng gold
        mythic    = 0xE67E22, -- cam
        mythical  = 0xE67E22,
        divine    = 0xE74C3C, -- đỏ
        prismatic = 0x1ABC9C, -- ngọc
    }
    function Runtime.RarityColor(rarity, fallback)
        local key = tostring(rarity or ""):lower():gsub("%s+", "")
        return COLORS[key] or fallback or 0x5865F2
    end
end

-- ẢNH PET cho embed webhook. LƯU Ý: đây là URL ẢNH NGOÀI (wiki Grow a Garden), KHÔNG nằm trong
-- source game (Workspace/ReplicatedStorage/Players_scripts) -> phần này CHƯA xác nhận trong source,
-- chỉ dùng để hiển thị cho đẹp. Pet nào chưa có URL thì dùng Placeholder.
-- Chồng thêm pet mới: lấy URL ảnh từ wiki rồi nhét vào bảng này theo đúng tên pet.
do
    local PLACEHOLDER = "https://static.wikia.nocookie.net/growagarden27847/images/4/47/Placeholder.png/revision/latest/scale-to-width-down/85?cb=20260402181137"
    local IMG = {
        ["Robin"]            = "https://static.wikia.nocookie.net/growagarden27847/images/1/1b/Robin.png/revision/latest/scale-to-width-down/85?cb=20260612231816",
        ["Bee"]              = "https://static.wikia.nocookie.net/growagarden27847/images/5/56/Bee.png/revision/latest/scale-to-width-down/85?cb=20260612231815",
        ["Monkey"]           = "https://static.wikia.nocookie.net/growagarden27847/images/2/27/Monkey.png/revision/latest/scale-to-width-down/85?cb=20260612231816",
        ["Golden Dragonfly"] = "https://static.wikia.nocookie.net/growagarden27847/images/e/ee/GoldenDragonfly.png/revision/latest/scale-to-width-down/85?cb=20260612231815",
        ["GoldenDragonfly"]  = "https://static.wikia.nocookie.net/growagarden27847/images/e/ee/GoldenDragonfly.png/revision/latest/scale-to-width-down/85?cb=20260612231815",
        ["Unicorn"]          = "https://static.wikia.nocookie.net/growagarden27847/images/7/7e/Unicorn.png/revision/latest/scale-to-width-down/85?cb=20260612212539",
        ["Raccoon"]          = "https://static.wikia.nocookie.net/growagarden27847/images/7/7c/Raccoon.png/revision/latest/scale-to-width-down/85?cb=20260612232005",
    }
    Runtime.PetWikiImage = IMG
    function Runtime.GetPetImage(petName)
        local url = petName and IMG[tostring(petName)]
        if type(url) == "string" and url ~= "" then
            return url
        end
        return PLACEHOLDER
    end
end

local function notifyHighPet(petName, rarity, source, petId, petType, count)
    -- Pet có Id riêng -> key theo Id (mỗi con báo 1 lần). Không có Id mới fallback theo tên.
    local keyId = petId
    if type(keyId) ~= "string" or keyId == "" then
        keyId = tostring(petName) .. ":count=" .. tostring(count or 1)
    end
    local key = "pet:" .. tostring(source or "unknown") .. ":" .. tostring(keyId)
    local sourceLabel = source == "Tool" and "Đang cầm (Tool)"
        or source == "Inventory" and "Trong kho (Inventory)"
        or tostring(source or "-")
    return sendWebhookOnce(
        key,
        "🐾 Pet Hiếm Phát Hiện",
        ("Tìm thấy **%s** • **%s** trên acc này."):format(tostring(petName), tostring(rarity)),
        {
            webhookField("👤 Tài khoản", getAccountName(), true),
            webhookField("🆔 UserId", tostring(LocalPlayer.UserId), true),
            webhookField("🐾 Pet", tostring(petName), true),
            webhookField("⭐ Độ hiếm", tostring(rarity), true),
            webhookField("🧬 Loại", tostring(petType ~= nil and petType ~= "" and petType or "-"), true),
            webhookField("🔢 Số lượng", tostring(count or 1), true),
            webhookField("📦 Nguồn", sourceLabel, false),
        },
        Runtime.RarityColor(rarity, 0xF1C40F),
        {
            author = "Kaitun • Valuable Watcher",
            footer = "Kaitun Valuable Watcher • " .. getAccountName(),
            thumbnail = Runtime.GetPetImage(petName),
            persist = CFG.ValuableWatcher and CFG.ValuableWatcher.PersistSeen ~= false,
        }
    )
end

local function notifyRainbowSeed(tool)
    local seedName = tool:GetAttribute("SeedTool") or tool:GetAttribute("SeedPack") or tool.Name
    local key = "seed:" .. tostring(tool:GetAttribute("Id") or tool.Name) .. ":" .. tostring(seedName)
    -- Đếm tổng rainbow seed đang giữ trong người (Backpack + đang cầm).
    local heldTotal = 0
    for _, t in ipairs(getAllTools()) do
        if isRainbowSeedTool(t) then
            heldTotal = heldTotal + 1
        end
    end
    return sendWebhookOnce(
        key,
        "🌈 Rainbow Seed Đã Giữ",
        ("Đã giữ lại **%s** — không plant / open / use."):format(tostring(seedName)),
        {
            webhookField("👤 Tài khoản", getAccountName(), true),
            webhookField("🆔 UserId", tostring(LocalPlayer.UserId), true),
            webhookField("🌱 Seed", tostring(seedName), true),
            webhookField("🎒 Tool", tostring(tool.Name), true),
            webhookField("🌈 Rainbow", isRainbow and "✅ Có" or "❌ Không", true),
            webhookField("🔢 Đang giữ", "x" .. tostring(heldTotal), true),
            webhookField("📦 Vị trí", tostring(tool.Parent and tool.Parent.Name or "-"), false),
        },
        0x9B59B6, -- tím rainbow
        {
            author = "Kaitun • Valuable Watcher",
            footer = "Kaitun Valuable Watcher • " .. getAccountName(),
            persist = CFG.ValuableWatcher and CFG.ValuableWatcher.PersistSeen ~= false,
        }
    )
end

notifyRainbowSeed = function(tool)
    local seedName = tool:GetAttribute("SeedTool") or tool:GetAttribute("SeedPack") or tool.Name
    local key = "seed:" .. tostring(tool:GetAttribute("Id") or tool.Name) .. ":" .. tostring(seedName)
    local heldTotal = 0
    for _, t in ipairs(getAllTools()) do
        if isRainbowSeedTool(t) then
            heldTotal = heldTotal + 1
        end
    end
    return sendWebhookOnce(
        key,
        "Rainbow Seed -> Dang Giu",
        ("Dang giu %s; khong plant/open/use."):format(tostring(seedName)),
        {
            webhookField("Acc", getAccountName(), true),
            webhookField("Seed", tostring(seedName), true),
            webhookField("Dang giu", "x" .. tostring(heldTotal), true),
        },
        0x9B59B6,
        {
            footer = "Kaitun ValuableWatcher - " .. getAccountName(),
            persist = CFG.ValuableWatcher and CFG.ValuableWatcher.PersistSeen ~= false,
        }
    )
end

local function isGoldSeedTool(tool)
    if not (tool and tool:IsA("Tool")) then return false end
    local hasSeedSignal = tool:GetAttribute("SeedTool") ~= nil
        or tool:GetAttribute("SeedPack") ~= nil
        or tool:GetAttribute("GoldSeed") == true
    if not hasSeedSignal then return false end
    if tool:GetAttribute("GoldSeed") == true then return true end
    local function hasGold(s) return type(s) == "string" and string.find(string.lower(s), "gold", 1, true) ~= nil end
    return hasGold(tool.Name) or hasGold(tool:GetAttribute("SeedTool")) or hasGold(tool:GetAttribute("SeedPack"))
end

local function notifyGoldSeed(tool)
    local seedName = tool:GetAttribute("SeedTool") or tool:GetAttribute("SeedPack") or tool.Name
    local key = "gold:" .. tostring(tool:GetAttribute("Id") or tool.Name) .. ":" .. tostring(seedName)
    return sendWebhookOnce(
        key,
        "Gold Seed -> Dang Giu",
        ("Dang giu %s (Gold); khong plant/open/use."):format(tostring(seedName)),
        {
            webhookField("Acc", getAccountName(), true),
            webhookField("Seed", tostring(seedName), true),
        },
        0xF1C40F, -- vàng gold
        {
            author = "Kaitun • Valuable Watcher",
            footer = "Kaitun Valuable Watcher • " .. getAccountName(),
            persist = CFG.ValuableWatcher and CFG.ValuableWatcher.PersistSeen ~= false,
        }
    )
end

local function doValuableWatcher()
    local c = CFG.ValuableWatcher
    if not (c and c.Enabled) then
        return
    end

    local minPetRarity = c.MinPetRarity or "Mythic"
    local highPets = 0
    local rainbowSeeds = 0

    if c.NotifyHighPet ~= false then
        -- Quét theo ĐÚNG cấu trúc kho pet (id -> entry). Mỗi con pet có Id riêng -> key webhook
        -- theo Id để báo từng con, relog không trùng (persist theo Id).
        for _, e in ipairs(Runtime.GetPetInventoryEntries()) do
            if isHighPetRarity(e.Rarity, minPetRarity) then
                highPets = highPets + 1
                notifyHighPet(e.Name, e.Rarity, "Inventory", e.Id, e.Type, 1)
            end
        end
    end

    for _, tool in ipairs(getAllTools()) do
        if c.NotifyHighPet ~= false then
            local petName = tool:GetAttribute("Pet")
            if type(petName) == "string" and petName ~= "" then
                local rarity = getPetRarityFromSource(petName, tool)
                if isHighPetRarity(rarity, minPetRarity) then
                    highPets = highPets + 1
                    notifyHighPet(
                        petName,
                        rarity,
                        "Tool",
                        tool:GetAttribute("PetId"),
                        tool:GetAttribute("PetType"),
                        1
                    )
                end
            end
        end

        if c.NotifyRainbowSeed ~= false then
            if isRainbowSeedTool(tool) then
                rainbowSeeds = rainbowSeeds + 1
                notifyRainbowSeed(tool)
            elseif isGoldSeedTool(tool) then
                rainbowSeeds = rainbowSeeds + 1
                notifyGoldSeed(tool)
            end
        end
    end

    if highPets > 0 or rainbowSeeds > 0 then
        local summary = ("pet=%s seed=%s"):format(tostring(highPets), tostring(rainbowSeeds))
        State.LastValuable = os.date("%H:%M:%S") .. " " .. summary
        if summary ~= ValuableLastSummary then
            ValuableLastSummary = summary
            actionLog("ValuableWatcher", "DONE", summary)
        end
    end
end

local function doAutoWater()
    local c = CFG.AutoWater
    if not (c and c.Enabled) then return end
    if Runtime.ShouldYieldForSeedPriority("AutoWater") or Runtime.ShouldYieldForPetPriority("AutoWater") then
        return
    end
    if not packet({ "WateringCan", "UseWateringCan" }) then
        logw("AutoWater: thiếu Networking.WateringCan.UseWateringCan -> tắt.")
        c.Enabled = false
        return
    end
    if not getPlot() then
        actionLog("AutoWater", "SKIP", "missing plot")
        return
    end
    local cans = getToolsWithAttribute("WateringCan")
    if #cans == 0 then
        actionLog("AutoWater", "SKIP", "no watering can")
        return
    end
    local tool = cans[1]
    if not equipTool(tool) then return end
    local canName = tool:GetAttribute("WateringCan")
    local n = math.max(tonumber(c.PerCycle) or 20, 1)
    local watered = 0
    for _ = 1, n do
        if not (tool and tool.Parent) then break end
        local pos = randomPlantPosition()
        if not pos then break end
        -- source gửi (vị trí trên PlantArea - (0,0.3,0), tên bình, tool)
        firePacket({ "WateringCan", "UseWateringCan" }, pos - Vector3.new(0, 0.3, 0), canName, tool)
        watered = watered + 1
        if not waitAlive(0.15) then return end
    end
    actionLog("AutoWater", "DONE", "watered=" .. tostring(watered))
end

-- Đặt sprinkler đang có trong túi xuống ô PlantArea (xác nhận SprinklerController.lua:432)
local function doAutoSprinkler()
    local c = CFG.AutoSprinkler
    if not (c and c.Enabled) then return end
    if Runtime.ShouldYieldForSeedPriority("AutoSprinkler") or Runtime.ShouldYieldForPetPriority("AutoSprinkler") then
        return
    end
    if not packet({ "Place", "PlaceSprinkler" }) then
        logw("AutoSprinkler: thiếu Networking.Place.PlaceSprinkler -> tắt.")
        c.Enabled = false
        return
    end
    if not getPlot() then
        actionLog("AutoSprinkler", "SKIP", "missing plot")
        return
    end
    local plotId = tonumber(LocalPlayer:GetAttribute("PlotId"))
    if not plotId then
        actionLog("AutoSprinkler", "SKIP", "missing PlotId")
        return
    end
    local sprinklers = getToolsWithAttribute("Sprinkler")
    if #sprinklers == 0 then
        actionLog("AutoSprinkler", "SKIP", "no sprinkler tool")
        return
    end
    local placed = 0
    local maxPlace = math.max(tonumber(c.PerCycle) or 5, 1)
    -- Sprinkler Stack: đặt CHỒNG nhiều sprinkler vào CÙNG 1 vị trí (engine bắn remote thẳng nên
    -- bỏ qua chặn IsTooCloseToSprinkler của client). Stack=1 = như cũ (mỗi cái 1 chỗ).
    local stack = math.max(math.floor(tonumber(c.Stack) or 1), 1)
    local stackPos = nil
    local stackUsed = 0
    for _, tool in ipairs(sprinklers) do
        if placed >= maxPlace then break end
        if not (tool and tool.Parent) then break end
        if not equipTool(tool) then break end
        local sprName = tool:GetAttribute("Sprinkler")
        if not stackPos or stackUsed >= stack then
            stackPos = randomPlantPosition()
            stackUsed = 0
        end
        local pos = stackPos
        if pos then
            -- PlaceSprinkler:Fire(vịTríTrênPlantArea, tênSprinkler, tool, plotId)
            firePacket({ "Place", "PlaceSprinkler" }, pos, sprName, tool, plotId)
            placed = placed + 1
            stackUsed = stackUsed + 1
            if not waitAlive(tonumber(c.Delay) or 0.5) then return end
        end
    end
    actionLog("AutoSprinkler", "DONE", "placed=" .. tostring(placed) .. " stack=" .. tostring(stack))
end

-- Mở Crate đang cầm (xác nhận CrateController.lua:110)
function Runtime.doAutoOpenCrate()
    local c = CFG.AutoOpenCrate
    if not (c and c.Enabled) then return end
    if Runtime.ShouldYieldForSeedPriority("AutoOpenCrate") or Runtime.ShouldYieldForPetPriority("AutoOpenCrate") then
        return
    end
    if not packet({ "Crate", "OpenCrate" }) then
        logw("AutoOpenCrate: thiếu Networking.Crate.OpenCrate -> tắt.")
        c.Enabled = false
        return
    end
    for _, tool in ipairs(getToolsWithAttribute("Crate")) do
        local crateName = tool:GetAttribute("Crate")
        if crateName and equipTool(tool) then
            actionLog("AutoOpenCrate", "OPEN", tostring(crateName))
            firePacket({ "Crate", "OpenCrate" }, crateName)
            if not waitAlive(tonumber(c.Delay) or 0.5) then return end
        end
    end
end

-- Mở Seed Pack đang cầm (xác nhận SeedPackHandleController.lua:204)
function Runtime.doAutoOpenSeedPack()
    local c = CFG.AutoOpenSeedPack
    if not (c and c.Enabled) then return end
    if Runtime.ShouldYieldForSeedPriority("AutoOpenSeedPack") or Runtime.ShouldYieldForPetPriority("AutoOpenSeedPack") then
        return
    end
    if not packet({ "SeedPack", "OpenSeedPack" }) then
        logw("AutoOpenSeedPack: thiếu Networking.SeedPack.OpenSeedPack -> tắt.")
        c.Enabled = false
        return
    end
    for _, tool in ipairs(getToolsWithAttribute("SeedPack")) do
        local packName = tool:GetAttribute("SeedPack")
        if Runtime.ShouldKeepSeed(packName, tool) then
            actionLog("AutoOpenSeedPack", "SKIP", "keep seed " .. tostring(packName or tool.Name))
            State.LastValuable = os.date("%H:%M:%S") .. " keep seed " .. tostring(packName or tool.Name)
        elseif packName and equipTool(tool) then
            actionLog("AutoOpenSeedPack", "OPEN", tostring(packName))
            firePacket({ "SeedPack", "OpenSeedPack" }, packName)
            if not waitAlive(tonumber(c.Delay) or 0.5) then return end
        end
    end
end

-- Cộng điểm kỹ năng (xác nhận Visiblity.lua: SpendSkillPoint:Fire(tênSkill))
-- Được cộng nếu SkillPoints.Value >= level hiện tại của skill đó.
-- ============================================================
-- MAILBOX TUTORIAL GATE: game CHẶN gift khi đang tutorial ("you can't gift item during the tutorial").
-- Signal THẬT: workspace:GetAttribute("InTutorial") == true (xác nhận RestockStoreController.lua:559).
-- Remote hoàn tất tutorial: Networking.Tutorial.Complete (Networking.lua:425).
-- ============================================================
Runtime.IsInTutorial = function()
    return workspace:GetAttribute("InTutorial") == true
end
-- Trả về true nếu PHẢI BỎ QUA mailbox (tắt cứng MailboxEnabled=false, hoặc đang tutorial).
Runtime.MailboxBlocked = function(action)
    if CFG.MailboxEnabled == false then
        return true
    end
    if CFG.AutoTutorialCheck ~= false and Runtime.IsInTutorial() then
        -- best-effort: thử bắn Tutorial.Complete 1 lần (server có thể không cho, không sao).
        if not Runtime.TutorialCompleteFired and packet({ "Tutorial", "Complete" }) then
            Runtime.TutorialCompleteFired = true
            firePacket({ "Tutorial", "Complete" })
        end
        if CFG.SkipMailboxIfTutorial ~= false then
            if not Runtime.MailboxTutorialLogged then
                Runtime.MailboxTutorialLogged = true
                log("[Mailbox] Tutorial not completed, mailbox disabled for this account.")
            end
            State.LastMailbox = os.date("%H:%M:%S") .. " tutorial (off)"
            actionLog(action or "Mailbox", "SKIP", "in tutorial -> mailbox off")
            return true
        end
    end
    return false
end

function Runtime.doAutoClaimMailbox()
    local c = CFG.AutoClaimMailbox
    if not (c and c.Enabled) then return end
    if Runtime.MailboxBlocked("AutoClaimMailbox") then return end
    if not packet({ "Mailbox", "OpenInbox" }) or not packet({ "Mailbox", "Claim" }) then
        logw("AutoClaimMailbox: thieu Networking.Mailbox.OpenInbox/Claim -> tat.")
        c.Enabled = false
        return
    end

    local ok, inbox = firePacket({ "Mailbox", "OpenInbox" })
    if not ok or type(inbox) ~= "table" then
        actionLog("AutoClaimMailbox", "SKIP", "no inbox")
        return
    end

    -- Tổng số quà thật có trong hộp thư khi mở (để báo webhook).
    local totalGifts = 0
    for giftId, giftData in pairs(inbox) do
        if type(giftId) == "string" and type(giftData) == "table" then
            totalGifts = totalGifts + 1
        end
    end

    local claimed = 0
    local maxPerCycle = math.max(tonumber(c.MaxPerCycle) or 20, 1)
    for giftId, giftData in pairs(inbox) do
        if claimed >= maxPerCycle then break end
        if type(giftId) == "string" and type(giftData) == "table" then
            local okClaim, result = firePacket({ "Mailbox", "Claim" }, giftId)
            if okClaim and result == true then
                claimed = claimed + 1
                actionLog("AutoClaimMailbox", "DONE", giftId)
                if not waitAlive(0.2) then return end
            end
        end
    end

    if claimed > 0 then
        Runtime.MailClaimedTotal = (Runtime.MailClaimedTotal or 0) + claimed
        State.LastMailbox = os.date("%H:%M:%S") .. " claimed=" .. tostring(claimed)
        actionLog("AutoClaimMailbox", "DONE", "claimed=" .. tostring(claimed))
        -- Báo webhook cho chồng: nhận được mấy quà + tổng trong hộp + tổng phiên.
        Runtime.MailClaimSeq = (Runtime.MailClaimSeq or 0) + 1
        sendWebhookOnce(
            "mailclaim:" .. tostring(Runtime.MailClaimSeq),
            "📬 Mailbox → Đã Nhận Quà",
            ("Đã nhận **%d** quà từ hộp thư."):format(claimed),
            {
                webhookField("👤 Tài khoản", getAccountName(), true),
                webhookField("🆔 UserId", tostring(LocalPlayer.UserId), true),
                webhookField("📥 Nhận vòng này", "x" .. tostring(claimed), true),
                webhookField("📨 Quà trong hộp", "x" .. tostring(totalGifts), true),
                webhookField("🧮 Tổng phiên này", "x" .. tostring(Runtime.MailClaimedTotal), true),
            },
            0x3BA55D, -- xanh lá
            {
                author = "Kaitun • AutoClaimMailbox",
                footer = "Kaitun AutoClaimMailbox • " .. getAccountName(),
            }
        )
    else
        State.LastMailbox = os.date("%H:%M:%S") .. " empty"
    end
end

do
local MailSeedSeq = 0
local MailRecipientCache = {}

local function resolveMailboxRecipient(c, actionName)
    if type(c) ~= "table" then
        return nil
    end
    if type(c.RecipientUserId) == "number" and c.RecipientUserId > 0 then
        return c.RecipientUserId, c.RecipientUsername
    end
    local username = c.RecipientUsername
    if type(username) ~= "string" or username == "" then
        actionLog(actionName or "AutoMail", "SKIP", "missing recipient")
        return nil
    end
    if MailRecipientCache[username] then
        return MailRecipientCache[username].UserId, MailRecipientCache[username].Name
    end
    local p = packet({ "Mailbox", "LookupPlayer" })
    if not p then
        actionLog(actionName or "AutoMail", "SKIP", "missing Mailbox.LookupPlayer")
        return nil
    end
    local ok, userId, displayName = pcall(function()
        return p:Fire(username)
    end)
    if not ok then
        actionLog(actionName or "AutoMail", "ERROR", "LookupPlayer " .. compactText(userId, 60))
        return nil
    end
    if type(userId) ~= "number" or userId <= 0 then
        actionLog(actionName or "AutoMail", "SKIP", "recipient not found " .. tostring(username))
        return nil
    end
    MailRecipientCache[username] = { UserId = userId, Name = displayName or username }
    return userId, displayName or username
end

local function getSeedInventoryEntries()
    local replica = getPlayerReplica()
    if not (replica and replica.Data and type(replica.Data.Inventory) == "table") then
        return {}, "no replica inventory"
    end
    local seeds = replica.Data.Inventory.Seeds
    if type(seeds) ~= "table" then
        return {}, "no seed inventory"
    end
    local out = {}
    for key, count in pairs(seeds) do
        local n = math.floor(tonumber(count) or 0)
        if type(key) == "string" and key ~= "" and n > 0 then
            table.insert(out, {
                ItemKey = key,
                DisplayName = key,
                Count = n,
            })
        end
    end
    table.sort(out, function(a, b)
        return tostring(a.ItemKey) < tostring(b.ItemKey)
    end)
    return out
end

local function buildAutoMailSeedConfig()
    local base = CFG.AutoMailSeeds or {}
    local rb = CFG.AutoMailRainbow or {}
    local enabled = base.Enabled ~= false or rb.Enabled ~= false
    local names = {}
    addConfiguredNames(names, base.SeedNames or base.Seeds or base.List)
    if rb.Enabled ~= false then
        names[normalizeItemName("Rainbow")] = true
    end
    return {
        Enabled = enabled,
        RecipientUsername = base.RecipientUsername or rb.RecipientUsername,
        RecipientUserId = tonumber(base.RecipientUserId) or tonumber(rb.RecipientUserId) or 0,
        Note = base.Note ~= nil and base.Note or rb.Note,
        DelayBeforeSend = tonumber(base.DelayBeforeSend) or tonumber(rb.DelayBeforeSend) or 0,
        MaxPerBatch = math.clamp(math.floor(tonumber(base.MaxPerBatch) or 20), 1, 20),
        Names = names,
    }
end

local function buildMailSeedCandidates(c)
    local entries, reason = getSeedInventoryEntries()
    local out = {}
    if next(c.Names) == nil then
        return out, "no configured seed names"
    end
    for _, entry in ipairs(entries) do
        if nameMatchesConfiguredSet(entry.ItemKey, c.Names)
            or nameMatchesConfiguredSet(entry.DisplayName, c.Names) then
            table.insert(out, entry)
        end
    end
    return out, (#entries == 0 and reason or nil)
end

local function notifyMailSeedSent(seedKey, sentCount, startCount, recipientName, recipientId, note, resultMsg, batches)
    MailSeedSeq = MailSeedSeq + 1
    local remain = math.max((tonumber(startCount) or 0) - (tonumber(sentCount) or 0), 0)
    local title = (hasRainbowText(seedKey) and "Rainbow Seed" or tostring(seedKey)) .. " -> Da Gui Mailbox"
    return sendWebhookOnce(
        "mailseed:" .. tostring(MailSeedSeq) .. ":" .. tostring(seedKey),
        title,
        ("%s x%d -> %s"):format(tostring(seedKey), tonumber(sentCount) or 0, tostring(recipientName or recipientId)),
        {
            webhookField("Acc gui", getAccountName(), true),
            webhookField("Acc nhan", tostring(recipientName or "-"), true),
            webhookField("Seed", tostring(seedKey), true),
            webhookField("So luong", "x" .. tostring(sentCount), true),
            webhookField("Con lai", "x" .. tostring(remain), true),
            webhookField("Batch", tostring(batches or 1), true),
            webhookField("Ket qua", tostring(resultMsg ~= "" and resultMsg or "Gift sent!"), false),
        },
        hasRainbowText(seedKey) and 0x9B59B6 or 0x3BA55D,
        {
            footer = "Kaitun AutoMailSeeds - " .. getAccountName(),
            content = tostring((CFG.Webhook and CFG.Webhook.Mention) or ""),
        }
    )
end

function Runtime.DoAutoMailSeeds()
    local c = buildAutoMailSeedConfig()
    if not c.Enabled then return end
    if Runtime.MailboxBlocked("AutoMailSeeds") then return end
    if not packet({ "Mailbox", "SendBatch" }) then
        logw("AutoMailSeeds: thieu Networking.Mailbox.SendBatch -> tat.")
        if CFG.AutoMailSeeds then CFG.AutoMailSeeds.Enabled = false end
        if CFG.AutoMailRainbow then CFG.AutoMailRainbow.Enabled = false end
        return
    end

    local candidates, reason = buildMailSeedCandidates(c)
    if #candidates == 0 then
        if reason then
            actionLog("AutoMailSeeds", "SKIP", tostring(reason))
        end
        return
    end

    local delayBeforeSend = math.max(tonumber(c.DelayBeforeSend) or 0, 0)
    if delayBeforeSend > 0 then
        State.LastMailRainbow = os.date("%H:%M:%S") .. " wait send seed"
        if not waitAlive(delayBeforeSend) then return end
        candidates = buildMailSeedCandidates(c)
        if #candidates == 0 then
            actionLog("AutoMailSeeds", "SKIP", "no seed after wait")
            return
        end
    end

    local userId, recipientName = resolveMailboxRecipient(c, "AutoMailSeeds")
    if not userId then return end
    if userId == LocalPlayer.UserId then
        actionLog("AutoMailSeeds", "SKIP", "recipient is self")
        return
    end

    local p = packet({ "Mailbox", "SendBatch" })
    local note = tostring(c.Note or "")
    for _, seed in ipairs(candidates) do
        local remaining = math.floor(tonumber(seed.Count) or 0)
        local startCount = remaining
        local sentTotal = 0
        local batches = 0
        while remaining > 0 do
            local chunk = math.min(remaining, c.MaxPerBatch)
            local items = {
                { Category = "Seeds", ItemKey = seed.ItemKey, Count = chunk },
            }
            local ok, success, msg = pcall(function()
                return p:Fire(userId, items, note)
            end)
            if not ok then
                actionLog("AutoMailSeeds", "ERROR", "SendBatch " .. compactText(success, 60))
                break
            end
            if not success then
                actionLog("AutoMailSeeds", "WARN", tostring(msg ~= "" and msg or "Could not send gift"))
                break
            end
            sentTotal = sentTotal + chunk
            remaining = remaining - chunk
            batches = batches + 1
            State.LastMailRainbow = os.date("%H:%M:%S")
                .. (" sent %s x%d -> %s"):format(tostring(seed.ItemKey), sentTotal, tostring(recipientName or userId))
            actionLog("AutoMailSeeds", "DONE", ("%s x%d"):format(tostring(seed.ItemKey), chunk))
            if remaining > 0 and not waitAlive(0.8) then return end
        end
        if sentTotal > 0 then
            notifyMailSeedSent(seed.ItemKey, sentTotal, startCount, recipientName, userId, note, "Gift sent!", batches)
            if not waitAlive(0.6) then return end
        end
    end
end

Runtime.DoAutoMailRainbow = Runtime.DoAutoMailSeeds

-- Mail Fruits: gửi TRÁI CÂY đã thu hoạch qua Mailbox. Category="HarvestedFruits", ItemKey=fruit.Id
-- (xác nhận MailboxController.lua:642-649 -> entry là bảng có .Id; SendBatch dùng ItemKey=Id như Pets).
local function getFruitInventoryEntries()
    local replica = getPlayerReplica()
    if not (replica and replica.Data and type(replica.Data.Inventory) == "table") then
        return {}, "no replica inventory"
    end
    local fruits = replica.Data.Inventory.HarvestedFruits
    if type(fruits) ~= "table" then
        return {}, "no fruit inventory"
    end
    local out = {}
    for key, entry in pairs(fruits) do
        if type(entry) == "table" and entry.Id ~= nil then
            -- tên quả: field FruitName (xác nhận MailboxItemCatalog.lua:293 'p85.FruitName or p85.Name'),
            -- fallback Name/SeedName/CorePartName cho chắc.
            local name = entry.FruitName or entry.Name or entry.SeedName or entry.CorePartName
            table.insert(out, {
                ItemKey = entry.Id,
                DisplayName = type(name) == "string" and name or tostring(key),
                Mutation = entry.Mutation,
                Count = 1,
            })
        end
    end
    return out
end

function Runtime.DoAutoMailFruits()
    local c = CFG.AutoMailFruits
    if not (c and c.Enabled) then return end
    if Runtime.MailboxBlocked("AutoMailFruits") then return end
    if not packet({ "Mailbox", "SendBatch" }) then
        logw("AutoMailFruits: thieu Networking.Mailbox.SendBatch -> tat.")
        c.Enabled = false
        return
    end

    local entries = getFruitInventoryEntries()
    -- Only These Fruits: có list thì chỉ gửi quả tên khớp (best-effort theo field tên ở trên).
    local onlyNames, onlyActive = {}, false
    for _, n in ipairs(type(c.OnlyThese) == "table" and c.OnlyThese or {}) do
        if type(n) == "string" and n ~= "" then onlyNames[string.lower(n)] = true; onlyActive = true end
    end
    -- Keep Favorites: không gửi quả tên nằm trong KeepSeeds.List (để dành).
    local keepFav = {}
    local keepList = CFG.KeepSeeds and type(CFG.KeepSeeds.List) == "table" and CFG.KeepSeeds.List or {}
    for _, n in ipairs(keepList) do
        if type(n) == "string" and n ~= "" then keepFav[string.lower(n)] = true end
    end

    local toSend = {}
    for _, e in ipairs(entries) do
        local nm = string.lower(tostring(e.DisplayName))
        local okName = (not onlyActive) or onlyNames[nm] == true
        local favBlocked = false
        for k in pairs(keepFav) do
            if nm:find(k, 1, true) then favBlocked = true break end
        end
        if okName and not favBlocked then table.insert(toSend, e) end
    end

    local minFruits = math.max(math.floor(tonumber(c.MinFruits) or 0), 1)
    if #toSend < minFruits then
        actionLog("AutoMailFruits", "SKIP", ("%d/%d fruit"):format(#toSend, minFruits))
        return
    end

    local userId, recipientName = resolveMailboxRecipient(c, "AutoMailFruits")
    if not userId then return end
    if userId == LocalPlayer.UserId then
        actionLog("AutoMailFruits", "SKIP", "recipient is self")
        return
    end

    local p = packet({ "Mailbox", "SendBatch" })
    local note = tostring(c.Note or "")
    local sent = 0
    local maxPerCycle = math.max(math.floor(tonumber(c.MaxPerCycle) or 20), 1)
    for _, e in ipairs(toSend) do
        if sent >= maxPerCycle then break end
        local items = { { Category = "HarvestedFruits", ItemKey = e.ItemKey, Count = 1 } }
        local ok, success, msg = pcall(function() return p:Fire(userId, items, note) end)
        if not ok then
            actionLog("AutoMailFruits", "ERROR", compactText(success, 60))
            break
        end
        if not success then
            actionLog("AutoMailFruits", "WARN", tostring(msg ~= "" and msg or "could not send fruit"))
            break
        end
        sent = sent + 1
        actionLog("AutoMailFruits", "DONE", tostring(e.DisplayName) .. " -> " .. tostring(recipientName or userId))
        if not waitAlive(0.6) then return end
    end
end
end

-- =====================================================================
-- AutoMailRainbow: phát hiện rainbow seed trong người -> đợi DELAY -> gửi qua Mailbox cho 1 acc.
--   Remote thật: Networking.Mailbox.SendBatch / LookupPlayer (Networking.lua:379-380).
--   item = { Category = "Seeds", ItemKey = <seedKey>, Count = n } (MailboxController.lua:991-996).
--   Mailbox trừ từ Inventory.Seeds (data), KHÔNG trừ Tool trong Backpack.
--   Gói trong do/end + export qua Runtime để không chiếm thêm slot local ở main scope.
-- =====================================================================
do
    local MailRainbowSentKeys = {} -- chống gửi trùng trong phiên (theo itemKey)
    local MailRainbowSeq = 0       -- đếm số lần gửi để tạo webhook key duy nhất

    -- Lấy đúng ItemKey rainbow trong Inventory.Seeds để gửi không lỗi.
    local function resolveMailRainbowItemKey(tool)
        -- 1) Ưu tiên đọc kho thật (PlayerStateClient.Data.Inventory.Seeds)
        local replica = getPlayerReplica()
        if replica and replica.Data and type(replica.Data.Inventory) == "table" then
            local seeds = replica.Data.Inventory.Seeds
            if type(seeds) == "table" then
                for key, count in pairs(seeds) do
                    if type(key) == "string" and (tonumber(count) or 0) > 0 and hasRainbowText(key) then
                        return key, tonumber(count) or 0
                    end
                end
            end
        end
        -- 2) Fallback: attribute SeedTool của tool
        if tool then
            local st = tool:GetAttribute("SeedTool")
            if type(st) == "string" and st ~= "" then
                return st, nil
            end
        end
        -- 3) Fallback cuối: theo buffer mẫu (ItemKey = "Rainbow")
        return "Rainbow", nil
    end

    local function resolveMailRainbowRecipient(c)
        if type(c.RecipientUserId) == "number" and c.RecipientUserId > 0 then
            return c.RecipientUserId
        end
        local username = c.RecipientUsername
        if type(username) ~= "string" or username == "" then
            actionLog("AutoMailRainbow", "SKIP", "chua cau hinh recipient")
            return nil
        end
        local p = packet({ "Mailbox", "LookupPlayer" })
        if not p then
            actionLog("AutoMailRainbow", "SKIP", "thieu Mailbox.LookupPlayer")
            return nil
        end
        local ok, userId, name = pcall(function()
            return p:Fire(username)
        end)
        if not ok then
            actionLog("AutoMailRainbow", "ERROR", "LookupPlayer " .. compactText(userId, 60))
            return nil
        end
        if type(userId) ~= "number" or userId <= 0 then
            actionLog("AutoMailRainbow", "SKIP", "khong thay user '" .. tostring(username) .. "'")
            return nil
        end
        return userId, name
    end

    -- Webhook embed chuyên nghiệp báo cho chồng khi gửi mail thành công.
    -- KHÔNG persist key này: seed gửi đi là rời inventory rồi, và itemKey chung ("Rainbow")
    -- nên lưu file sẽ chặn luôn những lần gửi seed mới sau này. Seq chỉ để webhook luôn bắn.
    local function notifyMailRainbowSent(itemKey, sendCount, invCount, recipientName, recipientId, note, resultMsg)
        MailRainbowSeq = MailRainbowSeq + 1
        local key = "mailrb:" .. tostring(MailRainbowSeq) .. ":" .. tostring(itemKey)
        local remain = invCount and tostring(math.max((tonumber(invCount) or 0) - sendCount, 0)) or "?"
        return sendWebhookOnce(
            key,
            "🌈 Rainbow Seed → Đã Gửi Mailbox",
            ("Đã tự gửi **%s** x%d cho **%s** qua Mailbox."):format(
                tostring(itemKey), sendCount, tostring(recipientName or recipientId)),
            {
                webhookField("👤 Acc gửi", getAccountName(), true),
                webhookField("🆔 UserId gửi", tostring(LocalPlayer.UserId), true),
                webhookField("🌱 Seed", tostring(itemKey), true),
                webhookField("📨 Người nhận", tostring(recipientName or "-"), true),
                webhookField("🔖 UserId nhận", tostring(recipientId or "-"), true),
                webhookField("📦 Đã gửi", "x" .. tostring(sendCount), true),
                webhookField("🎒 Kho còn lại", remain, true),
                webhookField("📝 Ghi chú", tostring(note ~= "" and note or "-"), true),
                webhookField("✅ Kết quả", tostring(resultMsg ~= "" and resultMsg or "Gift sent!"), false),
            },
            0x9B59B6, -- tím rainbow
            {
                author = "Kaitun • AutoMailRainbow",
                footer = "Kaitun AutoMailRainbow • " .. getAccountName(),
            }
        )
    end

    function Runtime.DoAutoMailRainbow()
        local c = CFG.AutoMailRainbow
        if not (c and c.Enabled) then return end
        if Runtime.MailboxBlocked("AutoMailRainbow") then return end
        if not packet({ "Mailbox", "SendBatch" }) then
            logw("AutoMailRainbow: thieu Networking.Mailbox.SendBatch -> tat.")
            c.Enabled = false
            return
        end

        -- Tìm rainbow seed trong Backpack/Character (cùng logic ValuableWatcher).
        local tool
        for _, t in ipairs(getAllTools()) do
            if isRainbowSeedTool(t) then
                tool = t
                break
            end
        end
        if not tool then
            return
        end

        local itemKey = resolveMailRainbowItemKey(tool)
        if c.SkipResentKey ~= false and MailRainbowSentKeys[itemKey] then
            return
        end

        actionLog("AutoMailRainbow", "DETECTED", "key=" .. tostring(itemKey))

        local delayBeforeSend = math.max(tonumber(c.DelayBeforeSend) or 0, 0)
        if delayBeforeSend > 0 then
            if not waitAlive(delayBeforeSend) then return end
        end

        -- Còn rainbow seed sau khi đợi mới gửi (tránh đã trồng/dùng hết trong lúc chờ).
        local stillHas = false
        for _, t in ipairs(getAllTools()) do
            if isRainbowSeedTool(t) then
                stillHas = true
                break
            end
        end
        if not stillHas then
            actionLog("AutoMailRainbow", "SKIP", "het rainbow seed sau khi doi")
            return
        end

        -- Đọc lại key + số lượng kho ngay trước khi gửi (cho webhook chính xác).
        local finalKey, invCount = resolveMailRainbowItemKey(tool)
        itemKey = finalKey or itemKey

        local userId, recipientName = resolveMailRainbowRecipient(c)
        if not userId then return end

        local sendCount = math.max(tonumber(c.SendCount) or 1, 1)
        local note = tostring(c.Note or "")
        local items = {
            { Category = "Seeds", ItemKey = itemKey, Count = sendCount },
        }
        local p = packet({ "Mailbox", "SendBatch" })
        local ok, success, msg = pcall(function()
            return p:Fire(userId, items, note)
        end)
        if not ok then
            actionLog("AutoMailRainbow", "ERROR", "SendBatch " .. compactText(success, 60))
            return
        end

        if success then
            if c.SkipResentKey ~= false then
                MailRainbowSentKeys[itemKey] = true
            end
            State.LastMailRainbow = os.date("%H:%M:%S")
                .. (" sent %s x%d -> %s"):format(tostring(itemKey), sendCount, tostring(recipientName or userId))
            actionLog("AutoMailRainbow", "DONE", tostring(msg ~= "" and msg or "Gift sent!"))
            -- Gửi thành công -> báo webhook embed cho chồng.
            notifyMailRainbowSent(itemKey, sendCount, invCount, recipientName, userId, note, msg)
        else
            State.LastMailRainbow = os.date("%H:%M:%S") .. " fail"
            actionLog("AutoMailRainbow", "WARN", tostring(msg ~= "" and msg or "Could not send gift"))
        end
    end
end

-- =====================================================================
-- AutoMailPets: gửi pet theo TÊN (PetNames) đang TRONG TÚI (chưa equip) qua Mailbox.
--   Remote thật: Networking.Mailbox.SendBatch (Networking.lua:379).
--   item = { Category = "Pets", ItemKey = <petId>, Count = 1 } (MailboxController.lua:991-995).
--   Pet phải Equipped ~= true mới gift được (MailboxController.lua:650-659).
--   Gói trong do/end + export qua Runtime để không chiếm thêm slot local ở main scope.
-- =====================================================================
do
    local MailPetSentIds = {} -- chống gửi trùng trong phiên (theo petId)
    local MailPetSeq = 0      -- tạo webhook key duy nhất mỗi lần gửi

    local function resolveMailPetRecipient(c)
        if type(c.RecipientUserId) == "number" and c.RecipientUserId > 0 then
            return c.RecipientUserId
        end
        local username = c.RecipientUsername
        if type(username) ~= "string" or username == "" then
            actionLog("AutoMailPets", "SKIP", "chua cau hinh recipient")
            return nil
        end
        local p = packet({ "Mailbox", "LookupPlayer" })
        if not p then
            actionLog("AutoMailPets", "SKIP", "thieu Mailbox.LookupPlayer")
            return nil
        end
        local ok, userId, name = pcall(function()
            return p:Fire(username)
        end)
        if not ok then
            actionLog("AutoMailPets", "ERROR", "LookupPlayer " .. compactText(userId, 60))
            return nil
        end
        if type(userId) ~= "number" or userId <= 0 then
            actionLog("AutoMailPets", "SKIP", "khong thay user '" .. tostring(username) .. "'")
            return nil
        end
        return userId, name
    end

    -- Pet chưa equip, TÊN nằm trong PetNames, chưa gửi trong phiên này.
    local function buildMailPetCandidates(c)
        local wanted = {}
        for _, w in ipairs(type(c.PetNames) == "table" and c.PetNames or {}) do
            if type(w) == "string" and w ~= "" then wanted[string.lower(w)] = true end
        end
        local out = {}
        if next(wanted) == nil then return out end
        for _, e in ipairs(Runtime.GetPetInventoryEntries()) do
            if not e.Equipped
                and type(e.Id) == "string" and e.Id ~= ""
                and not MailPetSentIds[e.Id]
                and type(e.Name) == "string" and wanted[string.lower(e.Name)] then
                table.insert(out, e)
            end
        end
        -- Xịn nhất gửi trước.
        table.sort(out, function(a, b)
            return getPetScore(a.Name) > getPetScore(b.Name)
        end)
        return out
    end

    local function notifyMailPetSent(petName, rarity, petType, recipientName, recipientId, note, resultMsg)
        MailPetSeq = MailPetSeq + 1
        local key = "mailpet:" .. tostring(MailPetSeq) .. ":" .. tostring(petName)
        return sendWebhookOnce(
            key,
            "🐾 Pet → Đã Gửi Mailbox",
            ("Đã tự gửi **%s** • **%s** cho **%s** qua Mailbox."):format(
                tostring(petName), tostring(rarity), tostring(recipientName or recipientId)),
            {
                webhookField("👤 Acc gửi", getAccountName(), true),
                webhookField("🆔 UserId gửi", tostring(LocalPlayer.UserId), true),
                webhookField("🐾 Pet", tostring(petName), true),
                webhookField("⭐ Độ hiếm", tostring(rarity), true),
                webhookField("🧬 Loại", tostring(petType ~= nil and petType ~= "" and petType or "-"), true),
                webhookField("📨 Người nhận", tostring(recipientName or "-"), true),
                webhookField("🔖 UserId nhận", tostring(recipientId or "-"), true),
                webhookField("📝 Ghi chú", tostring(note ~= "" and note or "-"), true),
                webhookField("✅ Kết quả", tostring(resultMsg ~= "" and resultMsg or "Gift sent!"), false),
            },
            Runtime.RarityColor(rarity, 0xE67E22),
            {
                author = "Kaitun • AutoMailPets",
                footer = "Kaitun AutoMailPets • " .. getAccountName(),
                thumbnail = Runtime.GetPetImage(petName),
            }
        )
    end

    notifyMailPetSent = function(petName, rarity, petType, recipientName, recipientId, note, resultMsg)
        MailPetSeq = MailPetSeq + 1
        local key = "mailpet:" .. tostring(MailPetSeq) .. ":" .. tostring(petName)
        return sendWebhookOnce(
            key,
            "Pet -> Da Gui Mailbox",
            ("%s %s -> %s"):format(tostring(petName), tostring(rarity), tostring(recipientName or recipientId)),
            {
                webhookField("Acc gui", getAccountName(), true),
                webhookField("Acc nhan", tostring(recipientName or "-"), true),
                webhookField("Pet", tostring(petName), true),
                webhookField("Do hiem", tostring(rarity), true),
                webhookField("Ket qua", tostring(resultMsg ~= "" and resultMsg or "Gift sent!"), false),
            },
            Runtime.RarityColor(rarity, 0xE67E22),
            {
                footer = "Kaitun AutoMailPets - " .. getAccountName(),
            }
        )
    end

    function Runtime.DoAutoMailPets()
        local c = CFG.AutoMailPets
        if not (c and c.Enabled) then return end
        if Runtime.MailboxBlocked("AutoMailPets") then return end
        if not packet({ "Mailbox", "SendBatch" }) then
            logw("AutoMailPets: thieu Networking.Mailbox.SendBatch -> tat.")
            c.Enabled = false
            return
        end

        local candidates = buildMailPetCandidates(c)
        if #candidates == 0 then
            return
        end

        actionLog("AutoMailPets", "DETECTED", "pets=" .. tostring(#candidates))

        local delayBeforeSend = math.max(tonumber(c.DelayBeforeSend) or 0, 0)
        if delayBeforeSend > 0 then
            if not waitAlive(delayBeforeSend) then return end
            -- đọc lại sau khi đợi (pet có thể đã bị equip/đổi trạng thái trong lúc chờ)
            candidates = buildMailPetCandidates(c)
            if #candidates == 0 then
                actionLog("AutoMailPets", "SKIP", "het pet du dieu kien sau khi doi")
                return
            end
        end

        local userId, recipientName = resolveMailPetRecipient(c)
        if not userId then return end
        if userId == LocalPlayer.UserId then
            actionLog("AutoMailPets", "SKIP", "recipient la chinh acc nay")
            return
        end

        local note = tostring(c.Note or "")
        local p = packet({ "Mailbox", "SendBatch" })
        local sent = 0
        local maxPerCycle = math.max(tonumber(c.MaxPerCycle) or 2, 1)
        for _, e in ipairs(candidates) do
            if sent >= maxPerCycle then break end
            local items = {
                { Category = "Pets", ItemKey = e.Id, Count = 1 },
            }
            local ok, success, msg = pcall(function()
                return p:Fire(userId, items, note)
            end)
            if not ok then
                actionLog("AutoMailPets", "ERROR", "SendBatch " .. compactText(success, 60))
            elseif success then
                if c.SkipResentKey ~= false then
                    MailPetSentIds[e.Id] = true
                end
                sent = sent + 1
                State.LastMailPets = os.date("%H:%M:%S")
                    .. (" sent %s(%s) -> %s"):format(tostring(e.Name), tostring(e.Rarity), tostring(recipientName or userId))
                actionLog("AutoMailPets", "DONE", ("%s %s"):format(tostring(e.Name), tostring(msg ~= "" and msg or "Gift sent!")))
                notifyMailPetSent(e.Name, e.Rarity, e.Type, recipientName, userId, note, msg)
                -- giãn nhịp > cooldown webhook (CFG.Webhook.Cooldown, mặc định 2s) để embed mỗi
                -- con pet đều gửi được, không bị rớt do cooldown.
                if not waitAlive(math.max((tonumber(CFG.Webhook and CFG.Webhook.Cooldown) or 2) + 0.5, 1)) then return end
            else
                State.LastMailPets = os.date("%H:%M:%S") .. " fail " .. tostring(e.Name)
                actionLog("AutoMailPets", "WARN", tostring(e.Name) .. " " .. tostring(msg ~= "" and msg or "Could not send gift"))
                if not waitAlive(0.6) then return end
            end
        end
    end
end

local function doAutoSnapPets()
    local c = CFG.AutoSnapPets
    if not (c and c.Enabled) then return end
    if not packet({ "Pets", "SnapPets" }) then
        logw("AutoSnapPets: thieu Networking.Pets.SnapPets -> tat.")
        c.Enabled = false
        return
    end
    local root = getRootPart()
    if not root then
        actionLog("AutoSnapPets", "SKIP", "missing root")
        return
    end
    if firePacket({ "Pets", "SnapPets" }, root.Position) then
        State.LastSnap = os.date("%H:%M:%S") .. " ok"
        actionLog("AutoSnapPets", "DONE")
    end
end

local function doAutoSpendSkill()
    local c = CFG.AutoSpendSkill
    if not (c and c.Enabled) then return end
    if not packet({ "SkillPoints", "SpendSkillPoint" }) then
        logw("AutoSpendSkill: thiếu Networking.SkillPoints.SpendSkillPoint -> tắt.")
        c.Enabled = false
        return
    end
    local skillData = LocalPlayer:FindFirstChild("SkillData")
    local pointsObj = skillData and skillData:FindFirstChild("SkillPoints")
    if not pointsObj then
        actionLog("AutoSpendSkill", "SKIP", "missing SkillData/SkillPoints")
        return
    end
    local priority = c.Priority or { "MaxBackpack", "ShovelPower", "BaseSpeed", "BaseJump" }
    local spent = 0
    for _ = 1, 40 do
        local points = tonumber(pointsObj.Value) or 0
        if points <= 0 then break end
        local target
        for _, skillName in ipairs(priority) do
            local sk = skillData:FindFirstChild(skillName)
            local lvl = sk and tonumber(sk.Value)
            if lvl and lvl <= points then
                target = skillName
                break
            end
        end
        if not target then break end
        actionLog("AutoSpendSkill", "SPEND", target .. " points=" .. tostring(points))
        firePacket({ "SkillPoints", "SpendSkillPoint" }, target)
        spent = spent + 1
        if not waitAlive(tonumber(c.Delay) or 0.3) then return end
    end
    if spent > 0 then
        actionLog("AutoSpendSkill", "DONE", "spent=" .. tostring(spent))
    end
end

-- Mở rộng vườn (xác nhận PlotsController.lua:337: Networking.Actions.ExpandGarden:Fire())

-- Mua thêm ô pet (xác nhận PetListController.lua:448: RequestPurchasePetSlot:Fire())

local function getNextPetSlotPrice()
    if not (PetSlotPrices and type(PetSlotPrices.GetNextPrice) == "function") then
        return nil
    end
    return tonumber(PetSlotPrices.GetNextPrice(getMaxEquippedPets()))
end

local function doAutoPurchasePetSlot()
    local c = CFG.AutoPurchasePetSlot
    if not (c and c.Enabled) then return end
    if Runtime.ShouldYieldForSeedPriority("AutoPurchasePetSlot") or Runtime.ShouldYieldForPetPriority("AutoPurchasePetSlot") then
        return
    end
    if not packet({ "Pets", "RequestPurchasePetSlot" }) then
        logw("AutoPurchasePetSlot: thieu Networking.Pets.RequestPurchasePetSlot -> tat.")
        c.Enabled = false
        return
    end
    -- Max Pet Slots: đã đạt số ô tối đa cho phép thì ngừng mua (0 = không giới hạn, mua tới max game).
    local maxSlots = tonumber(c.MaxSlots) or 0
    if maxSlots > 0 and getMaxEquippedPets() >= maxSlots then
        actionLog("AutoPurchasePetSlot", "SKIP", "reached MaxSlots " .. tostring(maxSlots))
        return
    end
    if CFG.AutoBuySeed and CFG.AutoBuySeed.Enabled then
        local seedCandidates = buildSeedCandidates(CFG.AutoBuySeed)
        if type(seedCandidates) == "table" and #seedCandidates > 0 then
            actionLog("AutoPurchasePetSlot", "SKIP", "seed first " .. tostring(seedCandidates[1].Name))
            return
        end
    end
    local price = getNextPetSlotPrice()
    if not price then
        actionLog("AutoPurchasePetSlot", "SKIP", "max")
        return
    end
    local keep = tonumber(c.KeepSheckles) or 0
    local money = tonumber(getSheckles()) or 0
    if money - keep < price then
        actionLog("AutoPurchasePetSlot", "SKIP", "need=" .. tostring(price))
        return
    end
    actionLog("AutoPurchasePetSlot", "BUY", "$" .. tostring(price))
    firePacket({ "Pets", "RequestPurchasePetSlot" })
end

local function getWildPetRefFolder()
    local map = workspace:FindFirstChild("Map")
    return map and map:FindFirstChild("WildPetRef")
end

local function getWildPetRarity(ref, petName)
    local rarity = ref and ref:GetAttribute("Rarity")
    if type(rarity) == "string" and rarity ~= "" then
        return normalizeRarity(rarity)
    end
    local data = PetData and PetData[petName]
    return normalizeRarity(data and data.Rarity or "Common")
end

local function buildWildPetCandidates(c)
    local folder = getWildPetRefFolder()
    local out = {}
    if not folder then
        return out, "no WildPetRef"
    end
    local keep = tonumber(c.KeepSheckles) or 0
    local money = tonumber(getSheckles()) or 0
    local budget = math.max(money - keep, 0)
    local minRarity = c.MinRarity or "Common"

    -- Pets To Buy theo SỐ LƯỢNG: OwnLimit = { [tên] = max muốn sở hữu }.
    --   Có map -> CHỈ tame tên trong map, và dừng khi (đang có + sắp tame) >= max (không mua dư).
    -- Không có map nhưng có PetNames (list) -> chỉ tame tên trong list (không giới hạn số).
    -- Không có cả hai -> tame theo MinRarity như cũ.
    local capMap
    if type(c.OwnLimit) == "table" and next(c.OwnLimit) ~= nil then
        capMap = {}
        for kName, v in pairs(c.OwnLimit) do
            if type(kName) == "string" and tonumber(v) then capMap[string.lower(kName)] = tonumber(v) end
        end
    end
    local nameFilter
    if not capMap and type(c.PetNames) == "table" and #c.PetNames > 0 then
        nameFilter = {}
        for _, n in ipairs(c.PetNames) do
            if type(n) == "string" and n ~= "" then nameFilter[string.lower(n)] = true end
        end
    end
    local owned = {}
    if capMap then
        for _, e in ipairs(Runtime.GetPetInventoryEntries()) do
            if type(e.Name) == "string" then
                local k = string.lower(e.Name)
                owned[k] = (owned[k] or 0) + 1
            end
        end
    end
    local planned = {}  -- đếm số đã thêm vào candidate theo tên (để không vượt cap trong 1 vòng)

    for _, ref in ipairs(folder:GetChildren()) do
        if ref:IsA("BasePart") then
            local petName = ref:GetAttribute("PetName")
            local ownerUserId = ref:GetAttribute("OwnerUserId")
            local price = tonumber(ref:GetAttribute("Price")) or 0
            if type(petName) == "string" and petName ~= "" and ownerUserId ~= LocalPlayer.UserId and price <= budget then
                local rarity = getWildPetRarity(ref, petName)
                local lname = string.lower(petName)
                local allow
                if capMap then
                    local cap = capMap[lname]
                    allow = cap ~= nil and ((owned[lname] or 0) + (planned[lname] or 0) < cap)
                elseif nameFilter then
                    allow = nameFilter[lname] == true
                else
                    allow = rarityAllowed(rarity, minRarity)
                end
                if allow then
                    planned[lname] = (planned[lname] or 0) + 1
                    table.insert(out, {
                        Ref = ref,
                        Name = petName,
                        Price = price,
                        Rarity = rarity,
                        Score = ((RarityScore[rarity] or 0) * 100000000) + price,
                    })
                end
            end
        end
    end

    table.sort(out, function(a, b)
        if a.Score ~= b.Score then
            return a.Score > b.Score
        end
        return a.Price > b.Price
    end)
    return out
end

do
    local PetBuySeq = 0
    Runtime.PendingWildPetTames = Runtime.PendingWildPetTames or {}

    local function notifyWildPetBought(info)
        if type(info) ~= "table" then return end
        PetBuySeq = PetBuySeq + 1
        sendWebhookOnce(
            "petbuy:" .. tostring(PetBuySeq) .. ":" .. tostring(info.Name),
            "Pet -> Da Mua Thanh Cong",
            ("%s %s -> %s"):format(tostring(info.Name), tostring(info.Rarity or "-"), getAccountName()),
            {
                webhookField("Acc", getAccountName(), true),
                webhookField("Pet", tostring(info.Name), true),
                webhookField("Do hiem", tostring(info.Rarity or "-"), true),
                webhookField("Gia", tostring(info.Price or "-"), true),
            },
            Runtime.RarityColor(info.Rarity, 0xE67E22),
            {
                footer = "Kaitun AutoTameWildPet - " .. getAccountName(),
            }
        )
    end

    function Runtime.SetupWildPetTameWatcher()
        if Runtime.WildPetTameWatcherReady then
            return
        end
        local resultEvent = packet({ "Pets", "WildPetTameResult" })
        if not (resultEvent and resultEvent.OnClientEvent) then
            actionLog("AutoTameWildPet", "SKIP", "missing WildPetTameResult")
            return
        end
        Runtime.WildPetTameWatcherReady = true
        local conn = resultEvent.OnClientEvent:Connect(function(ref, buyerUserId)
            if buyerUserId ~= LocalPlayer.UserId then
                return
            end
            local pending = Runtime.PendingWildPetTames[ref]
            local info = pending
            if not info and typeof(ref) == "Instance" then
                local petName = ref:GetAttribute("PetName")
                if type(petName) == "string" and petName ~= "" then
                    info = {
                        Name = petName,
                        Rarity = getWildPetRarity(ref, petName),
                        Price = tonumber(ref:GetAttribute("Price")) or 0,
                    }
                end
            end
            Runtime.PendingWildPetTames[ref] = nil
            if info then
                State.LastPet = os.date("%H:%M:%S") .. " bought " .. tostring(info.Name)
                actionLog("AutoTameWildPet", "BOUGHT", tostring(info.Name))
                Runtime.HideBlockingPopups()
                notifyWildPetBought(info)
            end
        end)
        table.insert(Runtime.Cleanups, function()
            pcall(function()
                conn:Disconnect()
            end)
        end)
    end
end

local function doAutoTameWildPet()
    local c = CFG.AutoTameWildPet
    if not (c and c.Enabled) then return end
    Runtime.SetupWildPetTameWatcher()
    if State.SellInProgress or State.AntiStealEngaging then return end
    if not packet({ "Pets", "WildPetTame" }) then
        logw("AutoTameWildPet: thieu Networking.Pets.WildPetTame -> tat.")
        c.Enabled = false
        return
    end
    if Runtime.ShouldYieldForSeedPriority("AutoTameWildPet") then
        return
    end

    local candidates, reason = buildWildPetCandidates(c)
    if #candidates == 0 then
        State.LastPet = os.date("%H:%M:%S") .. " tame skip"
        actionLog("AutoTameWildPet", "SKIP", tostring(reason or "no pet"))
        return
    end

    local tamed = 0
    local maxPerCycle = math.max(tonumber(c.MaxPerCycle) or 3, 1)
    State.PetTameInProgress = true
    State.PetTameUntil = os.clock() + math.max((maxPerCycle * 0.6) + 1, tonumber(c.PriorityYieldSeconds) or 1.5)
    for _, pet in ipairs(candidates) do
        if tamed >= maxPerCycle then break end
        if pet.Ref and pet.Ref.Parent then
            if c.TeleportToPet ~= false then
                teleportNearPosition(pet.Ref.Position, c)
            end
            actionLog("AutoTameWildPet", "BUY", pet.Name .. " " .. tostring(pet.Rarity) .. " $" .. tostring(pet.Price))
            Runtime.PendingWildPetTames[pet.Ref] = {
                Name = pet.Name,
                Rarity = pet.Rarity,
                Price = pet.Price,
            }
            if firePacket({ "Pets", "WildPetTame" }, pet.Ref) then
                tamed = tamed + 1
            else
                Runtime.PendingWildPetTames[pet.Ref] = nil
            end
            if not waitAlive(0.4) then return end
        end
    end
    State.PetTameInProgress = false
    State.PetTameUntil = os.clock() + 0.5
    if tamed > 0 then
        State.LastPet = os.date("%H:%M:%S") .. " tame=" .. tostring(tamed)
        actionLog("AutoTameWildPet", "DONE", "tame=" .. tostring(tamed))
        if c.ReturnHomeAfterTame ~= false then
            teleportToGardenHome("AutoTameWildPet", 0.05)
        end
    end
end

local function getNextExpansionPrice()
    if type(ExpansionPrices) ~= "table" then
        return nil
    end
    local replica = getPlayerReplica()
    local data = replica and replica.Data
    local owned = tonumber(data and data.OwnedExpansions) or 1
    local nextEntry = ExpansionPrices[owned + 1]
    return nextEntry and tonumber(nextEntry.Price) or nil
end

function Runtime.doAutoExpandGarden()
    local c = CFG.AutoExpandGarden
    if not (c and c.Enabled) then return end
    if Runtime.ShouldYieldForSeedPriority("AutoExpandGarden") or Runtime.ShouldYieldForPetPriority("AutoExpandGarden") then
        return
    end
    if not packet({ "Actions", "ExpandGarden" }) then
        logw("AutoExpandGarden: thieu Networking.Actions.ExpandGarden -> tat.")
        c.Enabled = false
        return
    end
    if CFG.AutoBuySeed and CFG.AutoBuySeed.Enabled then
        local seedCandidates = buildSeedCandidates(CFG.AutoBuySeed)
        if type(seedCandidates) == "table" and #seedCandidates > 0 then
            actionLog("AutoExpandGarden", "SKIP", "seed first " .. tostring(seedCandidates[1].Name))
            return
        end
    end
    local price = getNextExpansionPrice()
    if not price then
        actionLog("AutoExpandGarden", "SKIP", "max")
        return
    end
    local keep = tonumber(c.KeepSheckles) or 0
    local money = tonumber(getSheckles()) or 0
    if money - keep < price then
        actionLog("AutoExpandGarden", "SKIP", "need=" .. tostring(price))
        return
    end
    actionLog("AutoExpandGarden", "BUY", "$" .. tostring(price))
    local ok, res = firePacket({ "Actions", "ExpandGarden" })
    if ok and res == true then
        actionLog("AutoExpandGarden", "DONE")
    end
end

-- ============================================================
-- ESP + FPS BOOST  (chỉ client, không gọi remote)
-- ============================================================
local ESPHighlights = {}

local function clearEspHighlights()
    for inst, hl in pairs(ESPHighlights) do
        pcall(function() hl:Destroy() end)
        ESPHighlights[inst] = nil
    end
end

local function ensureHighlight(adornee, fillColor)
    local hl = ESPHighlights[adornee]
    if hl and hl.Parent then
        return hl
    end
    hl = Instance.new("Highlight")
    hl.Name = "KaitunESP"
    hl.FillColor = fillColor
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.55
    hl.OutlineTransparency = 0.1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = adornee
    hl.Parent = adornee
    ESPHighlights[adornee] = hl
    return hl
end

local function doEsp()
    local c = CFG.ESP
    if not (c and (c.ReadyPlants or c.Players)) then
        clearEspHighlights()
        return
    end
    local seen = {}
    if c.ReadyPlants then
        for _, prompt in ipairs(CollectionService:GetTagged("HarvestPrompt")) do
            if prompt:IsA("ProximityPrompt") then
                local model = getHarvestPromptModel(prompt)
                if model then
                    seen[model] = true
                    ensureHighlight(model, Color3.fromRGB(80, 222, 160))
                end
            end
        end
    end
    if c.Players then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                seen[plr.Character] = true
                ensureHighlight(plr.Character, Color3.fromRGB(248, 113, 113))
            end
        end
    end
    for inst, hl in pairs(ESPHighlights) do
        if not seen[inst] or not inst.Parent then
            pcall(function() hl:Destroy() end)
            ESPHighlights[inst] = nil
        end
    end
end

Runtime.ApplyFpsCap = function()
    local c = CFG.FpsBoost
    if not (c and c.Enabled) then
        return
    end
    if type(setfpscap) ~= "function" then
        if Runtime.FpsCapLogged ~= true then
            Runtime.FpsCapLogged = true
            actionLog("FpsBoost", "SKIP", "no setfpscap")
        end
        return
    end
    -- KHÔNG ép tối thiểu 10 nữa: cho phép cap thấp (3-10) đúng ý chồng. Tối thiểu 1 để tránh freeze.
    local target = math.max(math.floor(tonumber(c.TargetFPS) or 30), 1)
    -- LUÔN set lại mỗi vòng (đứng yên ở đúng mức, không để FPS nhảy lung tung).
    local ok = pcall(function()
        setfpscap(target)
    end)
    if ok then
        if Runtime.LastFpsCap ~= target then
            Runtime.LastFpsCap = target
            actionLog("FpsBoost", "APPLIED", "cap=" .. tostring(target))
        end
    else
        actionLog("FpsBoost", "ERROR", "setfpscap failed")
    end
end

local function applyFpsBoost()
    local c = CFG.FpsBoost
    if not (c and c.Enabled) then return end
    Runtime.ApplyFpsCap()
    pcall(function()
        local UserGameSettings = UserSettings():GetService("UserGameSettings")
        UserGameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
    end)
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    if c.MuteAudio ~= false then
        pcall(function()
            local soundService = game:GetService("SoundService")
            soundService.Volume = 0
            for _, inst in ipairs(soundService:GetDescendants()) do
                if inst:IsA("Sound") then
                    inst.Volume = 0
                end
            end
        end)
    end
    pcall(function()
        local Lighting = game:GetService("Lighting")
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 1e6
        if c.DisablePostEffects ~= false then
            for _, inst in ipairs(Lighting:GetDescendants()) do
                if inst:IsA("BloomEffect")
                    or inst:IsA("BlurEffect")
                    or inst:IsA("ColorCorrectionEffect")
                    or inst:IsA("DepthOfFieldEffect")
                    or inst:IsA("SunRaysEffect") then
                    inst.Enabled = false
                end
            end
        end
    end)
    pcall(function()
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain then
            terrain.Decoration = false
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 1
        end
    end)
    if c.DisableEffects ~= false then
        pcall(function()
            for _, inst in ipairs(workspace:GetDescendants()) do
                if inst:IsA("ParticleEmitter")
                    or inst:IsA("Trail")
                    or inst:IsA("Beam")
                    or inst:IsA("Fire")
                    or inst:IsA("Smoke")
                    or inst:IsA("Sparkles") then
                    inst.Enabled = false
                end
            end
        end)
    end
    actionLog("FpsBoost", "APPLIED")
end

-- ============================================================
-- VÒNG LẶP CHẠY  (mỗi tác vụ 1 luồng riêng, có nhịp delay riêng)
-- ============================================================
local ClientLightOriginal = {
    Parts = {},
    Effects = {},
}
local ClientLightLastSummary = nil

local function isEffectInstance(inst)
    return inst:IsA("ParticleEmitter")
        or inst:IsA("Trail")
        or inst:IsA("Beam")
        or inst:IsA("Fire")
        or inst:IsA("Smoke")
        or inst:IsA("Sparkles")
        or inst:IsA("PointLight")
        or inst:IsA("SpotLight")
        or inst:IsA("SurfaceLight")
end

local function isMyGardenPlot(plot)
    local myPlot = getPlot()
    if myPlot and plot == myPlot then
        return true
    end
    local ok, owner = pcall(function()
        return plot:GetAttribute("OwnerUserId")
    end)
    return ok and owner == LocalPlayer.UserId
end

local function restoreClientLight()
    for part, value in pairs(ClientLightOriginal.Parts) do
        if part and part.Parent then
            pcall(function()
                part.LocalTransparencyModifier = value
            end)
        end
    end
    for inst, value in pairs(ClientLightOriginal.Effects) do
        if inst and inst.Parent then
            pcall(function()
                inst.Enabled = value
            end)
        end
    end
    ClientLightOriginal.Parts = {}
    ClientLightOriginal.Effects = {}
end

local function applyClientLight()
    local c = CFG.ClientLight
    if not (c and c.Enabled) then
        return
    end
    local gardens = workspace:FindFirstChild("Gardens")
    if not gardens then
        actionLog("ClientLight", "SKIP", "missing Gardens")
        return
    end

    local hiddenPlots = 0
    local hiddenParts = 0
    local disabledEffects = 0

    for _, plot in ipairs(gardens:GetChildren()) do
        if not isMyGardenPlot(plot) then
            hiddenPlots = hiddenPlots + 1
            for _, inst in ipairs(plot:GetDescendants()) do
                if c.HideOtherGardens ~= false and inst:IsA("BasePart") then
                    if ClientLightOriginal.Parts[inst] == nil then
                        ClientLightOriginal.Parts[inst] = inst.LocalTransparencyModifier
                    end
                    if inst.LocalTransparencyModifier < 1 then
                        pcall(function()
                            inst.LocalTransparencyModifier = 1
                        end)
                    end
                    hiddenParts = hiddenParts + 1
                elseif c.DisableOtherGardenEffects ~= false and isEffectInstance(inst) then
                    if ClientLightOriginal.Effects[inst] == nil then
                        ClientLightOriginal.Effects[inst] = inst.Enabled
                    end
                    if inst.Enabled then
                        pcall(function()
                            inst.Enabled = false
                        end)
                    end
                    disabledEffects = disabledEffects + 1
                end
            end
        end
    end

    local summary = ("plots=%s parts=%s fx=%s"):format(tostring(hiddenPlots), tostring(hiddenParts), tostring(disabledEffects))
    State.LastClientLight = os.date("%H:%M:%S") .. " " .. summary
    if summary ~= ClientLightLastSummary then
        ClientLightLastSummary = summary
        actionLog("ClientLight", "DONE", summary)
    end
end

loopTask = function(name, fn, getDelay)
    local thread = task.spawn(function()
        while isAlive() do
            local ok, err = pcall(fn)
            if not ok then logw(name, "lỗi:", err) end
            local delayOk, delay = pcall(getDelay)
            if not delayOk then
                logw(name, "delay lỗi:", delay)
                delay = 1
            end
            if not waitAlive(delay or 1) then
                break
            end
        end
        actionLog(name, "STOPPED")
    end)
    table.insert(Runtime.Tasks, thread)
end

Runtime.LoopTaskIndex = 0

-- Auto Redeem Codes: nhập code qua remote thật Settings.SubmitCode (Networking.lua:85).
-- Mỗi code chỉ thử 1 lần/phiên (tránh spam khi đã đổi hoặc code sai).
Runtime.RedeemedCodes = Runtime.RedeemedCodes or {}
function Runtime.doAutoRedeemCode()
    local c = CFG.AutoRedeemCode
    if not (c and c.Enabled) then return end
    if not packet({ "Settings", "SubmitCode" }) then
        logw("AutoRedeemCode: thieu Networking.Settings.SubmitCode -> tat.")
        c.Enabled = false
        return
    end
    for _, code in ipairs(type(c.List) == "table" and c.List or {}) do
        code = tostring(code)
        if code ~= "" and not Runtime.RedeemedCodes[code] then
            Runtime.RedeemedCodes[code] = true
            actionLog("AutoRedeemCode", "SUBMIT", code)
            local ok, res = firePacket({ "Settings", "SubmitCode" }, code)
            actionLog("AutoRedeemCode", ok and "DONE" or "ERROR", code .. " " .. tostring(res))
            if not waitAlive(tonumber(c.Delay) or 1.5) then return end
        end
    end
end

-- Anti-AFK: chống bị đá vì treo máy. Hook LocalPlayer.Idled rồi giả lập input qua VirtualUser
-- (client-side, KHÔNG cần remote). Chỉ nối 1 lần.
function Runtime.SetupAntiAfk()
    if Runtime.AntiAfkConnected then return end
    local c = CFG.AntiAfk
    if not (c and c.Enabled ~= false) then return end
    if not VirtualUser then return end
    Runtime.AntiAfkConnected = true
    pcall(function()
        LocalPlayer.Idled:Connect(function()
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
        end)
    end)
    actionLog("AntiAfk", "ON", "hook LocalPlayer.Idled")
end

local function loopTask(name, fn, getDelay)
    Runtime.LoopTaskIndex = (Runtime.LoopTaskIndex or 0) + 1
    local taskIndex = Runtime.LoopTaskIndex
    local thread = task.spawn(function()
        local stagger = CFG.LowFpsMode and tonumber(CFG.LowFpsMode.StartupStagger) or 0
        if stagger and stagger > 0 and taskIndex > 1 then
            if not waitAlive(math.min(stagger * (taskIndex - 1), 4)) then
                return
            end
        end

        while isAlive() do
            local status = Runtime.TaskStatus[name] or {}
            status.LastRun = os.clock()
            status.Runs = (status.Runs or 0) + 1
            Runtime.TaskStatus[name] = status

            if Runtime.ShouldDeferForCriticalFps(name) then
                status.Deferred = (status.Deferred or 0) + 1
            else
                local ok, err = pcall(fn)
                if ok then
                    status.LastOk = os.clock()
                    status.LastErr = nil
                else
                    status.LastErr = tostring(err)
                    status.Errors = (status.Errors or 0) + 1
                    logw(name, "loi:", err)
                    actionLog(name, "ERROR", compactText(err, 80))
                end
            end

            local delayOk, delay = pcall(getDelay)
            if not delayOk then
                logw(name, "delay loi:", delay)
                delay = 1
            end
            delay = Runtime.AdaptiveDelay(name, delay or 1)
            if not waitAlive(delay or 1) then
                break
            end
        end
        actionLog(name, "STOPPED")
    end)
    table.insert(Runtime.Tasks, thread)
end

Runtime.SafeBoot = function(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        State.LastWatchdog = os.date("%H:%M:%S") .. " boot " .. tostring(name)
        actionLog("Watchdog", "ERROR", tostring(name) .. " " .. compactText(err, 80))
    end
    return ok
end

Runtime.SetupRuntimeWatchdog = function()
    local thread = task.spawn(function()
        while isAlive() do
            pcall(doAutoStartGame)

            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
            if CFG.Dashboard and CFG.Dashboard.Enabled ~= false then
                if playerGui and not playerGui:FindFirstChild("KaitunDashboard") then
                    Runtime.SafeBoot("DashboardRecover", setupKaitunDashboard)
                end
            end

            local aliveTasks = 0
            local errorTasks = 0
            for _, status in pairs(Runtime.TaskStatus) do
                if status.LastRun then
                    aliveTasks = aliveTasks + 1
                end
                if status.LastErr then
                    errorTasks = errorTasks + 1
                end
            end
            State.LastWatchdog = os.date("%H:%M:%S") .. (" tasks=%s err=%s"):format(tostring(aliveTasks), tostring(errorTasks))

            local delay = CFG.LowFpsMode and tonumber(CFG.LowFpsMode.WatchdogDelay) or 8
            if not waitAlive(delay or 8) then
                break
            end
        end
    end)
    table.insert(Runtime.Tasks, thread)
end

Runtime.SafeBoot("FpsMonitor", Runtime.SetupFpsMonitor)
Runtime.SafeBoot("AutoStartGame", doAutoStartGame)
Runtime.SafeBoot("NightNotifier", setupNightNotifier)
Runtime.SafeBoot("Dashboard", setupKaitunDashboard)
Runtime.SafeBoot("InventoryWatcher", setupInventoryWatcher)
Runtime.SafeBoot("PlantFullWatcher", Runtime.SetupPlantFullWatcher)
Runtime.SafeBoot("FpsBoost", applyFpsBoost)
Runtime.SafeBoot("ClientLight", applyClientLight)
Runtime.SafeBoot("ValuableWatcher", doValuableWatcher)
Runtime.SafeBoot("WildPetTameWatcher", Runtime.SetupWildPetTameWatcher)
Runtime.SafeBoot("RuntimeWatchdog", Runtime.SetupRuntimeWatchdog)
table.insert(Runtime.Cleanups, clearEspHighlights)
table.insert(Runtime.Cleanups, restoreClientLight)

log("Khởi động. Sheckles hiện tại:", tostring(getSheckles()))

loopTask("AutoStartGame", doAutoStartGame, function() return (CFG.AutoStartGame and CFG.AutoStartGame.Delay) or 2 end)
loopTask("AutoBuySeed",  Runtime.doAutoBuySeed,  function() return ((CFG.AutoBuySeed and CFG.AutoBuySeed.Delay) or 0.35) + 3 end)
loopTask("AutoPlant",    Runtime.doAutoPlant,    function() return 2 end)
loopTask("AutoShovelReplace", Runtime.doAutoShovelReplace, function() return (CFG.AutoShovelReplace and CFG.AutoShovelReplace.Delay) or 5 end)
loopTask("AutoWater",    doAutoWater,    function() return (CFG.AutoWater and CFG.AutoWater.Delay) or 2 end)
loopTask("AutoSprinkler",doAutoSprinkler,function() return ((CFG.AutoSprinkler and CFG.AutoSprinkler.Delay) or 0.5) + 2 end)
loopTask("AutoBuyGear",  Runtime.doAutoBuyGear,  function() return ((CFG.AutoBuyGear and CFG.AutoBuyGear.Delay) or 0.5) + 3 end)
loopTask("AutoBuyCrate", Runtime.doAutoBuyCrate, function() return ((CFG.AutoBuyCrate and CFG.AutoBuyCrate.Delay) or 0.5) + 5 end)
loopTask("ClientLight", applyClientLight, function() return (CFG.ClientLight and CFG.ClientLight.Delay) or 10 end)
loopTask("FpsCap", Runtime.ApplyFpsCap, function() return (CFG.FpsBoost and CFG.FpsBoost.CapRefreshDelay) or 5 end)
loopTask("AutoEquipGear",Runtime.doAutoEquipGear,function() return 10 end)
loopTask("AutoCollect",  Runtime.doAutoCollect,  function() return (CFG.AutoCollect and CFG.AutoCollect.Delay) or 1 end)
loopTask("AutoCollectDrops", Runtime.doAutoCollectDrops, function() return (CFG.AutoCollectDrops and CFG.AutoCollectDrops.Delay) or 1 end)
loopTask("ValuableWatcher", doValuableWatcher, function() return (CFG.ValuableWatcher and CFG.ValuableWatcher.Delay) or 2 end)
loopTask("AutoSell",     function() runSellSafe("timer") end, function()
    -- Random nhịp bán trong [Delay, DelayMax]. Acc mới chậm/không bao giờ đầy 100 quả
    -- vẫn được bán định kỳ; còn đầy túi thì doSellWhenFull/InventoryWatcher bán NGAY (không đợi).
    local s = CFG.AutoSell or {}
    local minD = tonumber(s.Delay) or 30
    local maxD = tonumber(s.DelayMax) or minD
    if maxD > minD then
        return minD + math.random() * (maxD - minD)
    end
    return minD
end)
loopTask("AutoSellFull", doSellWhenFull, function() return (CFG.AutoSell and CFG.AutoSell.FullCheckDelay) or 1 end)
loopTask("AntiSteal",    Runtime.doAntiSteal,    function() return (CFG.AntiSteal and CFG.AntiSteal.Delay) or 0.35 end)
loopTask("AutoHatchEgg", Runtime.doAutoHatchEgg, function() return (CFG.AutoHatchEgg and CFG.AutoHatchEgg.Delay) or 0.5 end)
loopTask("AutoOpenCrate",Runtime.doAutoOpenCrate,function() return ((CFG.AutoOpenCrate and CFG.AutoOpenCrate.Delay) or 0.5) + 2 end)
loopTask("AutoOpenSeedPack", Runtime.doAutoOpenSeedPack, function() return ((CFG.AutoOpenSeedPack and CFG.AutoOpenSeedPack.Delay) or 0.5) + 2 end)
loopTask("AutoClaimMailbox", Runtime.doAutoClaimMailbox, function() return (CFG.AutoClaimMailbox and CFG.AutoClaimMailbox.Delay) or 60 end)
loopTask("AutoMailSeeds", Runtime.DoAutoMailSeeds, function()
    local s = CFG.AutoMailSeeds or CFG.AutoMailRainbow or {}
    return tonumber(s.Delay) or 30
end)
loopTask("AutoMailPets", Runtime.DoAutoMailPets, function() return (CFG.AutoMailPets and CFG.AutoMailPets.Delay) or 30 end)
loopTask("AutoMailFruits", Runtime.DoAutoMailFruits, function() return (CFG.AutoMailFruits and CFG.AutoMailFruits.Delay) or 30 end)
loopTask("RainbowReport", Runtime.DoRainbowAccountReport, function() return (CFG.RainbowAccountReport and CFG.RainbowAccountReport.Interval) or 60 end)
loopTask("AutoEquipPet", Runtime.doAutoEquipPet, function() return (CFG.AutoEquipPet and CFG.AutoEquipPet.Delay) or 5 end)
loopTask("AutoSnapPets", doAutoSnapPets, function() return (CFG.AutoSnapPets and CFG.AutoSnapPets.Delay) or 15 end)
loopTask("AutoSpendSkill", doAutoSpendSkill, function() return ((CFG.AutoSpendSkill and CFG.AutoSpendSkill.Delay) or 0.3) + 4 end)
loopTask("AutoExpandGarden", Runtime.doAutoExpandGarden, function() return (CFG.AutoExpandGarden and CFG.AutoExpandGarden.Delay) or 10 end)
loopTask("AutoPurchasePetSlot", doAutoPurchasePetSlot, function() return (CFG.AutoPurchasePetSlot and CFG.AutoPurchasePetSlot.Delay) or 15 end)
loopTask("AutoTameWildPet", doAutoTameWildPet, function() return (CFG.AutoTameWildPet and CFG.AutoTameWildPet.Delay) or 2 end)
loopTask("ESP",          doEsp,          function() return (CFG.ESP and CFG.ESP.RefreshRate) or 1 end)
loopTask("AutoRedeemCode", Runtime.doAutoRedeemCode, function() return 30 end)
loopTask("TrimToQuota", Runtime.doTrimToQuota, function() return (CFG.TrimToQuota and CFG.TrimToQuota.Delay) or 8 end)

Runtime.SetupAntiAfk()

log("Đã chạy tất cả tác vụ theo config. Chỉnh getgenv().ConfigsKaitun để bật/tắt.")
