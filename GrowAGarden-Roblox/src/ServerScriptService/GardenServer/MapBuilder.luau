-- MapBuilder: cria o mapa inteiro (chao, rua, 6 jardins, lojas, decoracao).
-- Tudo e gerado por codigo, entao o jogo funciona mesmo em um lugar vazio.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

-- Medidas de cada jardim (coordenadas locais do jardim; -Z aponta para a rua)
MapBuilder.Layout = {
	plotHalfX = 28,
	plotHalfZ = 34,
	bedInner = 3, -- distancia do centro ate o inicio de cada canteiro
	bedOuter = 25, -- distancia do centro ate o fim de cada canteiro
	bedZMin = -26,
	bedZMax = 30,
	bedTop = 0.25, -- altura da terra
	columns = { -80, 0, 80 },
	rowZ = 56,
}

local SMOOTH = Enum.SurfaceType.Smooth
local WOOD = Color3.fromRGB(150, 105, 65)
local WOOD_LIGHT = Color3.fromRGB(205, 160, 105)
local WHITE = Color3.fromRGB(255, 255, 255)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	p.Material = material or Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = parent
	return p
end

local BLACK = Color3.fromRGB(20, 20, 20)

-- Cilindro em pe
local function cylinderPart(parent: Instance, name: string, height: number, diameter: number, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = cf * CFrame.Angles(0, 0, math.pi / 2)
	p.Parent = parent
	return p
end

local function ball(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = part(parent, name, size, cf, color)
	p.CanCollide = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function surfaceText(target: BasePart, text: string, textColor: Color3, face: Enum.NormalId?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = textColor
	label.TextStrokeTransparency = 0.6
	label.Text = text
	label.Parent = gui
	gui.Parent = target
	return label
end

local function billboard(adornee: BasePart, text: string, color: Color3, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 50)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.MaxDistance = 120
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	gui.Parent = adornee
end

---------------------------------------------------------------------
-- Jardins
---------------------------------------------------------------------

local function buildPlot(index: number, center: Vector3, rotation: number, parent: Instance)
	local L = MapBuilder.Layout
	local cf = CFrame.new(center) * CFrame.Angles(0, rotation, 0)
	local model = Instance.new("Model")
	model.Name = "Jardim" .. index
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerUserId", 0)

	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end

	part(model, "Base", Vector3.new(L.plotHalfX * 2, 0.2, L.plotHalfZ * 2), at(0, 0, 0), Color3.fromRGB(110, 185, 80), Enum.Material.Grass)
	local bedWidth = L.bedOuter - L.bedInner
	local bedLength = L.bedZMax - L.bedZMin
	local bedCenterZ = (L.bedZMax + L.bedZMin) / 2
	for _, side in { -1, 1 } do
		local bed = part(model, "Canteiro", Vector3.new(bedWidth, 0.5, bedLength), at(side * (L.bedInner + bedWidth / 2), 0, bedCenterZ), Color3.fromRGB(125, 82, 50), Enum.Material.Ground)
		bed:SetAttribute("Canteiro", true)
	end
	part(model, "Caminho", Vector3.new(L.bedInner * 2, 0.3, L.plotHalfZ * 2 - 1), at(0, 0, 0), Color3.fromRGB(215, 190, 140), Enum.Material.Sand)

	-- cerca
	-- skipStart/skipEnd evitam dois postes no mesmo canto
	local function fence(x1: number, z1: number, x2: number, z2: number, skipStart: boolean?, skipEnd: boolean?)
		local a = Vector3.new(x1, 0, z1)
		local b = Vector3.new(x2, 0, z2)
		local length = (b - a).Magnitude
		local mid = (a + b) / 2
		for _, y in { 1.1, 2.2 } do
			part(model, "Cerca", Vector3.new(0.35, 0.35, length), cf * CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(b.X, y, b.Z)), WOOD, Enum.Material.Wood)
		end
		local posts = math.max(1, math.floor(length / 6))
		for i = 0, posts do
			if not ((i == 0 and skipStart) or (i == posts and skipEnd)) then
				local p = a:Lerp(b, i / posts)
				part(model, "Poste", Vector3.new(0.6, 3, 0.6), at(p.X, 1.5, p.Z), WOOD, Enum.Material.Wood)
			end
		end
	end
	local hx, hz = L.plotHalfX, L.plotHalfZ
	fence(-hx, -hz, -hx, hz)
	fence(hx, -hz, hx, hz)
	fence(-hx, hz, hx, hz, true, true)
	fence(-hx, -hz, -5, -hz, true, false)
	fence(5, -hz, hx, -hz, false, true)

	-- placa com o nome do dono
	part(model, "PostePlaca", Vector3.new(0.5, 4, 0.5), at(-14, 2, -hz - 2), WOOD, Enum.Material.Wood)
	local board = part(model, "Placa", Vector3.new(10, 3, 0.4), at(-14, 4.8, -hz - 2), WOOD_LIGHT, Enum.Material.Wood)
	local signLabel = surfaceText(board, "Jardim Livre", Color3.fromRGB(70, 45, 20))
	signLabel.TextStrokeTransparency = 1

	local plantsFolder = Instance.new("Folder")
	plantsFolder.Name = "Plantas"
	plantsFolder.Parent = model
	model.Parent = parent

	return {
		index = index,
		model = model,
		cframe = cf,
		plantsFolder = plantsFolder,
		signLabel = signLabel,
		spawnCFrame = cf * CFrame.new(0, 3, -hz + 3) * CFrame.Angles(0, math.pi, 0),
		owner = nil :: Player?,
	}
end

---------------------------------------------------------------------
-- Lojas
---------------------------------------------------------------------

-- NPC com avatar no estilo Roblox (cabeca, tronco, bracos, pernas, cabelo, chapeu, roupa)
local function buildNpc(parent: Instance, cf: CFrame, look, name: string, role: string)
	local npc = Instance.new("Model")
	npc.Name = "NPC_" .. name
	local pieces = {}
	local function add(piece: BasePart)
		piece.CanCollide = false
		table.insert(pieces, piece)
		return piece
	end
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	local skin = look.skin
	-- pernas e sapatos
	for _, x in { -0.5, 0.5 } do
		add(part(npc, if x < 0 then "PernaEsquerda" else "PernaDireita", Vector3.new(1, 2, 1), at(x, 1, 0), look.pants))
		add(part(npc, "Sapato", Vector3.new(1.05, 0.35, 1.15), at(x, 0.18, -0.05), look.shoes))
	end
	add(part(npc, "Tronco", Vector3.new(2, 2, 1), at(0, 3, 0), look.shirt))
	add(part(npc, "BracoEsquerdo", Vector3.new(1, 2, 1), at(-1.5, 3, 0), look.sleeves or look.shirt))
	add(part(npc, "BracoDireito", Vector3.new(1, 2, 1), at(1.5, 3, 0), look.sleeves or look.shirt))
	for _, x in { -1.5, 1.5 } do
		add(part(npc, "Mao", Vector3.new(0.95, 0.45, 0.95), at(x, 1.85, 0), skin))
	end
	local head = add(part(npc, "Cabeca", Vector3.new(2, 1, 1), at(0, 4.5, 0), skin))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	-- rosto
	for _, x in { -0.25, 0.25 } do
		add(ball(npc, "Olho", Vector3.new(0.2, 0.28, 0.08), at(x, 4.62, -0.6), BLACK))
		add(ball(npc, "Brilho", Vector3.new(0.07, 0.08, 0.04), at(x + 0.04, 4.68, -0.64), WHITE))
		add(part(npc, "Sobrancelha", Vector3.new(0.28, 0.06, 0.04), at(x, 4.86, -0.61), look.hair))
	end
	add(part(npc, "Sorriso", Vector3.new(0.36, 0.07, 0.04), at(0, 4.27, -0.62), BLACK))
	for _, x in { -0.2, 0.2 } do
		add(part(npc, "Sorriso", Vector3.new(0.1, 0.07, 0.04), at(x, 4.31, -0.62), BLACK))
		add(ball(npc, "Bochecha", Vector3.new(0.2, 0.12, 0.04), at(x * 2.1, 4.4, -0.58), Color3.fromRGB(255, 160, 160)))
	end
	-- cabelo
	if look.hairStyle ~= "bald" then
		add(part(npc, "Cabelo", Vector3.new(1.32, 0.35, 1.3), at(0, 5.12, 0.02), look.hair))
		add(part(npc, "Cabelo", Vector3.new(1.32, 0.9, 0.3), at(0, 4.72, 0.52), look.hair))
		if look.hairStyle == "long" then
			add(part(npc, "Cabelo", Vector3.new(1.45, 1.9, 0.35), at(0, 4.05, 0.58), look.hair))
			for _, x in { -0.68, 0.68 } do
				add(part(npc, "Cabelo", Vector3.new(0.18, 1.4, 0.9), at(x, 4.35, 0.12), look.hair))
			end
		end
	end
	if look.beard then
		add(ball(npc, "Barba", Vector3.new(1.05, 0.65, 0.5), at(0, 4.1, -0.42), look.beard))
		add(part(npc, "Bigode", Vector3.new(0.6, 0.12, 0.1), at(0, 4.36, -0.64), look.beard))
	end
	if look.glasses then
		for _, x in { -0.25, 0.25 } do
			local lens = add(ball(npc, "Lente", Vector3.new(0.38, 0.32, 0.05), at(x, 4.62, -0.66), Color3.fromRGB(40, 40, 50)))
			lens.Transparency = 0.45
		end
		add(part(npc, "Armacao", Vector3.new(0.22, 0.05, 0.05), at(0, 4.64, -0.67), BLACK))
	end
	-- chapeu
	if look.hat == "straw" then
		add(cylinderPart(npc, "Chapeu", 0.12, 2.7, at(0, 5.28, 0), look.hatColor))
		add(cylinderPart(npc, "Chapeu", 0.6, 1.4, at(0, 5.6, 0), look.hatColor))
		add(cylinderPart(npc, "Fita", 0.16, 1.43, at(0, 5.38, 0), Color3.fromRGB(200, 60, 50)))
	elseif look.hat == "hardhat" then
		add(ball(npc, "Capacete", Vector3.new(1.5, 0.8, 1.5), at(0, 5.18, 0), look.hatColor))
		add(cylinderPart(npc, "Aba", 0.08, 1.75, at(0, 4.98, 0), look.hatColor))
	elseif look.hat == "cap" then
		add(ball(npc, "Bone", Vector3.new(1.38, 0.62, 1.38), at(0, 5.15, 0), look.hatColor))
		add(part(npc, "Aba", Vector3.new(1, 0.08, 0.65), at(0, 5, -0.78), look.hatColor))
	elseif look.hat == "bow" then
		for _, x in { -0.32, 0.32 } do
			add(ball(npc, "Laco", Vector3.new(0.5, 0.42, 0.2), at(x, 5.32, 0.35), look.hatColor))
		end
		add(ball(npc, "Laco", Vector3.new(0.22, 0.22, 0.22), at(0, 5.32, 0.35), look.hatColor))
	end
	-- roupa por cima
	if look.outfit == "overalls" then
		add(part(npc, "Macacao", Vector3.new(1.5, 1.0, 0.12), at(0, 2.7, -0.52), look.outfitColor))
		for _, x in { -0.55, 0.55 } do
			add(part(npc, "Alca", Vector3.new(0.22, 1.1, 0.1), at(x, 3.45, -0.53), look.outfitColor))
			add(ball(npc, "Botao", Vector3.new(0.12, 0.12, 0.05), at(x, 3.05, -0.6), Color3.fromRGB(240, 200, 60)))
		end
	elseif look.outfit == "apron" then
		add(part(npc, "Avental", Vector3.new(1.6, 2.1, 0.1), at(0, 2.55, -0.55), look.outfitColor))
		add(part(npc, "Bolso", Vector3.new(0.8, 0.4, 0.06), at(0, 2.2, -0.62), look.outfitColor:Lerp(Color3.new(0, 0, 0), 0.15)))
	elseif look.outfit == "vest" then
		for _, x in { -0.6, 0.6 } do
			add(part(npc, "Colete", Vector3.new(0.75, 2, 0.1), at(x, 3, -0.53), look.outfitColor))
			add(part(npc, "Faixa", Vector3.new(0.75, 0.12, 0.06), at(x, 2.6, -0.6), Color3.fromRGB(230, 230, 230)))
		end
		add(part(npc, "Cinto", Vector3.new(2.05, 0.25, 1.05), at(0, 2.1, 0), Color3.fromRGB(90, 60, 40)))
	elseif look.outfit == "dress" then
		add(part(npc, "Vestido", Vector3.new(2.3, 1.7, 1.3), at(0, 1.45, 0), look.outfitColor))
	end
	for _, piece in pieces do
		piece.CastShadow = true
	end
	npc.PrimaryPart = head
	npc:SetAttribute("Npc", name)
	CollectionService:AddTag(npc, "LojaNpc")
	npc.Parent = parent
	billboard(head, name .. "\n" .. role, WHITE, 3)
	return npc
end

local function buildStall(parent: Instance, info)
	local cf = CFrame.new(info.position) * CFrame.Angles(0, info.rotation, 0)
	local model = Instance.new("Model")
	model.Name = "Loja_" .. info.id

	local counter = part(model, "Balcao", Vector3.new(14, 3, 3), cf * CFrame.new(0, 1.5, -3), WOOD, Enum.Material.WoodPlanks)
	part(model, "Tampo", Vector3.new(14.6, 0.4, 3.6), cf * CFrame.new(0, 3.2, -3), WOOD_LIGHT, Enum.Material.Wood)
	for _, x in { -7, 7 } do
		for _, z in { -4.5, 4.5 } do
			part(model, "Pilar", Vector3.new(0.7, 8.5, 0.7), cf * CFrame.new(x, 4.25, z), WOOD, Enum.Material.Wood)
		end
	end
	part(model, "Fundo", Vector3.new(14, 8, 0.5), cf * CFrame.new(0, 4, 4.5), WOOD_LIGHT, Enum.Material.WoodPlanks)
	for i = 0, 7 do
		local color = if i % 2 == 0 then info.roofA else info.roofB
		part(model, "Telhado", Vector3.new(1.9, 0.4, 11), cf * CFrame.new(-6.65 + i * 1.9, 8.8, 0) * CFrame.Angles(math.rad(-8), 0, 0), color)
	end
	local sign = part(model, "Placa", Vector3.new(12, 2.4, 0.4), cf * CFrame.new(0, 10.4, -4.8), WHITE)
	surfaceText(sign, info.title, info.roofA)

	-- produtos decorativos no balcao
	for i = 1, 5 do
		local color = info.goods[(i - 1) % #info.goods + 1]
		ball(model, "Produto", Vector3.new(1, 1, 1), cf * CFrame.new(-5 + i * 1.7, 3.9, -3), color)
	end

	buildNpc(model, cf * CFrame.new(0, 0, 0.8), info.look, info.npc, info.title)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "AbrirLoja"
	prompt.ActionText = info.action
	prompt.ObjectText = info.title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("Shop", info.id)
	prompt.Parent = counter

	model.Parent = parent
	return cf * CFrame.new(0, 3, -9) * CFrame.Angles(0, math.pi, 0)
end

---------------------------------------------------------------------
-- Decoracao
---------------------------------------------------------------------

local function buildTree(parent: Instance, position: Vector3, scale: number)
	local trunk = part(parent, "Tronco", Vector3.new(1.2, 6, 1.2) * scale, CFrame.new(position + Vector3.new(0, 3 * scale, 0)), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	trunk.CastShadow = true
	ball(parent, "Copa", Vector3.new(7, 6, 7) * scale, CFrame.new(position + Vector3.new(0, 7.5 * scale, 0)), Color3.fromRGB(60, 150, 55))
	ball(parent, "Copa", Vector3.new(4.5, 4, 4.5) * scale, CFrame.new(position + Vector3.new(1.8, 9.5, 0.5) * scale), Color3.fromRGB(75, 165, 60))
end

local function buildLamp(parent: Instance, position: Vector3)
	part(parent, "PosteLuz", Vector3.new(0.5, 9, 0.5), CFrame.new(position + Vector3.new(0, 4.5, 0)), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	local lamp = ball(parent, "Lampada", Vector3.new(1.4, 1.4, 1.4), CFrame.new(position + Vector3.new(0, 9.4, 0)), Color3.fromRGB(255, 235, 170))
	lamp.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.5
	light.Color = Color3.fromRGB(255, 220, 160)
	light.Parent = lamp
	return light
end

local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(90, 90, 90)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 140)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.3
		atmosphere.Haze = 1
		atmosphere.Color = Color3.fromRGB(200, 220, 255)
		atmosphere.Parent = Lighting
	end
end

---------------------------------------------------------------------
-- Construcao completa
---------------------------------------------------------------------

function MapBuilder.build()
	local old = workspace:FindFirstChild("Mapa")
	if old then
		old:Destroy()
	end
	local map = Instance.new("Folder")
	map.Name = "Mapa"

	setupLighting()

	part(map, "Chao", Vector3.new(420, 2, 320), CFrame.new(0, -1, 0), Color3.fromRGB(95, 170, 70), Enum.Material.Grass)
	part(map, "Rua", Vector3.new(360, 0.2, 40), CFrame.new(0, 0, 0), Color3.fromRGB(220, 200, 150), Enum.Material.Sand)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(0, 0.2, 0)
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = SMOOTH
	spawn.Parent = map

	local welcome = part(map, "Boas-vindas", Vector3.new(26, 5, 0.6), CFrame.new(0, 14, 0), Color3.fromRGB(255, 250, 235))
	welcome.CanCollide = false
	surfaceText(welcome, "🌱 Cultive um Jardim 🌱", Color3.fromRGB(70, 150, 50), Enum.NormalId.Front)
	surfaceText(welcome, "🌱 Cultive um Jardim 🌱", Color3.fromRGB(70, 150, 50), Enum.NormalId.Back)

	-- jardins: 3 de cada lado da rua
	local L = MapBuilder.Layout
	local plots = {}
	for row = 1, 2 do
		local z = if row == 1 then L.rowZ else -L.rowZ
		local rotation = if row == 1 then 0 else math.pi
		for _, x in L.columns do
			table.insert(plots, buildPlot(#plots + 1, Vector3.new(x, 0, z), rotation, map))
		end
	end

	-- lojas entre os jardins
	local stalls = {
		{
			id = "Seeds", title = "Sementes", npc = "Sam", action = "Comprar sementes",
			position = Vector3.new(-40, 0, 30), rotation = 0,
			roofA = Color3.fromRGB(70, 160, 60), roofB = Color3.fromRGB(240, 240, 230),
			goods = { Color3.fromRGB(255, 140, 30), Color3.fromRGB(225, 30, 55), Color3.fromRGB(60, 80, 210) },
			look = {
				skin = Color3.fromRGB(255, 205, 160), hair = Color3.fromRGB(110, 70, 40), hairStyle = "short",
				hat = "straw", hatColor = Color3.fromRGB(235, 205, 120),
				shirt = Color3.fromRGB(90, 170, 70), pants = Color3.fromRGB(60, 90, 150), shoes = Color3.fromRGB(90, 60, 40),
				outfit = "overalls", outfitColor = Color3.fromRGB(60, 90, 150),
			},
		},
		{
			id = "Sell", title = "Venda", npc = "Steven", action = "Vender frutos",
			position = Vector3.new(40, 0, 30), rotation = 0,
			roofA = Color3.fromRGB(230, 170, 30), roofB = Color3.fromRGB(240, 240, 230),
			goods = { Color3.fromRGB(255, 205, 40), Color3.fromRGB(255, 230, 120) },
			look = {
				skin = Color3.fromRGB(240, 190, 150), hair = Color3.fromRGB(240, 210, 110), hairStyle = "short",
				hat = "cap", hatColor = Color3.fromRGB(230, 170, 30), glasses = true,
				shirt = Color3.fromRGB(70, 130, 210), pants = Color3.fromRGB(90, 90, 100), shoes = Color3.fromRGB(40, 40, 45),
				outfit = "apron", outfitColor = Color3.fromRGB(245, 205, 70),
			},
		},
		{
			id = "Gear", title = "Equipamentos", npc = "George", action = "Comprar equipamentos",
			position = Vector3.new(-40, 0, -30), rotation = math.pi,
			roofA = Color3.fromRGB(60, 120, 210), roofB = Color3.fromRGB(240, 240, 230),
			goods = { Color3.fromRGB(80, 140, 230), Color3.fromRGB(170, 170, 180) },
			look = {
				skin = Color3.fromRGB(230, 180, 140), hair = Color3.fromRGB(150, 150, 150), hairStyle = "short",
				hat = "hardhat", hatColor = Color3.fromRGB(250, 200, 40), beard = Color3.fromRGB(170, 170, 170),
				shirt = Color3.fromRGB(110, 110, 120), pants = Color3.fromRGB(50, 50, 60), shoes = Color3.fromRGB(70, 50, 35),
				outfit = "vest", outfitColor = Color3.fromRGB(250, 130, 40),
			},
		},
		{
			id = "Eggs", title = "Ovos & Pets", npc = "Eloise", action = "Comprar ovos",
			position = Vector3.new(40, 0, -30), rotation = math.pi,
			roofA = Color3.fromRGB(200, 90, 200), roofB = Color3.fromRGB(240, 240, 230),
			goods = { Color3.fromRGB(240, 235, 220), Color3.fromRGB(150, 230, 140), Color3.fromRGB(120, 170, 255) },
			look = {
				skin = Color3.fromRGB(255, 215, 185), hair = Color3.fromRGB(250, 140, 190), hairStyle = "long",
				hat = "bow", hatColor = Color3.fromRGB(255, 255, 255),
				shirt = Color3.fromRGB(250, 240, 250), sleeves = Color3.fromRGB(170, 90, 210), pants = Color3.fromRGB(170, 90, 210), shoes = Color3.fromRGB(250, 250, 250),
				outfit = "dress", outfitColor = Color3.fromRGB(170, 90, 210),
			},
		},
	}
	local locations = {}
	local shopPositions = {}
	for _, info in stalls do
		locations[info.id] = buildStall(map, info)
		shopPositions[info.id] = info.position
	end
	locations.Spawn = CFrame.new(0, 3, 0)

	-- decoracao
	local decor = Instance.new("Folder")
	decor.Name = "Decoracao"
	decor.Parent = map
	-- postes entre as entradas dos jardins (x = -140, -100, ..., 140)
	local lights = {}
	for x = -140, 140, 40 do
		for _, z in { -19, 19 } do
			table.insert(lights, buildLamp(decor, Vector3.new(x, 0, z)))
		end
	end
	for x = -180, 180, 30 do
		buildTree(decor, Vector3.new(x + (x % 20), 0, 115 + (x % 3) * 4), 1 + (x % 7) / 10)
		buildTree(decor, Vector3.new(x - (x % 20), 0, -115 - (x % 3) * 4), 1 + (x % 5) / 10)
	end
	for _, x in { -150, -130, 130, 150 } do
		for _, z in { -60, -30, 30, 60 } do
			buildTree(decor, Vector3.new(x, 0, z), 1.1)
		end
	end

	-- paredes invisiveis nas bordas
	local walls = {
		{ Vector3.new(420, 60, 2), Vector3.new(0, 30, 160) },
		{ Vector3.new(420, 60, 2), Vector3.new(0, 30, -160) },
		{ Vector3.new(2, 60, 320), Vector3.new(210, 30, 0) },
		{ Vector3.new(2, 60, 320), Vector3.new(-210, 30, 0) },
	}
	for _, wall in walls do
		local p = part(map, "Parede", wall[1], CFrame.new(wall[2]), WHITE)
		p.Transparency = 1
		p.CastShadow = false
	end

	map.Parent = workspace

	return {
		folder = map,
		plots = plots,
		locations = locations,
		shopPositions = shopPositions,
		lights = lights,
	}
end

return MapBuilder
