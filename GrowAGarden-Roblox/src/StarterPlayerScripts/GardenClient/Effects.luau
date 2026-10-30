-- Effects: efeitos visuais so do cliente.
--  * frutos e pets Arco-iris trocando de cor
--  * chuva, neve, areia, chocolate, raios
--  * luas, aurora, arco-iris e eclipse no ceu
--  * botoes "Colher" (seu jardim) e "Roubar" (jardins alheios, a noite)
--  * pets seguindo os jogadores
--  * NPCs das lojas animados e falando
--  * dica ao passar o mouse nas plantas

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))

local Effects = {}

local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne

local function localPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, sphere: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.Size = size
	part.CFrame = cf
	if sphere then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Parent = parent
	return part
end

---------------------------------------------------------------------
-- Arco-iris
---------------------------------------------------------------------

local function startRainbow()
	RunService.Heartbeat:Connect(function()
		local hue = (os.clock() * 0.25) % 1
		for index, part in CollectionService:GetTagged("RainbowFruit") do
			if part:IsA("BasePart") then
				part.Color = Color3.fromHSV((hue + index * 0.07) % 1, 0.75, 1)
			end
		end
	end)
end

---------------------------------------------------------------------
-- Clima: particulas e objetos no ceu
---------------------------------------------------------------------

local function emitter(parent: Instance, name: string, props: { [string]: any }): ParticleEmitter
	local particles = Instance.new("ParticleEmitter")
	particles.Name = name
	particles.Enabled = false
	for key, value in props do
		(particles :: any)[key] = value
	end
	particles.Parent = parent
	return particles
end

local SKY_POSITION = Vector3.new(160, 230, 320)

local function buildSkyObject(kind: string, folder: Folder)
	if kind == "bloodmoon" or kind == "goldmoon" or kind == "rainbowmoon" or kind == "megamoon" then
		local colors = {
			bloodmoon = Color3.fromRGB(220, 40, 40),
			goldmoon = Color3.fromRGB(255, 210, 80),
			rainbowmoon = Color3.fromRGB(255, 150, 255),
			megamoon = Color3.fromRGB(240, 240, 255),
		}
		local size = if kind == "megamoon" then 150 else 70
		local moon = localPart(folder, "Lua", Vector3.new(size, size, size), CFrame.new(SKY_POSITION), colors[kind], true)
		moon.Material = Enum.Material.Neon
		if kind == "rainbowmoon" then
			CollectionService:AddTag(moon, "RainbowFruit")
		end
	elseif kind == "eclipse" then
		local glow = localPart(folder, "Coroa", Vector3.new(1, 100, 100), CFrame.new(SKY_POSITION + Vector3.new(0, 0, 4)) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(255, 160, 60), false)
		glow.Shape = Enum.PartType.Cylinder
		glow.Material = Enum.Material.Neon
		glow.Transparency = 0.2
		localPart(folder, "Sol", Vector3.new(80, 80, 80), CFrame.new(SKY_POSITION), Color3.fromRGB(10, 10, 15), true)
	elseif kind == "aurora" then
		for i = 1, 6 do
			local band = localPart(folder, "Aurora", Vector3.new(160, 30, 2), CFrame.new(-200 + i * 60, 170 + (i % 2) * 12, 260 - i * 10) * CFrame.Angles(0, math.rad(15 * i), math.rad(8)), if i % 2 == 0 then Color3.fromRGB(90, 255, 170) else Color3.fromRGB(160, 110, 255), false)
			band.Material = Enum.Material.Neon
			band.Transparency = 0.6
			CollectionService:AddTag(band, "AuroraBand")
		end
	elseif kind == "rainbow" then
		local colors = { Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 160, 50), Color3.fromRGB(255, 230, 60), Color3.fromRGB(90, 220, 90), Color3.fromRGB(70, 150, 255), Color3.fromRGB(170, 90, 255) }
		for band, color in colors do
			local radius = 220 - band * 9
			for step = 0, 18 do
				local angle = math.pi * step / 18
				local position = Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius - 20, 330)
				local piece = localPart(folder, "ArcoIris", Vector3.new(9, 40, 2), CFrame.new(position) * CFrame.Angles(0, 0, angle), color, false)
				piece.Material = Enum.Material.Neon
				piece.Transparency = 0.35
			end
		end
	end
end

