local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LobbyConfig = require(ReplicatedStorage.Shared.Config.LobbyConfig)
local Tags = require(ReplicatedStorage.Shared.Config.Tags)

local LobbyBootstrap = {}

local FOLDER_NAME = "GorynychLobby"

local function part(props: {
	Name: string,
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3,
	Material: Enum.Material?,
	Anchored: boolean?,
	CanCollide: boolean?,
	Transparency: number?,
	Parent: Instance,
}): Part
	local p = Instance.new("Part")
	p.Name = props.Name
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color
	p.Material = props.Material or Enum.Material.Slate
	p.Anchored = if props.Anchored == nil then true else props.Anchored
	p.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	p.Transparency = props.Transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = props.Parent
	return p
end

local function makePad(
	parent: Instance,
	padId: string,
	displayName: string,
	capacity: number,
	position: Vector3,
	color: Color3
): BasePart
	local pad = part({
		Name = padId,
		Size = Vector3.new(14, 1, 14),
		CFrame = CFrame.new(position),
		Color = color,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	pad.Transparency = 0.25
	pad:SetAttribute("PadId", padId)
	pad:SetAttribute("PartySize", capacity)
	pad:SetAttribute("DisplayName", displayName)
	CollectionService:AddTag(pad, Tags.TeleportPad)

	local label = Instance.new("BillboardGui")
	label.Name = "PadLabel"
	label.Size = UDim2.fromScale(8, 2)
	label.StudsOffset = Vector3.new(0, 4, 0)
	label.AlwaysOnTop = true
	label.Parent = pad

	local text = Instance.new("TextLabel")
	text.Name = "Title"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 28
	text.TextColor3 = Color3.fromRGB(245, 240, 230)
	text.Text = string.format("%s  0 / %d", displayName, capacity)
	text.Parent = label

	return pad
end

function LobbyBootstrap.build(): Folder
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = FOLDER_NAME
	root.Parent = Workspace

	local baseZ = LobbyConfig.LobbySpawnOffset.Z
	part({
		Name = "LobbyFloor",
		Size = Vector3.new(80, 2, 50),
		CFrame = CFrame.new(0, 0, baseZ),
		Color = Color3.fromRGB(36, 28, 24),
		Material = Enum.Material.Rock,
		Parent = root,
	})

	part({
		Name = "LobbySpawn",
		Size = Vector3.new(8, 1, 8),
		CFrame = CFrame.new(LobbyConfig.LobbySpawnOffset.X, 1, baseZ + 16),
		Color = Color3.fromRGB(80, 60, 40),
		Parent = root,
	})

	makePad(root, "Solo", "SOLO", LobbyConfig.Pads.Solo, Vector3.new(-24, 1.5, baseZ - 6), Color3.fromRGB(80, 160, 100))
	makePad(root, "Duo", "DUO", LobbyConfig.Pads.Duo, Vector3.new(0, 1.5, baseZ - 6), Color3.fromRGB(232, 160, 50))
	makePad(root, "Squad", "SQUAD", LobbyConfig.Pads.Squad, Vector3.new(24, 1.5, baseZ - 6), Color3.fromRGB(232, 120, 48))

	return root
end

function LobbyBootstrap.getSpawnCFrame(): CFrame
	local lobby = Workspace:FindFirstChild(FOLDER_NAME)
	if lobby then
		local spawn = lobby:FindFirstChild("LobbySpawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 4, 0)
		end
	end
	return CFrame.new(LobbyConfig.LobbySpawnOffset)
end

function LobbyBootstrap.destroy()
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end
end

return LobbyBootstrap
