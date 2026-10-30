-- Cenario de teste completo: simula jogadores jogando o jogo do comeco ao fim.
local H = __H
local checks, failed = 0, 0
local function check(condition, message)
	checks += 1
	if not condition then
		failed += 1
		H.report("error", "FALHOU: " .. message)
	end
end
local function section(name)
	H.logs[#H.logs + 1] = "== " .. name
end

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- arvore igual a do projeto
local shared = H.newInstance("Folder", true)
shared.Name = "Shared"
shared.Parent = RS
H.makeScript("ModuleScript", "Config", "Shared/Config", shared)
H.makeScript("ModuleScript", "Formulas", "Shared/Formulas", shared)
local serverScript = H.makeScript("Script", "GardenServer", "Server/init", SSS)
for _, name in { "DataService", "DayNightService", "GardenService", "Inventory", "MapBuilder", "PetService", "QuestService", "Remotes", "ShopService", "StealService", "Sync", "Visuals", "WeatherService" } do
	H.makeScript("ModuleScript", name, "Server/" .. name, serverScript)
end

-- dados antigos (versao 1) para testar a migracao
H.storeData["CultiveUmJardim_v1"] = H.storeData["CultiveUmJardim_v1"] or {}
H.storeData["CultiveUmJardim_v1"]["Jogador_7007"] = {
	version = 1,
	sheckles = 999,
	seeds = { OrangeTulip = 3, Carrot = 1, Inexistente = 2 },
	gear = { BasicSprinkler = 2, MasterSprinkler = 1, WateringCan = 4 },
	eggs = {},
	fruits = { { s = "OrangeTulip", w = 0.05, m = { "Wet" } }, { s = "Carrot", w = 0.3, m = {} } },
	plants = { { id = 3, s = "OrangeTulip", x = 10, z = 0, p = 1, b = 0, f = { w = 0.05, m = {} } } },
	sprinklers = { { id = 4, g = "BasicSprinkler", x = 0, z = 0, t = 1 } },
	placedEggs = {},
	pets = { { id = 5, p = "Fox" }, { id = 6, p = "Panda" }, { id = 7, p = "Dog" } },
	equippedPets = { 5, 7 },
	stock = { window = -1, seeds = {}, gear = {}, eggs = {} },
	nextId = 8,
	stats = { harvested = 1, earned = 10, planted = 1 },
}

H.runScript(serverScript)
H.run(1)

local Config = require(shared.Config)
local Formulas = require(shared.Formulas)
local DataService = require(serverScript.DataService)
local GardenService = require(serverScript.GardenService)
local PetService = require(serverScript.PetService)
local QuestService = require(serverScript.QuestService)
local StealService = require(serverScript.StealService)
local DayNightService = require(serverScript.DayNightService)
local Sync = require(serverScript.Sync)

check(workspace:FindFirstChild("Mapa") ~= nil, "mapa criado")
check(#workspace.Mapa:GetChildren() > 10, "mapa tem varias partes")
check(RS:FindFirstChild("Remotes") ~= nil, "remotes criados")
local npcCount = 0
for _, d in workspace.Mapa:GetDescendants() do
	if d:IsA("Model") and d:GetAttribute("Npc") then
		npcCount += 1
	end
end
check(npcCount == 4, "4 NPCs nas lojas (Sam, Steven, George, Eloise): " .. npcCount)

local function startClient(player)
	local clientScript = H.makeScript("LocalScript", "GardenClient", "Client/init", player:WaitForChild("PlayerScripts"))
	H.makeScript("ModuleScript", "Interface", "Client/Interface", clientScript)
	H.makeScript("ModuleScript", "Effects", "Client/Effects", clientScript)
	H.runScript(clientScript)
	return clientScript
end

-- busca recursiva de botao por texto
local function findButton(root, pattern)
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") and string.find(d.Text, pattern, 1, true) and (d.Parent ~= nil) then
			return d
		end
	end
	return nil
end
local function findButtons(root, pattern)
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") and string.find(d.Text, pattern, 1, true) then
			table.insert(list, d)
		end
	end
	return list
end
local function click(buttonInstance)
	if not buttonInstance then
		H.report("error", "click em botao inexistente\n" .. debug.traceback())
		return
	end
	H.fire(H.signal(buttonInstance, "Activated"))
	H.run(0.3)
end
local function equip(player, kind, id)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	for _, container in { backpack, character } do
		for _, tool in container:GetChildren() do
			if tool:IsA("Tool") and tool:GetAttribute("ItemKind") == kind and tool:GetAttribute("ItemId") == id then
				for _, other in character:GetChildren() do
					if other:IsA("Tool") and other ~= tool then
						other.Parent = backpack
					end
				end
				tool.Parent = character
				H.run(0.05)
				return tool
			end
		end
	end
	return nil
end
local function activate(player, tool, position)
	if not tool then
		H.report("error", "ferramenta inexistente\n" .. debug.traceback())
		return
	end
	H.setMouse(player, position)
	H.fire(H.signal(tool, "Activated"))
	H.run(0.3)
end
local function chat(player, message)
	H.fire(H.signal(player, "Chatted"), message)
	H.run(0.3)
end
local function plotOf(player)
	local index = player:GetAttribute("PlotIndex")
	return workspace.Mapa:FindFirstChild("Jardim" .. tostring(index))
end
local function bedPoint(player, lx, lz)
	local plot = plotOf(player)
	local base = plot:FindFirstChild("Base")
	return base.CFrame:PointToWorldSpace(Vector3.new(lx, 0.25, lz))
end
local KIND = { Colher = "Harvest", Chocar = "Hatch" }
local function promptsIn(root, action)
	local list = {}
	for _, d in root:GetDescendants() do
		if d:IsA("ProximityPrompt") and (action == nil or d:GetAttribute("Kind") == KIND[action]) then
			table.insert(list, d)
		end
	end
	return list
end
local function trigger(prompt, player)
	if not prompt then
		H.report("error", "prompt inexistente\n" .. debug.traceback())
		return
	end
	H.fire(H.signal(prompt, "Triggered"), player)
	if player == H.localPlayer then
		H.fire(H.signal(game:GetService("ProximityPromptService"), "PromptTriggered"), prompt, player)
	end
	H.run(0.2)
end
local function plantOf(data, seedId)
	for _, plant in data.plants do
		if plant.s == seedId then
			return plant
		end
	end
	return nil
end
local function shopRowButton(gui, panelName, itemName)
	for _, row in gui[panelName]:GetDescendants() do
		if row:IsA("TextLabel") and row.Text == itemName then
			return row.Parent:FindFirstChildOfClass("TextButton")
		end
	end
	return nil
end

-- exporta a interface (para gerar capturas de tela em HTML)
local function jsonString(str)
	str = string.gsub(str, '[%c"\\]', function(ch)
		if ch == '"' then
			return '\\"'
		elseif ch == "\\" then
			return "\\\\"
		elseif ch == "\n" then
			return "\\n"
		end
		return string.format("\\u%04x", string.byte(ch))
	end)
	return '"' .. str .. '"'
end
local function toJson(value)
	local t = type(value)
	if t == "table" then
		if #value > 0 or next(value) == nil then
			local parts = {}
			for _, v in ipairs(value) do
				table.insert(parts, toJson(v))
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for k, v in value do
			table.insert(parts, jsonString(tostring(k)) .. ":" .. toJson(v))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif t == "string" then
		return jsonString(value)
	elseif t == "boolean" then
		return tostring(value)
	elseif t == "number" then
		return string.format("%.4f", value)
	end
	return "null"
end
local function udim2(u)
	return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset }
end
local function color(c)
	return { c.R, c.G, c.B }
end
local function guiNode(inst)
	local node = { class = inst.ClassName, name = inst.Name, children = {} }
	if inst:IsA("GuiObject") then
		node.pos = udim2(inst.Position)
		node.size = udim2(inst.Size)
		node.anchor = { inst.AnchorPoint.X, inst.AnchorPoint.Y }
		node.bg = color(inst.BackgroundColor3)
		node.bgT = inst.BackgroundTransparency
		node.visible = inst.Visible
		node.order = inst.LayoutOrder
		node.auto = inst.AutomaticSize.Name
		if inst:IsA("TextLabel") or inst:IsA("TextButton") then
			node.text = inst.Text
			node.tc = color(inst.TextColor3)
			node.ts = inst.TextSize
			node.scaled = inst.TextScaled
			node.xa = inst.TextXAlignment.Name
			node.wrap = inst.TextWrapped
			node.strokeT = inst.TextStrokeTransparency
		end
	elseif inst:IsA("UIListLayout") then
		node.dir = inst.FillDirection.Name
		node.pad = inst.Padding.Offset
		node.ha = inst.HorizontalAlignment.Name
		node.va = inst.VerticalAlignment.Name
	elseif inst:IsA("UICorner") then
		node.r = inst.CornerRadius.Offset
	elseif inst:IsA("UIStroke") then
		node.c = color(inst.Color)
		node.th = inst.Thickness
	elseif inst:IsA("UIPadding") then
		node.p = { inst.PaddingTop.Offset, inst.PaddingRight.Offset, inst.PaddingBottom.Offset, inst.PaddingLeft.Offset }
	elseif inst:IsA("UIScale") then
		node.scale = inst.Scale
	elseif inst:IsA("UITextSizeConstraint") then
		node.max = inst.MaxTextSize
	end
	for _, child in inst:GetChildren() do
		table.insert(node.children, guiNode(child))
	end
	return node
end
local function dumpGui(tag, player)
	if not __DUMP then
		return
	end
	local root = player.PlayerGui:FindFirstChild("JardimUI")
	H.realPrint("GUI|" .. tag .. "|" .. toJson(guiNode(root)))
end


---------------------------------------------------------------------
section("Jogador 1 entra")
local p1 = H.addPlayer(1001, "Jogador1", true)
H.run(0.5)
H.spawnCharacter(p1)
startClient(p1)
H.run(3)
chat(p1, "/dia")
H.run(1)

local data = DataService.get(p1)
check(data ~= nil, "dados carregados")
check(data.sheckles == 20, "comeca com 20 sheckles")
check(data.seeds.Carrot == 2, "comeca com 2 sementes de cenoura")
check(p1.leaderstats.Sheckles.Value == 20, "leaderstats mostra 20")
check(p1:GetAttribute("PlotIndex") == 1, "recebeu o jardim 1")
check(#data.quests.list == 3, "3 missoes do dia")
local gui = p1.PlayerGui:FindFirstChild("JardimUI")
check(gui ~= nil, "interface criada")
local seedTool = equip(p1, "Seed", "Carrot")
check(seedTool ~= nil, "ferramenta de semente de cenoura na mochila")
local rootPos = p1.Character.HumanoidRootPart.Position
local spawnPos = plotOf(p1).Base.CFrame:PointToWorldSpace(Vector3.new(0, 3, -31))
check((rootPos - spawnPos).Magnitude < 1, "personagem teleportado para o jardim")
local moneyText = nil
for _, d in gui:GetDescendants() do
	if d:IsA("TextLabel") and string.sub(d.Text, 1, #Config.CurrencySymbol) == Config.CurrencySymbol then
		moneyText = d.Text
	end
end
check(moneyText == "¢20", "HUD mostra ¢20 (mostrou " .. tostring(moneyText) .. ")")
dumpGui("1_inicio", p1)

---------------------------------------------------------------------
section("Plantar, broto, crescer e amadurecer")
activate(p1, seedTool, Vector3.new(0, 0, 0))
check(#data.plants == 0, "nao planta na rua")
activate(p1, seedTool, bedPoint(p1, 10, 0))
check(#data.plants == 1, "plantou cenoura no canteiro")
local carrot = data.plants[1]
local container = plotOf(p1).Plantas:FindFirstChildWhichIsA("Model")
check(container ~= nil and container:FindFirstChild("Broto") ~= nil, "planta nova aparece como broto")
check(container ~= nil and container:FindFirstChild("Corpo") == nil, "corpo escondido enquanto e broto")
H.run(6)
check(container:FindFirstChild("Broto") == nil and container:FindFirstChild("Corpo") ~= nil, "broto vira planta")
local produce = nil
for _, d in container:GetDescendants() do
	if d:IsA("BasePart") and d:GetAttribute("Produce") then
		produce = d
	end
end
local greenish = produce and produce.Color ~= produce:GetAttribute("BaseColor")
check(greenish == true or #carrot.f.m > 0, "fruto comeca verde (nao maduro)")
H.run(12)
local carrotPrompts = promptsIn(plotOf(p1), "Colher")
check(#carrotPrompts == 1, "cenoura madura tem botao Colher")
check(carrotPrompts[1] and carrotPrompts[1].Enabled == true and carrotPrompts[1].ActionText == "Colher", "botao Colher habilitado para o dono")
if produce and #carrot.f.m == 0 and not carrot.v then
	check(produce.Color == produce:GetAttribute("BaseColor"), "fruto maduro com a cor final")
end
trigger(carrotPrompts[1], p1)
check(#data.fruits == 1, "colheu 1 fruto")
check(#data.plants == 0, "cenoura removida apos colher")

---------------------------------------------------------------------
section("Vender")
click(findButton(gui, "💰 Vender"))
check(gui.PainelSell.Visible == true, "painel de venda aberto")
local before = data.sheckles
click(findButton(gui, "Vender Tudo"))
check(data.sheckles > before, "vendeu e ganhou sheckles")
check(#data.fruits == 0, "inventario vazio apos vender")

---------------------------------------------------------------------
section("Comprar todas as sementes")
click(findButton(gui, "🌱 Sementes"))
check(gui.PainelSeeds.Visible == true, "loja de sementes aberta")
dumpGui("2_loja_sementes", p1)
chat(p1, "/sheckles 2000000000")
chat(p1, "/estoque")
local shopSeeds = 0
for _, seed in Config.SeedList do
	if seed.inShop then
		shopSeeds += 1
		click(findButton(gui, "🌱 Sementes"))
		local b = shopRowButton(gui, "PainelSeeds", seed.name)
		check(b ~= nil, "linha da loja para " .. seed.name)
		if b then
			click(b)
		end
	else
		click(findButton(gui, "🌱 Sementes"))
		check(shopRowButton(gui, "PainelSeeds", seed.name) == nil, "semente secreta nao aparece na loja: " .. seed.name)
	end
end
local boughtAll = true
for _, seed in Config.SeedList do
	if seed.inShop and (data.seeds[seed.id] or 0) < 1 then
		boughtAll = false
		H.report("error", "nao comprou " .. seed.id)
	end
end
check(boughtAll, "comprou todas as " .. shopSeeds .. " sementes da loja")

---------------------------------------------------------------------
section("Plantar todas as sementes")
H.run(0.5)
local i = 0
for _, seed in Config.SeedList do
	if seed.inShop then
		i += 1
		local tool = equip(p1, "Seed", seed.id)
		check(tool ~= nil, "ferramenta da semente " .. seed.id)
		if tool then
			local side = if i % 2 == 0 then 1 else -1
			local index = math.floor((i - 1) / 2)
			local row, col = index % 7, math.floor(index / 7)
			activate(p1, tool, bedPoint(p1, side * (6 + col * 6), -23 + row * 8))
		end
	end
end
check(#data.plants == shopSeeds, "plantou todas (" .. #data.plants .. "/" .. shopSeeds .. ")")
chat(p1, "/crescer")
H.run(3)
local plot1 = plotOf(p1)
local types = {}
for _, plant in data.plants do
	types[Config.Seeds[plant.s].plantType] = true
end
local typeCount = 0
for _ in types do
	typeCount += 1
end
check(typeCount >= 20, "todos os tipos de planta construidos: " .. typeCount)
local harvestPrompts = promptsIn(plot1, "Colher")
check(#harvestPrompts >= shopSeeds, "todas tem frutos maduros (" .. #harvestPrompts .. ")")

-- exporta o mundo para renderizar no Blender
if __DUMP then
	local P = H.realPrint
	for _, d in workspace:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 and d.Name ~= "HumanoidRootPart" and not d:IsDescendantOf(workspace.CeuLocal) then
			local shape = "block"
			if d:IsA("Part") then
				local name = d.Shape.Name
				if name == "Ball" then
					shape = "ball"
				elseif name == "Cylinder" then
					shape = "cyl"
				end
			end
			local mesh = d:FindFirstChildOfClass("SpecialMesh")
			if mesh and (mesh.MeshType.Name == "Sphere" or mesh.MeshType.Name == "Head") then
				shape = "ball"
			end
			local c = { d.CFrame:GetComponents() }
			local size, color = d.Size, d.Color
			P(string.format("PART|%s|%.3f|%.3f|%.3f|%.5f|%.5f|%.5f|%.5f|%.5f|%.5f|%.5f|%.5f|%.5f|%.3f|%.3f|%.3f|%.4f|%.4f|%.4f|%.2f|%s",
				shape, c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12],
				size.X, size.Y, size.Z, color.R, color.G, color.B, d.Transparency, d.Material.Name))
		end
	end
end

for _, prompt in harvestPrompts do
	trigger(prompt, p1)
end
check(#data.fruits >= shopSeeds, "colheu frutos de todas as plantas (" .. #data.fruits .. ")")
local multi = 0
for _, seed in Config.SeedList do
	if seed.multiHarvest and seed.inShop then
		multi += 1
	end
end
check(#data.plants == multi, "plantas de varias colheitas ficaram (" .. #data.plants .. "/" .. multi .. ")")
H.run(60)
check(#promptsIn(plot1, "Colher") > 0, "frutos voltam a crescer")

---------------------------------------------------------------------
section("Inventario e venda de um fruto")
click(findButton(gui, "🎒 Inventário"))
check(gui.PainelInventory.Visible == true, "inventario aberto")
dumpGui("4_inventario", p1)
click(findButton(gui, "💰 Vender"))
local count = #data.fruits
local rowButton = nil
for _, b in findButtons(gui.PainelSell, "Vender") do
	if b.Text == "Vender" then
		rowButton = b
		break
	end
end
check(rowButton ~= nil, "botao vender individual")
dumpGui("3_venda", p1)
if rowButton then
	click(rowButton)
end
check(#data.fruits == count - 1, "vendeu um fruto")

---------------------------------------------------------------------
section("Equipamentos")
click(findButton(gui, "🔧 Equip."))
check(gui.PainelGear.Visible == true, "loja de equipamentos aberta")
chat(p1, "/estoque")
dumpGui("5_equipamentos", p1)
for _, gear in Config.GearList do
	click(findButton(gui, "🔧 Equip."))
	local b = shopRowButton(gui, "PainelGear", gear.name)
	if b then
		click(b)
	end
end
check(data.gear.WateringCan == 10, "regador com 10 usos")
check(data.gear.Shovel == 1 and data.gear.Trowel == 1 and data.gear.StrawberrySniper == 1, "comprou pa, espatula e atirador")
check((data.gear.CommonSprinkler or 0) >= 1 and (data.gear.SuperSprinkler or 0) >= 1, "comprou sprinklers")
check((data.gear.Gnome or 0) >= 1 and (data.gear.Lantern or 0) >= 1, "comprou gnomo e lanterna")
click(findButton(gui, "🏡 Jardim"))
H.run(1)

local can = equip(p1, "Gear", "WateringCan")
local firstPlant = data.plants[1]
local bonusBefore = firstPlant.b
activate(p1, can, plot1.Base.CFrame:PointToWorldSpace(Vector3.new(firstPlant.x, 0.25, firstPlant.z)))
check(firstPlant.b > bonusBefore, "regador acelerou a planta")
check(data.gear.WateringCan == 9, "regador gastou um uso")

for _, gear in Config.GearList do
	if gear.kind == "sprinkler" then
		local tool = equip(p1, "Gear", gear.id)
		if tool then
			activate(p1, tool, bedPoint(p1, 0.5, 8 + #data.sprinklers * 3))
		end
	end
end
check(#data.sprinklers >= 5, "sprinklers colocados (" .. #data.sprinklers .. ")")

local lantern = equip(p1, "Gear", "Lantern")
activate(p1, lantern, plot1.Base.CFrame:PointToWorldSpace(Vector3.new(0, 0.2, -28)))
check(#data.props == 1, "lanterna colocada")

-- espatula: mover uma planta
local trowel = equip(p1, "Gear", "Trowel")
local mover = plantOf(data, "Strawberry")
local oldX, oldZ = mover.x, mover.z
activate(p1, trowel, plot1.Base.CFrame:PointToWorldSpace(Vector3.new(mover.x, 0.25, mover.z)))
activate(p1, trowel, bedPoint(p1, -9, 21))
check(mover.x ~= oldX or mover.z ~= oldZ, "espatula moveu o morango")

-- espatula: fusoes secretas
for _, recipe in Config.MergeRecipes do
	local a, b = plantOf(data, recipe.a), plantOf(data, recipe.b)
	check(a ~= nil and b ~= nil, "plantas da fusao existem: " .. recipe.result)
	if a and b then
		activate(p1, trowel, plot1.Base.CFrame:PointToWorldSpace(Vector3.new(a.x, 0.25, a.z)))
		activate(p1, trowel, plot1.Base.CFrame:PointToWorldSpace(Vector3.new(b.x, 0.25, b.z)))
	end
	check(plantOf(data, recipe.result) ~= nil, "fusao criou " .. recipe.result)
	check(plantOf(data, recipe.a) == nil and plantOf(data, recipe.b) == nil, "fusao consumiu as plantas de " .. recipe.result)
end
check(data.stats.merged == #Config.MergeRecipes, "estatistica de fusoes")

-- pa: remover planta
H.run(2)
local shovel = equip(p1, "Gear", "Shovel")
local target = data.plants[#data.plants]
local plantsBefore = #data.plants
local pos = plot1.Base.CFrame:PointToWorldSpace(Vector3.new(target.x, 0.25, target.z))
activate(p1, shovel, pos)
check(#data.plants == plantsBefore, "primeiro clique da pa so avisa")
activate(p1, shovel, pos)
check(#data.plants == plantsBefore - 1, "segundo clique remove a planta")

-- cogumelo de velocidade
local humanoid1 = p1.Character:FindFirstChildOfClass("Humanoid")
local mushroom = equip(p1, "Gear", "SpeedMushroom")
activate(p1, mushroom, bedPoint(p1, 0, 0))
H.run(1)
check(humanoid1.WalkSpeed > Config.BaseWalkSpeed, "cogumelo deixou mais rapido: " .. humanoid1.WalkSpeed)
H.run(50)
check(math.abs(humanoid1.WalkSpeed - Config.BaseWalkSpeed) < 0.5, "efeito do cogumelo acabou")

---------------------------------------------------------------------
section("Eclipse ao colher a Flor do Eclipse")
chat(p1, "/crescer")
H.run(3)
local eclipse = plantOf(data, "EclipseBloom")
local eclipseView = nil
for _, model in plot1.Plantas:GetChildren() do
	if model:GetAttribute("PlantId") == (eclipse and eclipse.id) then
		eclipseView = model
	end
end
local eclipsePrompt = eclipseView and promptsIn(eclipseView, "Colher")[1]
check(eclipsePrompt ~= nil, "Flor do Eclipse tem fruto maduro")
if eclipsePrompt then
	trigger(eclipsePrompt, p1)
end
H.run(1)
check(workspace:GetAttribute("Weather") == "Eclipse", "colher a Flor do Eclipse chamou o Eclipse")
H.run(30)
check(workspace.CeuLocal:FindFirstChild("Sol") ~= nil, "eclipse aparece no ceu")
chat(p1, "/clima parar")

---------------------------------------------------------------------
section("Ovos e pets")
click(findButton(gui, "🥚 Ovos"))
check(gui.PainelEggs.Visible == true, "loja de ovos aberta")
chat(p1, "/estoque")
dumpGui("6_ovos", p1)
for _, egg in Config.EggList do
	click(findButton(gui, "🥚 Ovos"))
	local b = shopRowButton(gui, "PainelEggs", egg.name)
	if b then
		click(b)
	end
end
check((data.eggs.CommonEgg or 0) >= 1 and (data.eggs.SuperEgg or 0) >= 1, "comprou ovos")
click(findButton(gui, "🏡 Jardim"))
H.run(1)
local placed = 0
for _, egg in Config.EggList do
	local tool = equip(p1, "Egg", egg.id)
	if tool and placed < Config.MaxEggsPerGarden then
		activate(p1, tool, plot1.Base.CFrame:PointToWorldSpace(Vector3.new(0, 0.2, -18 + placed * 4)))
		placed += 1
	end
end
check(#data.placedEggs == Config.MaxEggsPerGarden, "ovos colocados (" .. #data.placedEggs .. ")")
chat(p1, "/crescer")
H.run(2)
local hatchPrompts = promptsIn(plot1, "Chocar")
check(#hatchPrompts == #data.placedEggs, "ovos prontos para chocar")
for _, prompt in hatchPrompts do
	trigger(prompt, p1)
end
check(#data.pets >= 3, "chocou pets (" .. #data.pets .. ")")
check(data.stats.hatched == 3, "estatistica de ovos chocados")
local attr = p1:GetAttribute("EquippedPets")
check(type(attr) == "string" and string.find(attr, ":", 1, true) ~= nil, "atributo de pets com variante e nivel: " .. tostring(attr))
H.run(1)
local petsFolder = workspace:FindFirstChild("PetsLocais")
check(petsFolder ~= nil and #petsFolder:GetChildren() >= 1, "pets aparecem seguindo o jogador")
-- XP e nivel
local equippedPet = nil
for _, pet in data.pets do
	if table.find(data.equippedPets, pet.id) then
		equippedPet = pet
	end
end
local levelBefore = Formulas.petLevel(equippedPet.xp)
H.run(30)
check(Formulas.petLevel(equippedPet.xp) > levelBefore, "pet subiu de nivel com XP")
click(findButton(gui, "🐾 Pets"))
check(gui.PainelPets.Visible == true, "painel de pets aberto")
dumpGui("7_pets", p1)
local guardar = findButton(gui.PainelPets, "Guardar")
if guardar then
	local equippedBefore = #data.equippedPets
	click(guardar)
	check(#data.equippedPets == equippedBefore - 1, "guardou um pet")
	local equipar = findButton(gui.PainelPets, "Equipar")
	if equipar then
		click(equipar)
		check(#data.equippedPets == equippedBefore, "equipou de novo")
	end
end
-- pets com habilidades especiais
for _, pet in data.pets do
	PetService.handleAction(p1, "unequip", pet.id)
end
chat(p1, "/pet robin")
chat(p1, "/pet monkey mega")
chat(p1, "/pet raccoon")
check(#data.equippedPets == 3, "3 pets especiais equipados")
local fruitsBefore = #data.fruits
chat(p1, "/crescer")
H.run(50)
check(#data.fruits > fruitsBefore, "Pintarroxo/Macaco colhem sozinhos")

---------------------------------------------------------------------
section("Missoes")
click(findButton(gui, "📜 Missões"))
check(gui.PainelQuests.Visible == true, "painel de missoes aberto")
for _, quest in data.quests.list do
	QuestService.progress(p1, quest.id, 1000)
end
H.run(0.5)
click(findButton(gui, "📜 Missões"))
click(findButton(gui, "📜 Missões"))
dumpGui("9_missoes", p1)
local money = data.sheckles
local claim = findButton(gui.PainelQuests, "Pegar!")
check(claim ~= nil, "botao de pegar recompensa")
if claim then
	click(claim)
end
check(data.sheckles > money, "recompensa da missao recebida")
check(data.quests.list[1].claimed or data.quests.list[2].claimed or data.quests.list[3].claimed, "missao marcada como feita")

---------------------------------------------------------------------
section("Indice de mutacoes")
click(findButton(gui, "✨ Mutações"))
check(gui.PainelIndex.Visible == true, "indice de mutacoes aberto")
dumpGui("10_indice", p1)

---------------------------------------------------------------------
section("Mutacoes e combinacoes")
local function combo(list, add)
	local m = table.clone(list)
	Formulas.addMutation(m, add)
	table.sort(m)
	return table.concat(m, ",")
end
check(combo({ "Wet" }, "Chilled") == "Frozen", "Molhado + Gelado = Congelado")
check(combo({ "Frozen" }, "Wet") == "Frozen", "Congelado ignora Molhado")
check(combo({ "Wet" }, "Sandy") == "Clay", "Molhado + Arenoso = Barro")
check(combo({ "Clay" }, "Sundried") == "Ceramic", "Barro + Ressecado = Ceramica")
check(combo({ "Shocked" }, "Ignited") == "Plasma", "Eletrizado + Inflamado = Plasma")
check(combo({ "Eclipsed" }, "Bloodlit") == "Abyssal", "Eclipsado + Sangrento = Abissal")
check(combo({ "Celestial" }, "Starstruck") == "Cosmic", "Celestial + Estelar = Cosmico")
check(combo({ "Wet", "Shocked" }, "Frozen") == "Frozen,Shocked", "Congelado direto remove Molhado")
check(combo({ "Rainbow" }, "Gold") == "Rainbow", "Arco-iris vale mais que Dourado")
check(Formulas.mutationMultiplier({ "Rainbow", "Shocked" }) == 5000, "multiplicador arco-iris + eletrizado = 5000")
check(Formulas.fruitValue("Strawberry", 0.29, {}, 0, "White") == math.floor(3 * 1.6 + 0.5), "variante branca vale 1.6x")
check(Formulas.sizeClass("Strawberry", 0.29 * 3) == "Gigante", "classe de tamanho Gigante")
local multiPlant = nil
for _, plant in data.plants do
	if Config.Seeds[plant.s].multiHarvest and #plant.slots >= 4 then
		multiPlant = plant
		break
	end
end
if multiPlant then
	multiPlant.slots[1].m = { "Rainbow", "Shocked" }
	multiPlant.slots[2].m = { "Gold", "Frozen" }
	multiPlant.slots[3].m = { "Plasma" }
	multiPlant.slots[4].m = { "Rainbow" }
	chat(p1, "/crescer")
	H.run(2)
	local CollectionService = game:GetService("CollectionService")
	check(#CollectionService:GetTagged("RainbowFruit") >= 1, "fruto arco-iris marcado")
	local sparkles, fires = 0, 0
	for _, d in plot1:GetDescendants() do
		if d:IsA("Sparkles") then
			sparkles += 1
		elseif d:IsA("Fire") then
			fires += 1
		end
	end
	check(sparkles >= 2, "brilho nos frutos raros (" .. sparkles .. ")")
	check(fires >= 1, "fogo no fruto de Plasma (" .. fires .. ")")
end

---------------------------------------------------------------------
section("Renascer")
H.spawnCharacter(p1)
H.run(2)
local toolCount = 0
for _, d in p1.Backpack:GetChildren() do
	if d:IsA("Tool") then
		toolCount += 1
	end
end
check(toolCount > 0, "ferramentas voltam na mochila nova apos renascer (" .. toolCount .. ")")
local rootAfter = p1.Character.HumanoidRootPart.Position
local gardenSpawn = plotOf(p1).Base.CFrame:PointToWorldSpace(Vector3.new(0, 3, -31))
check((rootAfter - gardenSpawn).Magnitude < 1, "renasce no proprio jardim")
humanoid1 = p1.Character:FindFirstChildOfClass("Humanoid")

---------------------------------------------------------------------
section("Todos os climas")
chat(p1, "/dia")
for _, weather in Config.WeatherList do
	chat(p1, "/clima " .. string.lower(weather.id))
	check(workspace:GetAttribute("Weather") == weather.id, "clima comecou: " .. weather.id)
	H.run(12)
	if weather.particle then
		check(workspace.ClimaLocal:FindFirstChildWhichIsA("ParticleEmitter") ~= nil, "particulas existem: " .. weather.id)
		local enabled = false
		for _, e in workspace.ClimaLocal:GetChildren() do
			if e:IsA("ParticleEmitter") and e.Enabled then
				enabled = true
			end
		end
		check(enabled, "particulas ligadas: " .. weather.id)
	end
	if weather.skyObject then
		check(#workspace.CeuLocal:GetChildren() > 0, "objeto no ceu: " .. weather.id)
	end
	if weather.id == "Rain" then
		dumpGui("8_chuva", p1)
	end
end
chat(p1, "/clima parar")
H.run(2)
check(workspace:GetAttribute("Weather") == "", "clima parou")
local mutated = 0
for _, plant in data.plants do
	local seed = Config.Seeds[plant.s]
	if seed.multiHarvest then
		for _, slot in plant.slots do
			if #slot.m > 0 then
				mutated += 1
			end
		end
	end
end
check(mutated > 0, "climas aplicaram mutacoes (" .. mutated .. ")")

---------------------------------------------------------------------
section("Dica do mouse")
local anyPlant = plot1.Plantas:FindFirstChildWhichIsA("Model")
local part = anyPlant and anyPlant:FindFirstChildWhichIsA("BasePart", true)
H.setMouse(p1, Vector3.new(0, 0, 0), part)
click(findButton(gui, "🏡 Jardim"))
H.run(0.5)
check(gui.Dica.Visible == true and gui.Dica.Text ~= "", "dica aparece sobre a planta: " .. tostring(gui.Dica.Text))

---------------------------------------------------------------------
section("Dia e noite")
chat(p1, "/noite")
H.run(1)
check(workspace:GetAttribute("Phase") == "Night", "virou noite")
local lightsOn = 0
for _, d in workspace.Mapa.Decoracao:GetDescendants() do
	if d:IsA("PointLight") and d.Enabled then
		lightsOn += 1
	end
end
check(lightsOn > 0, "postes acendem a noite")
check(game:GetService("Lighting").ClockTime >= 19 or game:GetService("Lighting").ClockTime < 7, "relogio de noite: " .. game:GetService("Lighting").ClockTime)
dumpGui("11_noite", p1)

---------------------------------------------------------------------
section("Segundo jogador e roubo a noite")
local p2 = H.addPlayer(2002, "Jogador2", false)
H.run(0.5)
H.spawnCharacter(p2)
H.run(2)
local data2 = DataService.get(p2)
check(p2:GetAttribute("PlotIndex") == 2, "jogador 2 recebeu jardim 2")
local plot2 = plotOf(p2)
data2.seeds.Carrot = 3
data2.seeds.Strawberry = 1
data2.seeds.Cactus = 1
data2.seeds.VenusFlyTrap = 1
data2.seeds.HypnoBloom = 1
data2.gear.Shovel = 1
data2.gear.Gnome = 1
local street = Vector3.new(0, 3, 0)
H.moveCharacter(p2, bedPoint(p2, 0, -20) + Vector3.new(0, 3, 0))
local spots = { Carrot = { 10, 10 }, Strawberry = { 14, 10 } }
GardenService.useItem(p2, "Seed", "Carrot", bedPoint(p2, 10, 10))
H.run(0.3)
GardenService.useItem(p2, "Seed", "Carrot", bedPoint(p2, 10, 14))
H.run(0.3)
GardenService.useItem(p2, "Seed", "Strawberry", bedPoint(p2, 14, 10))
H.run(0.3)
check(#data2.plants == 3, "jogador 2 plantou")
GardenService.growAll(p2)
H.run(2)
-- de noite com o dono em casa: trancado
H.run(1)
check(plot2:GetAttribute("Locked") == true, "jardim trancado com o dono em casa")
local p2Prompts = promptsIn(plot2, "Colher")
check(#p2Prompts >= 2, "frutos maduros no jardim 2")
check(p2Prompts[1].Enabled == false, "botao escondido para o jogador 1 com jardim trancado")
H.moveCharacter(p1, bedPoint(p2, 9, 10) + Vector3.new(0, 3, 0))
trigger(p2Prompts[1], p1)
check(StealService.isCarrying(p1) == false, "nao rouba jardim trancado")
-- dono sai de casa
H.moveCharacter(p2, street)
H.run(1)
check(plot2:GetAttribute("Locked") == false, "jardim destrancado com o dono fora")
check(p2Prompts[1].Enabled == true and p2Prompts[1].ActionText == "Roubar", "botao vira Roubar para o jogador 1")
local fruits2Before = #data2.plants
trigger(p2Prompts[1], p1)
check(StealService.isCarrying(p1), "jogador 1 esta carregando o fruto roubado")
check(p1:GetAttribute("Carrying") == true, "atributo Carrying")
H.run(1.2)
check(humanoid1.WalkSpeed <= Config.Stealing.carryWalkSpeed + 4.01, "ladrao anda devagar: " .. humanoid1.WalkSpeed)
check(gui.Roubo.Visible == true, "faixa de roubo aparece")
dumpGui("12_roubo", p1)
local posBeforeTeleport = p1.Character.HumanoidRootPart.Position
RS.Remotes.Teleport:FireServer("Garden")
H.run(0.5)
check((p1.Character.HumanoidRootPart.Position - posBeforeTeleport).Magnitude < 0.1, "nao teletransporta carregando fruto")
local fruitsP1 = #data.fruits
H.moveCharacter(p1, bedPoint(p1, 0, -20) + Vector3.new(0, 3, 0))
H.run(1)
check(not StealService.isCarrying(p1), "roubo garantido ao chegar no jardim")
check(#data.fruits >= fruitsP1 + 1, "fruto roubado no inventario do ladrao")
check(data.stats.stolen == 1 and data2.stats.stolenFrom == 1, "estatisticas de roubo")
-- segundo roubo e a pazada do dono
H.moveCharacter(p1, bedPoint(p2, 13, 10) + Vector3.new(0, 3, 0))
H.run(5)
local strawberryPrompt = nil
for _, prompt in promptsIn(plot2, "Colher") do
	if prompt.Enabled then
		strawberryPrompt = prompt
	end
end
check(strawberryPrompt ~= nil, "outro fruto para roubar")
if strawberryPrompt then
	trigger(strawberryPrompt, p1)
end
check(StealService.isCarrying(p1), "segundo roubo em andamento")
local fruits2 = #data2.fruits
H.moveCharacter(p2, p1.Character.HumanoidRootPart.Position + Vector3.new(2, 0, 0))
GardenService.useItem(p2, "Gear", "Shovel", p1.Character.HumanoidRootPart.Position)
H.run(0.5)
check(not StealService.isCarrying(p1), "pazada fez o ladrao soltar o fruto")
check(#data2.fruits == fruits2 + 1, "fruto voltou para o dono")
H.run(4)
check(humanoid1.WalkSpeed > 0, "atordoamento acabou")
-- plantas de defesa
H.moveCharacter(p2, bedPoint(p2, -10, -20) + Vector3.new(0, 3, 0))
GardenService.useItem(p2, "Seed", "Cactus", bedPoint(p2, -10, 0))
H.run(0.3)
GardenService.useItem(p2, "Seed", "VenusFlyTrap", bedPoint(p2, -16, 0))
H.run(0.3)
GardenService.growAll(p2)
H.moveCharacter(p2, street)
H.run(1)
local health = humanoid1.Health
H.moveCharacter(p1, bedPoint(p2, -12, 0) + Vector3.new(0, 3, 0))
H.run(3)
check(humanoid1.Health < health, "cacto e dioneia machucam o intruso: " .. humanoid1.Health)
-- morte devolve o fruto
H.spawnCharacter(p1)
H.run(2)
humanoid1 = p1.Character:FindFirstChildOfClass("Humanoid")
GardenService.growAll(p2)
H.run(1)
H.moveCharacter(p1, bedPoint(p2, 13, 10) + Vector3.new(0, 3, 0))
H.run(5)
local again = nil
for _, prompt in promptsIn(plot2, "Colher") do
	local fruitPart = prompt.Parent
	if prompt.Enabled and fruitPart and (fruitPart.Position - p1.Character.HumanoidRootPart.Position).Magnitude < 12 then
		again = prompt
	end
end
if again then
	trigger(again, p1)
	check(StealService.isCarrying(p1), "terceiro roubo em andamento")
	humanoid1.Health = 0
	H.run(1)
	check(not StealService.isCarrying(p1), "ladrao morto solta o fruto")
end
-- flor hipnotica expulsa
H.spawnCharacter(p1)
H.run(2)
humanoid1 = p1.Character:FindFirstChildOfClass("Humanoid")
H.moveCharacter(p2, bedPoint(p2, -10, -20) + Vector3.new(0, 3, 0))
GardenService.useItem(p2, "Seed", "HypnoBloom", bedPoint(p2, 20, -20))
H.run(0.3)
GardenService.growAll(p2)
H.moveCharacter(p2, street)
H.run(1)
H.moveCharacter(p1, bedPoint(p2, 20, -16) + Vector3.new(0, 3, 0))
H.run(2)
local garden2 = GardenService.getGarden(p2)
check(not GardenService.isInside(garden2, p1.Character.HumanoidRootPart.Position), "Flor Hipnotica expulsou o intruso")
-- gnomo tranca o jardim
H.moveCharacter(p2, bedPoint(p2, 0, -20) + Vector3.new(0, 3, 0))
GardenService.useItem(p2, "Gear", "Gnome", plot2.Base.CFrame:PointToWorldSpace(Vector3.new(0, 0.2, -26)))
H.run(0.3)
H.moveCharacter(p2, street)
H.run(1)
check(plot2:GetAttribute("Locked") == true, "gnomo tranca o jardim com o dono fora")
-- guaxinim de noite traz um fruto
local fruitsRaccoon = #data.fruits
H.run(3)
check(#data.fruits >= fruitsRaccoon, "guaxinim nao quebrou nada")
chat(p1, "/dia")
H.run(2)
check(workspace:GetAttribute("Phase") == "Day", "voltou o dia")

---------------------------------------------------------------------
section("Reabastecimento e eventos naturais")
H.run(700, 0.5)
check(true, "simulou 700s")

---------------------------------------------------------------------
section("Sair, crescer offline e voltar")
local plantsSaved = #data.plants
local fruitsSaved = #data.fruits
local petsSaved = #data.pets
local sheckSaved = data.sheckles
H.removePlayer(p1)
H.run(2)
check(H.storeData[Config.DataStoreName]["Jogador_1001"] ~= nil, "dados salvos ao sair")
check(plot1:GetAttribute("OwnerUserId") == 0, "jardim liberado")
check(#plot1.Plantas:GetChildren() == 0, "plantas removidas do mapa ao sair")
H.run(300, 1)
local p1b = H.addPlayer(1001, "Jogador1", true)
H.run(0.5)
H.spawnCharacter(p1b)
startClient(p1b)
H.run(3)
local dataB = DataService.get(p1b)
check(dataB ~= nil and #dataB.plants == plantsSaved, "plantas restauradas (" .. (dataB and #dataB.plants or -1) .. "/" .. plantsSaved .. ")")
check(dataB and #dataB.fruits >= fruitsSaved, "frutos restaurados")
check(dataB and #dataB.pets == petsSaved, "pets restaurados")
check(dataB and dataB.sheckles >= sheckSaved, "sheckles restaurados")
local newPlot = plotOf(p1b)
check(newPlot ~= nil and #newPlot.Plantas:GetChildren() >= plantsSaved, "plantas recriadas no mapa")

---------------------------------------------------------------------
section("Dados antigos (migracao)")
local p7 = H.addPlayer(7007, "Veterano", false)
H.run(3)
local data7 = DataService.get(p7)
check(data7 ~= nil and data7.version == 2, "dados antigos atualizados para a versao 2")
check(data7.seeds.Tulip == 3 and data7.seeds.Inexistente == nil, "semente antiga trocada pela nova")
check(data7.gear.CommonSprinkler == 2 and data7.gear.SuperSprinkler == 1 and data7.gear.BasicSprinkler == nil, "sprinklers antigos trocados")
check(data7.fruits[1].s == "Tulip" and data7.plants[1].s == "Tulip", "frutos e plantas antigos trocados")
local petNames = {}
for _, pet in data7.pets do
	table.insert(petNames, pet.p)
end
table.sort(petNames)
check(table.concat(petNames, ",") == "Bear,Deer,Dog", "pets antigos trocados: " .. table.concat(petNames, ","))
H.removePlayer(p7)
H.run(2)

---------------------------------------------------------------------
section("Falha no DataStore")
H.dataStoreFailures = 3
local p3 = H.addPlayer(3003, "Jogador3", false)
H.run(10)
check(H.dataStoreFailures == 0, "tentou carregar 3 vezes antes de desistir")
local data3 = DataService.get(p3)
check(data3 ~= nil, "jogador 3 joga mesmo com falha")
H.removePlayer(p3)
H.run(2)
check(H.storeData[Config.DataStoreName]["Jogador_3003"] == nil, "nao salvou por cima apos falha de carregamento")

---------------------------------------------------------------------
section("Servidor cheio")
for n = 1, 6 do
	H.addPlayer(5000 + n, "Extra" .. n, false)
	H.run(1)
end
H.run(2)
check(H.kicked ~= nil and #H.kicked >= 1, "7o jogador e expulso com servidor cheio")

---------------------------------------------------------------------
section("Modelos do Blender (biblioteca)")
local library = H.newInstance("Folder", true)
library.Name = "Modelos"
library.Parent = RS
local function meshModel(name, parts)
	local model = H.newInstance("Model", true)
	model.Name = name
	for _, info in parts do
		local mesh = H.newInstance("MeshPart", true)
		mesh.Name = info[1]
		mesh.Size = info[2]
		mesh.CFrame = CFrame.new(info[3])
		mesh.Parent = model
	end
	model.Parent = library
end
meshModel("Planta_Carrot", { { "Corpo_Carrot", Vector3.new(0.8, 1.2, 0.8), Vector3.new(0, 1.5, 0) }, { "Produto_Carrot", Vector3.new(0.5, 1, 0.5), Vector3.new(0, 0.4, 0) } })
meshModel("Fruto_Strawberry", { { "Produto_Strawberry", Vector3.new(30, 36, 30), Vector3.new(100, 100, 100) }, { "Cabo_Strawberry", Vector3.new(5, 10, 5), Vector3.new(100, 120, 100) } })
meshModel("Sprinkler_CommonSprinkler", { { "Base_CommonSprinkler", Vector3.new(1.4, 0.4, 1.4), Vector3.new(0, 0.2, 0) }, { "Cabeca_CommonSprinkler", Vector3.new(0.8, 0.8, 0.8), Vector3.new(0, 1.9, 0) } })
meshModel("Ovo_CommonEgg", { { "Casca_CommonEgg", Vector3.new(16, 20, 16), Vector3.new(0, 10, 0) } })
meshModel("Gnomo", { { "Corpo_Gnomo", Vector3.new(1, 1, 1), Vector3.new(0, 0.5, 0) }, { "Chapeu_Gnomo", Vector3.new(0.8, 1, 0.8), Vector3.new(0, 1.5, 0) } })
meshModel("Lanterna", { { "Vidro_Lanterna", Vector3.new(0.5, 0.6, 0.5), Vector3.new(0, 2.6, 0) }, { "Poste_Lanterna", Vector3.new(0.2, 3, 0.2), Vector3.new(0, 1.5, 0) } })
meshModel("Planta_MoonBloom", { { "Corpo_MoonBloom", Vector3.new(1, 3, 1), Vector3.new(0, 1.5, 0) }, { "Brilho_MoonBloom", Vector3.new(0.6, 0.6, 0.6), Vector3.new(0, 3.6, 0) } })
meshModel("Planta_CherryBlossom", { { "Corpo_CherryBlossom", Vector3.new(1, 3, 1), Vector3.new(0, 1.5, 0) }, { "Copa_CherryBlossom", Vector3.new(5, 3, 5), Vector3.new(0, 4.5, 0) } })
-- textura do Blender nas partes de fruto
for _, model in library:GetChildren() do
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") and string.find(d.Name, "Produto", 1, true) then
			d.TextureID = "rbxassetid://777"
		end
	end
end
local single = H.newInstance("MeshPart", true)
single.Name = "Planta_Tomato"
single.Size = Vector3.new(200, 300, 200)
single.Parent = library
dataB.seeds.Carrot = 1
dataB.seeds.Strawberry = 1
dataB.seeds.Tomato = 1
dataB.seeds.MoonBloom = 1
dataB.seeds.CherryBlossom = 1
dataB.gear.CommonSprinkler = 1
dataB.gear.Gnome = 1
dataB.gear.Lantern = 1
dataB.eggs.CommonEgg = 1
Sync.markDirty(p1b)
H.run(0.5)
for n, id in { "Carrot", "Strawberry", "Tomato" } do
	local tool = equip(p1b, "Seed", id)
	if tool then
		activate(p1b, tool, bedPoint(p1b, -22, 18 + n * 2.5))
	end
end
for n, id in { "MoonBloom", "CherryBlossom" } do
	local tool = equip(p1b, "Seed", id)
	if tool then
		activate(p1b, tool, bedPoint(p1b, -16, 17 + n * 4))
	end
end
-- textura escondida enquanto o fruto esta verde (depois do broto, antes de amadurecer)
H.run(3)
local function libraryProduce(name)
	for _, d in newPlot:GetDescendants() do
		if d:IsA("MeshPart") and d.Name == name and d:GetAttribute("Produce") then
			return d
		end
	end
	return nil
end
local carrotProduce = libraryProduce("Produto_Carrot")
check(carrotProduce ~= nil and carrotProduce.TextureID == "" and carrotProduce:GetAttribute("Texture") == "rbxassetid://777", "textura do Blender some no fruto verde")
local libSprinkler = equip(p1b, "Gear", "CommonSprinkler")
if libSprinkler then
	activate(p1b, libSprinkler, bedPoint(p1b, 0.5, 25))
end
for _, id in { "Gnome", "Lantern" } do
	local tool = equip(p1b, "Gear", id)
	if tool then
		activate(p1b, tool, newPlot.Base.CFrame:PointToWorldSpace(Vector3.new(if id == "Gnome" then -2 else 2, 0.2, -30)))
	end
end
local libEgg = equip(p1b, "Egg", "CommonEgg")
if libEgg then
	activate(p1b, libEgg, bedPoint(p1b, -1, 29))
end
chat(p1b, "/crescer")
H.run(3)
check(#promptsIn(newPlot, "Colher") > 0, "plantas com modelos importados funcionam")
local strawberryStem = nil
for _, d in newPlot:GetDescendants() do
	if d:IsA("MeshPart") and d.Name == "Cabo_Strawberry" then
		strawberryStem = d
	end
end
check(strawberryStem ~= nil and strawberryStem:GetAttribute("Produce") == nil, "cabo do fruto importado nao conta como fruto")
local waterOnHead = false
for _, d in newPlot:GetDescendants() do
	if d:IsA("ParticleEmitter") and d.Parent and d.Parent.Name == "Cabeca_CommonSprinkler" then
		waterOnHead = true
	end
end
check(waterOnHead, "agua sai da cabeca do sprinkler importado")
check(#promptsIn(newPlot, "Chocar") >= 1, "ovo importado pode chocar")
local importedGnome, importedLantern = false, false
for _, d in newPlot:GetDescendants() do
	if d:IsA("MeshPart") and d.Name == "Chapeu_Gnomo" then
		importedGnome = true
	elseif d:IsA("MeshPart") and d.Name == "Vidro_Lanterna" then
		importedLantern = true
	end
end
check(importedGnome and importedLantern, "gnomo e lanterna importados usados")
local function textureOk(part)
	if not part then
		return false
	end
	local expected = if part:GetAttribute("Mutated") or part:GetAttribute("Variant") then "" else "rbxassetid://777"
	return part.TextureID == expected
end
check(textureOk(libraryProduce("Produto_Carrot")), "textura do Blender volta no fruto maduro (planta)")
check(textureOk(libraryProduce("Produto_Strawberry")), "textura do Blender volta no fruto maduro (fruto)")
local moonLight, petals = false, false
for _, d in newPlot:GetDescendants() do
	if d:IsA("PointLight") and d.Parent and d.Parent.Name == "Brilho_MoonBloom" then
		moonLight = true
	elseif d:IsA("ParticleEmitter") and d.Name == "Petalas" and d.Parent and d.Parent.Name == "Copa_CherryBlossom" then
		petals = true
	end
end
check(moonLight, "parte Brilho do modelo importado ganha luz")
check(petals, "copa da Cerejeira importada solta petalas")

---------------------------------------------------------------------
section("Fechar servidor")
for _, fn in H.bindToClose or {} do
	task.spawn(fn)
end
H.run(5)
check(H.storeData[Config.DataStoreName]["Jogador_1001"] ~= nil, "BindToClose salvou")

---------------------------------------------------------------------
local unimpl = {}
for k in H.unimplemented do
	table.insert(unimpl, k)
end
local deprecated = {}
for k in H.deprecatedUse do
	table.insert(deprecated, k)
end
table.sort(unimpl)
table.sort(deprecated)
local P = H.realPrint
local seen = {}
for _, w in H.warnings do
	if not seen[w] then
		seen[w] = true
		P("[aviso] " .. w)
	end
end
P(string.format("CHECAGENS: %d, falharam: %d, erros: %d, avisos: %d", checks, failed, #H.errors, #H.warnings))
P("Metodos sem simulacao: " .. table.concat(unimpl, ", "))
P("APIs obsoletas usadas: " .. table.concat(deprecated, ", "))
return checks
