-- ============================================================
--  W424HUB-GAG2 | V.3.2 (Kairo UI)
--  Grow a Garden 2 – All-in-One + Fixed Auto Plant
-- ============================================================
print("=== LOADING W424HUB-GAG2 V.3.2 ===")

if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local CollectionService = game:GetService("CollectionService")
local VirtualUser = game:GetService("VirtualUser")

-- ===== LOAD KAIRO UI =====
local Kairo = loadstring(game:HttpGet("https://raw.githubusercontent.com/Itzzavi335/Kairo-Ui-Library/refs/heads/main/source.luau"))()
if not Kairo then error("Kairo UI gagal dimuat") end

local ScreenSize = workspace.CurrentCamera.ViewportSize
local MobileWidth = math.clamp(ScreenSize.X - 20, 280, 400)
local MobileHeight = math.clamp(ScreenSize.Y - 80, 380, 480)

local Window = Kairo:CreateWindow({
    Title = "W424HUB-GAG2 | V.3.2",
    Theme = "Midnight",
    Size = UDim2.fromOffset(MobileWidth, MobileHeight),
    Center = true,
    Draggable = true,
    Resize = false,
    Badges = {"GAG2", "V.3.2"},
    MinimizeKey = Enum.KeyCode.RightShift,
    MinimizeButton = true,
    MinimizeButton_Image = "rbxassetid://116850882259653",
    Config = { Enabled = true, Folder = "W424HUB_GAG2", AutoLoad = true }
})

-- ============================================================
--  ITEM DATABASE
-- ============================================================
local SEEDS = {
    "Carrot", "Strawberry", "Blueberry", "Tulip", "Tomato", "Apple",
    "Bamboo", "Corn", "Cactus", "Pineapple", "Mushroom", "Green Bean",
    "Banana", "Grape", "Coconut", "Mango", "Dragon Fruit", "Acorn",
    "Cherry", "Sunflower", "Venus Fly Trap", "Pomegranate", "Poison Apple",
    "Venom Spitter", "Moon Bloom", "Hypno Bloom", "Dragon's Breath"
}

local GEARS = {
    "Common Watering Can", "Common Sprinkler", "Sign", "Uncommon Sprinkler",
    "Trowel", "Rare Sprinkler", "Jump Mushroom", "Speed Mushroom",
    "Lantern", "Shrink Mushroom", "Supersize Mushroom", "Gnome",
    "Flashbang", "Basic Pot", "Legendary Sprinkler", "Invisibility Mushroom",
    "Teleporter", "Wheelbarrow", "Super Watering Can", "Super Sprinkler"
}

local CRATES = {
    "Ladder Crate", "Bench Crate", "Light Crate", "Sign Crate",
    "Arch Crate", "Roleplay Crate", "Bridge Crate", "Spring Crate",
    "Seesaw Crate", "Conveyor Crate", "Owner Door Crate", "Bear Trap Crate",
    "Fence Crate", "Teleporter Pad Crate"
}

-- ============================================================
--  MODUL DAN FUNGSI INTI
-- ============================================================
local Networking, SeedData, FruitValueCalc, PlantLifecycleHandler, StealFlags

pcall(function()
    Networking = require(ReplicatedStorage.SharedModules.Networking)
end)
if not Networking then
    warn("⚠️ Networking module gagal dimuat, beberapa fitur mungkin gak jalan")
end

pcall(function()
    SeedData = require(ReplicatedStorage.SharedModules.SeedData)
end)
pcall(function()
    FruitValueCalc = require(ReplicatedStorage.SharedModules.FruitValueCalc)
end)
pcall(function()
    PlantLifecycleHandler = require(LocalPlayer.PlayerScripts.Controllers.PlantLifecycleHandler)
end)
pcall(function()
    StealFlags = require(ReplicatedStorage.SharedModules.Flags.StealFlags)
end)

local Gardens = Workspace:FindFirstChild("Gardens")
local Night = ReplicatedStorage:FindFirstChild("Night")

local function getMyPlot()
    if not Gardens then return nil end
    for _, plot in ipairs(Gardens:GetChildren()) do
        if plot:GetAttribute("Owner") == LocalPlayer.Name then return plot end
    end
    return nil
end