local function startWeather()
	local holder = localPart(workspace, "ClimaLocal", Vector3.new(120, 1, 120), CFrame.new(0, 100, 0), Color3.new(1, 1, 1), false)
	holder.Transparency = 1
	local skyFolder = Instance.new("Folder")
	skyFolder.Name = "CeuLocal"
	skyFolder.Parent = workspace

	local particles = {
		rain = emitter(holder, "Chuva", {
			Rate = 500, Lifetime = NumberRange.new(1, 1.3), Speed = NumberRange.new(60, 70),
			EmissionDirection = Enum.NormalId.Bottom, Orientation = Enum.ParticleOrientation.VelocityParallel,
			Size = NumberSequence.new(0.18), Squash = NumberSequence.new(2.5), Transparency = NumberSequence.new(0.25),
			Color = ColorSequence.new(Color3.fromRGB(175, 205, 255)), LightEmission = 0.3,
		}),
		snow = emitter(holder, "Neve", {
			Rate = 160, Lifetime = NumberRange.new(6, 8), Speed = NumberRange.new(5, 9),
			EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(1, -1, 0),
			Size = NumberSequence.new(0.35), Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)), LightEmission = 0.5,
			RotSpeed = NumberRange.new(-90, 90),
		}),
		heavysnow = emitter(holder, "Nevasca", {
			Rate = 450, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(10, 16),
			EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(35, 35), Acceleration = Vector3.new(6, -2, 0),
			Size = NumberSequence.new(0.45), Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)), LightEmission = 0.5,
		}),
		sand = emitter(holder, "Areia", {
			Rate = 350, Lifetime = NumberRange.new(3, 4), Speed = NumberRange.new(20, 30),
			EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(25, -5, 0),
			Size = NumberSequence.new(0.3), Color = ColorSequence.new(Color3.fromRGB(230, 200, 140)), Transparency = NumberSequence.new(0.3),
		}),
		chocolate = emitter(holder, "Chocolate", {
			Rate = 300, Lifetime = NumberRange.new(1.4, 1.8), Speed = NumberRange.new(45, 55),
			EmissionDirection = Enum.NormalId.Bottom, Orientation = Enum.ParticleOrientation.VelocityParallel,
			Size = NumberSequence.new(0.3), Squash = NumberSequence.new(1.5),
			Color = ColorSequence.new(Color3.fromRGB(110, 60, 30)),
		}),
	}

	local function apply()
		local weatherId = workspace:GetAttribute("Weather")
		local weather = if type(weatherId) == "string" then Config.Weather[weatherId] else nil
		for name, particle in particles do
			particle.Enabled = weather ~= nil and weather.particle == name
		end
		skyFolder:ClearAllChildren()
		if weather and weather.skyObject then
			buildSkyObject(weather.skyObject, skyFolder)
		end
	end
	workspace:GetAttributeChangedSignal("Weather"):Connect(apply)
	apply()

	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera then
			holder.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 35, 0))
		end
		local t = os.clock()
		for index, band in CollectionService:GetTagged("AuroraBand") do
			if band:IsA("BasePart") then
				band.Transparency = 0.55 + math.sin(t * 1.5 + index) * 0.2
			end
		end
	end)

	-- clarao quando cai um raio ou meteoro
	local flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "ClaraoLocal"
	flash.Brightness = 0
	flash.Parent = Lighting
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Raio" or child.Name == "Meteoro" then
			flash.Brightness = 0.45
			TweenService:Create(flash, TweenInfo.new(0.4), { Brightness = 0 }):Play()
		end
	end)
end

---------------------------------------------------------------------
-- Pets
---------------------------------------------------------------------

local PET_OFFSETS = {
	Vector3.new(-2.8, 0, 3),
	Vector3.new(2.8, 0, 3),
	Vector3.new(0, 0, 5),
}

-- Detalhes de cada bicho (orelhas, focinho, asas, rabo...)
local PET_LOOKS = {
	Frog = { eyes = "top", ears = "none", nose = "none", mouth = true, tail = "none" },
	Bunny = { ears = "long", tail = "puff", cheeks = true },
	Cat = { ears = "pointy", tail = "thin", cheeks = true, whiskers = true },
	Owl = { eyes = "big", ears = "tufts", nose = "beak", tail = "feather", wings = "folded", feet = "bird" },
	Dog = { ears = "floppy", nose = "muzzle", tail = "wag", cheeks = true },
	Chicken = { ears = "none", nose = "beak", comb = true, tail = "feather", wings = "folded", feet = "bird" },
	Deer = { ears = "small", antlers = true, tail = "puff", spots = true },
	Turtle = { ears = "none", shell = true, tail = "small" },
	Pig = { ears = "small", nose = "snout", tail = "curly", cheeks = true },
	Robin = { ears = "none", nose = "beak", tail = "feather", wings = "folded", chest = true, feet = "bird" },
	Bee = { ears = "none", nose = "none", stripes = true, antennae = true, wings = "insect", tail = "stinger", feet = "none" },
	Butterfly = { ears = "none", nose = "none", antennae = true, wings = "butterfly", tail = "none", slim = true, feet = "none" },
	Monkey = { ears = "side", face = true, tail = "curly", cheeks = true },
	Bear = { ears = "round", nose = "muzzle", tail = "puff" },
	Unicorn = { ears = "pointy", horn = true, mane = true, tail = "mane" },
	GoldenDragonfly = { ears = "none", nose = "none", eyes = "big", wings = "dragonfly", tail = "long", slim = true, feet = "none" },
	Firefly = { ears = "none", nose = "none", antennae = true, wings = "insect", glow = true, tail = "none", feet = "none" },
	BaldEagle = { ears = "none", nose = "beak", wings = "folded", tail = "feather", whiteHead = true, feet = "bird" },
	Dragon = { ears = "none", horns = true, spikes = true, wings = "bat", tail = "dragon" },
	Phoenix = { ears = "none", nose = "beak", crest = true, wings = "flame", tail = "flame", feet = "bird" },
	Raccoon = { ears = "pointy", mask = true, tail = "striped", cheeks = true },
	Kitsune = { ears = "pointy", tail = "kitsune", cheeks = true },
}

