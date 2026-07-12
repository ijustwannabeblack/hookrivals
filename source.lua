local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/ijustwannabeblack/hookrivals/refs/heads/main/source.lua"))()

local Window = library:window({
    name = "Hook Rivals",
    size = UDim2.fromOffset(800, 600),
})

-- PAGES (tabs)
local CombatPage = Window:tab({ name = "Combat" })
local VisualsPage = Window:tab({ name = "Visuals" })
local WorldPage = Window:tab({ name = "World" })
local SpooferPage = Window:tab({ name = "Spoofer" })
local SettingsPage = Window:tab({ name = "Settings" })

-- ============ COMBAT ============
local AimbotColumn = CombatPage:column({ fill = false })
local AimbotSection = AimbotColumn:section({ name = "Aimbot" })

local aimbotEnabled = false
local aimbotSmoothness = 0
local aimbotHitpart = "Head"
local aimbotFovRadius = 90

AimbotSection:addToggle({
    name = "Aimbot",
    flag = "aimbot_enabled",
    default = false,
    callback = function(state) aimbotEnabled = state end,
})

AimbotSection:addSlider({
    name = "Smoothness",
    flag = "aimbot_smoothness",
    min = 0,
    max = 10,
    interval = 1,
    default = 0,
    suffix = "",
    callback = function(val) aimbotSmoothness = val end,
})

AimbotSection:addDropdown({
    name = "Hit Part",
    flag = "aimbot_hitpart",
    items = { "Head", "Torso", "HumanoidRootPart", "UpperTorso", "LowerTorso" },
    default = "Head",
    callback = function(val) aimbotHitpart = val end,
})

AimbotSection:addSlider({
    name = "FOV Size",
    flag = "aimbot_fov_size",
    min = 10,
    max = 360,
    interval = 1,
    default = 90,
    suffix = "",
    callback = function(val) aimbotFovRadius = val end,
})

local FovColumn = CombatPage:column({ fill = false })
local FovSection = FovColumn:section({ name = "FOV" })

local fovColor = Color3.fromRGB(255, 255, 255)

local fovLabel = FovSection:addLabel({ name = "Color" })
fovLabel:addColorPicker({
    name = "Color",
    flag = "aimbot_fov_color",
    color = Color3.fromRGB(255, 255, 255),
    callback = function(color) fovColor = color end,
})

-- FOV circle
local cam = workspace.CurrentCamera
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local fovOverlay = Instance.new("ScreenGui")
fovOverlay.Name = "FOVOverlay"
fovOverlay.ResetOnSpawn = false
fovOverlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
fovOverlay.Parent = CoreGui

local fovFrame = Instance.new("Frame")
fovFrame.Size = UDim2.new(0, 0, 0, 0)
fovFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
fovFrame.BackgroundColor3 = Color3.new(1, 1, 1)
fovFrame.BackgroundTransparency = 0.85
fovFrame.BorderSizePixel = 0
fovFrame.Visible = false
fovFrame.Parent = fovOverlay

local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovFrame

local fovStroke = Instance.new("UIStroke")
fovStroke.Thickness = 1
fovStroke.Color = Color3.fromRGB(255, 255, 255)
fovStroke.Parent = fovFrame

RunService.RenderStepped:Connect(function()
	fovFrame.Visible = aimbotEnabled
	fovStroke.Color = fovColor
	if aimbotEnabled then
		local radius = aimbotFovRadius * (cam.ViewportSize.Y / 720)
		local size = radius * 2
		fovFrame.Size = UDim2.new(0, size, 0, size)
	end
end)

-- Aimbot
RunService.RenderStepped:Connect(function()
	if not aimbotEnabled then return end

	local myChar = LocalPlayer.Character
	if not myChar then return end

	local myHead = myChar:FindFirstChild("Head")
	if not myHead then return end

	local closest, closestDist = nil, math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		if not player.Character then continue end
		local hitPart = player.Character:FindFirstChild(aimbotHitpart)
		if not hitPart then
			hitPart = player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
			if not hitPart then continue end
		end
		local dist = (myHead.Position - hitPart.Position).Magnitude
		if dist < closestDist then
			closestDist = dist
			closest = hitPart
		end
	end

	if not closest then return end

	local targetPos = closest.Position
	local camPos = cam.CFrame.Position
	local goalCF = CFrame.lookAt(camPos, targetPos)

	if aimbotSmoothness > 0 then
		local speed = 1 / (aimbotSmoothness * 2 + 1)
		cam.CFrame = cam.CFrame:Lerp(goalCF, speed)
	else
		cam.CFrame = goalCF
	end
end)

-- ============ VISUALS ============
local VisColumn = VisualsPage:column({ fill = false })
local VisSection = VisColumn:section({ name = "Visuals" })

local boxesEnabled = false
local skeletonsEnabled = false
local namesEnabled = false
local healthEnabled = false

VisSection:addToggle({
    name = "Boxes",
    flag = "esp_boxes",
    default = false,
    callback = function(state) boxesEnabled = state end,
})

VisSection:addToggle({
    name = "Skeletons",
    flag = "esp_skeletons",
    default = false,
    callback = function(state) skeletonsEnabled = state end,
})

VisSection:addToggle({
    name = "Names",
    flag = "esp_names",
    default = false,
    callback = function(state) namesEnabled = state end,
})