local function isNightTime()
    return Night and Night.Value == true
end

local function getChar() return LocalPlayer.Character end
local function getHRP() local c = getChar() return c and c:FindFirstChild("HumanoidRootPart") end

local function teleportTo(targetCF, speed)
    speed = speed or 35
    local hrp = getHRP()
    if not hrp or not targetCF then return end
    local start = hrp.CFrame
    local dist = (targetCF.Position - start.Position).Magnitude
    if dist < 2 then return end
    local duration = dist / speed
    local con
    local elapsed = 0
    con = RunService.RenderStepped:Connect(function(dt)
        elapsed = elapsed + dt
        if elapsed >= duration then
            if hrp and hrp.Parent then hrp.CFrame = targetCF end
            if con then con:Disconnect() end
            return
        end
        local alpha = elapsed / duration
        if hrp and hrp.Parent then
            hrp.CFrame = start:Lerp(targetCF, alpha)
        else
            if con then con:Disconnect() end
        end
    end)
    task.wait(duration + 0.5)
    if con and con.Connected then con:Disconnect() end
end

local function isSelected(items, name)
    if not items then return false end
    if type(items) == "table" then
        for k, v in pairs(items) do
            if v == "All" or k == "All" then return true end
            if v == name or k == name then return true end
        end
        return false
    elseif type(items) == "string" then
        return items == "All" or items == name
    end
    return false
end

-- ============================================================
--  STATE
-- ============================================================
local S = {
    autoHarvest = false,
    autoSell = false,
    autoSteal = false,
    autoBuy = false,
    autoPlant = false,
    sellInterval = 60,
    stealInterval = 5,
    plantInterval = 10,
    buyInterval = 30,
    antiAfk = true,
    optimize = false,
    -- NEW
    autoWater = false,
    autoSprinkler = false,
    waterInterval = 30,
    autoExpand = false,
    autoShovel = false,
    autoClaim = false,
    onlyHarvestMutated = false,
    onlyHarvestFavorite = false,
    targetWeight = 0,
}

local Selected = {
    harvestItem = {},
    plantItem = {},
    buyItem = {},
}

-- Helper for number input
local function AddNumberInput(tab, title, desc, default, callback, flag)
    if Window.AddInput then
        Window:AddInput(tab, title, desc, tostring(default), function(v)
            local num = tonumber(v)
            if num then callback(num) else callback(default) end
        end, flag)
    elseif Window.AddTextbox then
        Window:AddTextbox(tab, title, desc, tostring(default), function(v)
            local num = tonumber(v)
            if num then callback(num) else callback(default) end
        end, flag)
    else
        warn("Kairo UI does not support Input Boxes. Using default for " .. title)
        callback(default)
    end
end

-- ============================================================
--  FIXED AUTO PLANT (using official handler)
-- ============================================================
local function plantSpecific(items)
    local plot = getMyPlot()
    if not plot then
        warn("No plot found")
        return
    end
    if not Networking and not PlantLifecycleHandler then
        warn("No planting interface available")
        return
    end

    local inv = LocalPlayer:GetAttribute("Inventory")
    if not inv or not inv.Seeds then
        warn("No seeds in inventory")
        return
    end
    local seeds = inv.Seeds

    -- Gather free positions (more thorough)
    local freeSpots = {}
    local function addSpotsFromArea(area)
        if not area:IsA("BasePart") then return end
        local size = area.Size
        local step = 5.5
        for x = -size.X/2 + 3, size.X/2 - 3, step do
            for z = -size.Z/2 + 3, size.Z/2 - 3, step do
                local pos = area.CFrame * CFrame.new(x, 0.5, z)
                table.insert(freeSpots, pos.Position)
            end
        end
    end

    -- Search plot for PlantArea parts
    for _, child in ipairs(plot:GetDescendants()) do
        if child:IsA("BasePart") and (child.Name == "PlantArea" or child.Name == "Soil") then
            addSpotsFromArea(child)
        end
    end
    -- Also check CollectionService tagged areas
    for _, area in ipairs(CollectionService:GetTagged("PlantArea")) do
        if area:IsDescendantOf(plot) then
            addSpotsFromArea(area)
        end
    end

    if #freeSpots == 0 then
        warn("No plantable spots found")
        return
    end

    local planted = 0
    for seedName, count in pairs(seeds) do
        if count > 0 and planted < 40 then
            local shouldPlant = isSelected(items, seedName)
            if shouldPlant then
                -- Plant up to 5 per seed type per cycle
                local toPlant = math.min(count, 5)
                for i = 1, toPlant do
                    if planted >= #freeSpots then break end
                    local pos = freeSpots[planted + 1]
                    local success = false
                    
                    -- Try using the official PlantLifecycleHandler first
                    if PlantLifecycleHandler and PlantLifecycleHandler.PlantSeed then
                        pcall(function()
                            PlantLifecycleHandler:PlantSeed(seedName, pos, plot)
                        end)
                        success = true
                    elseif Networking and Networking.Plant and Networking.Plant.PlantSeed then
                        -- Fallback: try corrected order (plot, pos, seed)
                        pcall(function()
                            Networking.Plant.PlantSeed:Fire(plot, pos, seedName)
                        end)
                        success = true
                    else
                        warn("No planting method available")
                        return
                    end
                    
                    if success then
                        planted = planted + 1
                        task.wait(0.15) -- gentle delay
                    end
                end
            end
        end
    end