local function buildPet(info, variant, level: number): Model
	local model = Instance.new("Model")
	model.Name = info.name
	local s = info.size * variant.scale
	local look = PET_LOOKS[info.id] or {}
	local color, accent = info.color, info.accent
	local light = color:Lerp(Color3.new(1, 1, 1), 0.45)
	local dark = Color3.fromRGB(25, 25, 30)
	local white = Color3.new(1, 1, 1)
	local orange = Color3.fromRGB(255, 175, 40)
	local function add(name: string, size: Vector3, x: number, y: number, z: number, partColor: Color3, sphere: boolean, rotation: CFrame?): Part
		local cf = CFrame.new(x * s, y * s, z * s)
		if rotation then
			cf *= rotation
		end
		return localPart(model, name, size * s, cf, partColor, sphere)
	end
	local function neon(piece: Part): Part
		piece.Material = Enum.Material.Neon
		return piece
	end

	-- corpo e cabeca
	local body = add("Corpo", if look.slim then Vector3.new(0.7, 0.7, 1.5) else Vector3.new(1.4, 1.1, 1.6), 0, 0, 0, color, true)
	if not look.slim then
		add("Barriga", Vector3.new(1, 0.75, 1.1), 0, -0.2, -0.15, if look.chest then accent else light, true)
	end
	local head = add("Cabeca", Vector3.new(1.15, 1.1, 1.1), 0, 0.6, -0.85, if look.whiteHead then white else color, true)

	-- olhos (branco + pupila + brilho)
	local eyeScale = if look.eyes == "big" then 1.45 else 1
	local eyeY, eyeZ, eyeX = 0.72, -1.33, 0.24
	if look.eyes == "top" then
		eyeY, eyeZ, eyeX = 1.12, -1.0, 0.3
	end
	for _, side in { -1, 1 } do
		local x = side * eyeX
		if look.eyes == "big" and look.nose == "beak" then
			add("Aro", Vector3.new(0.5, 0.52, 0.08), x, eyeY, eyeZ + 0.04, accent, true)
		end
		add("Olho", Vector3.new(0.3, 0.34, 0.14) * eyeScale, x, eyeY, eyeZ, white, true)
		add("Pupila", Vector3.new(0.17, 0.22, 0.08) * eyeScale, x, eyeY - 0.02, eyeZ - 0.06 * eyeScale, dark, true)
		add("BrilhoOlho", Vector3.new(0.06, 0.07, 0.04) * eyeScale, x + 0.04, eyeY + 0.05, eyeZ - 0.1 * eyeScale, white, true)
		if look.cheeks then
			add("Bochecha", Vector3.new(0.2, 0.11, 0.06), side * 0.38, 0.5, -1.28, Color3.fromRGB(255, 150, 160), true)
		end
	end

	-- nariz, bico ou focinho
	if look.nose == "beak" then
		add("Bico", Vector3.new(0.26, 0.2, 0.44), 0, 0.52, -1.48, orange, true)
	elseif look.nose == "snout" then
		add("Focinho", Vector3.new(0.5, 0.38, 0.3), 0, 0.5, -1.42, light, true)
		for _, side in { -1, 1 } do
			add("Narina", Vector3.new(0.08, 0.12, 0.05), side * 0.1, 0.5, -1.57, dark, true)
		end
	elseif look.nose == "muzzle" then
		add("Focinho", Vector3.new(0.55, 0.4, 0.4), 0, 0.46, -1.36, light, true)
		add("Nariz", Vector3.new(0.22, 0.16, 0.12), 0, 0.55, -1.55, dark, true)
	elseif look.nose ~= "none" then
		add("Nariz", Vector3.new(0.2, 0.15, 0.1), 0, 0.53, -1.42, accent, true)
	end
	if look.mouth then
		add("Boca", Vector3.new(0.6, 0.05, 0.05), 0, 0.42, -1.38, dark, false)
	end
	if look.whiskers then
		for _, side in { -1, 1 } do
			for i = 0, 1 do
				add("Bigode", Vector3.new(0.4, 0.03, 0.03), side * 0.42, 0.5 - i * 0.08, -1.3, white, false, CFrame.Angles(0, 0, math.rad(side * (8 - i * 16))))
			end
		end
	end

	-- orelhas
	local ears = look.ears or "pointy"
	for _, side in { -1, 1 } do
		local tilt = CFrame.Angles(0, 0, math.rad(-side * 18))
		if ears == "long" then
			local lean = CFrame.Angles(0, 0, math.rad(-side * 8))
			add("Orelha", Vector3.new(0.24, 0.95, 0.16), side * 0.24, 1.45, -0.78, color, false, lean)
			add("OrelhaDentro", Vector3.new(0.12, 0.7, 0.04), side * 0.24, 1.45, -0.87, Color3.fromRGB(255, 170, 190), false, lean)
		elseif ears == "pointy" then
			add("Orelha", Vector3.new(0.34, 0.42, 0.14), side * 0.33, 1.15, -0.8, color, false, tilt)
			add("OrelhaDentro", Vector3.new(0.18, 0.26, 0.04), side * 0.33, 1.13, -0.88, accent, false, tilt)
		elseif ears == "round" then
			add("Orelha", Vector3.new(0.4, 0.4, 0.16), side * 0.44, 1.08, -0.82, color, true)
			add("OrelhaDentro", Vector3.new(0.22, 0.22, 0.06), side * 0.44, 1.08, -0.9, light, true)
		elseif ears == "side" then
			add("Orelha", Vector3.new(0.16, 0.42, 0.42), side * 0.6, 0.66, -0.85, light, true)
		elseif ears == "floppy" then
			add("Orelha", Vector3.new(0.3, 0.62, 0.18), side * 0.58, 0.62, -0.82, accent, true, CFrame.Angles(0, 0, math.rad(side * 18)))
		elseif ears == "small" then
			add("Orelha", Vector3.new(0.24, 0.3, 0.12), side * 0.36, 1.1, -0.78, color, false, CFrame.Angles(0, 0, math.rad(-side * 25)))
		elseif ears == "tufts" then
			add("Tufo", Vector3.new(0.18, 0.4, 0.12), side * 0.36, 1.2, -0.8, accent, false, CFrame.Angles(0, 0, math.rad(-side * 20)))
		end
	end

	-- enfeites de cada bicho
	if look.antlers then
		local antler = Color3.fromRGB(205, 165, 110)
		for _, side in { -1, 1 } do
			add("Galhada", Vector3.new(0.09, 0.62, 0.09), side * 0.3, 1.45, -0.8, antler, false, CFrame.Angles(0, 0, math.rad(-side * 22)))
			add("Galho", Vector3.new(0.07, 0.32, 0.07), side * 0.5, 1.55, -0.8, antler, false, CFrame.Angles(0, 0, math.rad(-side * 60)))
		end
	end
	if look.horn then
		neon(add("Chifre", Vector3.new(0.15, 0.7, 0.15), 0, 1.3, -1.05, Color3.fromRGB(255, 220, 90), false, CFrame.Angles(math.rad(-25), 0, 0)))
	end
	if look.horns then
		for _, side in { -1, 1 } do
			add("Chifre", Vector3.new(0.12, 0.42, 0.12), side * 0.25, 1.2, -0.66, Color3.fromRGB(245, 235, 210), false, CFrame.Angles(math.rad(30), 0, math.rad(-side * 12)))
		end
	end
	if look.mane then
		local rainbow = { Color3.fromRGB(255, 120, 180), Color3.fromRGB(170, 120, 255), Color3.fromRGB(110, 190, 255), Color3.fromRGB(255, 210, 90) }
		for i = 0, 3 do
			add("Crina", Vector3.new(0.3, 0.32, 0.36), 0, 1.08 - i * 0.22, -0.55 + i * 0.25, rainbow[i + 1], true)
		end
	end
	if look.comb then
		for i = -1, 1 do
			add("Crista", Vector3.new(0.16, 0.22, 0.16), 0, 1.2 + (if i == 0 then 0.06 else 0), -0.85 + i * 0.16, Color3.fromRGB(230, 40, 40), true)
		end
		add("Barbela", Vector3.new(0.14, 0.22, 0.12), 0, 0.36, -1.44, Color3.fromRGB(230, 40, 40), true)
	end
	if look.crest then
		for i = -1, 1 do
			neon(add("Pena", Vector3.new(0.1, 0.5, 0.14), i * 0.12, 1.3, -0.75, Color3.fromRGB(255, 200, 60), false, CFrame.Angles(math.rad(-20), 0, math.rad(i * 18))))
		end
	end
	if look.mask then
		add("Mascara", Vector3.new(1.02, 0.26, 0.12), 0, 0.72, -1.25, Color3.fromRGB(45, 45, 50), false)
	end
	if look.face then
		add("Rosto", Vector3.new(0.8, 0.7, 0.2), 0, 0.56, -1.28, light, true)
	end
	if look.shell then
		local shellColor = accent
		add("Casco", Vector3.new(1.6, 0.95, 1.8), 0, 0.28, 0.05, shellColor, true)
		add("BordaCasco", Vector3.new(1.72, 0.22, 1.92), 0, -0.02, 0.05, shellColor:Lerp(white, 0.25), true)
		for i = 0, 3 do
			local angle = i * math.pi / 2 + math.pi / 4
			add("Placa", Vector3.new(0.45, 0.2, 0.45), math.cos(angle) * 0.4, 0.68, 0.05 + math.sin(angle) * 0.42, shellColor:Lerp(dark, 0.25), true)
		end
	end
	if look.stripes then
		for _, z in { -0.15, 0.32 } do
			add("Listra", Vector3.new(1.44, 1.14, 0.24), 0, 0, z, dark, true)
		end
	end
	if look.spots then
		for i = 1, 4 do
			add("Pinta", Vector3.new(0.18, 0.08, 0.18), (i % 2 == 0 and 0.3 or -0.3), 0.5, -0.3 + i * 0.18, white, true)
		end
	end
	if look.spikes then
		for i = 0, 3 do
			add("Espinho", Vector3.new(0.26, 0.26, 0.26), 0, 0.62 - i * 0.04, -0.35 + i * 0.32, accent, false, CFrame.Angles(math.rad(45), 0, 0))
		end
	end
	if look.antennae then
		for _, side in { -1, 1 } do
			add("Antena", Vector3.new(0.05, 0.55, 0.05), side * 0.2, 1.3, -0.92, dark, false, CFrame.Angles(math.rad(-20), 0, math.rad(-side * 20)))
			add("PontaAntena", Vector3.new(0.13, 0.13, 0.13), side * 0.31, 1.55, -1.02, if look.glow then accent else dark, true)
		end
	end
	if look.glow then
		neon(add("Luz", Vector3.new(0.6, 0.6, 0.6), 0, 0, 0.9, accent, true))
	end

	-- asas
	local wings = look.wings
	for _, side in { -1, 1 } do
		if wings == "folded" then
			add("Asa", Vector3.new(0.25, 0.75, 1.15), side * 0.72, 0.1, 0.05, color:Lerp(dark, 0.18), true, CFrame.Angles(math.rad(10), 0, math.rad(side * 8)))
		elseif wings == "insect" then
			local wing = add("Asa", Vector3.new(0.9, 0.08, 0.55), side * 0.75, 0.62, 0, white, true, CFrame.Angles(0, 0, math.rad(side * 25)))
			wing.Transparency = 0.35
		elseif wings == "butterfly" then
			add("Asa", Vector3.new(1.3, 0.06, 1.0), side * 0.95, 0.35, -0.2, accent, true, CFrame.Angles(0, 0, math.rad(side * 30)))
			add("Asa", Vector3.new(0.9, 0.06, 0.8), side * 0.75, 0.12, 0.45, color, true, CFrame.Angles(0, 0, math.rad(side * 20)))
			add("Pinta", Vector3.new(0.3, 0.08, 0.3), side * 1.05, 0.44, -0.25, white, true, CFrame.Angles(0, 0, math.rad(side * 30)))
		elseif wings == "dragonfly" then
			for k = 0, 1 do
				local wing = add("Asa", Vector3.new(1.4, 0.04, 0.32), side * 0.85, 0.42, -0.25 + k * 0.4, Color3.fromRGB(230, 245, 255), true, CFrame.Angles(0, math.rad(side * (k == 0 and -8 or 8)), 0))
				wing.Transparency = 0.3
			end
		elseif wings == "bat" then
			add("Asa", Vector3.new(1.3, 0.08, 1.0), side * 1.0, 0.55, 0.1, accent, true, CFrame.Angles(0, 0, math.rad(side * 30)))
			add("Osso", Vector3.new(1.2, 0.1, 0.1), side * 1.0, 0.85, -0.25, color, false, CFrame.Angles(0, 0, math.rad(side * 30)))
		elseif wings == "flame" then
			neon(add("Asa", Vector3.new(1.2, 0.1, 0.8), side * 0.95, 0.4, 0.05, accent, true, CFrame.Angles(0, 0, math.rad(side * 25))))
			neon(add("PontaAsa", Vector3.new(0.6, 0.08, 0.45), side * 1.45, 0.62, 0.1, Color3.fromRGB(255, 230, 120), true, CFrame.Angles(0, 0, math.rad(side * 25))))
		end
	end

	-- rabo
	local tail = look.tail or "puff"
	if tail == "puff" then
		add("Rabo", Vector3.new(0.42, 0.42, 0.42), 0, 0.15, 0.85, light, true)
	elseif tail == "thin" then
		add("Rabo", Vector3.new(0.14, 0.75, 0.14), 0, 0.5, 0.95, color, false, CFrame.Angles(math.rad(-30), 0, 0))
		add("PontaRabo", Vector3.new(0.2, 0.2, 0.2), 0, 0.85, 1.12, accent, true)
	elseif tail == "wag" then
		add("Rabo", Vector3.new(0.22, 0.6, 0.22), 0, 0.42, 0.92, accent, true, CFrame.Angles(math.rad(-35), 0, 0))
	elseif tail == "curly" then
		for i = 0, 2 do
			local angle = i * 2
			add("Rabo", Vector3.new(0.16, 0.16, 0.16), math.cos(angle) * 0.12, 0.25 + math.sin(angle) * 0.12, 0.85 + i * 0.06, color:Lerp(dark, 0.1), true)
		end
	elseif tail == "feather" then
		add("Rabo", Vector3.new(0.6, 0.12, 0.65), 0, 0.22, 0.95, color:Lerp(dark, 0.2), true, CFrame.Angles(math.rad(20), 0, 0))
	elseif tail == "striped" then
		for i = 0, 3 do
			add("Rabo", Vector3.new(0.34, 0.34, 0.34), 0, 0.15 + i * 0.18, 0.85 + i * 0.12, if i % 2 == 0 then color else Color3.fromRGB(45, 45, 50), true)
		end
	elseif tail == "kitsune" then
		for i = -1, 1 do
			local turn = CFrame.Angles(math.rad(-40), math.rad(i * 30), 0)
			add("Rabo", Vector3.new(0.38, 0.38, 0.9), i * 0.32, 0.45, 1.05, color, true, turn)
			neon(add("PontaRabo", Vector3.new(0.3, 0.3, 0.3), i * 0.5, 0.82, 1.4, white, true))
		end
	elseif tail == "dragon" then
		for i = 0, 2 do
			local size = 0.42 - i * 0.1
			add("Rabo", Vector3.new(size, size, 0.6), 0, 0.05 - i * 0.05, 0.9 + i * 0.45, color, true)
		end
		add("PontaRabo", Vector3.new(0.4, 0.08, 0.34), 0, -0.08, 2.0, accent, false, CFrame.Angles(0, math.rad(45), 0))
	elseif tail == "flame" then
		local flames = { accent, Color3.fromRGB(255, 140, 40), Color3.fromRGB(255, 220, 90) }
		for i = 1, 3 do
			neon(add("Chama", Vector3.new(0.3, 0.2, 0.9), (i - 2) * 0.28, 0.2, 1.1, flames[i], true, CFrame.Angles(math.rad(-15), math.rad((i - 2) * 22), 0)))
		end
	elseif tail == "stinger" then
		add("Ferrao", Vector3.new(0.12, 0.12, 0.32), 0, 0, 0.9, dark, true)
	elseif tail == "long" then
		for i = 0, 2 do
			add("Rabo", Vector3.new(0.22, 0.22, 0.5), 0, 0, 0.9 + i * 0.42, color, true)
		end
	elseif tail == "mane" then
		add("Rabo", Vector3.new(0.34, 0.6, 0.34), 0, 0.2, 0.9, Color3.fromRGB(255, 120, 180), true, CFrame.Angles(math.rad(25), 0, 0))
		add("Rabo", Vector3.new(0.28, 0.5, 0.28), 0, -0.05, 1.05, Color3.fromRGB(110, 190, 255), true, CFrame.Angles(math.rad(35), 0, 0))
	elseif tail == "small" then
		add("Rabo", Vector3.new(0.2, 0.2, 0.25), 0, -0.1, 0.92, color, true)
	end

	-- patas
	local feet = look.feet or "paws"
	if feet == "paws" then
		for _, x in { -0.42, 0.42 } do
			for _, z in { -0.45, 0.45 } do
				add("Pata", Vector3.new(0.34, 0.34, 0.36), x, -0.5, z, color:Lerp(dark, 0.08), true)
			end
		end
	elseif feet == "bird" then
		for _, x in { -0.25, 0.25 } do
			add("Pe", Vector3.new(0.22, 0.12, 0.3), x, -0.55, -0.1, orange, true)
		end
	end

	if variant.id == "Rainbow" then
		CollectionService:AddTag(body, "RainbowFruit")
		CollectionService:AddTag(head, "RainbowFruit")
	end
	model.PrimaryPart = body
	model.WorldPivot = CFrame.new()

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 28)
	gui.StudsOffset = Vector3.new(0, 1.6 * s, 0)
	gui.MaxDistance = 50
	gui.Adornee = body
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = FONT
	label.TextScaled = true
	label.TextColor3 = Config.Rarities[info.rarity].color
	label.TextStrokeTransparency = 0.3
	label.Text = string.format("%s%s • Nv %d", info.name, if variant.name ~= "" then " " .. variant.name else "", level)
	label.Parent = gui
	gui.Parent = model
	return model