VisSection:addToggle({
    name = "Health",
    flag = "esp_health",
    default = false,
    callback = function(state) healthEnabled = state end,
})

local ChecksColumn = VisualsPage:column({ fill = false })
local ChecksSection = ChecksColumn:section({ name = "Checks" })

-- ESP
local espFolder = Instance.new("Folder")
espFolder.Name = "ESPFolder"

local function getOrCreateEspGui(player)
	local existing = espFolder:FindFirstChild(player.Name)
	if existing then return existing end

	local gui = Instance.new("Folder")
	gui.Name = player.Name
	gui.Parent = espFolder

	local box = Instance.new("SelectionBox")
	box.Name = "Box"
	box.Adornee = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	box.Color3 = Color3.fromRGB(255, 255, 255)
	box.LineThickness = 0.03
	box.SurfaceTransparency = 1
	box.Visible = false
	box.Parent = gui

	local head = player.Character and player.Character:FindFirstChild("Head")
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Adornee = head or (player.Character and player.Character:FindFirstChild("HumanoidRootPart"))
	billboard.Size = UDim2.new(0, 200, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.Parent = gui

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.Name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.2
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextSize = 14
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.Parent = billboard

	local hbBg = Instance.new("Frame")
	hbBg.Name = "HealthBg"
	hbBg.Size = UDim2.new(1, -20, 0, 3)
	hbBg.Position = UDim2.new(0, 10, 0.5, 5)
	hbBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	hbBg.BorderSizePixel = 0
	hbBg.Parent = billboard

	local hbFill = Instance.new("Frame")
	hbFill.Name = "HealthFill"
	hbFill.Size = UDim2.new(1, 0, 1, 0)
	hbFill.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	hbFill.BorderSizePixel = 0
	hbFill.Parent = hbBg

	player.CharacterAdded:Connect(function(char)
		task.wait(0.3)
		local h = char:FindFirstChild("Head")
		local r = char:FindFirstChild("HumanoidRootPart")
		if billboard then billboard.Adornee = h or r end
		if box then box.Adornee = r end
	end)

	return gui
end

espFolder.Parent = CoreGui

RunService.RenderStepped:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		local char = player.Character
		if not char then continue end
		local root = char:FindFirstChild("HumanoidRootPart")
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then continue end

		local gui = getOrCreateEspGui(player)
		local billboard = gui:FindFirstChild("BillboardGui")
		local box = gui:FindFirstChild("SelectionBox")
		local head = char:FindFirstChild("Head")

		if billboard then
			billboard.Enabled = namesEnabled or healthEnabled
			billboard.Adornee = head or root
			local nameLabel = billboard:FindFirstChild("Name")
			if nameLabel then nameLabel.Visible = namesEnabled end
			local hbBg = billboard:FindFirstChild("HealthBg")
			if hbBg then
				hbBg.Visible = healthEnabled
				local hbFill = hbBg:FindFirstChild("HealthFill")
				if hbFill then
					local pct = humanoid.Health / humanoid.MaxHealth
					if pct < 0 then pct = 0 end
					if pct > 1 then pct = 1 end
					hbFill.Size = UDim2.new(pct, 0, 1, 0)
					hbFill.BackgroundColor3 = Color3.fromRGB(255 - 255 * pct, 255 * pct, 0)
				end
			end
		end

		if box then
			box.Visible = boxesEnabled
			box.Adornee = root
		end

		if skeletonsEnabled then
			if not gui:FindFirstChild("Skeleton") then
				local skel = Instance.new("Folder")
				skel.Name = "Skeleton"
				local pairs = {
					{"Head", "UpperTorso"},
					{"UpperTorso", "LowerTorso"},
					{"UpperTorso", "LeftUpperArm"},
					{"LeftUpperArm", "LeftLowerArm"},
					{"LeftLowerArm", "LeftHand"},
					{"UpperTorso", "RightUpperArm"},
					{"RightUpperArm", "RightLowerArm"},
					{"RightLowerArm", "RightHand"},
					{"LowerTorso", "LeftUpperLeg"},
					{"LeftUpperLeg", "LeftLowerLeg"},
					{"LeftLowerLeg", "LeftFoot"},
					{"LowerTorso", "RightUpperLeg"},
					{"RightUpperLeg", "RightLowerLeg"},
					{"RightLowerLeg", "RightFoot"},
				}
				for _, pair in ipairs(pairs) do
					local partA = char:FindFirstChild(pair[1])
					local partB = char:FindFirstChild(pair[2])
					if partA and partB then
						local beam = Instance.new("Beam")
						local att0 = Instance.new("Attachment")
						att0.Name = "Skel_A_" .. pair[1]
						att0.Parent = partA
						local att1 = Instance.new("Attachment")
						att1.Name = "Skel_A_" .. pair[2]
						att1.Parent = partB
						beam.Attachment0 = att0
						beam.Attachment1 = att1
						beam.Width0 = 0.12
						beam.Width1 = 0.12
						beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
						beam.Transparency = NumberSequence.new(0)
						beam.FaceCamera = true
						beam.Parent = skel
					end
				end
				skel.Parent = gui
			end
			gui.Skeleton.Visible = true
		elseif gui:FindFirstChild("Skeleton") then
			gui.Skeleton.Visible = false
		end
	end
end)
