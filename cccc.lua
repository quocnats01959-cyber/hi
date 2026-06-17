--======================================================================
-- MAILBOX COMBINED
-- Gộp 2 script:
-- - bipga.lua: GUI gửi mail thủ công, xem seed/pet trong túi, claim mail, anti-AFK, reconnect.
-- - auto_send_mail.lua: hàng chờ gửi mail tự động nhiều acc, threshold loop, webhook.
--
-- Cách dùng nhanh:
-- 1) Tab "Gửi Thủ Công":
--    - Nhập "Tên acc nhận hoặc UserId".
--    - Bấm tick seed/pet trong danh sách.
--    - Nhập "Số lượng mỗi món", rồi bấm "Gửi Đã Chọn".
-- 2) Tab "Hàng Chờ Auto":
--    - Nhập acc nhận, chọn HẠT/PET, nhập tên món cách nhau bằng dấu phẩy.
--    - Để trống tên món = gửi tất cả loại đang có.
--    - Số lượng 0 = gửi hết; ngưỡng 0 = gửi ngay.
--    - Ngưỡng > 0 = script lặp lại, canh đủ số lượng mới gửi.
-- 3) Đổi ngôn ngữ: bấm nút "VI/EN" trên góc phải GUI.
-- 4) Dừng script: getgenv().StopMailboxCombined()
--
-- Source đã xác nhận:
-- - ReplicatedStorage.SharedModules.Networking.Mailbox.SendBatch/LookupPlayer/OpenInbox/Claim
-- - ReplicatedStorage.SharedModules.Networking.Tutorial.Complete
-- - ReplicatedStorage.ClientModules.PlayerStateClient
-- - replica.Data.Inventory.Seeds / replica.Data.Inventory.Pets
--======================================================================

getgenv().MailboxCombinedConfig = getgenv().MailboxCombinedConfig or {
    -- Ngôn ngữ giao diện: "vi" = tiếng Việt có dấu, "en" = tiếng Anh.
    Language = "vi",

    -- Gửi thủ công: dùng tab "Gửi Thủ Công".
    Manual = {
        ClaimDelay = 0.05,       -- Bao lâu quét hộp thư 1 lần nếu tự nhận thư đang bật.
        MaxClaimsPerCycle = 50,  -- Mỗi vòng nhận tối đa bao nhiêu thư.
        ClaimItemDelay = 0,      -- Nghỉ giữa mỗi thư được nhận; 0 = nhanh.
        DefaultNote = "",  -- Ghi chú mặc định khi gửi thủ công.
        ClaimDefaultOn = true,   -- Vào script là bật tự nhận mail.
        BatchSize = 100000,      -- Số item tối đa mỗi lần SendBatch trong tab thủ công.
        SendCooldown = 10,       -- Mailbox cần chờ khoảng 10 giây sau mỗi lần gửi.
    },

    -- Hàng chờ auto: có thể tạo job sẵn ở đây, hoặc để Recipient="" rồi thêm bằng GUI.
    Queue = {
        Recipient = "",         -- Tên acc nhận hoặc UserId. Rỗng = chỉ thêm bằng GUI.
        AutoStart = false,      -- true = tự chạy hàng chờ ngay khi load script.
        Note = "",              -- Ghi chú gửi mail cho job auto.

        SendSeeds = true,       -- Tạo job gửi hạt từ config.
        Seeds = {},             -- {} = tất cả hạt; ví dụ { "Rainbow", "Moon Bloom" }.
        SeedAmount = 0,         -- 0 = gửi hết; >0 = gửi tối đa N hạt.
        SeedThreshold = 0,      -- 0 = gửi ngay; >0 = chỉ gửi khi loại hạt đó >= N.

        SendPets = false,       -- Tạo job gửi pet từ config.
        Pets = {},              -- {} = tất cả pet chưa equip; ví dụ { "Raccoon", "Unicorn" }.
        PetAmount = 0,          -- 0 = gửi hết; >0 = gửi tối đa N pet.
        PetThreshold = 0,       -- 0 = gửi ngay; >0 = chỉ gửi khi pet cùng tên >= N.

        BatchSize = 100000,     -- Số item tối đa mỗi lần SendBatch trong hàng chờ.
        DelayBetween = 10,      -- Mailbox cần chờ khoảng 10 giây sau mỗi lần gửi.
        LoopInterval = 5,       -- Job có ngưỡng sẽ quét lại mỗi N giây.
        WebhookUrl = "",       -- Webhook Discord; rỗng = tắt.
        Mention = "",          -- Text mention kèm webhook, ví dụ "<@123>".
    },

    -- Chống bị kick AFK. Đây là runtime API, không phải remote game.
    AntiAfk = {
        Enabled = true,
        Log = false,            -- true = ghi log mỗi lần pulse anti-AFK.
    },

    -- Tự reconnect khi Roblox hiện ErrorPrompt hoặc teleport fail.
    AutoReconnect = {
        Enabled = true,
        Delay = 3,              -- Đợi bao nhiêu giây rồi reconnect.
        SameServer = false,     -- true = cố gắng vào lại cùng server.
    },
}

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local GUARD = "__MAILBOX_COMBINED"
do
    local old = getgenv()[GUARD]
    if old and old.Stop then
        pcall(old.Stop, "new script loaded")
    end
end

local CFG = getgenv().MailboxCombinedConfig
CFG.Manual = CFG.Manual or {}
CFG.Queue = CFG.Queue or {}
CFG.AntiAfk = CFG.AntiAfk or {}
CFG.AutoReconnect = CFG.AutoReconnect or {}

local function setDefault(tbl, key, value)
    if type(tbl) == "table" and tbl[key] == nil then
        tbl[key] = value
    end
end

setDefault(CFG, "Language", "vi")
setDefault(CFG.Manual, "ClaimDelay", 0.05)
setDefault(CFG.Manual, "MaxClaimsPerCycle", 50)
setDefault(CFG.Manual, "ClaimItemDelay", 0)
setDefault(CFG.Manual, "DefaultNote", "1tenhe")
setDefault(CFG.Manual, "ClaimDefaultOn", true)
setDefault(CFG.Manual, "BatchSize", 100000)
setDefault(CFG.Manual, "SendCooldown", 10)

setDefault(CFG.Queue, "Recipient", "")
setDefault(CFG.Queue, "AutoStart", false)
setDefault(CFG.Queue, "Note", "")
setDefault(CFG.Queue, "SendSeeds", true)
setDefault(CFG.Queue, "Seeds", {})
setDefault(CFG.Queue, "SeedAmount", 0)
setDefault(CFG.Queue, "SeedThreshold", 0)
setDefault(CFG.Queue, "SendPets", false)
setDefault(CFG.Queue, "Pets", {})
setDefault(CFG.Queue, "PetAmount", 0)
setDefault(CFG.Queue, "PetThreshold", 0)
setDefault(CFG.Queue, "BatchSize", 100000)
setDefault(CFG.Queue, "DelayBetween", 10)
setDefault(CFG.Queue, "LoopInterval", 5)
setDefault(CFG.Queue, "WebhookUrl", "")
setDefault(CFG.Queue, "Mention", "")

CFG.Manual.SendCooldown = math.max(tonumber(CFG.Manual.SendCooldown) or 10, 10)
CFG.Queue.DelayBetween = math.max(tonumber(CFG.Queue.DelayBetween) or 10, 10)

setDefault(CFG.AntiAfk, "Enabled", true)
setDefault(CFG.AntiAfk, "Log", false)
setDefault(CFG.AutoReconnect, "Enabled", true)
setDefault(CFG.AutoReconnect, "Delay", 3)
setDefault(CFG.AutoReconnect, "SameServer", false)

local Runtime = {
    Active = true,
    Tasks = {},
    Connections = {},
    Gui = nil,
}

getgenv()[GUARD] = Runtime

local function alive()
    return Runtime.Active and getgenv()[GUARD] == Runtime
end

local function track(connection)
    if connection then
        table.insert(Runtime.Connections, connection)
    end
    return connection
end

local function waitAlive(seconds)
    local target = os.clock() + math.max(tonumber(seconds) or 0, 0)
    while alive() and os.clock() < target do
        task.wait(math.min(target - os.clock(), 0.25))
    end
    return alive()
end

function Runtime.Stop(reason)
    if not Runtime.Active then
        return
    end

    Runtime.Active = false
    print("[MAILBOX-COMBINED]", "Stop:", tostring(reason or "manual"))

    for _, thread in ipairs(Runtime.Tasks) do
        pcall(task.cancel, thread)
    end

    for _, connection in ipairs(Runtime.Connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end

    if Runtime.Gui and Runtime.Gui.Parent then
        Runtime.Gui:Destroy()
    end
end

getgenv().StopMailboxCombined = Runtime.Stop

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser
local CoreGui

pcall(function()
    VirtualUser = game:GetService("VirtualUser")
end)
pcall(function()
    CoreGui = game:GetService("CoreGui")
end)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 10)

local function trim(text)
    text = tostring(text or "")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function clamp(value, low, high)
    value = tonumber(value) or low
    if value < low then
        return low
    end
    if value > high then
        return high
    end
    return value
end