end

local function startPets()
	local folder = Instance.new("Folder")
	folder.Name = "PetsLocais"
	folder.Parent = workspace
	local followers: { [Player]: { key: string, models: { Model }, current: { CFrame } } } = {}

	local function rebuild(owner: Player)
		local old = followers[owner]
		if old then
			for _, model in old.models do
				model:Destroy()
			end
			followers[owner] = nil
		end
		local key = owner:GetAttribute("EquippedPets")
		if type(key) ~= "string" or key == "" then
			return
		end
		local entry = { key = key, models = {}, current = {} }
		for _, item in string.split(key, ",") do
			local parts = string.split(item, ":")
			local info = Config.Pets[parts[1]]
			if info and #entry.models < #PET_OFFSETS then
				local variant = Formulas.petVariant(if parts[2] and parts[2] ~= "" then parts[2] else nil)
				local model = buildPet(info, variant, tonumber(parts[3]) or 1)
				model.Parent = folder
				table.insert(entry.models, model)
			end
		end
		followers[owner] = entry
	end

	local function watch(owner: Player)
		owner:GetAttributeChangedSignal("EquippedPets"):Connect(function()
			rebuild(owner)
		end)
		rebuild(owner)
	end

	for _, owner in Players:GetPlayers() do
		watch(owner)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(owner)
		local entry = followers[owner]
		if entry then
			for _, model in entry.models do
				model:Destroy()
			end
			followers[owner] = nil
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for owner, entry in followers do
			local character = owner.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local rootCF = root.CFrame
				local flat = CFrame.lookAt(rootCF.Position, rootCF.Position + Vector3.new(rootCF.LookVector.X, 0, rootCF.LookVector.Z + 1e-4))
				for index, model in entry.models do
					local offset = PET_OFFSETS[index]
					local bob = math.sin(t * 5 + index) * 0.2
					local target = flat * CFrame.new(offset.X, -2.3 + bob, offset.Z)
					local current = entry.current[index] or target
					current = current:Lerp(target, math.min(1, dt * 7))
					entry.current[index] = current
					model:PivotTo(current)
				end
			end
		end
	end)