end

-- ============================================================
--  OTHER FUNCTIONS (unchanged)
-- ============================================================

local function harvestSpecific(items)
    local plot = getMyPlot()
    if not plot or not Networking then return 0 end
    local plants = plot:FindFirstChild("Plants")
    if not plants then return 0 end
    local count = 0
    
    for _, plant in ipairs(plants:GetChildren()) do
        local fruits = plant:FindFirstChild("Fruits")
        if fruits then
            for _, fruit in ipairs(fruits:GetChildren()) do
                if fruit:IsA("Model") then
                    local seedName = fruit:GetAttribute("SeedName") or fruit:GetAttribute("CorePartName")
                    local shouldHarvest = isSelected(items, seedName)
                    if shouldHarvest then
                        -- Apply filters
                        if S.onlyHarvestMutated then
                            local isMutated = fruit:GetAttribute("IsMutated") or false
                            if not isMutated then goto continue end
                        end
                        if S.onlyHarvestFavorite then
                            local isFavorite = fruit:GetAttribute("IsFavorite") or false
                            if not isFavorite then goto continue end
                        end
                        if S.targetWeight > 0 then
                            local weight = fruit:GetAttribute("Weight") or 0
                            if weight < S.targetWeight then goto continue end
                        end
                        local age = fruit:GetAttribute("Age") or 0
                        local maxAge = fruit:GetAttribute("MaxAge") or 0
                        if age >= maxAge then
                            local pid = fruit:GetAttribute("PlantId")
                            local fid = fruit:GetAttribute("FruitId") or ""
                            if pid then
                                pcall(function() Networking.Garden.CollectFruit:Fire(pid, fid) end)
                                count = count + 1
                                task.wait(0.05)
                            end
                        end
                    end
                    ::continue::
                end
            end
        else
            local seedName = plant:GetAttribute("SeedName") or plant:GetAttribute("CorePartName")
            local shouldHarvest = isSelected(items, seedName)
            if shouldHarvest then
                if S.onlyHarvestMutated then
                    local isMutated = plant:GetAttribute("IsMutated") or false
                    if not isMutated then goto continue2 end
                end
                if S.onlyHarvestFavorite then
                    local isFavorite = plant:GetAttribute("IsFavorite") or false
                    if not isFavorite then goto continue2 end
                end
                if S.targetWeight > 0 then
                    local weight = plant:GetAttribute("Weight") or 0
                    if weight < S.targetWeight then goto continue2 end
                end
                local age = plant:GetAttribute("Age") or 0
                local maxAge = plant:GetAttribute("MaxAge") or 0
                if age >= maxAge then
                    local pid = plant:GetAttribute("PlantId")
                    if pid then
                        pcall(function() Networking.Garden.CollectFruit:Fire(pid, "") end)
                        count = count + 1
                        task.wait(0.05)
                    end
                end
            end
            ::continue2::
        end
    end
    return count
end

local function sellAll()
    if Networking then
        pcall(function() Networking.NPCS.SellAll:Fire() end)
    end
