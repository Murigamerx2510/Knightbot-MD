-- Interface: toda a interface do jogador (HUD, lojas, venda, inventario, pets,
-- missoes, indice de mutacoes, avisos, dia/noite e roubo).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))

local Interface = {}

local player = Players.LocalPlayer
local FONT = Enum.Font.FredokaOne

local COLORS = {
	panel = Color3.fromRGB(255, 246, 226),
	row = Color3.fromRGB(242, 226, 194),
	header = Color3.fromRGB(228, 206, 165),
	border = Color3.fromRGB(110, 72, 38),
	text = Color3.fromRGB(70, 45, 20),
	soft = Color3.fromRGB(120, 85, 45),
	green = Color3.fromRGB(85, 190, 70),
	darkGreen = Color3.fromRGB(50, 140, 40),
	yellow = Color3.fromRGB(245, 185, 40),
	red = Color3.fromRGB(225, 75, 60),
	blue = Color3.fromRGB(70, 150, 230),
	purple = Color3.fromRGB(170, 90, 220),
	pink = Color3.fromRGB(230, 120, 160),
	brown = Color3.fromRGB(160, 110, 60),
	gray = Color3.fromRGB(150, 150, 150),
	white = Color3.fromRGB(255, 255, 255),
	money = Color3.fromRGB(130, 235, 95),
	night = Color3.fromRGB(40, 50, 110),
}

local NOTIFY_COLORS = {
	success = COLORS.green,
	error = COLORS.red,
	rare = COLORS.purple,
	info = COLORS.blue,
}

local PHASE_TEXT = {
	Day = { "☀️ Dia", Color3.fromRGB(255, 220, 90) },
	Sunset = { "🌅 Pôr do sol", Color3.fromRGB(255, 160, 80) },
	Night = { "🌙 Noite", Color3.fromRGB(170, 180, 255) },
}

---------------------------------------------------------------------
-- Ajudantes para criar instancias
---------------------------------------------------------------------

local function new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function corner(parent: Instance, radius: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

local function stroke(parent: Instance, color: Color3, thickness: number?)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function darker(color: Color3, amount: number?): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount or 0.3)
end

local function text(parent: Instance, value: string, position: UDim2, size: UDim2, textSize: number, color: Color3, align: Enum.TextXAlignment?): TextLabel
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Position = position,
		Size = size,
		Font = FONT,
		Text = value,
		TextSize = textSize,
		TextColor3 = color,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		Parent = parent,
	})
end

local function button(parent: Instance, value: string, color: Color3, position: UDim2, size: UDim2, onClick: () -> ()): TextButton
	local b = new("TextButton", {
		BackgroundColor3 = color,
		Position = position,
		Size = size,
		Font = FONT,
		Text = value,
		TextSize = 18,
		TextColor3 = COLORS.white,
		TextStrokeTransparency = 0.5,
		TextWrapped = true,
		AutoButtonColor = true,
		Parent = parent,
	})
	corner(b, 8)
	stroke(b, darker(color), 2)
	b.Activated:Connect(onClick)
	return b
end

local function pill(parent: Instance, value: string, color: Color3, position: UDim2, width: number): Frame
	local frame = new("Frame", {
		BackgroundColor3 = color,
		Position = position,
		Size = UDim2.fromOffset(width, 20),
		Parent = parent,
	})
	corner(frame, 10)
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = FONT,
		Text = value,
		TextSize = 13,
		TextColor3 = COLORS.white,
		TextStrokeTransparency = 0.4,
		Parent = frame,
	})
	return frame
end

local function swatch(parent: Instance, color: Color3)
	local frame = new("Frame", {
		BackgroundColor3 = color,
		Position = UDim2.new(0, 10, 0.5, -23),
		Size = UDim2.fromOffset(46, 46),
		Parent = parent,
	})
	corner(frame, 23)
	stroke(frame, darker(color), 3)
	return frame
end

local function progressBar(parent: Instance, fraction: number, position: UDim2, size: UDim2, color: Color3)
	local back = new("Frame", {
		BackgroundColor3 = COLORS.header,
		Position = position,
		Size = size,
		Parent = parent,
	})
	corner(back, 6)
	local fill = new("Frame", {
		BackgroundColor3 = color,
		Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
		Parent = back,
	})
	corner(fill, 6)
	return back
end

local function clearList(list: Instance)
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function makeRow(list: Instance, order: number, height: number): Frame
	local row = new("Frame", {
		BackgroundColor3 = COLORS.row,
		Size = UDim2.new(1, -12, 0, height),
		LayoutOrder = order,
		Parent = list,
	})
	corner(row, 10)
	return row
