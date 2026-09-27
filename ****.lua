-- SKAY
-- Password: Fortnite67!
-- K: show/hide menu.
-- Flight: movement controls + Space / Left Ctrl.
-- Building uses the supplied grid bounds.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer
assert(LP, "Run this on the client.")

local previous = _G.TrapBuildJob
if type(previous) == "table" and type(previous.close) == "function" then
    pcall(previous.close)
end
_G.TrapBuildJob = nil
_G.InfiniteRampJob = nil
_G.TrapSupportJob = nil

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- Password gate before features are initialized.
local Window = Rayfield:CreateWindow({
    Name = "SKAY",
    LoadingTitle = "SKAY",
    LoadingSubtitle = "Building and movement",
    ShowText = "SKAY",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {Enabled = false},
    Discord = {Enabled = false},
    KeySystem = true,
    KeySettings = {
        Title = "SKAY",
        Subtitle = "Password Required",
        Note = "Enter the password to open the panel.",
        FileName = "SKAY_Password",
        SaveKey = false,
        GrabKeyFromSite = false,
        Key = {"Fortnite67!"},
    },
})

local job = {
    active = true, auto = true, interval = 10,
    nextDue = 0, pending = false, busy = false,
    epoch = 0, lastSent = 0, totalSent = 0,
}
_G.TrapBuildJob = job

local flags = {
    silentAim = false, infiniteAmmo = false,
    noRecoil = false, noSpread = false,
    fastFire = false, autoGuns = false,
    esp = false, noclip = false, jump = false,
    speed = false, fly = false, infiniteJump = false,
}

local jumpPower, walkSpeed, flySpeed, flingPower = 100, 60, 80, 150
local BaseWeapon, flight, trackedCharacter
local speedHumanoid, savedWalkSpeed, lastTeleport
local hooks, connections, espObjects = {}, {}, {}
local savedCollisions, movementToggles, waypoints = {}, {}, {}

local espFolder = Instance.new("Folder")
espFolder.Name = "SKAY_ESP"
espFolder.Parent = workspace

local function alive()
    return job.active and _G.TrapBuildJob == job
end

local function notify(message)
    if alive() then
        Rayfield:Notify({
            Title = "SKAY",
            Content = tostring(message),
            Duration = 5,
        })
    end