end

local function buySpecific(items)
    if not Networking then return end
    if isSelected(items, "All") then
        buyItems()
        return
    end
    pcall(function()
        local seedStock = ReplicatedStorage.StockValues.SeedShop.Items
        for _, item in ipairs(seedStock:GetChildren()) do
            if item:IsA("ValueBase") and item.Value > 0 and isSelected(items, item.Name) then
                Networking.SeedShop.PurchaseSeed:Fire(item.Name)
                task.wait(0.05)
            end
        end
    end)
    pcall(function()
        local gearStock = ReplicatedStorage.StockValues.GearShop.Items
        for _, item in ipairs(gearStock:GetChildren()) do
            if item:IsA("ValueBase") and item.Value > 0 and isSelected(items, item.Name) then
                Networking.GearShop.PurchaseGear:Fire(item.Name)
                task.wait(0.05)
            end
        end
    end)
    pcall(function()
        local crateStock = ReplicatedStorage.StockValues.CrateShop.Items
        for _, item in ipairs(crateStock:GetChildren()) do
            if item:IsA("ValueBase") and item.Value > 0 and isSelected(items, item.Name) then
                Networking.CrateShop.PurchaseCrate:Fire(item.Name)
                task.wait(0.05)
            end
        end
    end)
end

local function buyItems()
    if not Networking then return end
    pcall(function()
        local seedStock = ReplicatedStorage.StockValues.SeedShop.Items
        for _, item in ipairs(seedStock:GetChildren()) do
            if item:IsA("ValueBase") and item.Value > 0 then
                Networking.SeedShop.PurchaseSeed:Fire(item.Name)
                task.wait(0.05)
            end
        end
    end)
    pcall(function()
        local gearStock = ReplicatedStorage.StockValues.GearShop.Items
        for _, item in ipairs(gearStock:GetChildren()) do
            if item:IsA("ValueBase") and item.Value > 0 then
                Networking.GearShop.PurchaseGear:Fire(item.Name)
                task.wait(0.05)
            end
        end
    end)
    pcall(function()
        local crateStock = ReplicatedStorage.StockValues.CrateShop.Items
        for _, item in ipairs(crateStock:GetChildren()) do
            if item:IsA("ValueBase") and item.Value > 0 then
                Networking.CrateShop.PurchaseCrate:Fire(item.Name)
                task.wait(0.05)
            end
        end
    end)
end

local function openItems(category)
    if not Networking then return end
    local inv = LocalPlayer:GetAttribute("Inventory") or {}
    local pkt
    if category == "Eggs" then pkt = Networking.Egg.OpenEgg
    elseif category == "Crates" then pkt = Networking.Crate.OpenCrate
    elseif category == "SeedPacks" then pkt = Networking.SeedPack.OpenSeedPack
    else return end
    for name, count in pairs(inv[category] or {}) do
        for i = 1, count do
            pcall(function() pkt:Fire(name) end)
            task.wait(0.1)
        end
    end
end

local function performSteal()
    if not isNightTime() or not Networking then return end
    local target = nil
    for _, plot in ipairs(Gardens:GetChildren()) do
        local plants = plot:FindFirstChild("Plants")
        if plants then
            for _, plant in ipairs(plants:GetChildren()) do
                local fruits = plant:FindFirstChild("Fruits")
                if fruits then
                    for _, fruit in ipairs(fruits:GetChildren()) do
                        if fruit:IsA("Model") then
                            local seedName = fruit:GetAttribute("SeedName") or fruit:GetAttribute("CorePartName")
                            if seedName and StealFlags and StealFlags.IsPlantStealable and StealFlags.IsPlantStealable(seedName) then
                                local ownerId = fruit:GetAttribute("UserId")
                                if ownerId then
                                    local owner = Players:GetPlayerByUserId(tonumber(ownerId))
                                    if owner and owner ~= LocalPlayer and not owner:GetAttribute("IsInOwnGarden") then
                                        target = fruit
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
                if target then break end
            end
        end
        if target then break end
    end
    if not target then return end
    local ownerId = target:GetAttribute("UserId")
    local plantId = target:GetAttribute("PlantId")
    local fruitId = target:GetAttribute("FruitId") or ""
    if not (ownerId and plantId) then return end
    local plot = getMyPlot()
    if not plot then return end
    local ref = plot:FindFirstChild("PlotSizeReference")
    if not ref then return end
    local home = ref.CFrame
    local bp = target:FindFirstChildWhichIsA("BasePart")
    if not bp then return end
    local targetCF = bp.CFrame + Vector3.new(0, 3, 0)
    teleportTo(targetCF, 33)
    task.wait(0.5)
    pcall(function()
        Networking.Steal.BeginSteal:Fire(tonumber(ownerId), plantId, fruitId)
    end)
    task.wait(0.1)
    pcall(function()
        Networking.Steal.CompleteSteal:Fire()
    end)
    task.wait(0.5)
    teleportTo(home, 33)