end

---------------------------------------------------------------------
-- Botoes "Colher" e "Roubar"
---------------------------------------------------------------------

local function plotOf(instance: Instance): Instance?
	local node = instance.Parent
	while node and node ~= workspace do
		if node:GetAttribute("PlotIndex") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function startPromptFilter()
	local prompts: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local watchedPlots: { [Instance]: boolean } = {}

	local function evaluate(prompt: ProximityPrompt)
		local owner = prompt:GetAttribute("OwnerUserId")
		if type(owner) ~= "number" or owner == 0 then
			return
		end
		if owner == player.UserId then
			prompt.Enabled = true
			if prompt:GetAttribute("Kind") == "Harvest" then
				prompt.ActionText = "Colher"
				prompt.HoldDuration = 0
			end
			return
		end
		local canSteal = prompt:GetAttribute("Kind") == "Harvest"
			and workspace:GetAttribute("StealingEnabled") == true
			and workspace:GetAttribute("Phase") == "Night"
			and player:GetAttribute("Carrying") ~= true
		local plot = plotOf(prompt)
		if plot and plot:GetAttribute("Locked") == true then
			canSteal = false
		end
		prompt.Enabled = canSteal
		if canSteal then
			prompt.ActionText = "Roubar"
			prompt.HoldDuration = Config.Stealing.holdDuration
		end
	end

	local function evaluateAll()
		for prompt in prompts do
			if prompt.Parent then
				evaluate(prompt)
			end
		end
	end

	local function track(instance: Instance)
		if instance:IsA("ProximityPrompt") and instance:GetAttribute("OwnerUserId") ~= nil then
			prompts[instance] = true
			local plot = plotOf(instance)
			if plot and not watchedPlots[plot] then
				watchedPlots[plot] = true
				plot:GetAttributeChangedSignal("Locked"):Connect(evaluateAll)
			end
			evaluate(instance)
		end
	end

	workspace.DescendantAdded:Connect(track)
	for _, descendant in workspace:GetDescendants() do
		track(descendant)
	end
	workspace:GetAttributeChangedSignal("Phase"):Connect(evaluateAll)
	player:GetAttributeChangedSignal("Carrying"):Connect(evaluateAll)