end

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    connections[#connections + 1] = connection
    return connection
end

local function characterParts()
    local character = LP.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or humanoid.Health <= 0
        or not root or not root:IsA("BasePart") then return nil end
    return character, humanoid, root
end

local function stopBuilding()
    job.auto = false
    job.pending = false
    job.epoch = job.epoch + 1
end

local function removeESP(player)
    local entry = espObjects[player]
    if not entry then return end
    entry.highlight:Destroy()
    entry.billboard:Destroy()
    espObjects[player] = nil
end

local function clearESP()
    for player in pairs(espObjects) do removeESP(player) end
end

local function restoreCollisions()
    for part, value in pairs(savedCollisions) do
        if part.Parent then
            pcall(function() part.CanCollide = value end)
        end
    end
    table.clear(savedCollisions)
    trackedCharacter = nil
end

local function restoreSpeed()
    if speedHumanoid and speedHumanoid.Parent and savedWalkSpeed ~= nil then
        pcall(function() speedHumanoid.WalkSpeed = savedWalkSpeed end)
    end
    speedHumanoid, savedWalkSpeed = nil, nil
end

local function stopFlight()
    local old = flight
    flight = nil
    if not old then return end
    old.velocity:Destroy()
    old.attachment:Destroy()
    if old.humanoid.Parent then
        old.humanoid.AutoRotate = old.autoRotate
    end
    if old.root.Parent then
        old.root.AssemblyLinearVelocity = Vector3.zero
        old.root.AssemblyAngularVelocity = Vector3.zero
    end
end

local function stopMovement()
    flags.speed, flags.fly, flags.noclip = false, false, false
    flags.infiniteJump, flags.jump = false, false
    stopFlight()
    restoreSpeed()
    restoreCollisions()
end

job.close = function()
    if not job.active then return end
    stopBuilding()
    job.active = false
    for key in pairs(flags) do flags[key] = false end
    for _, connection in ipairs(connections) do connection:Disconnect() end
    table.clear(connections)
    pcall(stopMovement)
    pcall(clearESP)
    espFolder:Destroy()
    if BaseWeapon then
        for name, hook in pairs(hooks) do
            pcall(function()
                if BaseWeapon[name] == hook.wrapper then
                    BaseWeapon[name] = hook.original
                end
            end)
        end
    end
    if _G.TrapBuildJob == job then _G.TrapBuildJob = nil end
    pcall(function() Rayfield:Destroy() end)
end

local BuildTab = Window:CreateTab("Building", 4483362458)
local WeaponTab = Window:CreateTab("Weapons", 4483362458)
local KillTab = Window:CreateTab("Killall", 4483362458)
local ESPTab = Window:CreateTab("ESP", 4483362458)
local MovementTab = Window:CreateTab("Movement", 4483362458)
local TeleportTab = Window:CreateTab("Waypoints", 4483362458)
local JumpTab = Window:CreateTab("Jump Power", 4483362458)
local FlingTab = Window:CreateTab("Fling", 4483362458)
local CreditsTab = Window:CreateTab("Credits", 4483362458)
CreditsTab:CreateSection("SKAY")

local function button(tab, name, callback)
    return tab:CreateButton({
        Name = name,
        Callback = function()
            if not alive() then return end
            local ok, err = pcall(callback)
            if not ok then notify(err) end
        end,
    })
end

local function slider(tab, name, minimum, maximum, increment,
    value, suffix, flag, callback)
    return tab:CreateSlider({
        Name = name,
        Range = {minimum, maximum},
        Increment = increment,
        CurrentValue = value,
        Suffix = suffix,
        Flag = flag,
        Callback = function(newValue)
            if alive() then callback(newValue) end
        end,
    })
end

local function movementToggle(tab, name, key, onChange)
    local toggle = tab:CreateToggle({
        Name = name,
        CurrentValue = false,
        Flag = "SKAY_" .. key,
        Callback = function(enabled)
            if not alive() then return end
            flags[key] = enabled
            if onChange then onChange(enabled) end
        end,
    })
    movementToggles[key] = toggle
    return toggle
end

-- BUILDING

local Event
do
    local ok, result = pcall(function()
        return RS.BuildingSystem.Libraries.Grid.AddGridObject
    end)
    if ok and typeof(result) == "Instance" and result:IsA("RemoteEvent") then
        Event = result
    else
        job.auto = false
        notify("Building remote unavailable.")
    end
end

local RATE = 450
local FLOOR_Y, ROOF_Y = 16, 17
local MIN_X, MAX_X, MIN_Z, MAX_Z = -2, 2, -3, 5
local plan, seen = {}, {}

local function add(piece, x, y, z)
    local kind = piece:match("^Floor%$") and "Floor" or piece
    local key = kind .. ":" .. x .. "," .. y .. "," .. z
    if seen[key] then return end
    seen[key] = true
    plan[#plan + 1] = {piece, Vector3.new(x, y, z)}
end

local function ramp(piece, topX, topZ, dx, dz)
    for y = 0, FLOOR_Y - 1 do
        local distance = FLOOR_Y - 1 - y
        add(piece, topX - dx * distance, y, topZ - dz * distance)
    end
end

local function ring(minX, maxX, minZ, maxZ, walls)
    if walls then
        for z = minZ, maxZ do
            add("Wall$90$0", maxX, FLOOR_Y, z)
            add("Wall$270$0", minX, FLOOR_Y, z)
        end
        for x = minX, maxX do
            add("Wall$0$0", x, FLOOR_Y, minZ)
            add("Wall$180$0", x, FLOOR_Y, maxZ)
        end
    else
        for x = minX, maxX do
            add("Floor$180$0", x, FLOOR_Y, minZ)
            add("Floor$0$0", x, FLOOR_Y, maxZ)
        end
        for z = minZ + 1, maxZ - 1 do
            add("Floor$0$0", minX, FLOOR_Y, z)
            add("Floor$0$0", maxX, FLOOR_Y, z)
        end
    end
end

local function floorRectangle(minX, maxX, minZ, maxZ, y)
    for x = minX, maxX do
        for z = minZ, maxZ do
            add(z == MIN_Z and "Floor$180$0" or "Floor$0$0", x, y, z)
        end
    end
end

ramp("Ramp$270$0", 2, -2, -1, 0)
ring(MIN_X, MAX_X, MIN_Z, MAX_Z, false)
ring(MIN_X + 1, MAX_X - 1, MIN_Z + 1, MAX_Z - 1, false)
floorRectangle(MIN_X, MAX_X, MIN_Z, MAX_Z, FLOOR_Y)
ring(MIN_X, MAX_X, MIN_Z, MAX_Z, true)

-- Interior cells; fit depends on the game's wall pivots.
for x = MIN_X + 1, MAX_X - 1 do
    for z = MIN_Z + 1, MAX_Z - 1 do
        for _, rotation in ipairs({0, 90, 180, 270}) do
            add("Wall$" .. rotation .. "$0", x, FLOOR_Y, z)
        end
    end
end

floorRectangle(MIN_X, MAX_X, MIN_Z, MAX_Z, ROOF_Y)

for z = MIN_Z, MAX_Z do
    ramp("Ramp$270$0", MAX_X, z, -1, 0)
    ramp("Ramp$90$0", MIN_X, z, 1, 0)
end
for x = MIN_X + 1, MAX_X - 1 do
    ramp("Ramp$0$0", x, MIN_Z, 0, 1)
    ramp("Ramp$180$0", x, MAX_Z, 0, -1)
end

local RegenToggle
RegenToggle = BuildTab:CreateToggle({
    Name = "Auto Regen",
    CurrentValue = job.auto,
    Flag = "SKAYAutoRegen",
    Callback = function(enabled)
        if not alive() then return end
        if enabled and Event then
            job.auto = true
            job.nextDue = 0
        else
            stopBuilding()
            if enabled and not Event then
                notify("Building remote unavailable.")
                task.defer(function()
                    if alive() and RegenToggle then RegenToggle:Set(false) end
                end)
            end
        end
    end,
})

local function setDelay(value)
    local number = tonumber(value)
    if not number or number ~= number or number < 0.1 or number > 60 then
        notify("Enter a delay from 0.1 to 60 seconds.")
        return nil
    end
    job.interval = number
    if not job.busy then job.nextDue = os.clock() + number end
    return number
end

local delaySlider = slider(BuildTab, "Delay between rebuilds",
    0.1, 60, 0.1, 10, "seconds", "SKAYRegenDelay", setDelay)

BuildTab:CreateInput({
    Name = "Custom Regen Delay",
    CurrentValue = "",
    PlaceholderText = "0.1 to 60 seconds",
    RemoveTextAfterFocusLost = false,
    Flag = "SKAYCustomRegenDelay",
    Callback = function(text)
        if not alive() or text == "" then return end
        local number = setDelay(text)
        if number then
            delaySlider:Set(number)
            setDelay(number)
            notify("Delay: " .. number .. " seconds after each build.")
        end
    end,
})

button(BuildTab, "Build / Repair Once", function()
    if not Event then notify("Building remote unavailable.") return end
    job.pending = true
    if job.busy then notify("One repair queued.") end
end)

button(BuildTab, "Cancel Queued Repair", function()
    job.pending = false
    notify("Queued repair removed.")
end)

button(BuildTab, "Show Build Status", function()
    notify(string.format(
        "%s | Auto: %s | Delay: %.3fs | Queued: %s | Last: %d/%d",
        job.busy and "Building" or "Idle",
        tostring(job.auto), job.interval,
        tostring(job.pending), job.lastSent, #plan
    ))
end)

button(BuildTab, "Stop All Building", function()
    stopBuilding()
    RegenToggle:Set(false)
end)

button(BuildTab, "Stop and Close Everything", function() job.close() end)

local function sendBuild()
    local epoch, budget, sent = job.epoch, 0, 0
    job.lastSent = 0
    local function cancelled()
        return not alive() or job.epoch ~= epoch
    end
    for _, piece in ipairs(plan) do
        if cancelled() then return sent end
        while budget < 1 do
            local elapsed = task.wait()
            if cancelled() then return sent end
            budget = math.min(budget + elapsed * RATE, 15)
        end
        if cancelled() then return sent end
        Event:FireServer(piece[1], piece[2])
        budget, sent = budget - 1, sent + 1
        job.lastSent = sent
        job.totalSent = job.totalSent + 1
    end
    return sent
end

-- WEAPONS

do
    local ok, result = pcall(function()
        return require(RS.WeaponsSystem.Libraries.BaseWeapon)
    end)
    if ok and type(result) == "table" then
        BaseWeapon = result
    else
        notify("BaseWeapon unavailable.")
    end
end

local function closestHead()
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    local mouse = UIS:GetMouseLocation()
    local closest, distance = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local head = character and character:FindFirstChild("Head")
            if humanoid and humanoid.Health > 0 and head and head:IsA("BasePart") then
                local point, visible = camera:WorldToScreenPoint(head.Position)
                if visible then
                    local current = (Vector2.new(point.X, point.Y) - mouse).Magnitude
                    if current < distance then distance, closest = current, head end
                end
            end
        end
    end
    return closest
end

local function installHook(name, factory)
    if not BaseWeapon or type(BaseWeapon[name]) ~= "function" then return end
    local original = BaseWeapon[name]
    local wrapper = factory(original)
    local ok, err = pcall(function() BaseWeapon[name] = wrapper end)
    if ok then
        hooks[name] = {original = original, wrapper = wrapper}
    else
        warn("SKAY: " .. name .. ": " .. tostring(err))
    end
end

installHook("getAmmoInWeapon", function(original)
    return function(self, ...)
        if alive() and flags.infiniteAmmo then return 8999999488 end
        return original(self, ...)
    end
end)

installHook("useAmmo", function(original)
    return function(self, ...)
        if alive() and flags.infiniteAmmo and self.ammoInWeaponValue then return 1 end
        return original(self, ...)
    end
end)

installHook("fire", function(original)
    return function(self, ...)
        local args = table.pack(...)
        if alive() and flags.silentAim and typeof(args[1]) == "Vector3" then
            local head = closestHead()
            if head then
                local direction = head.Position - args[1]
                if direction.Magnitude > 0 then
                    args[2], args[3] = direction.Unit, 1
                    args.n = math.max(args.n, 3)
                end
            end
        end
        return original(self, table.unpack(args, 1, args.n))
    end
end)

installHook("getConfigValue", function(original)
    return function(self, key, ...)
        if alive() then
            if flags.fastFire and key == "ShotCooldown" then return 0.01
            elseif flags.autoGuns and key == "FireMode" then return "Automatic"
            elseif flags.noRecoil and (key == "RecoilMin" or key == "RecoilMax") then return 0
            elseif flags.noSpread and (key == "MinSpread" or key == "MaxSpread") then return 0
            end
        end
        return original(self, key, ...)
    end
end)

local function weaponToggle(name, key, requiredHooks)
    local toggle
    toggle = WeaponTab:CreateToggle({
        Name = name, CurrentValue = false, Flag = "SKAY_" .. key,
        Callback = function(enabled)
            if not alive() then return end
            local available = BaseWeapon ~= nil
            for _, hookName in ipairs(requiredHooks) do
                if not hooks[hookName] then available = false end
            end
            if enabled and not available then
                flags[key] = false
                notify(name .. " unavailable.")
                task.defer(function()
                    if alive() and toggle then toggle:Set(false) end
                end)
                return
            end
            flags[key] = enabled
        end,
    })
end

weaponToggle("Silent Aim", "silentAim", {"fire"})
weaponToggle("Infinite Ammo", "infiniteAmmo", {"getAmmoInWeapon", "useAmmo"})
weaponToggle("No Recoil", "noRecoil", {"getConfigValue"})
weaponToggle("No Spread", "noSpread", {"getConfigValue"})
weaponToggle("Fast Guns", "fastFire", {"getConfigValue"})
weaponToggle("Automatic Guns", "autoGuns", {"getConfigValue"})

-- SINGLE-PASS KILLALL

local killBusy = false
button(KillTab, "Killall V1", function()
    if killBusy then return end
    killBusy = true
    local ok, err = pcall(function()
        local character, humanoid = characterParts()
        if not character then error("Your character is not ready.") end
        local backpack = LP:FindFirstChildOfClass("Backpack")
        local gun = character:FindFirstChild("Sniper")
            or (backpack and backpack:FindFirstChild("Sniper"))
        if not gun or not gun:IsA("Tool") then error("A Sniper tool is required.") end
        local hitEvent = RS.WeaponsSystem.Network.WeaponHit
        if not hitEvent:IsA("RemoteEvent") then error("WeaponHit unavailable.") end
        if gun.Parent ~= character then
            humanoid:EquipTool(gun)
            task.wait(0.1)
        end
        if not alive() then return end
        if gun.Parent ~= character then error("Could not equip Sniper.") end
        for _, player in ipairs(Players:GetPlayers()) do
            if not alive() then return end
            if player ~= LP then
                local target = player.Character
                local head = target and target:FindFirstChild("Head")
                local hum = target and target:FindFirstChildOfClass("Humanoid")
                if head and head:IsA("BasePart") and hum and hum.Health > 0 then
                    hitEvent:FireServer(gun, {
                        p = head.Position, pid = 1, part = head,
                        d = 500, maxDist = 500, h = hum,
                        m = Enum.Material.Plastic,
                        n = Vector3.new(
                            -0.9637810587882996,
                            -0.046888358891,
                            -0.2625408172607
                        ),
                        t = 0.15185665205004445, sid = 32,
                    })
                end
            end
            task.wait()
        end
    end)
    killBusy = false
    if not ok then notify(err) end
end)

-- CUSTOM ESP

local function createESP(player, character, head)
    removeESP(player)
    local highlight = Instance.new("Highlight")
    highlight.Name = "SKAY_Outline"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.8
    highlight.OutlineTransparency = 0
    highlight.Parent = espFolder

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "SKAY_Nameplate"
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.fromOffset(220, 64)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    billboard.Parent = espFolder

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0.2
    label.Parent = billboard

    local entry = {
        character = character, head = head,
        highlight = highlight, billboard = billboard, label = label,
    }
    espObjects[player] = entry
    return entry
end

local function updateESP()
    local valid = {}
    local _, _, ownRoot = characterParts()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LP then
            local character = player.Character
            local hum = character and character:FindFirstChildOfClass("Humanoid")
            local head = character and character:FindFirstChild("Head")
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if character and character.Parent and hum and hum.Health > 0
                and head and head:IsA("BasePart")
                and root and root:IsA("BasePart") then
                valid[player] = true
                local entry = espObjects[player]
                if not entry or entry.character ~= character or entry.head ~= head
                    or not entry.highlight.Parent or not entry.billboard.Parent then
                    entry = createESP(player, character, head)
                end
                local color = Color3.fromRGB(255, 90, 90)
                if player.Team and not player.Neutral then color = player.TeamColor.Color end
                entry.highlight.FillColor = color
                entry.highlight.OutlineColor = color
                local name = player.DisplayName
                if name ~= player.Name then name = name .. " (@" .. player.Name .. ")" end
                local distanceText = ownRoot and string.format(
                    " | %.0f studs", (ownRoot.Position - root.Position).Magnitude
                ) or ""
                entry.label.Text = string.format(
                    "%s\nHP: %.0f / %.0f%s", name, hum.Health, hum.MaxHealth, distanceText
                )
            end
        end
    end
    for player in pairs(espObjects) do
        if not valid[player] then removeESP(player) end
    end
end

ESPTab:CreateToggle({
    Name = "SKAY ESP - Names / Health / Distance",
    CurrentValue = false, Flag = "SKAYCustomESP",
    Callback = function(enabled)
        if not alive() then return end
        flags.esp = enabled
        if not enabled then clearESP() end
    end,
})

local espElapsed = 0
connect(RunService.Heartbeat, function(dt)
    if not alive() or not flags.esp then return end
    espElapsed = espElapsed + dt
    if espElapsed < 0.1 then return end
    espElapsed = 0
    updateESP()
end)
connect(Players.PlayerRemoving, removeESP)

-- MOVEMENT

movementToggle(MovementTab, "Noclip", "noclip", function(enabled)
    if not enabled then restoreCollisions() end
end)

connect(RunService.Stepped, function()
    if not alive() or not flags.noclip then return end
    local character = LP.Character
    if character ~= trackedCharacter then
        restoreCollisions()
        trackedCharacter = character
    end
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            if savedCollisions[part] == nil then
                savedCollisions[part] = part.CanCollide
            end
            part.CanCollide = false
        end
    end
    for part, value in pairs(savedCollisions) do
        if not part:IsDescendantOf(character) then
            if part.Parent then part.CanCollide = value end
            savedCollisions[part] = nil
        end
    end
end)

slider(MovementTab, "Walk Speed", 16, 200, 1, walkSpeed,
    "studs/s", "SKAYWalkSpeed", function(value) walkSpeed = value end)

movementToggle(MovementTab, "Enable Speed Boost", "speed", function(enabled)
    if not enabled then restoreSpeed() end
end)

slider(MovementTab, "Fly Speed", 10, 250, 1, flySpeed,
    "studs/s", "SKAYFlySpeed", function(value) flySpeed = value end)

movementToggle(MovementTab, "Fly / Hover", "fly", function(enabled)
    if not enabled then stopFlight() end
end)

movementToggle(MovementTab, "Infinite Jump", "infiniteJump")

local function startFlight(humanoid, root)
    stopFlight()
    local attachment = Instance.new("Attachment")
    attachment.Name = "SKAY_FlightAttachment"
    attachment.Parent = root
    local velocity = Instance.new("LinearVelocity")
    velocity.Name = "SKAY_FlightVelocity"
    velocity.Attachment0 = attachment
    velocity.RelativeTo = Enum.ActuatorRelativeTo.World
    velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
    velocity.ForceLimitsEnabled = false
    velocity.VectorVelocity = Vector3.zero
    flight = {
        root = root, humanoid = humanoid,
        attachment = attachment, velocity = velocity,
        autoRotate = humanoid.AutoRotate,
    }
    humanoid.AutoRotate = false
    velocity.Parent = root
end

local function updateMovement()
    local _, humanoid, root = characterParts()
    if not humanoid then
        restoreSpeed()
        stopFlight()
        return
    end
    if flags.speed then
        if speedHumanoid ~= humanoid then
            restoreSpeed()
            speedHumanoid, savedWalkSpeed = humanoid, humanoid.WalkSpeed
        end
        humanoid.WalkSpeed = walkSpeed
    end
    if flags.fly then
        if humanoid.SeatPart then stopFlight() return end
        if not flight or flight.root ~= root or not flight.velocity.Parent then
            startFlight(humanoid, root)
        end
        local vertical = 0
        local movement = humanoid.MoveDirection
        if UIS:GetFocusedTextBox() then
            movement = Vector3.zero
        else
            if UIS:IsKeyDown(Enum.KeyCode.Space) then vertical = vertical + 1 end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then vertical = vertical - 1 end
        end
        local direction = Vector3.new(movement.X, vertical, movement.Z)
        if direction.Magnitude > 1 then direction = direction.Unit end
        flight.velocity.VectorVelocity = direction * flySpeed
    end
end

connect(RunService.Heartbeat, function()
    if not alive() then return end
    local ok, err = pcall(updateMovement)
    if not ok then
        stopMovement()
        for _, toggle in pairs(movementToggles) do toggle:Set(false) end
        notify("Movement stopped: " .. tostring(err))
    end
end)

local lastJump = 0
connect(UIS.JumpRequest, function()
    if not alive() or not flags.infiniteJump or flags.fly
        or UIS:GetFocusedTextBox() then return end
    if os.clock() - lastJump < 0.15 then return end
    local _, humanoid, root = characterParts()
    if not humanoid or humanoid.SeatPart then return end
    lastJump = os.clock()
    local velocity = root.AssemblyLinearVelocity
    local power = humanoid.UseJumpPower and humanoid.JumpPower
        or math.sqrt(2 * workspace.Gravity * humanoid.JumpHeight)
    root.AssemblyLinearVelocity = Vector3.new(velocity.X, power, velocity.Z)
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end)

local function flightStep(delta)
    if not flags.fly then notify("Enable Fly / Hover first.") return end
    local character, humanoid = characterParts()
    if not character or humanoid.SeatPart then
        notify("Stand up with a living character first.")
        return
    end
    character:PivotTo(character:GetPivot() + Vector3.new(0, delta, 0))
end

button(MovementTab, "Fly Up 8 Studs (Touch)", function() flightStep(8) end)
button(MovementTab, "Fly Down 8 Studs (Touch)", function() flightStep(-8) end)

button(MovementTab, "EMERGENCY: Disable All Movement", function()
    stopMovement()
    for _, toggle in pairs(movementToggles) do toggle:Set(false) end
    local _, _, root = characterParts()
    if root then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    notify("Movement disabled.")
end)

connect(LP.CharacterRemoving, function()
    stopFlight()
    restoreSpeed()
    restoreCollisions()
end)

-- WAYPOINTS

local function teleportTo(destination)
    local character, humanoid, root = characterParts()
    if not character then notify("Your character is not ready.") return end
    if humanoid.SeatPart then notify("Stand up before teleporting.") return end
    local origin = character:GetPivot()
    character:PivotTo(destination)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    lastTeleport = origin
end

for i = 1, 3 do
    local slot = i
    button(TeleportTab, "Save Position to Slot " .. slot, function()
        local character = characterParts()
        if not character then notify("Your character is not ready.") return end
        waypoints[slot] = character:GetPivot()
        notify("Saved slot " .. slot .. ".")
    end)
    button(TeleportTab, "Teleport to Slot " .. slot, function()
        if not waypoints[slot] then notify("Save a position first.") return end
        teleportTo(waypoints[slot])
    end)
end

button(TeleportTab, "Return to Previous Position", function()
    if not lastTeleport then notify("Use a waypoint first.") return end
    teleportTo(lastTeleport)
end)

button(TeleportTab, "Clear Saved Positions", function()
    table.clear(waypoints)
    lastTeleport = nil
    notify("Saved positions cleared.")
end)

-- JUMP PAD

local function applyJumpBoost()
    local event = RS:FindFirstChild("JumpPadEvent")
    if not event or not event:IsA("RemoteEvent") then
        error("JumpPadEvent was not found.")
    end
    if type(firesignal) ~= "function" then
        error("firesignal is unavailable.")
    end
    firesignal(event.OnClientEvent, jumpPower)
end

slider(JumpTab, "Jump Power", 1, 1000, 1, jumpPower,
    "power", "SKAYJumpPower", function(value) jumpPower = value end)

local JumpToggle = movementToggle(JumpTab, "Repeat Jump Boost", "jump")
button(JumpTab, "Apply Jump Boost Once", applyJumpBoost)

button(JumpTab, "Stop Repeating Jump Boost", function()
    flags.jump = false
    JumpToggle:Set(false)
end)

-- SELF FLING / LAUNCH

FlingTab:CreateSection("Launch your own character")

slider(FlingTab, "Launch Power", 25, 500, 5, flingPower,
    "studs/s", "SKAYLaunchPower", function(value) flingPower = value end)

local function launchSelf(upward)
    local _, humanoid, root = characterParts()
    if not humanoid then notify("Your character is not ready.") return end
    if humanoid.SeatPart then notify("Stand up before launching.") return end

    flags.fly = false
    stopFlight()
    if movementToggles.fly then movementToggles.fly:Set(false) end

    local direction = Vector3.new(0, 1, 0)
    if not upward then
        local camera = workspace.CurrentCamera
        local look = camera and camera.CFrame.LookVector or root.CFrame.LookVector
        local horizontal = Vector3.new(look.X, 0, look.Z)
        if horizontal.Magnitude < 0.01 then
            horizontal = Vector3.new(0, 0, -1)
        end
        direction = (horizontal.Unit + Vector3.new(0, 0.5, 0)).Unit
    end

    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    root.AssemblyLinearVelocity = direction * flingPower
end

button(FlingTab, "Launch Forward", function() launchSelf(false) end)
button(FlingTab, "Launch Upward", function() launchSelf(true) end)

button(FlingTab, "Stop Current Momentum", function()
    local _, _, root = characterParts()
    if not root then return end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end)

-- WORKERS

task.spawn(function()
    while alive() do
        if flags.jump then
            local ok, err = pcall(applyJumpBoost)
            if not alive() then break end
            if not ok then
                flags.jump = false
                JumpToggle:Set(false)
                notify("Jump boost stopped: " .. tostring(err))
            end
        end
        task.wait(0.25)
    end
end)

task.spawn(function()
    while alive() do
        local due = job.auto and os.clock() >= job.nextDue
        if Event and (job.pending or due) then
            job.pending = false
            job.busy = true
            local ok, result = pcall(sendBuild)
            job.busy = false
            job.nextDue = os.clock() + job.interval
            if not alive() then break end
            if not ok then
                stopBuilding()
                RegenToggle:Set(false)
                notify("Building stopped: " .. tostring(result))
            elseif result == #plan then
                print("SKAY: sent " .. result .. " placement requests.")
            end
        end
        task.wait(0.1)
    end
end)

notify("Unlocked. SKAY is ready.")