end

-- ============================================================
--  NEW FEATURE FUNCTIONS (Water, Expand, Shovel, Claim, Teleport)
-- ============================================================

local function autoWaterPlants()
    local plot = getMyPlot()
    if not plot or not Networking then return end
    local plants = plot:FindFirstChild("Plants")
    if not plants then return end
    for _, plant in ipairs(plants:GetChildren()) do
        if plant:IsA("Model") then
            local waterLevel = plant:GetAttribute("WaterLevel") or 0
            local maxWater = plant:GetAttribute("MaxWater") or 100
            if waterLevel < maxWater * 0.5 then
                local pid = plant:GetAttribute("PlantId")
                if pid then
                    pcall(function() Networking.Plant.WaterPlant:Fire(pid) end)
                    task.wait(0.1)
                end
            end
        end
    end
end

local function autoPlaceSprinkler()
    local plot = getMyPlot()
    if not plot or not Networking then return end
    local inv = LocalPlayer:GetAttribute("Inventory") or {}
    local gears = inv.Gears or {}
    local hasSprinkler = false
    for name, count in pairs(gears) do
        if string.find(name:lower(), "sprinkler") and count > 0 then
            hasSprinkler = true
            break
        end
    end
    if not hasSprinkler then return end
    local ref = plot:FindFirstChild("PlotSizeReference")
    if not ref then return end
    local pos = ref.CFrame * CFrame.new(0, 0.5, 0)
    pcall(function()
        Networking.Plant.PlaceSprinkler:Fire(pos.Position, plot)
    end)
end

local function autoExpandGarden()
    if not Networking then return end
    local plot = getMyPlot()
    if not plot then return end
    local expandData = ReplicatedStorage:FindFirstChild("GardenExpansion")
    if expandData then
        local cost = expandData:GetAttribute("Cost") or 0
        local sheckles = LocalPlayer:GetAttribute("Sheckles") or 0
        if sheckles >= cost then
            pcall(function() Networking.Garden.ExpandGarden:Fire() end)
        end
    end
end

local function autoShovelWorstPlant()
    local plot = getMyPlot()
    if not plot or not Networking then return end
    local plants = plot:FindFirstChild("Plants")
    if not plants then return end
    local worstPlant = nil
    local worstValue = math.huge
    for _, plant in ipairs(plants:GetChildren()) do
        if plant:IsA("Model") then
            local age = plant:GetAttribute("Age") or 0
            local growthTime = plant:GetAttribute("GrowthTime") or 0
            local efficiency = age > 0 and growthTime / age or math.huge
            if efficiency < worstValue then
                worstValue = efficiency
                worstPlant = plant
            end
        end
    end
    if worstPlant then
        local pid = worstPlant:GetAttribute("PlantId")
        if pid then
            pcall(function() Networking.Plant.ShovelPlant:Fire(pid) end)
        end
    end
end

local CODES = {"UPDATE2026", "GAG2FARM", "FREESHEK"} -- Update with current codes
local function autoClaimRewards()
    if not Networking then return end
    pcall(function() Networking.DailyReward.Claim:Fire() end)
    local rewards = ReplicatedStorage:FindFirstChild("Rewards")
    if rewards then
        for _, reward in ipairs(rewards:GetChildren()) do
            if reward:IsA("ValueBase") and reward.Value == true then
                pcall(function() Networking.Rewards.Claim:Fire(reward.Name) end)
            end
        end
    end
    for _, code in ipairs(CODES) do
        pcall(function() Networking.Codes.Redeem:Fire(code) end)
        task.wait(0.5)
    end