local function compact(text, limit)
    text = tostring(text or "")
    limit = tonumber(limit) or 80
    if #text > limit then
        return text:sub(1, math.max(limit - 3, 1)) .. "..."
    end
    return text
end

local function norm(text)
    return (tostring(text or ""):lower():gsub("%s+", ""))
end

local function getCountFromEntry(value)
    if type(value) == "number" then
        return value
    end
    if type(value) == "table" then
        return tonumber(value.Count or value.Amount or value.Quantity or value.Stack or 0) or 0
    end
    return 0
end

local function extractName(entry, fallback, keys)
    if type(entry) == "table" then
        for _, key in ipairs(keys) do
            if entry[key] ~= nil and tostring(entry[key]) ~= "" then
                return tostring(entry[key])
            end
        end
    end
    return tostring(fallback or "")
end

local function isLockedOrFavorite(entry)
    if type(entry) ~= "table" then
        return false
    end
    return entry.Locked == true
        or entry.IsLocked == true
        or entry.Favorite == true
        or entry.Favorited == true
        or entry.IsFavorite == true
end

local function parseNameList(text)
    local list = {}
    local active = false
    for piece in tostring(text or ""):gmatch("[^,]+") do
        local name = trim(piece)
        if name ~= "" then
            table.insert(list, norm(name))
            active = true
        end
    end
    return list, active
end

local function parseArrayList(arr)
    local list = {}
    local active = false
    if type(arr) == "table" then
        for _, value in ipairs(arr) do
            if type(value) == "string" and trim(value) ~= "" then
                table.insert(list, norm(value))
                active = true
            end
        end
    end
    return list, active
end

local function nameAllowed(name, allowList, allowActive)
    if not allowActive then
        return true
    end

    local n = norm(name)
    for _, wanted in ipairs(allowList) do
        if n == wanted or string.find(n, wanted, 1, true) or string.find(wanted, n, 1, true) then
            return true
        end
    end
    return false
end

--======================================================================
-- Modules and remotes
--======================================================================

local Networking
local PlayerStateClient

do
    local sharedModules = ReplicatedStorage:WaitForChild("SharedModules", 15)
    local networkingModule = sharedModules and sharedModules:WaitForChild("Networking", 15)
    if networkingModule then
        local ok, result = pcall(require, networkingModule)
        if ok then
            Networking = result
        else
            warn("[MAILBOX-COMBINED] require Networking failed:", result)
        end
    end

    local clientModules = ReplicatedStorage:WaitForChild("ClientModules", 15)
    local stateModule = clientModules and clientModules:FindFirstChild("PlayerStateClient")
    if stateModule then
        local ok, result = pcall(require, stateModule)
        if ok then
            PlayerStateClient = result
        else
            warn("[MAILBOX-COMBINED] require PlayerStateClient failed:", result)
        end
    end
end

local function mailbox(name)
    return Networking and Networking.Mailbox and Networking.Mailbox[name]
end

local function getLocalReplica(timeout)
    if not PlayerStateClient then
        return nil
    end

    local replica
    if type(PlayerStateClient.GetLocalReplica) == "function" then
        local ok, result = pcall(function()
            return PlayerStateClient:GetLocalReplica()
        end)
        if ok and result then
            replica = result
        end
    end

    if not replica and type(PlayerStateClient.WaitForLocalReplica) == "function" then
        local ok, result = pcall(function()
            return PlayerStateClient:WaitForLocalReplica(timeout or 5)
        end)
        if ok then
            replica = result
        end
    end

    return replica
end

local function getInventory()
    local replica = getLocalReplica(5)
    local data = replica and replica.Data
    if type(data) ~= "table" or type(data.Inventory) ~= "table" then
        return nil
    end
    return data.Inventory
end

local function tryCompleteTutorial()
    if workspace:GetAttribute("InTutorial") ~= true then
        return
    end
    local tutorial = Networking and Networking.Tutorial
    if tutorial and tutorial.Complete and type(tutorial.Complete.Fire) == "function" then
        pcall(function()
            tutorial.Complete:Fire()
        end)
    end
end

--======================================================================
-- UI helpers
--======================================================================

local uiParent = PlayerGui
if type(gethui) == "function" then
    local ok, result = pcall(gethui)
    if ok and result then
        uiParent = result
    end
elseif CoreGui then
    uiParent = CoreGui
end

local oldGui = uiParent and uiParent:FindFirstChild("MailboxCombinedGui")
if oldGui then
    oldGui:Destroy()
end

local COL = {
    bg = Color3.fromRGB(16, 19, 26),
    top = Color3.fromRGB(25, 30, 40),
    panel = Color3.fromRGB(25, 31, 42),
    panel2 = Color3.fromRGB(33, 40, 53),
    field = Color3.fromRGB(12, 17, 25),
    stroke = Color3.fromRGB(65, 76, 96),
    text = Color3.fromRGB(235, 241, 250),
    sub = Color3.fromRGB(152, 166, 188),
    blue = Color3.fromRGB(72, 132, 214),
    green = Color3.fromRGB(45, 142, 97),
    orange = Color3.fromRGB(186, 119, 44),
    red = Color3.fromRGB(145, 54, 65),
}

local LANG = {
    vi = {
        title = "MAILBOX COMBINED",
        manualTab = "Gửi Thủ Công",
        queueTab = "Hàng Chờ Auto",
        subtitle = "Gửi thủ công + hàng chờ auto trong cùng một script",
        manualRecipient = "Tên acc nhận hoặc UserId",
        manualQuantity = "Số lượng mỗi món",
        manualNote = "Ghi chú gửi mail",
        sendSelected = "Gửi Đã Chọn",
        sending = "Đang gửi...",
        manualCooldown = "Chờ %ds",
        stop = "Dừng",
        refresh = "Làm Mới",
        claimOn = "Nhận Thư: BẬT",
        claimOff = "Nhận Thư: TẮT",
        clearTicks = "Bỏ Tick",
        idle = "Đang chờ",
        seeds = "Hạt",
        pets = "Pet",
        queueKindSeed = "HẠT",
        queueKindPet = "PET",
        queueRecipient = "Tên acc nhận hoặc UserId",
        queueItems = "Tên món cách nhau bằng dấu phẩy; để trống = tất cả",
        queueAmount = "Số lượng 0=gửi hết",
        queueThreshold = "Ngưỡng 0=tắt",
        addJob = "Thêm Job",
        queueTitle = "HÀNG CHỜ",
        run = "Chạy",
        pause = "Tạm Dừng",
        clearAll = "Xóa Hết",
        queuePausedHint = "Tạm dừng - thêm job rồi bấm Chạy",
        languageButton = "VI",
        removedJob = "Đã xóa job. Hàng chờ: %d",
        recipientEmpty = "Chưa nhập acc nhận",
        jobAdded = "Đã thêm job. Hàng chờ: %d",
        paused = "Đã tạm dừng",
        runningQueue = "Đang chạy hàng chờ",
        queueStopped = "Đã dừng hàng chờ",
        queueCleared = "Đã xóa hết hàng chờ",
        autoStart = "Tự chạy theo config",
        configLoaded = "Đã nạp job từ config. Bấm Chạy",
        ready = "Mailbox Combined đã sẵn sàng",
        loaded = "Đã nạp Gửi Thủ Công + Hàng Chờ Auto. Dừng: getgenv().StopMailboxCombined()",
    },
    en = {
        title = "MAILBOX COMBINED",
        manualTab = "Manual Send",
        queueTab = "Queue Auto",
        subtitle = "Manual sender + queued auto sender in one script",
        manualRecipient = "Recipient username or UserId",
        manualQuantity = "Quantity each item",
        manualNote = "Mail note",
        sendSelected = "Send Selected",
        sending = "Sending...",
        manualCooldown = "Wait %ds",
        stop = "Stop",
        refresh = "Refresh",
        claimOn = "Claim: ON",
        claimOff = "Claim: OFF",
        clearTicks = "Clear Ticks",
        idle = "Idle",
        seeds = "Seeds",
        pets = "Pets",
        queueKindSeed = "SEED",
        queueKindPet = "PET",
        queueRecipient = "Recipient username or UserId",
        queueItems = "Names separated by commas; empty = all",
        queueAmount = "Amount 0=all",
        queueThreshold = "Threshold 0=off",
        addJob = "Add Job",
        queueTitle = "QUEUE",
        run = "Run",
        pause = "Pause",
        clearAll = "Clear All",
        queuePausedHint = "Paused - add jobs then press Run",
        languageButton = "EN",
        removedJob = "Removed job. Queue: %d",
        recipientEmpty = "Recipient empty",
        jobAdded = "Added job. Queue: %d",
        paused = "Paused",
        runningQueue = "Running queue",
        queueStopped = "Queue stopped",
        queueCleared = "Queue cleared",
        autoStart = "AutoStart from config",
        configLoaded = "Loaded config jobs. Press Run",
        ready = "Mailbox Combined ready",
        loaded = "Manual + Queue loaded. Stop: getgenv().StopMailboxCombined()",
    },
}

local currentLanguage = tostring(CFG.Language or "vi"):lower()
if not LANG[currentLanguage] then
    currentLanguage = "vi"
end

local function tr(key)
    local pack = LANG[currentLanguage] or LANG.vi
    return pack[key] or (LANG.vi and LANG.vi[key]) or key