end

---------------------------------------------------------------------
-- NPCs das lojas
---------------------------------------------------------------------

local NPC_LINES = {
	Sam = { "Sementes fresquinhas!", "A loja reabastece a cada 5 minutos!", "Já viu a Semente Arco-íris?", "Plante e espere crescer!" },
	Steven = { "Compro qualquer fruto!", "Frutos mutados valem muito mais!", "Quanto mais pesado, melhor!", "Venda tudo aqui!" },
	George = { "Proteja seu jardim com um Gnomo!", "A Espátula faz fusões secretas...", "Sprinklers deixam os frutos maiores!", "Lanternas revelam ladrões invisíveis!" },
	Eloise = { "Ovos quentinhos!", "Pets Mega são 3x mais fortes!", "O Guaxinim é super raro...", "Pets sobem de nível com você!" },
}

local function startNpcs()
	local rng = Random.new()
	local animated: { [Model]: { base: { [BasePart]: CFrame }, bubble: TextLabel?, nextLine: number } } = {}

	local function setup(npc: Instance)
		if not npc:IsA("Model") or animated[npc] then
			return
		end
		local base = {}
		for _, descendant in npc:GetDescendants() do
			if descendant:IsA("BasePart") then
				base[descendant] = descendant.CFrame
			end
		end
		local head = npc:FindFirstChild("Cabeca")
		local bubble = nil
		if head and head:IsA("BasePart") then
			local gui = Instance.new("BillboardGui")
			gui.Name = "Fala"
			gui.Size = UDim2.fromOffset(220, 46)
			gui.StudsOffset = Vector3.new(0, 5.2, 0)
			gui.MaxDistance = 60
			gui.Adornee = head
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			label.BackgroundTransparency = 0.1
			label.Font = FONT
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(50, 40, 30)
			label.Text = ""
			label.Visible = false
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0, 12)
			round.Parent = label
			label.Parent = gui
			gui.Parent = npc
			bubble = label
		end
		animated[npc] = { base = base, bubble = bubble, nextLine = os.clock() + rng:NextNumber(2, 6) }
	end

	for _, npc in CollectionService:GetTagged("LojaNpc") do
		setup(npc)
	end
	CollectionService:GetInstanceAddedSignal("LojaNpc"):Connect(setup)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for npc, info in animated do
			if not npc.Parent then
				animated[npc] = nil
				continue
			end
			local bob = math.sin(t * 2 + #npc.Name) * 0.08
			local wave = math.sin(t * 3) * 0.35
			for part, cf in info.base do
				if part.Parent then
					local offset = CFrame.new(0, bob, 0)
					if part.Name == "BracoDireito" then
						part.CFrame = offset * cf * CFrame.new(0, 0.8, 0) * CFrame.Angles(wave, 0, 0) * CFrame.new(0, -0.8, 0)
					else
						part.CFrame = offset * cf
					end
				end
			end
			if info.bubble and t >= info.nextLine then
				local lines = NPC_LINES[npc:GetAttribute("Npc") or ""] or { "Olá!" }
				info.bubble.Text = lines[rng:NextInteger(1, #lines)]
				info.bubble.Visible = not info.bubble.Visible
				info.nextLine = t + (if info.bubble.Visible then 4 else rng:NextNumber(6, 12))
			end
		end
	end)
end

---------------------------------------------------------------------
-- Dica ao passar o mouse
---------------------------------------------------------------------

local DEFENSE_TEXT = {
	contact = "🛡️ Espinhos machucam ladrões",
	poison = "🛡️ Envenena e deixa ladrões lentos",
	bite = "🛡️ Morde ladrões à noite",
	ranged = "🛡️ Cospe veneno em ladrões",
	dragon = "🛡️ Lança fogo e faz o ladrão soltar o fruto",
	hypno = "🛡️ Hipnotiza e expulsa ladrões",
}

local function describe(target: Instance): string?
	local fruitModel: Instance? = nil
	local plantModel: Instance? = nil
	local node: Instance? = target
	while node and node ~= workspace do
		if node:IsA("Model") then
			if node:GetAttribute("SeedId") ~= nil then
				plantModel = node
				break
			elseif fruitModel == nil and node:GetAttribute("Weight") ~= nil then
				fruitModel = node
			end
		end
		node = node.Parent
	end
	if not plantModel then
		return nil
	end
	local seedId = plantModel:GetAttribute("SeedId")
	local seed = Config.Seeds[seedId]
	if not seed then
		return nil
	end
	local variantId = plantModel:GetAttribute("Variant")
	local name = Formulas.fruitName(seed.id, if type(variantId) == "string" then variantId else nil)
	local source = fruitModel or plantModel
	local lines = { name .. "  (" .. Config.Rarities[seed.rarity].name .. ")" }
	local weight = source:GetAttribute("Weight")
	if type(weight) == "number" then
		local size = source:GetAttribute("Size")
		lines[1] = string.format("%s • %s%s", name, Formulas.formatWeight(weight), if type(size) == "string" then " • " .. size else "")
	end
	local mutations = source:GetAttribute("Mutations")
	if type(mutations) == "string" and mutations ~= "" then
		table.insert(lines, "✨ " .. mutations)
	end
	if source:GetAttribute("Ripe") then
		table.insert(lines, if plantModel:GetAttribute("OwnerUserId") == player.UserId then "Pronto! Aperte E para colher" else "Pronto para colher")
	elseif fruitModel then
		table.insert(lines, "Fruto amadurecendo...")
	else
		local progress = plantModel:GetAttribute("Progress")
		if type(progress) == "number" and progress >= 100 then
			table.insert(lines, "Produzindo frutos")
		elseif type(progress) == "number" and progress < Config.Growth.sproutUntil * 100 then
			table.insert(lines, "🌱 Brotando: " .. tostring(progress) .. "%")
		else
			table.insert(lines, "Crescendo: " .. tostring(progress or 0) .. "%")
		end
	end
	local defense = plantModel:GetAttribute("Defense")
	if type(defense) == "string" and DEFENSE_TEXT[defense] then
		table.insert(lines, DEFENSE_TEXT[defense])
	end
	return table.concat(lines, "\n")
end

local function startTooltip(interface)
	local mouse = player:GetMouse()
	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed = 0
		local target = mouse.Target
		local message = if target and not interface.isPanelOpen() then describe(target) else nil
		interface.setTooltip(message, mouse.X, mouse.Y)
	end)
end

-- usado tambem para gerar as previas dos pets
Effects.buildPet = buildPet

function Effects.start(interface)
	startRainbow()
	startWeather()
	startPets()
	startPromptFilter()
	startNpcs()
	startTooltip(interface)
end

return Effects