end

local function teleportToLocation(locationName)
    local hrp = getHRP()
    if not hrp then return end
    local loc = nil
    for _, part in ipairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.Name == locationName then
            loc = part
            break
        end
    end
    if loc then
        local targetCF = loc.CFrame + Vector3.new(0, 3, 0)
        teleportTo(targetCF, 50)
    end
end

-- ============================================================
--  UI – KAIRO (UPDATED)
-- ============================================================

-- ===== TAB: FARM =====
local FarmTab = Window:CreateTab("Farm", "rbxassetid://16932740082")

Window:AddParagraph(FarmTab, "Auto Farm", "Panen & Tanam Otomatis")

Window:AddToggle(FarmTab, "Auto Harvest", "Panen otomatis tanpa jeda", false, function(v)
    S.autoHarvest = v
end, "AutoHarvest")

Window:AddToggle(FarmTab, "Auto Sell", "Jual semua buah otomatis", false, function(v)
    S.autoSell = v
end, "AutoSell")

AddNumberInput(FarmTab, "Sell Interval", "Jeda antar jual (detik)", 60, function(v)
    S.sellInterval = v
end, "SellInterval")

Window:AddToggle(FarmTab, "Auto Plant", "Tanam bibit dari inventory", false, function(v)
    S.autoPlant = v
end, "AutoPlant")

AddNumberInput(FarmTab, "Plant Interval", "Jeda antar tanam (detik)", 10, function(v)
    S.plantInterval = v
end, "PlantInterval")

-- Harvest filters
Window:AddDivider(FarmTab, "Harvest Filters")
Window:AddToggle(FarmTab, "Only Mutated", "Hanya panen buah yang bermutasi", false, function(v)
    S.onlyHarvestMutated = v
end, "OnlyMutated")
Window:AddToggle(FarmTab, "Only Favorite", "Hanya panen buah favorit", false, function(v)
    S.onlyHarvestFavorite = v
end, "OnlyFavorite")
AddNumberInput(FarmTab, "Min Weight", "Panen buah dengan berat >= nilai ini", 0, function(v)
    S.targetWeight = v
end, "MinWeight")

-- Dropdowns
local harvestOptions = {"All"}
for _, seed in ipairs(SEEDS) do table.insert(harvestOptions, seed) end
Window:AddDropdown(FarmTab, "Harvest Item", "Pilih tanaman (Bisa lebih dari 1)", harvestOptions, true, {}, function(v)
    Selected.harvestItem = v
end, "HarvestItem")

local plantOptions = {"All"}
for _, seed in ipairs(SEEDS) do table.insert(plantOptions, seed) end
Window:AddDropdown(FarmTab, "Plant Item", "Pilih bibit (Bisa lebih dari 1)", plantOptions, true, {}, function(v)
    Selected.plantItem = v
end, "PlantItem")

Window:AddButton(FarmTab, "Harvest Now", "Panen sekali sekarang", "rbxassetid://16932740082", function()
    local count = harvestSpecific(Selected.harvestItem)
    Window:Notify({Title = "Harvest", Description = "Panen " .. count .. " tanaman", Content = "Selesai", Color = Color3.fromRGB(0,200,100), Delay = 2})
end)

Window:AddButton(FarmTab, "Sell Now", "Jual semua sekarang", "rbxassetid://16932740082", function()
    sellAll()
    Window:Notify({Title = "Sell", Description = "Semua terjual!", Content = "", Color = Color3.fromRGB(255,200,0), Delay = 2})
end)

Window:AddButton(FarmTab, "Plant Now", "Tanam sekali sekarang", "rbxassetid://16932740082", function()
    plantSpecific(Selected.plantItem)
    Window:Notify({Title = "Plant", Description = "Menanam bibit terpilih", Content = "", Color = Color3.fromRGB(0,200,50), Delay = 2})
end)