end

local function make(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    return make("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, parent)
end

local function stroke(parent, color, thickness, transparency)
    return make("UIStroke", {
        Color = color or COL.stroke,
        Thickness = thickness or 1,
        Transparency = transparency == nil and 0.15 or transparency,
    }, parent)
end

local function padding(parent, left, top, right, bottom)
    return make("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingRight = UDim.new(0, right or left or 0),
        PaddingBottom = UDim.new(0, bottom or top or 0),
    }, parent)
end

local function label(parent, name, text, size, bold)
    return make("TextLabel", {
        Name = name,
        BackgroundTransparency = 1,
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        Text = text or "",
        TextColor3 = COL.text,
        TextSize = size or 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = true,
    }, parent)
end

local function button(parent, name, text, color)
    local b = make("TextButton", {
        Name = name,
        BackgroundColor3 = color or COL.blue,
        BorderSizePixel = 0,
        AutoButtonColor = true,
        Font = Enum.Font.GothamBold,
        Text = text or "",
        TextColor3 = COL.text,
        TextSize = 13,
    }, parent)
    corner(b, 6)
    return b
end

local function textbox(parent, name, placeholder, defaultText)
    local box = make("TextBox", {
        Name = name,
        BackgroundColor3 = COL.field,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.Gotham,
        PlaceholderText = placeholder or "",
        PlaceholderColor3 = COL.sub,
        Text = defaultText or "",
        TextColor3 = COL.text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
    corner(box, 6)
    stroke(box, COL.stroke, 1, 0.35)
    padding(box, 8, 0, 8, 0)
    return box
end

local function clearGuiObjects(parent)
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
end

local gui = make("ScreenGui", {
    Name = "MailboxCombinedGui",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, uiParent)
Runtime.Gui = gui

local main = make("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, 940, 0, 660),
    BackgroundColor3 = COL.bg,
    BorderSizePixel = 0,
    Active = true,
    ClipsDescendants = true,
}, gui)
corner(main, 10)
stroke(main, COL.stroke, 1, 0.1)

local titleBar = make("Frame", {
    Name = "TitleBar",
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = COL.top,
    BorderSizePixel = 0,
    Active = true,
}, main)
corner(titleBar, 10)

local title = label(titleBar, "Title", tr("title"), 16, true)
title.Position = UDim2.new(0, 14, 0, 0)
title.Size = UDim2.new(1, -235, 1, 0)

local langButton = button(titleBar, "Language", tr("languageButton"), COL.panel2)
langButton.Position = UDim2.new(1, -110, 0, 6)
langButton.Size = UDim2.new(0, 36, 0, 26)

local minButton = button(titleBar, "Minimize", "-", COL.panel2)
minButton.Position = UDim2.new(1, -68, 0, 6)
minButton.Size = UDim2.new(0, 26, 0, 26)

local closeButton = button(titleBar, "Close", "X", COL.red)
closeButton.Position = UDim2.new(1, -36, 0, 6)
closeButton.Size = UDim2.new(0, 26, 0, 26)

local tabs = make("Frame", {
    Name = "Tabs",
    Position = UDim2.new(0, 12, 0, 46),
    Size = UDim2.new(1, -24, 0, 32),
    BackgroundTransparency = 1,
}, main)

local manualTabButton = button(tabs, "ManualTab", tr("manualTab"), COL.blue)
manualTabButton.Position = UDim2.new(0, 0, 0, 0)
manualTabButton.Size = UDim2.new(0, 140, 1, 0)

local queueTabButton = button(tabs, "QueueTab", tr("queueTab"), COL.panel2)
queueTabButton.Position = UDim2.new(0, 148, 0, 0)
queueTabButton.Size = UDim2.new(0, 140, 1, 0)

local activeTabLabel = label(tabs, "ActiveInfo", tr("subtitle"), 12, false)
activeTabLabel.TextColor3 = COL.sub
activeTabLabel.Position = UDim2.new(0, 304, 0, 0)
activeTabLabel.Size = UDim2.new(1, -304, 1, 0)

local content = make("Frame", {
    Name = "Content",
    Position = UDim2.new(0, 12, 0, 86),
    Size = UDim2.new(1, -24, 0, 430),
    BackgroundTransparency = 1,
}, main)

local manualFrame = make("Frame", {
    Name = "Manual",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Visible = true,
}, content)

local queueFrame = make("Frame", {
    Name = "Queue",
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Visible = false,
}, content)

local logPanel = make("Frame", {
    Name = "LogPanel",
    Position = UDim2.new(0, 12, 0, 524),
    Size = UDim2.new(1, -24, 0, 124),
    BackgroundColor3 = COL.field,
    BorderSizePixel = 0,
}, main)
corner(logPanel, 8)
stroke(logPanel, COL.stroke, 1, 0.35)

local logScroll = make("ScrollingFrame", {
    Name = "LogScroll",
    Position = UDim2.new(0, 8, 0, 8),
    Size = UDim2.new(1, -16, 1, -16),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 5,
    ScrollBarImageColor3 = COL.stroke,
}, logPanel)

local logLayout = make("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 2),
}, logScroll)

track(logLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    logScroll.CanvasSize = UDim2.new(0, 0, 0, logLayout.AbsoluteContentSize.Y + 4)
    logScroll.CanvasPosition = Vector2.new(0, math.max(0, logLayout.AbsoluteContentSize.Y))
end))

local logCount = 0
local function addLog(message)
    logCount = logCount + 1
    make("TextLabel", {
        Name = "LogLine",
        LayoutOrder = logCount,
        Size = UDim2.new(1, -8, 0, 18),
        BackgroundTransparency = 1,
        Font = Enum.Font.Code,
        Text = os.date("%H:%M:%S") .. "  " .. tostring(message),
        TextColor3 = Color3.fromRGB(205, 216, 232),
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, logScroll)

    local lines = {}
    for _, child in ipairs(logScroll:GetChildren()) do
        if child:IsA("TextLabel") then
            table.insert(lines, child)
        end
    end
    if #lines > 140 then
        table.sort(lines, function(a, b)
            return a.LayoutOrder < b.LayoutOrder
        end)
        lines[1]:Destroy()
    end
end

local function setActiveTab(name)
    local isManual = name == "Manual"
    manualFrame.Visible = isManual
    queueFrame.Visible = not isManual
    manualTabButton.BackgroundColor3 = isManual and COL.blue or COL.panel2
    queueTabButton.BackgroundColor3 = isManual and COL.panel2 or COL.blue
end

track(manualTabButton.MouseButton1Click:Connect(function()
    setActiveTab("Manual")
end))

track(queueTabButton.MouseButton1Click:Connect(function()
    setActiveTab("Queue")
end))

--======================================================================
-- Shared inventory and send helpers
--======================================================================

local recipientCache = {}

local function lookupRecipient(name)
    name = trim(name)
    if name == "" then
        return nil, nil, "recipient empty"
    end

    local directId = tonumber(name)
    if directId and directId > 0 then
        return directId, name, nil
    end

    if recipientCache[name] then
        return recipientCache[name].Id, recipientCache[name].Name, nil
    end

    local remote = mailbox("LookupPlayer")
    if not remote or type(remote.Fire) ~= "function" then
        return nil, nil, "Mailbox.LookupPlayer missing"
    end

    local ok, userId, resolvedName = pcall(function()
        return remote:Fire(name)
    end)

    if not ok then
        return nil, nil, "Lỗi tìm acc: " .. tostring(userId)
    end
    if type(userId) ~= "number" or userId <= 0 then
        return nil, nil, "Không thấy acc nhận: " .. name
    end

    recipientCache[name] = { Id = userId, Name = resolvedName or name }
    return userId, resolvedName or name, nil
end

local function parseMailboxCooldown(message)
    local text = tostring(message or "")
    local seconds = text:match("[Ww]ait%s+(%d+)%s*s")
        or text:match("[Ww]ait%s+(%d+)%s*seconds")
        or text:match("(%d+)%s*s%s+before%s+sending")
    return tonumber(seconds)
end

local function sendBatch(userId, batch, note, cooldownSeconds)
    local remote = mailbox("SendBatch")
    if not remote or type(remote.Fire) ~= "function" then
        return false, "Mailbox.SendBatch missing"
    end
    if userId == LocalPlayer.UserId then
        return false, "Không gửi cho chính mình"
    end

    cooldownSeconds = math.max(tonumber(cooldownSeconds) or 10, 10)
    local lastMessage = nil

    for attempt = 1, 3 do
        local ok, success, message = pcall(function()
            return remote:Fire(userId, batch, tostring(note or ""))
        end)

        if not ok then
            return false, tostring(success)
        end
        if success == true then
            return true, message
        end

        lastMessage = tostring(message or success)
        local serverWait = parseMailboxCooldown(lastMessage)
        if serverWait and attempt < 3 then
            local waitSeconds = math.max(serverWait + 1, cooldownSeconds)
            addLog(string.format("Mailbox cooldown: chờ %ds rồi gửi lại", waitSeconds))
            if not waitAlive(waitSeconds) then
                return false, "Đã dừng trong lúc chờ cooldown mailbox"
            end
        else
            return false, lastMessage
        end
    end

    return false, lastMessage or "SendBatch failed"
end

local function getSeedAmount(itemKey)
    local inv = getInventory()
    local seeds = inv and inv.Seeds
    if type(seeds) ~= "table" then
        return 0
    end
    return math.floor(tonumber(getCountFromEntry(seeds[itemKey])) or 0)
end

local function getSeedEntries(allowList, allowActive)
    local inv = getInventory()
    local seeds = inv and inv.Seeds
    local out = {}
    if type(seeds) ~= "table" then
        return out
    end

    for itemKey, entry in pairs(seeds) do
        local count = math.floor(tonumber(getCountFromEntry(entry)) or 0)
        if type(itemKey) == "string" and itemKey ~= "" and count > 0 then
            local displayName = extractName(entry, itemKey, { "SeedName", "Name", "DisplayName", "ItemName" })
            if nameAllowed(itemKey, allowList, allowActive) or nameAllowed(displayName, allowList, allowActive) then
                table.insert(out, {
                    Category = "Seeds",
                    ItemKey = tostring(itemKey),
                    Name = displayName,
                    Count = count,
                    CountText = "x" .. tostring(count),
                })
            end
        end
    end

    table.sort(out, function(a, b)
        return a.Name:lower() < b.Name:lower()
    end)
    return out
end

local function getPetEntries(allowList, allowActive)
    local inv = getInventory()
    local pets = inv and inv.Pets
    local out = {}
    if type(pets) ~= "table" then
        return out
    end

    for itemKey, entry in pairs(pets) do
        if type(entry) == "table" and entry.Equipped ~= true then
            local petName = extractName(entry, itemKey, { "Name", "PetName", "Species", "DisplayName" })
            if petName ~= "" and nameAllowed(petName, allowList, allowActive) then
                table.insert(out, {
                    Category = "Pets",
                    ItemKey = tostring(itemKey),
                    Name = petName,
                    Entry = entry,
                })
            end
        end
    end

    table.sort(out, function(a, b)
        return a.Name:lower() < b.Name:lower()
    end)
    return out
end

local function getPetKeysByName(name, limit)
    local keys = {}
    local inv = getInventory()
    local pets = inv and inv.Pets
    if type(pets) ~= "table" then
        return keys
    end

    limit = math.max(math.floor(tonumber(limit) or 0), 0)
    for itemKey, entry in pairs(pets) do
        if limit > 0 and #keys >= limit then
            break
        end
        if type(entry) == "table" and entry.Equipped ~= true then
            local petName = extractName(entry, itemKey, { "Name", "PetName", "Species", "DisplayName" })
            if petName == name then
                table.insert(keys, tostring(itemKey))
            end
        end
    end

    return keys
end

local function postWebhook(content)
    local url = tostring(CFG.Queue.WebhookUrl or "")
    local httpRequest = (syn and syn.request) or (http and http.request) or http_request
        or (fluxus and fluxus.request) or request
    if url == "" or not httpRequest then
        return
    end

    local mention = tostring(CFG.Queue.Mention or "")
    if mention ~= "" then
        content = mention .. " " .. tostring(content)
    end

    pcall(function()
        httpRequest({
            Url = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({ content = content }),
        })
    end)
end

--======================================================================
-- Manual tab
--======================================================================

local manualControls = make("Frame", {
    Name = "ManualControls",
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 0, 94),
    BackgroundColor3 = COL.panel,
    BorderSizePixel = 0,
}, manualFrame)
corner(manualControls, 8)
stroke(manualControls, COL.stroke, 1, 0.35)

local manualRecipient = textbox(manualControls, "Recipient", tr("manualRecipient"), "")
manualRecipient.Position = UDim2.new(0, 12, 0, 12)
manualRecipient.Size = UDim2.new(0, 200, 0, 30)

local manualQuantity = textbox(manualControls, "Quantity", tr("manualQuantity"), "1")
manualQuantity.Position = UDim2.new(0, 222, 0, 12)
manualQuantity.Size = UDim2.new(0, 130, 0, 30)

local manualNote = textbox(manualControls, "Note", tr("manualNote"), tostring(CFG.Manual.DefaultNote or ""))
manualNote.Position = UDim2.new(0, 362, 0, 12)
manualNote.Size = UDim2.new(0, 210, 0, 30)

local manualSendButton = button(manualControls, "Send", tr("sendSelected"), COL.green)
manualSendButton.Position = UDim2.new(0, 584, 0, 12)
manualSendButton.Size = UDim2.new(0, 128, 0, 30)

local manualStopButton = button(manualControls, "Stop", tr("stop"), COL.red)
manualStopButton.Position = UDim2.new(0, 724, 0, 12)
manualStopButton.Size = UDim2.new(0, 68, 0, 30)

local manualRefreshButton = button(manualControls, "Refresh", tr("refresh"), COL.blue)
manualRefreshButton.Position = UDim2.new(0, 804, 0, 12)
manualRefreshButton.Size = UDim2.new(0, 90, 0, 30)

local claimButton = button(manualControls, "ClaimToggle", tr("claimOff"), COL.panel2)
claimButton.Position = UDim2.new(0, 12, 0, 52)
claimButton.Size = UDim2.new(0, 116, 0, 28)

local clearManualButton = button(manualControls, "ClearTicks", tr("clearTicks"), COL.panel2)
clearManualButton.Position = UDim2.new(0, 140, 0, 52)
clearManualButton.Size = UDim2.new(0, 112, 0, 28)

local manualStatus = label(manualControls, "Status", tr("idle"), 13, false)
manualStatus.TextColor3 = COL.sub
manualStatus.Position = UDim2.new(0, 266, 0, 48)
manualStatus.Size = UDim2.new(1, -278, 0, 38)

local progressBack = make("Frame", {
    Name = "ProgressBack",
    Position = UDim2.new(0, 0, 0, 104),
    Size = UDim2.new(1, 0, 0, 8),
    BackgroundColor3 = COL.panel2,
    BorderSizePixel = 0,
}, manualFrame)
corner(progressBack, 4)

local progressFill = make("Frame", {
    Name = "ProgressFill",
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = COL.green,
    BorderSizePixel = 0,
}, progressBack)
corner(progressFill, 4)

local lists = make("Frame", {
    Name = "Lists",
    Position = UDim2.new(0, 0, 0, 124),
    Size = UDim2.new(1, 0, 1, -124),
    BackgroundTransparency = 1,
}, manualFrame)

local function makeListPanel(parent, name, titleText, xScale, widthScale)
    local panel = make("Frame", {
        Name = name,
        Position = UDim2.new(xScale, xScale == 0 and 0 or 8, 0, 0),
        Size = UDim2.new(widthScale, xScale == 0 and -4 or -8, 1, 0),
        BackgroundColor3 = COL.panel,
        BorderSizePixel = 0,
    }, parent)
    corner(panel, 8)
    stroke(panel, COL.stroke, 1, 0.35)

    local panelTitle = label(panel, "Title", titleText, 14, true)
    panelTitle.Position = UDim2.new(0, 12, 0, 0)
    panelTitle.Size = UDim2.new(1, -24, 0, 32)

    local scroll = make("ScrollingFrame", {
        Name = "Scroll",
        Position = UDim2.new(0, 8, 0, 34),
        Size = UDim2.new(1, -16, 1, -42),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 5,
        ScrollBarImageColor3 = COL.stroke,
    }, panel)

    local layout = make("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    }, scroll)
    padding(scroll, 0, 2, 4, 4)

    track(layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
    end))

    return scroll
end

local seedsScroll = makeListPanel(lists, "SeedsPanel", tr("seeds"), 0, 0.5)
local petsScroll = makeListPanel(lists, "PetsPanel", tr("pets"), 0.5, 0.5)

local selected = {}
local rowById = {}
local claimEnabled = CFG.Manual.ClaimDefaultOn == true
local manualSending = false
local manualButtonCoolingDown = false
local manualStopRequested = false

local function itemId(category, key)
    return tostring(category) .. "|" .. tostring(key)
end

local function setManualProgress(done, total, text)
    total = tonumber(total) or 0
    done = tonumber(done) or 0
    local ratio = total > 0 and clamp(done / total, 0, 1) or 0
    progressFill.Size = UDim2.new(ratio, 0, 1, 0)
    manualStatus.Text = text or manualStatus.Text
end

local function setRowSelected(id, isSelected)
    local row = rowById[id]
    if not row then
        return
    end
    row.Frame.BackgroundColor3 = isSelected and Color3.fromRGB(40, 82, 69) or COL.panel2
    row.Check.Text = isSelected and "X" or ""
    row.Check.BackgroundColor3 = isSelected and COL.green or COL.field
end

local function toggleManualRow(entry)
    local id = itemId(entry.Category, entry.ItemKey)
    if selected[id] then
        selected[id] = nil
        setRowSelected(id, false)
    else
        selected[id] = {
            Category = entry.Category,
            ItemKey = entry.ItemKey,
            Name = entry.Name,
        }
        setRowSelected(id, true)
    end
end

local function addManualRow(scroll, entry, order)
    local id = itemId(entry.Category, entry.ItemKey)
    local row = make("TextButton", {
        Name = "Row",
        LayoutOrder = order,
        Size = UDim2.new(1, -4, 0, 34),
        BackgroundColor3 = COL.panel2,
        BorderSizePixel = 0,
        AutoButtonColor = true,
        Text = "",
    }, scroll)
    corner(row, 6)

    local check = make("TextLabel", {
        Name = "Check",
        Position = UDim2.new(0, 8, 0, 7),
        Size = UDim2.new(0, 20, 0, 20),
        BackgroundColor3 = COL.field,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "",
        TextColor3 = COL.text,
        TextSize = 13,
    }, row)
    corner(check, 4)
    stroke(check, COL.stroke, 1, 0.35)

    local nameLabel = label(row, "Name", entry.Name, 13, false)
    nameLabel.Position = UDim2.new(0, 38, 0, 0)
    nameLabel.Size = UDim2.new(1, -154, 1, 0)
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

    local countLabel = label(row, "Count", entry.CountText, 12, false)
    countLabel.Position = UDim2.new(1, -112, 0, 0)
    countLabel.Size = UDim2.new(0, 104, 1, 0)
    countLabel.TextColor3 = COL.sub
    countLabel.TextXAlignment = Enum.TextXAlignment.Right
    countLabel.TextTruncate = Enum.TextTruncate.AtEnd

    rowById[id] = { Frame = row, Check = check }
    setRowSelected(id, selected[id] ~= nil)

    track(row.MouseButton1Click:Connect(function()
        toggleManualRow(entry)
    end))
end

local function scanManualInventory()
    local inv = getInventory()
    if not inv then
        return nil, nil, "Cannot read inventory replica"
    end

    local seeds = getSeedEntries({}, false)
    local petGroups = {}

    if type(inv.Pets) == "table" then
        for itemKey, entry in pairs(inv.Pets) do
            if type(entry) == "table" then
                local petName = extractName(entry, itemKey, { "Name", "PetName", "Species", "DisplayName" })
                if petName ~= "" then
                    local group = petGroups[petName]
                    if not group then
                        group = {
                            Category = "Pets",
                            ItemKey = petName,
                            Name = petName,
                            Total = 0,
                            Sendable = 0,
                            Locked = 0,
                        }
                        petGroups[petName] = group
                    end
                    group.Total = group.Total + 1
                    if entry.Equipped ~= true then
                        group.Sendable = group.Sendable + 1
                    end
                    if isLockedOrFavorite(entry) then
                        group.Locked = group.Locked + 1
                    end
                end
            end
        end
    end

    local pets = {}
    for _, group in pairs(petGroups) do
        group.Count = group.Sendable
        if group.Locked > 0 then
            group.CountText = tostring(group.Sendable) .. "/" .. tostring(group.Total) .. " send"
        else
            group.CountText = tostring(group.Sendable) .. "/" .. tostring(group.Total)
        end
        table.insert(pets, group)
    end

    table.sort(pets, function(a, b)
        return a.Name:lower() < b.Name:lower()
    end)

    return seeds, pets, nil
end

local function refreshManualInventory(keepStatus)
    rowById = {}
    clearGuiObjects(seedsScroll)
    clearGuiObjects(petsScroll)

    local seeds, pets, err = scanManualInventory()
    if err then
        setManualProgress(0, 0, err)
        addLog(err)
        return
    end

    local present = {}
    for i, entry in ipairs(seeds) do
        present[itemId(entry.Category, entry.ItemKey)] = true
        addManualRow(seedsScroll, entry, i)
    end
    for i, entry in ipairs(pets) do
        present[itemId(entry.Category, entry.ItemKey)] = true
        addManualRow(petsScroll, entry, i)
    end

    for id in pairs(selected) do
        if not present[id] then
            selected[id] = nil
        end
    end

    if keepStatus ~= true then
        setManualProgress(0, 0, "Inventory refreshed")
    end
    addLog(string.format("Inventory refreshed: %d seeds, %d pet types", #seeds, #pets))
end

local function selectedCount()
    local count = 0
    for _ in pairs(selected) do
        count = count + 1
    end
    return count
end

local function buildManualJobs(quantity)
    local jobs = {}
    local totalUnits = 0

    for _, item in pairs(selected) do
        if item.Category == "Seeds" then
            local available = getSeedAmount(item.ItemKey)
            local take = math.min(quantity, available)
            if take > 0 then
                table.insert(jobs, {
                    Category = "Seeds",
                    ItemKey = item.ItemKey,
                    Name = item.Name,
                    Remaining = take,
                })
                totalUnits = totalUnits + take
                if available < quantity then
                    addLog(string.format("%s has %d available, requested %d", item.Name, available, quantity))
                end
            else
                addLog(item.Name .. " skipped: no seed available")
            end
        elseif item.Category == "Pets" then
            local keys = getPetKeysByName(item.Name, quantity)
            if #keys > 0 then
                table.insert(jobs, {
                    Category = "Pets",
                    Name = item.Name,
                    Keys = keys,
                    Index = 1,
                })
                totalUnits = totalUnits + #keys
                if #keys < quantity then
                    addLog(string.format("%s has %d sendable pets, requested %d", item.Name, #keys, quantity))
                end
            else
                addLog(item.Name .. " skipped: no unequipped pet available")
            end
        end
    end

    return jobs, totalUnits
end

local function buildChunkFromJobs(jobs, maxUnits)
    local batch = {}
    local marks = {}
    local summary = {}
    local units = 0

    maxUnits = math.max(math.floor(tonumber(maxUnits) or 100000), 1)

    for _, job in ipairs(jobs) do
        if units >= maxUnits then
            break
        end

        if job.Category == "Seeds" and (tonumber(job.Remaining) or 0) > 0 then
            local take = math.min(job.Remaining, maxUnits - units)
            if take > 0 then
                table.insert(batch, { Category = "Seeds", ItemKey = job.ItemKey, Count = take })
                table.insert(marks, { Job = job, Kind = "Seed", Count = take })
                table.insert(summary, tostring(job.Name) .. " x" .. tostring(take))
                units = units + take
            end
        elseif job.Category == "Pets" and type(job.Keys) == "table" then
            local petCount = 0
            local index = job.Index or 1
            while index <= #job.Keys and units < maxUnits do
                table.insert(batch, { Category = "Pets", ItemKey = job.Keys[index], Count = 1 })
                table.insert(marks, { Job = job, Kind = "Pet", Count = 1 })
                petCount = petCount + 1
                units = units + 1
                index = index + 1
            end
            if petCount > 0 then
                table.insert(summary, tostring(job.Name) .. " pet x" .. tostring(petCount))
            end
        end
    end

    return batch, marks, units, table.concat(summary, ", ")
end

local function applySendMarks(marks)
    for _, mark in ipairs(marks) do
        local job = mark.Job
        if mark.Kind == "Seed" then
            job.Remaining = math.max((tonumber(job.Remaining) or 0) - (tonumber(mark.Count) or 0), 0)
        elseif mark.Kind == "Pet" then
            job.Index = (job.Index or 1) + 1
        end
    end
end

local function jobsDone(jobs)
    for _, job in ipairs(jobs) do
        if job.Category == "Seeds" and (tonumber(job.Remaining) or 0) > 0 then
            return false
        end
        if job.Category == "Pets" and type(job.Keys) == "table" and (job.Index or 1) <= #job.Keys then
            return false
        end
    end
    return true
end

local function setManualSendButtonEnabled(enabled, textValue)
    manualSendButton.Active = enabled == true
    manualSendButton.AutoButtonColor = enabled == true
    manualSendButton.BackgroundColor3 = enabled and COL.green or COL.panel2
    manualSendButton.Text = textValue or (enabled and tr("sendSelected") or tr("sending"))
end

local function startManualSendButtonCooldown()
    if manualButtonCoolingDown then
        return
    end

    manualButtonCoolingDown = true
    task.spawn(function()
        local seconds = math.max(math.floor(tonumber(CFG.Manual.SendCooldown) or 10), 10)
        for remaining = seconds, 1, -1 do
            if not alive() then
                return
            end
            setManualSendButtonEnabled(false, string.format(tr("manualCooldown"), remaining))
            task.wait(1)
        end
        manualButtonCoolingDown = false
        if alive() and not manualSending then
            setManualSendButtonEnabled(true, tr("sendSelected"))
        end
    end)
end

local function runManualSend()
    if manualSending then
        addLog("Đang gửi thủ công rồi")
        return
    end
    if manualButtonCoolingDown then
        return
    end
    if selectedCount() == 0 then
        setManualProgress(0, 0, "Chưa chọn món nào")
        addLog("Chưa chọn món nào")
        return
    end

    local quantity = math.floor(tonumber(manualQuantity.Text) or 0)
    if quantity <= 0 then
        setManualProgress(0, 0, "So luong khong hop le")
        addLog("Quantity must be greater than 0")
        return
    end

    local userId, resolvedName, lookupErr = lookupRecipient(manualRecipient.Text)
    if lookupErr then
        setManualProgress(0, 0, lookupErr)
        addLog(lookupErr)
        return
    end

    manualSending = true
    manualStopRequested = false
    setManualSendButtonEnabled(false, tr("sending"))

    local ok, err = pcall(function()
        local jobs, totalUnits = buildManualJobs(quantity)
        if totalUnits <= 0 then
            setManualProgress(0, 0, "Không có gì để gửi")
            addLog("Không có món nào gửi được trong túi hiện tại")
            return
        end

        local sentUnits = 0
        local note = tostring(manualNote.Text or "")
        local maxUnits = math.max(math.floor(tonumber(CFG.Manual.BatchSize) or 100000), 1)

        addLog(string.format("Acc nhan thu cong: %s (%d)", tostring(resolvedName), userId))

        while alive() and not manualStopRequested and not jobsDone(jobs) do
            local batch, marks, units, summary = buildChunkFromJobs(jobs, maxUnits)
            if #batch == 0 or units <= 0 then
                break
            end

            setManualProgress(sentUnits, totalUnits, "Đang gửi: " .. summary)
            addLog("SendBatch -> " .. compact(summary, 120))

            local success, message = sendBatch(userId, batch, note, CFG.Manual.SendCooldown)
            if not success then
                setManualProgress(sentUnits, totalUnits, "Gửi thất bại")
                addLog("Gửi thất bại: " .. tostring(message))
                return
            end

            applySendMarks(marks)
            sentUnits = sentUnits + units
            setManualProgress(sentUnits, totalUnits, string.format("Sent %d/%d to %s", sentUnits, totalUnits, tostring(resolvedName)))

            if not jobsDone(jobs) and not waitAlive(CFG.Manual.SendCooldown) then
                return
            end
        end

        if manualStopRequested then
            setManualProgress(sentUnits, totalUnits, string.format("Stopped at %d/%d", sentUnits, totalUnits))
            addLog("Đã dừng gửi thủ công theo yêu cầu")
        else
            setManualProgress(totalUnits, totalUnits, string.format("Đã gửi %d item cho %s", totalUnits, tostring(resolvedName)))
            addLog("Gửi thủ công xong")
        end

        refreshManualInventory(true)
    end)

    if not ok then
        setManualProgress(0, 0, "Lỗi gửi thủ công")
        addLog("Lỗi gửi thủ công: " .. tostring(err))
    end

    manualSending = false
    manualStopRequested = false
    startManualSendButtonCooldown()
end

local function claimOnce()
    local openInbox = mailbox("OpenInbox")
    local claimRemote = mailbox("Claim")
    if not openInbox or not claimRemote then
        addLog("Thieu remote nhan thu")
        return
    end

    local ok, inbox = pcall(function()
        return openInbox:Fire()
    end)
    if not ok or type(inbox) ~= "table" then
        return
    end

    local claimed = 0
    local maxClaims = math.max(math.floor(tonumber(CFG.Manual.MaxClaimsPerCycle) or 50), 1)
    for id, data in pairs(inbox) do
        if claimed >= maxClaims then
            break
        end
        if type(id) == "string" and type(data) == "table" then
            local okClaim, result = pcall(function()
                return claimRemote:Fire(id)
            end)
            if okClaim and result == true then
                claimed = claimed + 1
                if tonumber(CFG.Manual.ClaimItemDelay) and tonumber(CFG.Manual.ClaimItemDelay) > 0 then
                    if not waitAlive(tonumber(CFG.Manual.ClaimItemDelay)) then
                        return
                    end
                end
            end
        end
    end

    if claimed > 0 then
        addLog("Đã nhận " .. tostring(claimed) .. " thư")
        refreshManualInventory(true)
    end
end

local function updateClaimButton()
    claimButton.Text = claimEnabled and tr("claimOn") or tr("claimOff")
    claimButton.BackgroundColor3 = claimEnabled and COL.green or COL.panel2
end

track(manualRefreshButton.MouseButton1Click:Connect(function()
    refreshManualInventory()
end))

track(clearManualButton.MouseButton1Click:Connect(function()
    selected = {}
    for id in pairs(rowById) do
        setRowSelected(id, false)
    end
    addLog("Đã bỏ tick tất cả món thủ công")
end))

track(claimButton.MouseButton1Click:Connect(function()
    claimEnabled = not claimEnabled
    updateClaimButton()
    addLog(claimEnabled and "Claim mail enabled" or "Claim mail disabled")
end))

track(manualSendButton.MouseButton1Click:Connect(function()
    if manualSending or manualButtonCoolingDown or manualSendButton.Active == false then
        return
    end
    task.spawn(runManualSend)
end))

track(manualStopButton.MouseButton1Click:Connect(function()
    if manualSending then
        manualStopRequested = true
        addLog("Đã yêu cầu dừng gửi thủ công")
    end
end))

--======================================================================
-- Queue tab
--======================================================================

local queueInput = make("Frame", {
    Name = "QueueInput",
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 0, 130),
    BackgroundColor3 = COL.panel,
    BorderSizePixel = 0,
}, queueFrame)
corner(queueInput, 8)
stroke(queueInput, COL.stroke, 1, 0.35)
padding(queueInput, 10, 10, 10, 10)

local qRecipient = textbox(queueInput, "Recipient", tr("queueRecipient"), "")
qRecipient.Position = UDim2.new(0, 10, 0, 10)
qRecipient.Size = UDim2.new(1, -20, 0, 30)

local qKindButton = button(queueInput, "Kind", tr("queueKindSeed"), COL.green)
qKindButton.Position = UDim2.new(0, 10, 0, 50)
qKindButton.Size = UDim2.new(0, 100, 0, 30)
local queueKind = "Seed"

local qItems = textbox(queueInput, "Items", tr("queueItems"), "")
qItems.Position = UDim2.new(0, 120, 0, 50)
qItems.Size = UDim2.new(1, -130, 0, 30)

local qAmount = textbox(queueInput, "Amount", tr("queueAmount"), "")
qAmount.Position = UDim2.new(0, 10, 0, 90)
qAmount.Size = UDim2.new(0, 150, 0, 30)

local qThreshold = textbox(queueInput, "Threshold", tr("queueThreshold"), "")
qThreshold.Position = UDim2.new(0, 170, 0, 90)
qThreshold.Size = UDim2.new(0, 170, 0, 30)

local qAddButton = button(queueInput, "Add", tr("addJob"), COL.blue)
qAddButton.Position = UDim2.new(1, -130, 0, 90)
qAddButton.Size = UDim2.new(0, 120, 0, 30)

local queueWrap = make("Frame", {
    Name = "QueueWrap",
    Position = UDim2.new(0, 0, 0, 138),
    Size = UDim2.new(1, 0, 0, 220),
    BackgroundColor3 = COL.panel,
    BorderSizePixel = 0,
}, queueFrame)
corner(queueWrap, 8)
stroke(queueWrap, COL.stroke, 1, 0.35)
padding(queueWrap, 8, 8, 8, 8)

local queueTitle = label(queueWrap, "Title", tr("queueTitle"), 13, true)
queueTitle.TextColor3 = COL.sub
queueTitle.Position = UDim2.new(0, 8, 0, 0)
queueTitle.Size = UDim2.new(1, -16, 0, 18)

local queueScroll = make("ScrollingFrame", {
    Name = "QueueScroll",
    Position = UDim2.new(0, 0, 0, 24),
    Size = UDim2.new(1, 0, 1, -24),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 5,
    ScrollBarImageColor3 = COL.stroke,
}, queueWrap)

local queueLayout = make("UIListLayout", {
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 5),
}, queueScroll)

track(queueLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    queueScroll.CanvasSize = UDim2.new(0, 0, 0, queueLayout.AbsoluteContentSize.Y + 8)
end))

local queueControls = make("Frame", {
    Name = "QueueControls",
    Position = UDim2.new(0, 0, 0, 368),
    Size = UDim2.new(1, 0, 0, 38),
    BackgroundColor3 = COL.panel,
    BorderSizePixel = 0,
}, queueFrame)
corner(queueControls, 8)
stroke(queueControls, COL.stroke, 1, 0.35)

local qRunButton = button(queueControls, "Run", tr("run"), COL.green)
qRunButton.Position = UDim2.new(0, 8, 0, 5)
qRunButton.Size = UDim2.new(0, 120, 0, 28)

local qStopButton = button(queueControls, "Stop", tr("stop"), COL.red)
qStopButton.Position = UDim2.new(0, 136, 0, 5)
qStopButton.Size = UDim2.new(0, 120, 0, 28)

local qClearButton = button(queueControls, "Clear", tr("clearAll"), COL.panel2)
qClearButton.Position = UDim2.new(0, 264, 0, 5)
qClearButton.Size = UDim2.new(0, 120, 0, 28)

local queueStatus = label(queueControls, "Status", tr("queuePausedHint"), 12, false)
queueStatus.TextColor3 = COL.sub
queueStatus.Position = UDim2.new(0, 396, 0, 0)
queueStatus.Size = UDim2.new(1, -408, 1, 0)

local queue = {}
local queuePaused = true
local queueStopped = false

local STATUS_ICON = {
    waiting = "WAIT",
    running = "RUN",
    looping = "LOOP",
    done = "DONE",
    error = "ERR",
}

local function setQueueStatus(text)
    queueStatus.Text = tostring(text or "")
end

local function queueJobText(job)
    local items = job.Items ~= "" and job.Items or "ALL"
    return ("%s %s -> %s | %s%s%s | sent: %d"):format(
        STATUS_ICON[job.Status] or "-",
        job.Kind == "Pet" and "PET" or "SEED",
        tostring(job.Recipient),
        tostring(items),
        job.Amount > 0 and (" x" .. tostring(job.Amount)) or "",
        (job.Threshold or 0) > 0 and (" >= " .. tostring(job.Threshold)) or "",
        tonumber(job.Sent) or 0
    )
end

local function updateQueueRow(job)
    if job.Label then
        job.Label.Text = queueJobText(job)
    end
end

local function removeQueueJob(job)
    job.Removed = true
    for i, current in ipairs(queue) do
        if current == job then
            table.remove(queue, i)
            break
        end
    end
    if job.Row then
        job.Row:Destroy()
    end
end

local function addQueueRow(job)
    local row = make("Frame", {
        Name = "Job",
        Size = UDim2.new(1, -4, 0, 30),
        BackgroundColor3 = COL.panel2,
        BorderSizePixel = 0,
    }, queueScroll)
    corner(row, 6)

    local rowLabel = label(row, "Text", "", 12, false)
    rowLabel.Position = UDim2.new(0, 8, 0, 0)
    rowLabel.Size = UDim2.new(1, -44, 1, 0)
    rowLabel.TextTruncate = Enum.TextTruncate.AtEnd

    local removeButton = button(row, "Remove", "X", COL.red)
    removeButton.Position = UDim2.new(1, -30, 0, 3)
    removeButton.Size = UDim2.new(0, 24, 0, 24)

    job.Row = row
    job.Label = rowLabel
    updateQueueRow(job)

    track(removeButton.MouseButton1Click:Connect(function()
        removeQueueJob(job)
        setQueueStatus(string.format(tr("removedJob"), #queue))
    end))
end

local function addQueueJob(recipient, kind, items, amount, threshold)
    recipient = trim(recipient)
    if recipient == "" then
        return nil
    end

    local job = {
        Recipient = recipient,
        Kind = kind == "Pet" and "Pet" or "Seed",
        Items = trim(items or ""),
        Amount = math.max(math.floor(tonumber(amount) or 0), 0),
        Threshold = math.max(math.floor(tonumber(threshold) or 0), 0),
        Status = "waiting",
        Sent = 0,
        Removed = false,
        NextCheck = 0,
    }

    table.insert(queue, job)
    addQueueRow(job)
    return job
end

track(qKindButton.MouseButton1Click:Connect(function()
    if queueKind == "Seed" then
        queueKind = "Pet"
        qKindButton.Text = tr("queueKindPet")
        qKindButton.BackgroundColor3 = COL.orange
    else
        queueKind = "Seed"
        qKindButton.Text = tr("queueKindSeed")
        qKindButton.BackgroundColor3 = COL.green
    end
end))

track(qAddButton.MouseButton1Click:Connect(function()
    local job = addQueueJob(qRecipient.Text, queueKind, qItems.Text, qAmount.Text, qThreshold.Text)
    if not job then
        setQueueStatus(tr("recipientEmpty"))
        return
    end
    setQueueStatus(string.format(tr("jobAdded"), #queue))
    qRecipient.Text = ""
end))

local function updateQueueRunButton()
    qRunButton.Text = queuePaused and tr("run") or tr("pause")
    qRunButton.BackgroundColor3 = queuePaused and COL.green or COL.orange
end

local function applyLanguage()
    CFG.Language = currentLanguage
    title.Text = tr("title")
    langButton.Text = tr("languageButton")
    manualTabButton.Text = tr("manualTab")
    queueTabButton.Text = tr("queueTab")
    activeTabLabel.Text = tr("subtitle")

    manualRecipient.PlaceholderText = tr("manualRecipient")
    manualQuantity.PlaceholderText = tr("manualQuantity")
    manualNote.PlaceholderText = tr("manualNote")
    manualStopButton.Text = tr("stop")
    manualRefreshButton.Text = tr("refresh")
    clearManualButton.Text = tr("clearTicks")
    if manualSending then
        setManualSendButtonEnabled(false, tr("sending"))
    elseif not manualButtonCoolingDown then
        setManualSendButtonEnabled(true, tr("sendSelected"))
    end

    local seedsTitle = seedsScroll.Parent and seedsScroll.Parent:FindFirstChild("Title")
    if seedsTitle then
        seedsTitle.Text = tr("seeds")
    end
    local petsTitle = petsScroll.Parent and petsScroll.Parent:FindFirstChild("Title")
    if petsTitle then
        petsTitle.Text = tr("pets")
    end

    qRecipient.PlaceholderText = tr("queueRecipient")
    qItems.PlaceholderText = tr("queueItems")
    qAmount.PlaceholderText = tr("queueAmount")
    qThreshold.PlaceholderText = tr("queueThreshold")
    qKindButton.Text = queueKind == "Pet" and tr("queueKindPet") or tr("queueKindSeed")
    qAddButton.Text = tr("addJob")
    queueTitle.Text = tr("queueTitle")
    qStopButton.Text = tr("stop")
    qClearButton.Text = tr("clearAll")

    updateClaimButton()
    updateQueueRunButton()
end

track(qRunButton.MouseButton1Click:Connect(function()
    if queueStopped then
        queueStopped = false
        queuePaused = false
    else
        queuePaused = not queuePaused
    end
    updateQueueRunButton()
    setQueueStatus(queuePaused and tr("paused") or tr("runningQueue"))
end))

track(qStopButton.MouseButton1Click:Connect(function()
    queueStopped = true
    queuePaused = true
    updateQueueRunButton()
    setQueueStatus(tr("queueStopped"))
end))

track(qClearButton.MouseButton1Click:Connect(function()
    for i = #queue, 1, -1 do
        local job = queue[i]
        job.Removed = true
        if job.Row then
            job.Row:Destroy()
        end
        table.remove(queue, i)
    end
    setQueueStatus(tr("queueCleared"))
end))

local function waitQueueDelay(seconds)
    local target = os.clock() + math.max(tonumber(seconds) or 0, 0)
    while alive() and not queueStopped and os.clock() < target do
        task.wait(math.min(target - os.clock(), 0.25))
    end
    return alive() and not queueStopped
end

local function processQueueJob(job)
    local userId, recipientName, lookupErr = lookupRecipient(job.Recipient)
    if lookupErr then
        job.Status = "error"
        updateQueueRow(job)
        setQueueStatus(lookupErr)
        return
    end
    if userId == LocalPlayer.UserId then
        job.Status = "error"
        updateQueueRow(job)
        setQueueStatus("Recipient is self: " .. tostring(job.Recipient))
        return
    end

    tryCompleteTutorial()

    local sentThisPass = 0
    local amountLeft = job.Amount > 0 and math.max(job.Amount - job.Sent, 0) or math.huge
    if amountLeft <= 0 then
        job.Status = "done"
        updateQueueRow(job)
        return
    end

    local allowList, allowActive = parseNameList(job.Items)
    local batchSize = math.max(math.floor(tonumber(CFG.Queue.BatchSize) or 100000), 1)
    local threshold = tonumber(job.Threshold) or 0
    local note = tostring(CFG.Queue.Note or "")

    if job.Kind == "Seed" then
        for _, seed in ipairs(getSeedEntries(allowList, allowActive)) do
            if queueStopped or queuePaused or job.Removed or amountLeft <= 0 then
                break
            end

            if threshold <= 0 or seed.Count >= threshold then
                local available = seed.Count
                while available > 0 and amountLeft > 0 do
                    if queueStopped or queuePaused or job.Removed then
                        break
                    end

                    local chunk = math.min(available, batchSize, amountLeft)
                    if chunk <= 0 then
                        break
                    end

                    local batch = {
                        { Category = "Seeds", ItemKey = seed.ItemKey, Count = chunk },
                    }
                    local success, message = sendBatch(userId, batch, note, CFG.Queue.DelayBetween)
                    if not success then
                        addLog("Queue send failed: " .. tostring(message))
                        break
                    end

                    job.Sent = job.Sent + chunk
                    sentThisPass = sentThisPass + chunk
                    amountLeft = job.Amount > 0 and math.max(job.Amount - job.Sent, 0) or math.huge
                    available = available - chunk
                    setQueueStatus(string.format("SEED %s x%d -> %s", tostring(seed.ItemKey), chunk, tostring(recipientName)))
                    updateQueueRow(job)

                    if not waitQueueDelay(CFG.Queue.DelayBetween) then
                        break
                    end
                end
            end
        end
    else
        local pets = getPetEntries(allowList, allowActive)
        if threshold > 0 then
            local counts = {}
            for _, pet in ipairs(pets) do
                counts[pet.Name] = (counts[pet.Name] or 0) + 1
            end
            local filtered = {}
            for _, pet in ipairs(pets) do
                if (counts[pet.Name] or 0) >= threshold then
                    table.insert(filtered, pet)
                end
            end
            pets = filtered
        end

        for _, pet in ipairs(pets) do
            if queueStopped or queuePaused or job.Removed or amountLeft <= 0 then
                break
            end

            local batch = {
                { Category = "Pets", ItemKey = pet.ItemKey, Count = 1 },
            }
            local success, message = sendBatch(userId, batch, note, CFG.Queue.DelayBetween)
            if not success then
                addLog("Queue pet send failed: " .. tostring(message))
                break
            end

            job.Sent = job.Sent + 1
            sentThisPass = sentThisPass + 1
            amountLeft = job.Amount > 0 and math.max(job.Amount - job.Sent, 0) or math.huge
            setQueueStatus(string.format("PET %s -> %s", tostring(pet.Name), tostring(recipientName)))
            updateQueueRow(job)

            if not waitQueueDelay(CFG.Queue.DelayBetween) then
                break
            end
        end
    end

    if job.Removed then
        return
    end

    if job.Amount > 0 and job.Sent >= job.Amount then
        job.Status = "done"
        updateQueueRow(job)
        setQueueStatus(string.format("Xong %s - đã gửi %d", tostring(job.Recipient), job.Sent))
        postWebhook(("Xong %s: %s đã gửi %d -> %s"):format(tostring(job.Recipient), tostring(job.Kind), job.Sent, tostring(recipientName)))
        return
    end

    if threshold > 0 then
        job.Status = "looping"
        updateQueueRow(job)
        if sentThisPass > 0 then
            setQueueStatus(string.format("Loop %s - da gui them %d", tostring(job.Recipient), sentThisPass))
            postWebhook(("Loop %s: da gui them %d -> %s"):format(tostring(job.Recipient), sentThisPass, tostring(recipientName)))
        end
    else
        job.Status = "done"
        updateQueueRow(job)
        setQueueStatus(string.format("Xong %s - đã gửi %d", tostring(job.Recipient), job.Sent))
        postWebhook(("Xong %s: %s đã gửi %d -> %s"):format(tostring(job.Recipient), tostring(job.Kind), job.Sent, tostring(recipientName)))
    end
end

-- Initial config job from Queue config.
do
    local rec = trim(CFG.Queue.Recipient or "")
    if rec ~= "" then
        if CFG.Queue.SendSeeds then
            local names = type(CFG.Queue.Seeds) == "table" and table.concat(CFG.Queue.Seeds, ",") or ""
            addQueueJob(rec, "Seed", names, CFG.Queue.SeedAmount, CFG.Queue.SeedThreshold)
        end
        if CFG.Queue.SendPets then
            local names = type(CFG.Queue.Pets) == "table" and table.concat(CFG.Queue.Pets, ",") or ""
            addQueueJob(rec, "Pet", names, CFG.Queue.PetAmount, CFG.Queue.PetThreshold)
        end
        if CFG.Queue.AutoStart then
            queuePaused = false
            queueStopped = false
            setQueueStatus(tr("autoStart"))
        else
            setQueueStatus(tr("configLoaded"))
        end
        updateQueueRunButton()
    end
end

--======================================================================
-- Anti-AFK and reconnect
--======================================================================

local function setupAntiAfk()
    if CFG.AntiAfk.Enabled == false or not VirtualUser then
        return
    end

    track(LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
        if CFG.AntiAfk.Log == true then
            addLog("Anti-AFK pulse")
        end
    end))
end

local reconnecting = false
local watchedPromptOverlays = {}
local watchedPromptGuis = {}

local function requestReconnect(reason)
    if CFG.AutoReconnect.Enabled == false or reconnecting then
        return
    end

    reconnecting = true
    local why = tostring(reason or "disconnect")
    addLog("Reconnect triggered: " .. why)

    task.spawn(function()
        if not waitAlive(tonumber(CFG.AutoReconnect.Delay) or 3) then
            return
        end

        while alive() do
            local ok, err = pcall(function()
                if CFG.AutoReconnect.SameServer == true and type(game.JobId) == "string" and game.JobId ~= "" then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
                else
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end
            end)

            if ok then
                addLog("Reconnect requested")
            else
                addLog("Reconnect retry failed: " .. tostring(err))
            end

            if not waitAlive(5) then
                return
            end
        end
    end)
end

local function watchPromptOverlay(overlay)
    if not overlay or watchedPromptOverlays[overlay] then
        return
    end
    watchedPromptOverlays[overlay] = true

    local function inspect(child)
        if child and child.Name == "ErrorPrompt" then
            requestReconnect("Roblox ErrorPrompt")
        end
    end

    for _, child in ipairs(overlay:GetChildren()) do
        inspect(child)
    end
    track(overlay.ChildAdded:Connect(inspect))
end

local function watchRobloxPromptGui(promptGui)
    if not promptGui or watchedPromptGuis[promptGui] then
        return
    end
    watchedPromptGuis[promptGui] = true

    local overlay = promptGui:FindFirstChild("promptOverlay")
    if overlay then
        watchPromptOverlay(overlay)
    end

    track(promptGui.ChildAdded:Connect(function(child)
        if child.Name == "promptOverlay" then
            watchPromptOverlay(child)
        end
    end))
end

local function setupAutoReconnect()
    if CFG.AutoReconnect.Enabled == false then
        return
    end

    if CoreGui then
        local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
        if promptGui then
            watchRobloxPromptGui(promptGui)
        end

        track(CoreGui.ChildAdded:Connect(function(child)
            if child.Name == "RobloxPromptGui" then
                watchRobloxPromptGui(child)
            end
        end))
    else
        addLog("CoreGui unavailable; reconnect watcher limited")
    end

    pcall(function()
        track(LocalPlayer.OnTeleport:Connect(function(state)
            if state == Enum.TeleportState.Failed then
                reconnecting = false
                requestReconnect("teleport failed")
            end
        end))
    end)
end

--======================================================================
-- Window controls, dragging, loops
--======================================================================

local normalMainSize = main.Size
local minimizedMainSize = UDim2.new(0, 330, 0, 38)
local normalTitleSize = title.Size
local minimizedTitleSize = UDim2.new(1, -110, 1, 0)
local minimized = false

local function setMinimized(value)
    minimized = value == true
    tabs.Visible = not minimized
    content.Visible = not minimized
    logPanel.Visible = not minimized
    main.Size = minimized and minimizedMainSize or normalMainSize
    title.Size = minimized and minimizedTitleSize or normalTitleSize
    minButton.Text = minimized and "+" or "-"
end

track(minButton.MouseButton1Click:Connect(function()
    setMinimized(not minimized)
end))

track(langButton.MouseButton1Click:Connect(function()
    currentLanguage = currentLanguage == "vi" and "en" or "vi"
    applyLanguage()
    addLog(currentLanguage == "vi" and "Đã đổi giao diện sang tiếng Việt" or "Switched interface to English")
end))

track(closeButton.MouseButton1Click:Connect(function()
    Runtime.Stop("close button")
end))

do
    local dragging = false
    local dragStart
    local startPosition

    track(titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = main.Position
            track(input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end))
        end
    end))

    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end))
end

Runtime.Tasks[#Runtime.Tasks + 1] = task.spawn(function()
    while alive() do
        if claimEnabled then
            pcall(claimOnce)
        end
        if not waitAlive(tonumber(CFG.Manual.ClaimDelay) or 0.05) then
            break
        end
    end
end)

Runtime.Tasks[#Runtime.Tasks + 1] = task.spawn(function()
    while alive() do
        if queuePaused or queueStopped then
            task.wait(0.3)
        else
            local snapshot = {}
            for _, job in ipairs(queue) do
                table.insert(snapshot, job)
            end

            for _, job in ipairs(snapshot) do
                if queuePaused or queueStopped or not alive() then
                    break
                end
                if not job.Removed then
                    local isLoop = (tonumber(job.Threshold) or 0) > 0 and job.Status ~= "done"
                    if isLoop then
                        if (job.NextCheck or 0) <= os.clock() then
                            job.Status = "looping"
                            updateQueueRow(job)
                            local ok, err = pcall(processQueueJob, job)
                            if not ok then
                                job.Status = "error"
                                updateQueueRow(job)
                                addLog("Queue job error: " .. tostring(err))
                            end
                            job.NextCheck = os.clock() + math.max(tonumber(CFG.Queue.LoopInterval) or 5, 1)
                        end
                    elseif job.Status == "waiting" then
                        job.Status = "running"
                        updateQueueRow(job)
                        local ok, err = pcall(processQueueJob, job)
                        if not ok then
                            job.Status = "error"
                            updateQueueRow(job)
                            addLog("Queue job error: " .. tostring(err))
                        end
                    end
                end
            end

            task.wait(1)
        end
    end
end)

setupAntiAfk()
setupAutoReconnect()
applyLanguage()

if not Networking then
    addLog("Missing Networking module")
    setManualProgress(0, 0, "Missing Networking module")
elseif not PlayerStateClient then
    addLog("Missing PlayerStateClient module")
    setManualProgress(0, 0, "Missing PlayerStateClient module")
elseif not mailbox("SendBatch") or not mailbox("LookupPlayer") then
    addLog("Missing mailbox send remotes")
    setManualProgress(0, 0, "Missing mailbox send remotes")
else
    refreshManualInventory()
    addLog(tr("ready"))
    addLog(tr("loaded"))
    addLog("Anti-AFK " .. (CFG.AntiAfk.Enabled ~= false and "enabled" or "disabled")
        .. ", reconnect " .. (CFG.AutoReconnect.Enabled ~= false and "enabled" or "disabled"))
end