end

local function sectionRow(list: Instance, order: number, title: string)
	local row = new("Frame", {
		BackgroundColor3 = COLORS.header,
		Size = UDim2.new(1, -12, 0, 30),
		LayoutOrder = order,
		Parent = list,
	})
	corner(row, 8)
	text(row, title, UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), 18, COLORS.text)
end

local function fruitTitle(fruit): string
	return string.format("%s  •  %s  •  %s", Formulas.fruitName(fruit.s, fruit.v), Formulas.formatWeight(fruit.w), fruit.sz or "")
end

local function fruitColor(fruit): Color3
	local seed = Config.Seeds[fruit.s]
	if not seed then
		return COLORS.gray
	end
	local variant = Formulas.variantInfo(seed, fruit.v)
	return if variant then variant.color else seed.fruitColor
end

---------------------------------------------------------------------
-- Criacao da interface
---------------------------------------------------------------------

function Interface.create(remotes)
	local api = {}
	local state = nil
	local openName: string? = nil
	local busy = false
	local scalers: { UIScale } = {}
	local toastCounter = 0

	local gui = new("ScreenGui", {
		Name = "JardimUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	local function addScale(target: Instance)
		table.insert(scalers, new("UIScale", { Parent = target }))
	end

	local function updateScale()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local scale = math.clamp(math.min(viewport.X / 1100, viewport.Y / 720), 0.55, 1)
		for _, scaler in scalers do
			scaler.Scale = scale
		end
	end

	local function notify(message: string, kind: string?)
		local toasts = gui:FindFirstChild("Avisos")
		if not toasts then
			return
		end
		toastCounter += 1
		local toast = new("TextLabel", {
			Name = "Aviso",
			BackgroundColor3 = NOTIFY_COLORS[kind or "info"] or COLORS.blue,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = FONT,
			Text = message,
			TextSize = 19,
			TextColor3 = COLORS.white,
			TextStrokeTransparency = 0.5,
			TextWrapped = true,
			LayoutOrder = toastCounter,
			Parent = toasts,
		})
		corner(toast, 10)
		new("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			Parent = toast,
		})
		local list = {}
		for _, child in toasts:GetChildren() do
			if child:IsA("TextLabel") then
				table.insert(list, child)
			end
		end
		table.sort(list, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i = 1, #list - 5 do
			list[i]:Destroy()
		end
		task.delay(4.5, function()
			if toast.Parent then
				local tween = TweenService:Create(toast, TweenInfo.new(0.5), { BackgroundTransparency = 1, TextTransparency = 1, TextStrokeTransparency = 1 })
				tween:Play()
				tween.Completed:Wait()
				toast:Destroy()
			end
		end)
	end
	api.notify = notify

	---------------------------------------------------------------
	-- HUD
	---------------------------------------------------------------

	local toasts = new("Frame", {
		Name = "Avisos",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -100),
		Size = UDim2.fromOffset(480, 330),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = toasts,
	})
	addScale(toasts)

	-- dinheiro, dia/noite e botoes laterais
	local side = new("Frame", {
		Name = "Lateral",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(220, 330),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	addScale(side)
	local moneyFrame = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromOffset(220, 56),
		Parent = side,
	})
	corner(moneyFrame, 12)
	local moneyLabel = new("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(1, -20, 1, 0),
		Font = FONT,
		Text = Config.CurrencySymbol .. "...",
		TextScaled = true,
		TextColor3 = COLORS.money,
		TextStrokeTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = moneyFrame,
	})
	new("UITextSizeConstraint", { MaxTextSize = 38, Parent = moneyLabel })
	-- ate 2 linhas (a noite mostra se o jardim esta protegido); TextScaled diminui o texto se precisar
	local phaseLabel = text(side, "", UDim2.fromOffset(4, 58), UDim2.fromOffset(216, 44), 17, COLORS.white)
	phaseLabel.TextStrokeTransparency = 0.3
	phaseLabel.TextScaled = true
	new("UITextSizeConstraint", { MaxTextSize = 17, Parent = phaseLabel })
	local plantsLabel = text(side, "🌱 0/" .. Config.MaxPlantsPerGarden .. " plantas", UDim2.fromOffset(4, 103), UDim2.fromOffset(216, 20), 17, COLORS.white)
	plantsLabel.TextStrokeTransparency = 0.3

	---------------------------------------------------------------
	-- Paineis
	---------------------------------------------------------------

	local panels = {}

	local function closePanels()
		for _, panel in panels do
			panel.frame.Visible = false
		end
		openName = nil
	end

	local function makePanel(name: string, title: string, accent: Color3)
		local frame = new("Frame", {
			Name = "Painel" .. name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.53),
			Size = UDim2.fromOffset(600, 450),
			BackgroundColor3 = COLORS.panel,
			Visible = false,
			Parent = gui,
		})
		corner(frame, 14)
		stroke(frame, COLORS.border, 3)
		addScale(frame)
		local titleBar = new("Frame", {
			BackgroundColor3 = accent,
			Size = UDim2.new(1, 0, 0, 50),
			Parent = frame,
		})
		corner(titleBar, 14)
		new("Frame", {
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, -14),
			Size = UDim2.new(1, 0, 0, 14),
			Parent = titleBar,
		})
		local titleLabel = text(titleBar, title, UDim2.fromOffset(16, 0), UDim2.new(1, -80, 1, 0), 28, COLORS.white)
		titleLabel.TextStrokeTransparency = 0.4
		titleLabel.ZIndex = 2
		local closeButton = button(titleBar, "X", COLORS.red, UDim2.new(1, -46, 0, 6), UDim2.fromOffset(38, 38), closePanels)
		closeButton.ZIndex = 2
		local info = text(frame, "", UDim2.fromOffset(14, 56), UDim2.new(1, -240, 0, 34), 16, COLORS.text)
		local header = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 56),
			Size = UDim2.fromOffset(220, 34),
			Parent = frame,
		})
		local list = new("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(10, 96),
			Size = UDim2.new(1, -20, 1, -106),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 8,
			ScrollBarImageColor3 = COLORS.border,
			Parent = frame,
		})
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Parent = list,
		})
		new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6), Parent = list })
		local panel = { frame = frame, info = info, header = header, list = list }
		panels[name] = panel
		return panel
	end

	local seedsPanel = makePanel("Seeds", "🌱 Sementes do Sam", COLORS.green)
	local gearPanel = makePanel("Gear", "🔧 Equipamentos do George", COLORS.blue)
	local eggsPanel = makePanel("Eggs", "🥚 Ovos & Pets da Eloise", COLORS.purple)
	local sellPanel = makePanel("Sell", "💰 Venda do Steven", COLORS.yellow)
	local inventoryPanel = makePanel("Inventory", "🎒 Inventário", COLORS.brown)
	local petsPanel = makePanel("Pets", "🐾 Meus Pets", COLORS.pink)
	local questsPanel = makePanel("Quests", "📜 Missões do Dia", Color3.fromRGB(90, 160, 130))
	local indexPanel = makePanel("Index", "✨ Índice de Mutações", Color3.fromRGB(120, 90, 200))

	local function invoke(remote: RemoteFunction, ...): (boolean, string)
		if busy then
			return false, ""
		end
		busy = true
		local args = table.pack(...)
		local ok, success, message = pcall(function()
			return remote:InvokeServer(table.unpack(args, 1, args.n))
		end)
		busy = false
		if not ok then
			return false, "Falha de conexão. Tente novamente."
		end
		return success == true, if type(message) == "string" then message else ""
	end

	local function report(success: boolean, message: string)
		if message ~= "" then
			notify(message, if success then "success" else "error")
		end
	end

	local function restockText(): string
		if not state then
			return ""
		end
		return "🔄 Reabastece em " .. Formulas.formatTime(state.restockAt - workspace:GetServerTimeNow())
	end

	local function shopRow(list: Instance, item, category: string, stock: number, owned: number, subtitle: string, color: Color3, badges: { { string } }?)
		local row = makeRow(list, item.order, 78)
		swatch(row, color)
		text(row, item.name, UDim2.fromOffset(66, 4), UDim2.new(1, -220, 0, 26), 21, COLORS.text)
		local rarity = Config.Rarities[item.rarity]
		pill(row, rarity.name, if item.rarity == "Secret" then Color3.fromRGB(60, 60, 60) else rarity.color, UDim2.fromOffset(66, 31), 84)
		local x = 156
		for _, badge in badges or {} do
			pill(row, badge[1], badge[2], UDim2.fromOffset(x, 31), 84)
			x += 90
		end
		text(row, "Você tem: " .. owned, UDim2.fromOffset(x + 2, 31), UDim2.fromOffset(120, 20), 14, COLORS.text)
		text(row, subtitle, UDim2.fromOffset(66, 53), UDim2.new(1, -220, 0, 22), 13, COLORS.soft)
		text(row, Formulas.formatMoney(item.price), UDim2.new(1, -146, 0, 4), UDim2.fromOffset(136, 26), 20, COLORS.darkGreen, Enum.TextXAlignment.Right)
		local affordable = state and state.sheckles >= item.price
		local label = if stock > 0 then "Comprar (x" .. stock .. ")" else "Sem estoque"
		local color2 = if stock > 0 and affordable then COLORS.green elseif stock > 0 then COLORS.yellow else COLORS.gray
		button(row, label, color2, UDim2.new(1, -146, 0, 36), UDim2.fromOffset(136, 34), function()
			report(invoke(remotes.Buy, category, item.id))
		end)
	end

	local function renderSeeds()
		local panel = seedsPanel
		panel.info.Text = restockText()
		clearList(panel.list)
		for _, seed in Config.SeedList do
			if seed.inShop then
				local stock = state.stock.seeds[seed.id] or 0
				local subtitle = string.format(
					"%s • cresce em %s • vale ~%s",
					if seed.multiHarvest then "Várias colheitas" else "Colheita única",
					Formulas.formatTime(seed.growTime),
					Formulas.formatMoney(seed.baseValue)
				)
				local badges = {}
				if seed.defense then
					table.insert(badges, { "🛡️ Defesa", Color3.fromRGB(200, 70, 60) })
				end
				if seed.limited then
					table.insert(badges, { "⏳ Limitada", Color3.fromRGB(230, 120, 40) })
				elseif seed.classic then
					table.insert(badges, { "Clássica", Color3.fromRGB(120, 120, 140) })
				end
				shopRow(panel.list, seed, "Seeds", stock, state.seeds[seed.id] or 0, subtitle, seed.fruitColor, badges)
			end
		end
	end

	local function renderGear()
		local panel = gearPanel
		panel.info.Text = restockText()
		clearList(panel.list)
		for _, gear in Config.GearList do
			local stock = state.stock.gear[gear.id] or 0
			shopRow(panel.list, gear, "Gear", stock, state.gear[gear.id] or 0, gear.description, gear.color)
		end
	end

	local function renderEggs()
		local panel = eggsPanel
		panel.info.Text = restockText() .. "  •  Variantes: Grande 10%, Arco-íris 4%, Mega 1%"
		clearList(panel.list)
		for _, egg in Config.EggList do
			local stock = state.stock.eggs[egg.id] or 0
			local total = 0
			for _, entry in egg.pets do
				total += entry.weight
			end
			local chances = {}
			for _, entry in egg.pets do
				local pet = Config.Pets[entry.pet]
				table.insert(chances, string.format("%s %d%%", pet.name, math.floor(entry.weight / total * 100 + 0.5)))
			end
			local subtitle = "Choca em " .. Formulas.formatTime(egg.hatchTime) .. " • " .. table.concat(chances, ", ")
			shopRow(panel.list, egg, "Eggs", stock, state.eggs[egg.id] or 0, subtitle, egg.color)
		end
	end

	local function sortedFruits()
		local list = table.clone(state.fruits)
		table.sort(list, function(a, b)
			if a.val == b.val then
				return a.i < b.i
			end
			return a.val > b.val
		end)
		return list
	end

	local function totalValue(): number
		local total = 0
		for _, fruit in state.fruits do
			total += fruit.val
		end
		return total
	end

	local function fruitRow(list: Instance, fruit, order: number, withSell: boolean)
		local row = makeRow(list, order, 62)
		swatch(row, fruitColor(fruit))
		text(row, fruitTitle(fruit), UDim2.fromOffset(66, 4), UDim2.new(1, -230, 0, 26), 18, COLORS.text)
		local mutations = Formulas.mutationNames(fruit.m)
		local mutationText = if mutations ~= "" then "✨ " .. mutations .. " (x" .. Formulas.formatNumber(Formulas.mutationMultiplier(fruit.m)) .. ")" else "Sem mutações"
		text(row, mutationText, UDim2.fromOffset(66, 32), UDim2.new(1, -230, 0, 22), 14, if mutations ~= "" then COLORS.purple else COLORS.soft)
		text(row, Formulas.formatMoney(fruit.val), UDim2.new(1, -156, 0, if withSell then 2 else 18), UDim2.fromOffset(146, 26), 19, COLORS.darkGreen, Enum.TextXAlignment.Right)
		if withSell then
			button(row, "Vender", COLORS.yellow, UDim2.new(1, -116, 0, 28), UDim2.fromOffset(106, 30), function()
				report(invoke(remotes.Sell, "one", fruit.i, fruit.s, fruit.w))
			end)
		end
	end

	local sellAllButton = button(sellPanel.header, "Vender Tudo", COLORS.green, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), function()
		report(invoke(remotes.Sell, "all"))
	end)
	sellAllButton.TextSize = 20

	local function emptyRow(list: Instance, message: string)
		local row = makeRow(list, 1, 60)
		text(row, message, UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), 17, COLORS.text, Enum.TextXAlignment.Center)
	end

	local function renderSell()
		local panel = sellPanel
		panel.info.Text = string.format("%d fruto(s) • Total: %s", #state.fruits, Formulas.formatMoney(totalValue()))
		clearList(panel.list)
		if #state.fruits == 0 then
			emptyRow(panel.list, "Você não tem frutos. Colha frutos maduros no seu jardim!")
			return
		end
		for order, fruit in sortedFruits() do
			fruitRow(panel.list, fruit, order, true)
		end
	end

	local function renderInventory()
		local panel = inventoryPanel
		panel.info.Text = string.format(
			"Frutos: %d/%d • Valor: %s",
			#state.fruits,
			state.capacity or Config.MaxFruitsInInventory,
			Formulas.formatMoney(totalValue())
		)
		clearList(panel.list)
		local stats = state.stats or {}
		local statsRow = makeRow(panel.list, 0, 58)
		text(
			statsRow,
			string.format(
				"Plantados: %d • Colhidos: %d • Vendidos: %d • Ganhos: %s\nRoubados por você: %d • Roubados de você: %d • Pets chocados: %d • Fusões: %d",
				stats.planted or 0,
				stats.harvested or 0,
				stats.sold or 0,
				Formulas.formatMoney(stats.earned or 0),
				stats.stolen or 0,
				stats.stolenFrom or 0,
				stats.hatched or 0,
				stats.merged or 0
			),
			UDim2.fromOffset(12, 0),
			UDim2.new(1, -24, 1, 0),
			14,
			COLORS.text,
			Enum.TextXAlignment.Center
		)
		if #state.fruits == 0 then
			emptyRow(panel.list, "Nenhum fruto ainda. Plante, espere crescer e aperte E para colher!")
			return
		end
		for order, fruit in sortedFruits() do
			fruitRow(panel.list, fruit, order, false)
		end
	end

	local function renderPets()
		local panel = petsPanel
		local bonuses = state.bonuses or {}
		local equipped = 0
		for _, pet in state.pets do
			if pet.eq then
				equipped += 1
			end
		end
		panel.info.Text = string.format(
			"Equipados %d/%d • Cresc. +%s • Venda +%s • Sorte +%s • Tamanho +%s",
			equipped,
			Config.MaxPetsEquipped,
			Formulas.formatPercent(bonuses.Growth or 0),
			Formulas.formatPercent(bonuses.Sell or 0),
			Formulas.formatPercent(bonuses.Luck or 0),
			Formulas.formatPercent(bonuses.Size or 0)
		)
		panel.info.Size = UDim2.new(1, -28, 0, 34)
		clearList(panel.list)
		if #state.pets == 0 then
			emptyRow(panel.list, "Você ainda não tem pets. Compre um ovo com a Eloise e choque no seu jardim!")
			return
		end
		local list = table.clone(state.pets)
		table.sort(list, function(a, b)
			if a.eq ~= b.eq then
				return a.eq
			end
			local ra = Config.Rarities[Config.Pets[a.p].rarity].order
			local rb = Config.Rarities[Config.Pets[b.p].rarity].order
			if ra ~= rb then
				return ra > rb
			end
			return a.id < b.id
		end)
		for order, pet in list do
			local info = Config.Pets[pet.p]
			local rarity = Config.Rarities[info.rarity]
			local variant = Formulas.petVariant(pet.v ~= "" and pet.v or nil)
			local row = makeRow(panel.list, order, 84)
			swatch(row, info.color)
			local name = info.name .. (if variant.name ~= "" then " " .. variant.name else "") .. (if pet.eq then "  ✅" else "")
			text(row, name, UDim2.fromOffset(66, 4), UDim2.new(1, -230, 0, 24), 19, COLORS.text)
			pill(row, rarity.name, if info.rarity == "Secret" then Color3.fromRGB(60, 60, 60) else rarity.color, UDim2.fromOffset(66, 30), 84)
			pill(row, "Nv " .. pet.lvl, COLORS.blue, UDim2.fromOffset(156, 30), 60)
			text(row, table.concat(pet.ab, " • "), UDim2.fromOffset(222, 30), UDim2.new(1, -370, 0, 22), 13, COLORS.text)
			local fraction = if pet.nextXp > 0 then pet.xp / pet.nextXp else 1
			progressBar(row, fraction, UDim2.fromOffset(66, 58), UDim2.new(1, -220, 0, 10), COLORS.blue)
			local action = if pet.eq then "unequip" else "equip"
			button(row, if pet.eq then "Guardar" else "Equipar", if pet.eq then COLORS.gray else COLORS.green, UDim2.new(1, -126, 0.5, -17), UDim2.fromOffset(116, 34), function()
				report(invoke(remotes.PetAction, action, pet.id))
			end)
		end
	end

	local function renderQuests()
		local panel = questsPanel
		local now = workspace:GetServerTimeNow()
		panel.info.Text = "Novas missões em " .. Formulas.formatTime(86400 - now % 86400)
		clearList(panel.list)
		local quests = state.quests or {}
		if #quests == 0 then
			emptyRow(panel.list, "Carregando missões...")
			return
		end
		for order, quest in quests do
			local row = makeRow(panel.list, order, 78)
			local done = quest.progress >= quest.target
			local icon = swatch(row, if quest.claimed then COLORS.gray elseif done then COLORS.green else COLORS.yellow)
			text(icon, quest.icon or "📜", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 24, COLORS.white, Enum.TextXAlignment.Center)
			text(row, quest.text, UDim2.fromOffset(66, 4), UDim2.new(1, -230, 0, 26), 19, COLORS.text)
			progressBar(row, quest.progress / quest.target, UDim2.fromOffset(66, 36), UDim2.new(1, -230, 0, 14), COLORS.green)
			text(row, string.format("%d / %d", quest.progress, quest.target), UDim2.fromOffset(66, 52), UDim2.fromOffset(120, 22), 14, COLORS.soft)
			text(row, "🎁 " .. Formulas.formatMoney(quest.reward), UDim2.new(1, -146, 0, 4), UDim2.fromOffset(136, 26), 18, COLORS.darkGreen, Enum.TextXAlignment.Right)
			local label = if quest.claimed then "Feita ✓" elseif done then "Pegar!" else "Em andamento"
			local color = if quest.claimed then COLORS.gray elseif done then COLORS.green else COLORS.yellow
			button(row, label, color, UDim2.new(1, -146, 0, 36), UDim2.fromOffset(136, 34), function()
				report(invoke(remotes.QuestAction, quest.i))
			end)
		end
	end

	local function renderIndex()
		local panel = indexPanel
		panel.info.Text = "Valor = Crescimento x (1 + soma dos climas). Combine mutações para multiplicadores enormes!"
		panel.info.Size = UDim2.new(1, -28, 0, 34)
		clearList(panel.list)
		local order = 0
		local function nextOrder()
			order += 1
			return order
		end
		sectionRow(panel.list, nextOrder(), "🌱 Mutações de crescimento (aparecem quando o fruto nasce)")
		local growth, env = {}, {}
		for _, id in Config.MutationOrder do
			local mutation = Config.Mutations[id]
			if mutation then
				table.insert(if mutation.kind == "growth" then growth else env, id)
			end
		end
		local function mutationRow(id: string)
			local mutation = Config.Mutations[id]
			local row = makeRow(panel.list, nextOrder(), 52)
			local dot = swatch(row, mutation.color)
			dot.Size = UDim2.fromOffset(34, 34)
			dot.Position = UDim2.new(0, 12, 0.5, -17)
			text(row, string.format("%s  (x%s)", mutation.name, Formulas.formatNumber(mutation.mult)), UDim2.fromOffset(60, 2), UDim2.new(1, -70, 0, 26), 18, COLORS.text)
			text(row, mutation.source or "", UDim2.fromOffset(60, 26), UDim2.new(1, -70, 0, 22), 14, COLORS.soft)
		end
		for _, id in growth do
			mutationRow(id)
		end
		sectionRow(panel.list, nextOrder(), "🌦️ Mutações de clima, noite, pets e plantas (somam entre si)")
		table.sort(env, function(a, b)
			return Config.Mutations[a].mult < Config.Mutations[b].mult
		end)
		for _, id in env do
			mutationRow(id)
		end
		sectionRow(panel.list, nextOrder(), "🧪 Combinações automáticas")
		for _, combo in Config.MutationCombos do
			local names = {}
			for _, id in combo.requires do
				table.insert(names, Config.Mutations[id].name)
			end
			local result = Config.Mutations[combo.result]
			local row = makeRow(panel.list, nextOrder(), 40)
			text(row, string.format("%s  =  %s (x%s)", table.concat(names, " + "), result.name, Formulas.formatNumber(result.mult)), UDim2.fromOffset(14, 0), UDim2.new(1, -28, 1, 0), 16, COLORS.text)
		end
		sectionRow(panel.list, nextOrder(), "🔮 Fusões secretas (use a Espátula em duas plantas adultas)")
		for _, recipe in Config.MergeRecipes do
			local row = makeRow(panel.list, nextOrder(), 40)
			text(row, string.format("%s  +  %s  =  %s", Config.Seeds[recipe.a].name, Config.Seeds[recipe.b].name, Config.Seeds[recipe.result].name), UDim2.fromOffset(14, 0), UDim2.new(1, -28, 1, 0), 16, COLORS.text)
		end
		sectionRow(panel.list, nextOrder(), "💎 Variantes e tamanhos")
		local sizes = {}
		for _, class in Config.SizeClasses do
			table.insert(sizes, class.name)
		end
		local row = makeRow(panel.list, nextOrder(), 64)
		text(
			row,
			string.format(
				"Variante de cor: %d%% das plantas (x1.6). Variante de Cristal: %d%% (x%s).\nTamanhos: %s",
				math.floor(Config.VariantChance * 100),
				math.floor(Config.CrystalChance * 100),
				tostring(Config.CrystalVariant.mult),
				table.concat(sizes, ", ")
			),
			UDim2.fromOffset(14, 0),
			UDim2.new(1, -28, 1, 0),
			15,
			COLORS.text
		)
	end

	local renderers = {
		Seeds = renderSeeds,
		Gear = renderGear,
		Eggs = renderEggs,
		Sell = renderSell,
		Inventory = renderInventory,
		Pets = renderPets,
		Quests = renderQuests,
		Index = renderIndex,
	}

	local function refresh()
		if openName and state then
			local renderer = renderers[openName]
			if renderer then
				renderer()
			end
		end
	end

	local function openPanel(name: string)
		local panel = panels[name]
		if not panel then
			return
		end
		closePanels()
		openName = name
		panel.frame.Visible = true
		if state then
			refresh()
		else
			panel.info.Text = "Carregando..."
		end
	end
	api.openShop = openPanel

	local function togglePanel(name: string)
		if openName == name then
			closePanels()
		else
			openPanel(name)
		end
	end

	local sideButtons = {
		{ "🎒 Inventário", COLORS.brown, "Inventory" },
		{ "🐾 Pets", COLORS.pink, "Pets" },
		{ "📜 Missões", Color3.fromRGB(90, 160, 130), "Quests" },
		{ "✨ Mutações", Color3.fromRGB(120, 90, 200), "Index" },
	}
	for index, info in sideButtons do
		local b = button(side, info[1], info[2], UDim2.fromOffset(0, 126 + (index - 1) * 50), UDim2.fromOffset(220, 44), function()
			togglePanel(info[3])
		end)
		b.TextSize = 21
	end

	-- botoes de teleporte no topo
	local top = new("Frame", {
		Name = "Topo",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(660, 46),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	addScale(top)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = top,
	})
	local teleports = {
		{ label = "🌱 Sementes", place = "Seeds", panel = "Seeds", color = COLORS.green },
		{ label = "💰 Vender", place = "Sell", panel = "Sell", color = COLORS.yellow },
		{ label = "🏡 Jardim", place = "Garden", panel = nil, color = COLORS.brown },
		{ label = "🔧 Equip.", place = "Gear", panel = "Gear", color = COLORS.blue },
		{ label = "🥚 Ovos", place = "Eggs", panel = "Eggs", color = COLORS.purple },
	}
	for order, info in teleports do
		local b = button(top, info.label, info.color, UDim2.new(), UDim2.fromOffset(124, 44), function()
			remotes.Teleport:FireServer(info.place)
			if info.panel then
				openPanel(info.panel)
			else
				closePanels()
			end
		end)
		b.LayoutOrder = order
		b.TextSize = 18
	end

	-- faixa do clima
	local weatherBanner = new("Frame", {
		Name = "Clima",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 58),
		Size = UDim2.fromOffset(600, 52),
		BackgroundColor3 = COLORS.blue,
		Visible = false,
		Parent = gui,
	})
	corner(weatherBanner, 10)
	addScale(weatherBanner)
	local weatherLabel = text(weatherBanner, "", UDim2.fromOffset(10, 0), UDim2.new(1, -20, 1, 0), 16, COLORS.white, Enum.TextXAlignment.Center)
	weatherLabel.TextStrokeTransparency = 0.4

	-- faixa de roubo (quando voce carrega um fruto roubado)
	local carryBanner = new("Frame", {
		Name = "Roubo",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 116),
		Size = UDim2.fromOffset(560, 40),
		BackgroundColor3 = COLORS.red,
		Visible = false,
		Parent = gui,
	})
	corner(carryBanner, 10)
	addScale(carryBanner)
	local carryLabel = text(carryBanner, "", UDim2.fromOffset(10, 0), UDim2.new(1, -20, 1, 0), 17, COLORS.white, Enum.TextXAlignment.Center)
	carryLabel.TextStrokeTransparency = 0.4

	-- dica ao passar o mouse nas plantas
	local tooltip = new("TextLabel", {
		Name = "Dica",
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BackgroundTransparency = 0.25,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Font = FONT,
		Text = "",
		TextSize = 16,
		TextColor3 = COLORS.white,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	corner(tooltip, 8)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 5),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
		Parent = tooltip,
	})

	function api.setTooltip(message: string?, x: number?, y: number?)
		if message and x and y then
			tooltip.Text = message
			tooltip.Position = UDim2.fromOffset(x + 16, y + 10)
			tooltip.Visible = true
		else
			tooltip.Visible = false
		end
	end

	function api.setState(newState)
		state = newState
		moneyLabel.Text = Formulas.formatMoney(state.sheckles)
		plantsLabel.Text = string.format("🌱 %d/%d plantas", state.plantCount or 0, Config.MaxPlantsPerGarden)
		refresh()
	end

	function api.isPanelOpen(): boolean
		return openName ~= nil
	end

	local function myPlotLocked(): boolean
		local index = player:GetAttribute("PlotIndex")
		local mapFolder = workspace:FindFirstChild("Mapa")
		local plot = mapFolder and mapFolder:FindFirstChild("Jardim" .. tostring(index))
		return plot ~= nil and plot:GetAttribute("Locked") == true
	end

	-- atualiza contadores a cada segundo
	task.spawn(function()
		while gui.Parent do
			local now = workspace:GetServerTimeNow()
			local weatherId = workspace:GetAttribute("Weather")
			local weather = if type(weatherId) == "string" then Config.Weather[weatherId] else nil
			if weather then
				local ends = workspace:GetAttribute("WeatherEnds")
				local remaining = if type(ends) == "number" then ends - now else 0
				weatherBanner.BackgroundColor3 = (weather.sky and weather.sky.color or COLORS.blue):Lerp(Color3.new(0, 0, 0), 0.45)
				weatherLabel.Text = string.format("%s %s (%s) — %s", weather.emoji, weather.name, Formulas.formatTime(remaining), weather.description)
				weatherBanner.Visible = true
			else
				weatherBanner.Visible = false
			end
			local phase = workspace:GetAttribute("Phase")
			local phaseEnds = workspace:GetAttribute("PhaseEnds")
			local phaseInfo = PHASE_TEXT[phase or "Day"] or PHASE_TEXT.Day
			local remaining = if type(phaseEnds) == "number" then Formulas.formatTime(phaseEnds - now) else "--:--"
			if phase == "Night" then
				phaseLabel.Text = string.format("%s • %s\n%s", phaseInfo[1], remaining, if myPlotLocked() then "🔒 Jardim protegido" else "🔓 Ladrões à solta!")
			else
				phaseLabel.Text = string.format("%s • %s %s", phaseInfo[1], if phase == "Day" then "noite em" else "termina em", remaining)
			end
			phaseLabel.TextColor3 = phaseInfo[2]
			if player:GetAttribute("Carrying") then
				local untilTime = player:GetAttribute("CarryUntil")
				local left = if type(untilTime) == "number" then untilTime - now else 0
				carryLabel.Text = string.format("🏃 Carregando %s! Leve ao SEU jardim (%s)", tostring(player:GetAttribute("CarryName")), Formulas.formatTime(left))
				carryBanner.Visible = true
			else
				carryBanner.Visible = false
			end
			if state and (openName == "Seeds" or openName == "Gear" or openName == "Eggs") then
				panels[openName].info.Text = restockText() .. (if openName == "Eggs" then "  •  Variantes: Grande 10%, Arco-íris 4%, Mega 1%" else "")
			end
			task.wait(1)
		end
	end)

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	updateScale()

	return api
end

return Interface