-- ===== TAB: WATER =====
local WaterTab = Window:CreateTab("Water", "rbxassetid://16932740082")
Window:AddParagraph(WaterTab, "Auto Water", "Siram & Sprinkler otomatis")
Window:AddToggle(WaterTab, "Auto Water", "Siram tanaman otomatis", false, function(v)
    S.autoWater = v
end, "AutoWater")
Window:AddToggle(WaterTab, "Auto Sprinkler", "Pasang sprinkler otomatis", false, function(v)
    S.autoSprinkler = v
end, "AutoSprinkler")
AddNumberInput(WaterTab, "Water Interval", "Jeda antar siram (detik)", 30, function(v)
    S.waterInterval = v
end, "WaterInterval")

-- ===== TAB: SHOP =====
local ShopTab = Window:CreateTab("Shop", "rbxassetid://16932740082")
Window:AddParagraph(ShopTab, "Auto Shop", "Beli & Buka Item")
Window:AddToggle(ShopTab, "Auto Buy", "Beli item otomatis", false, function(v)
    S.autoBuy = v
end, "AutoBuy")
AddNumberInput(ShopTab, "Buy Interval", "Jeda antar beli (detik)", 30, function(v)
    S.buyInterval = v
end, "BuyInterval")

local buyOptions = {"All"}
for _, seed in ipairs(SEEDS) do table.insert(buyOptions, seed) end
for _, gear in ipairs(GEARS) do table.insert(buyOptions, gear) end
for _, crate in ipairs(CRATES) do table.insert(buyOptions, crate) end
Window:AddDropdown(ShopTab, "Buy Item", "Pilih item (Bisa lebih dari 1)", buyOptions, true, {}, function(v)
    Selected.buyItem = v
end, "BuyItem")

Window:AddButton(ShopTab, "Buy Now", "Beli sekarang", "rbxassetid://16932740082", function()
    buySpecific(Selected.buyItem)
    Window:Notify({Title = "Buy", Description = "Membeli item terpilih", Content = "", Color = Color3.fromRGB(0,150,255), Delay = 2})
end)

Window:AddDivider(ShopTab, "")
Window:AddButton(ShopTab, "Open All Eggs", "Buka semua telur", "rbxassetid://16932740082", function()
    openItems("Eggs")
    Window:Notify({Title = "Open", Description = "Semua telur dibuka!", Content = "", Color = Color3.fromRGB(255,150,0), Delay = 2})
end)
Window:AddButton(ShopTab, "Open All Crates", "Buka semua crate", "rbxassetid://16932740082", function()
    openItems("Crates")
    Window:Notify({Title = "Open", Description = "Semua crate dibuka!", Content = "", Color = Color3.fromRGB(255,150,0), Delay = 2})
end)
Window:AddButton(ShopTab, "Open All Seed Packs", "Buka semua seed pack", "rbxassetid://16932740082", function()
    openItems("SeedPacks")
    Window:Notify({Title = "Open", Description = "Semua seed pack dibuka!", Content = "", Color = Color3.fromRGB(255,150,0), Delay = 2})
end)

-- ===== TAB: STEAL =====
local StealTab = Window:CreateTab("Steal", "rbxassetid://16932740082")
Window:AddParagraph(StealTab, "Auto Steal", "Curi buah saat malam")
Window:AddToggle(StealTab, "Auto Steal", "Curi otomatis saat malam", false, function(v)
    S.autoSteal = v
end, "AutoSteal")
AddNumberInput(StealTab, "Steal Interval", "Jeda antar curi (detik)", 5, function(v)
    S.stealInterval = v
end, "StealInterval")
Window:AddButton(StealTab, "Steal Now", "Coba curi sekali sekarang", "rbxassetid://16932740082", function()
    performSteal()
    Window:Notify({Title = "Steal", Description = "Mencoba mencuri...", Content = "", Color = Color3.fromRGB(150,100,255), Delay = 2})
end)

-- ===== TAB: ADVANCED =====
local AdvTab = Window:CreateTab("Adv", "rbxassetid://16932740082")
Window:AddParagraph(AdvTab, "Advanced", "Fitur tambahan")
Window:AddToggle(AdvTab, "Auto Expand", "Perluas kebun otomatis", false, function(v)
    S.autoExpand = v
end, "AutoExpand")
Window:AddToggle(AdvTab, "Auto Shovel", "Buang tanaman terburuk", false, function(v)
    S.autoShovel = v
end, "AutoShovel")
Window:AddToggle(AdvTab, "Auto Claim", "Klaim reward harian & redeem codes", false, function(v)
    S.autoClaim = v
end, "AutoClaim")

Window:AddDivider(AdvTab, "Teleport")
Window:AddButton(AdvTab, "TP to Garden", "Teleport ke kebun sendiri", "rbxassetid://16932740082", function()
    teleportToLocation("Garden")
end)
Window:AddButton(AdvTab, "TP to Shop", "Teleport ke toko benih", "rbxassetid://16932740082", function()
    teleportToLocation("Seed Shop")
end)
Window:AddButton(AdvTab, "TP to Crate Shop", "Teleport ke toko crate", "rbxassetid://16932740082", function()
    teleportToLocation("Crate Shop")
end)
Window:AddButton(AdvTab, "TP to Mailbox", "Teleport ke mailbox", "rbxassetid://16932740082", function()
    teleportToLocation("Mailbox")
end)

-- ===== TAB: MISC =====
local MiscTab = Window:CreateTab("Misc", "rbxassetid://16932740082")
Window:AddParagraph(MiscTab, "Lainnya", "Fitur tambahan")
Window:AddToggle(MiscTab, "Anti-AFK", "Cegah idle kick", true, function(v)
    S.antiAfk = v
end, "AntiAfk")
Window:AddToggle(MiscTab, "Optimize (FPS)", "Kurangi grafis untuk FPS tinggi", false, function(v)
    S.optimize = v
    if v then
        Lighting.GlobalShadows = false
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        for _, e in ipairs(Lighting:GetDescendants()) do
            if e:IsA("PostEffect") or e:IsA("Atmosphere") then
                pcall(function() e.Enabled = false end)
            end
        end
    else
        Lighting.GlobalShadows = true
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
    end
end, "Optimize")
Window:AddButton(MiscTab, "Unload Script", "Hapus UI dan stop script", "rbxassetid://16932740082", function()
    Window:Destroy()
end)

-- ============================================================
--  MAIN LOOPS
-- ============================================================

-- Auto Harvest (fast loop)
task.spawn(function()
    while true do
        task.wait(1)
        if S.autoHarvest then
            harvestSpecific(Selected.harvestItem)
        end
    end
end)

-- Auto Sell
task.spawn(function()
    while true do
        task.wait(S.sellInterval or 60)
        if S.autoSell then
            sellAll()
        end
    end
end)

-- Auto Plant (using fixed function)
task.spawn(function()
    while true do
        task.wait(S.plantInterval or 10)
        if S.autoPlant then
            plantSpecific(Selected.plantItem)
        end
    end
end)

-- Auto Buy
task.spawn(function()
    while true do
        task.wait(S.buyInterval or 30)
        if S.autoBuy then
            buySpecific(Selected.buyItem)
        end
    end
end)

-- Auto Steal
task.spawn(function()
    while true do
        task.wait(S.stealInterval or 5)
        if S.autoSteal and isNightTime() then
            performSteal()
        end
    end
end)

-- Auto Water & Sprinkler
task.spawn(function()
    while true do
        task.wait(S.waterInterval or 30)
        if S.autoWater then autoWaterPlants() end
        if S.autoSprinkler then autoPlaceSprinkler() end
    end
end)

-- Auto Expand
task.spawn(function()
    while true do
        task.wait(60)
        if S.autoExpand then autoExpandGarden() end
    end
end)

-- Auto Shovel
task.spawn(function()
    while true do
        task.wait(120)
        if S.autoShovel then autoShovelWorstPlant() end
    end
end)

-- Auto Claim
task.spawn(function()
    while true do
        task.wait(300)
        if S.autoClaim then autoClaimRewards() end
    end
end)

-- Anti-AFK
LocalPlayer.Idled:Connect(function()
    if S.antiAfk then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

-- Startup notification
Window:Notify({
    Title = "W424HUB-GAG2",
    Description = "V.3.2 – Grow a Garden 2",
    Content = "Press RightShift to toggle | Auto Plant FIXED!",
    Color = Color3.fromRGB(30, 30, 60),
    Delay = 6
})

print("✅ W424HUB-GAG2 V.3.2 (Kairo UI) loaded!")