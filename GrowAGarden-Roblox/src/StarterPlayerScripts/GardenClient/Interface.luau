-- Interface: toda a interface do jogador (HUD, lojas, venda, inventario, pets,
-- missoes, indice de mutacoes, avisos, dia/noite e roubo).
-- Visual: paineis com sombra e gradiente, cartoes com icone, cores de raridade,
-- botoes com relevo e pequenas animacoes.

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
	panel = Color3.fromRGB(255, 248, 232),
	card = Color3.fromRGB(255, 252, 244),
	cardStroke = Color3.fromRGB(226, 204, 166),
	header = Color3.fromRGB(236, 216, 178),
	border = Color3.fromRGB(92, 58, 30),
	text = Color3.fromRGB(74, 46, 22),
	soft = Color3.fromRGB(128, 92, 52),
	green = Color3.fromRGB(88, 200, 72),
	darkGreen = Color3.fromRGB(46, 140, 40),
	yellow = Color3.fromRGB(250, 190, 40),
	orange = Color3.fromRGB(245, 140, 40),
	red = Color3.fromRGB(232, 72, 60),
	blue = Color3.fromRGB(70, 150, 235),
	purple = Color3.fromRGB(160, 90, 225),
	pink = Color3.fromRGB(236, 110, 160),
	teal = Color3.fromRGB(60, 170, 140),
	brown = Color3.fromRGB(176, 118, 62),
	gray = Color3.fromRGB(160, 160, 165),
	white = Color3.fromRGB(255, 255, 255),
	black = Color3.fromRGB(0, 0, 0),
	money = Color3.fromRGB(140, 240, 100),
	hud = Color3.fromRGB(28, 32, 44),
	gold = Color3.fromRGB(255, 200, 50),
}

-- duas cores (claro em cima, escuro embaixo) para cada raridade
local RARITY_COLORS = {
	Common = { Color3.fromRGB(205, 205, 210), Color3.fromRGB(150, 150, 158) },
	Uncommon = { Color3.fromRGB(125, 232, 105), Color3.fromRGB(56, 168, 56) },
	Rare = { Color3.fromRGB(105, 185, 255), Color3.fromRGB(48, 108, 228) },
	Epic = { Color3.fromRGB(195, 125, 255), Color3.fromRGB(118, 58, 208) },
	Legendary = { Color3.fromRGB(255, 222, 85), Color3.fromRGB(238, 148, 28) },
	Mythic = { Color3.fromRGB(255, 125, 195), Color3.fromRGB(198, 48, 138) },
	Super = { Color3.fromRGB(255, 150, 60), Color3.fromRGB(220, 60, 60) },
	Secret = { Color3.fromRGB(80, 80, 92), Color3.fromRGB(22, 22, 28) },
}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 50)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(250, 230, 60)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(90, 220, 110)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(80, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 100, 255)),
})

local NOTIFY_STYLE = {
	success = { COLORS.green, "✅" },
	error = { COLORS.red, "⛔" },
	rare = { COLORS.purple, "✨" },
	info = { COLORS.blue, "💬" },
}

local PHASE_TEXT = {
	Day = { "☀️", "Dia", Color3.fromRGB(255, 220, 90) },
	Sunset = { "🌅", "Pôr do sol", Color3.fromRGB(255, 160, 80) },
	Night = { "🌙", "Noite", Color3.fromRGB(175, 185, 255) },
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

local function lighter(color: Color3, amount: number?): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount or 0.25)
end

local function darker(color: Color3, amount: number?): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount or 0.3)
end

local function corner(parent: Instance, radius: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

local function stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

-- contorno grosso nas letras (estilo desenho)
local function outline(label: TextLabel, color: Color3, thickness: number?)
	return new("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Parent = label,
	})
end

local function gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?)
	return new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90, Parent = parent })
end

-- brilho de "botao de desenho": parte de cima clara, faixa de baixo mais escura
local function shade(parent: Instance)
	return new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(242, 242, 242)),
			ColorSequenceKeypoint.new(0.54, Color3.fromRGB(218, 218, 218)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200)),
		}),
		Rotation = 90,
		Parent = parent,
	})
end

local function rarityGradient(parent: Instance, rarityId: string?)
	if rarityId == "Super" then
		return new("UIGradient", { Color = RAINBOW, Rotation = 0, Parent = parent })
	end
	local colors = RARITY_COLORS[rarityId or "Common"] or RARITY_COLORS.Common
	return gradient(parent, colors[1], colors[2])
end

local function rarityEdge(rarityId: string?): Color3
	if rarityId == "Super" then
		return Color3.fromRGB(200, 60, 160)
	elseif rarityId == "Secret" then
		return COLORS.gold
	end
	local colors = RARITY_COLORS[rarityId or "Common"] or RARITY_COLORS.Common
	return darker(colors[2], 0.15)
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

local function animateButton(b: GuiButton)
	local scale = new("UIScale", { Name = "Animacao", Parent = b })
	local info = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local function to(value: number)
		TweenService:Create(scale, info, { Scale = value }):Play()
	end
	b.MouseEnter:Connect(function()
		to(1.05)
	end)
	b.MouseLeave:Connect(function()
		to(1)
	end)
	b.MouseButton1Down:Connect(function()
		to(0.93)
	end)
	b.MouseButton1Up:Connect(function()
		to(1.05)
	end)
end

local function button(parent: Instance, value: string, color: Color3, position: UDim2, size: UDim2, onClick: () -> ()): TextButton
	local b = new("TextButton", {
		BackgroundColor3 = lighter(color, 0.12),
		Position = position,
		Size = size,
		Font = FONT,
		Text = value,
		TextSize = 18,
		TextColor3 = COLORS.white,
		TextStrokeColor3 = darker(color, 0.6),
		TextStrokeTransparency = 0,
		TextWrapped = true,
		AutoButtonColor = false,
		Parent = parent,
	})
	corner(b, 12)
	stroke(b, darker(color, 0.45), 3)
	shade(b)
	animateButton(b)
	b.Activated:Connect(onClick)
	return b
end

local function pill(parent: Instance, value: string, color: Color3, position: UDim2, width: number): Frame
	local frame = new("Frame", {
		BackgroundColor3 = lighter(color, 0.08),
		Position = position,
		Size = UDim2.fromOffset(width, 22),
		Parent = parent,
	})
	corner(frame, 11)
	stroke(frame, darker(color, 0.35), 2)
	shade(frame)
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = FONT,
		Text = value,
		TextSize = 13,
		TextColor3 = COLORS.white,
		TextStrokeColor3 = darker(color, 0.6),
		TextStrokeTransparency = 0.1,
		Parent = frame,
	})
	return frame
end

local function rarityPill(parent: Instance, rarityId: string, position: UDim2, width: number): Frame
	local rarity = Config.Rarities[rarityId]
	local frame = new("Frame", {
		BackgroundColor3 = COLORS.white,
		Position = position,
		Size = UDim2.fromOffset(width, 22),
		Parent = parent,
	})
	corner(frame, 11)
	stroke(frame, rarityEdge(rarityId), 2)
	rarityGradient(frame, rarityId)
	new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = FONT,
		Text = if rarity then rarity.name else rarityId,
		TextSize = 13,
		TextColor3 = COLORS.white,
		TextStrokeColor3 = COLORS.black,
		TextStrokeTransparency = 0.35,
		Parent = frame,
	})
	return frame
end

-- quadradinho arredondado com o icone (emoji) do item, na cor do item e com borda da raridade
local function iconBubble(parent: Instance, icon: string, color: Color3, rarityId: string?, size: number?): Frame
	local side = size or 58
	local bubble = new("Frame", {
		Name = "Icone",
		BackgroundColor3 = COLORS.white,
		Position = UDim2.new(0, 12, 0.5, -side / 2),
		Size = UDim2.fromOffset(side, side),
		Parent = parent,
	})
	corner(bubble, math.floor(side * 0.3))
	gradient(bubble, lighter(color, 0.78), lighter(color, 0.45))
	stroke(bubble, rarityEdge(rarityId), 3)
	local shine = new("Frame", {
		BackgroundColor3 = COLORS.white,
		BackgroundTransparency = 0.45,
		Position = UDim2.fromScale(0.14, 0.08),
		Size = UDim2.fromScale(0.42, 0.18),
		Parent = bubble,
	})
	corner(shine, 99)
	new("TextLabel", {
		Name = "Emoji",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = FONT,
		Text = icon,
		TextSize = math.floor(side * 0.56),
		TextColor3 = darker(color, 0.2),
		Parent = bubble,
	})
	return bubble
end

local function progressBar(parent: Instance, fraction: number, position: UDim2, size: UDim2, color: Color3, label: string?)
	local back = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(222, 202, 168),
		Position = position,
		Size = size,
		Parent = parent,
	})
	corner(back, 8)
	stroke(back, Color3.fromRGB(176, 140, 96), 2)
	local fill = new("Frame", {
		BackgroundColor3 = lighter(color, 0.1),
		Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
		Visible = fraction > 0.01,
		Parent = back,
	})
	corner(fill, 8)
	shade(fill)
	if label then
		local caption = text(back, label, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 13, COLORS.white, Enum.TextXAlignment.Center)
		caption.TextStrokeColor3 = darker(color, 0.6)
		caption.TextStrokeTransparency = 0
	end
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
		BackgroundColor3 = COLORS.card,
		Size = UDim2.new(1, -16, 0, height),
		LayoutOrder = order,
		Parent = list,
	})
	corner(row, 14)
	stroke(row, COLORS.cardStroke, 2)
	gradient(row, COLORS.white, Color3.fromRGB(244, 234, 214))
	return row
end

local function sectionRow(list: Instance, order: number, title: string)
	local row = new("Frame", {
		BackgroundColor3 = COLORS.white,
		Size = UDim2.new(1, -16, 0, 34),
		LayoutOrder = order,
		Parent = list,
	})
	corner(row, 10)
	stroke(row, Color3.fromRGB(170, 120, 70), 2)
	gradient(row, Color3.fromRGB(250, 220, 160), Color3.fromRGB(226, 182, 120))
	local label = text(row, title, UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), 18, COLORS.white)
	label.TextStrokeColor3 = Color3.fromRGB(120, 72, 30)
	label.TextStrokeTransparency = 0
end

local function iconOf(id: string, fallback: string): string
	return Config.Icons[id] or fallback
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

local function chipWidth(value: string): number
	return math.clamp(18 + (utf8.len(value) or #value) * 8, 50, 140)
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

	local function pop(target: Instance, from: number)
		local scale = target:FindFirstChild("Pop")
		if not scale then
			scale = new("UIScale", { Name = "Pop", Parent = target })
		end
		scale.Scale = from
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	local function notify(message: string, kind: string?)
		local toasts = gui:FindFirstChild("Avisos")
		if not toasts then
			return
		end
		toastCounter += 1
		local style = NOTIFY_STYLE[kind or "info"] or NOTIFY_STYLE.info
		local toast = new("TextLabel", {
			Name = "Aviso",
			BackgroundColor3 = lighter(style[1], 0.08),
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = FONT,
			Text = message,
			TextSize = 19,
			TextColor3 = COLORS.white,
			TextStrokeColor3 = darker(style[1], 0.6),
			TextStrokeTransparency = 0,
			TextWrapped = true,
			LayoutOrder = toastCounter,
			Parent = toasts,
		})
		corner(toast, 14)
		stroke(toast, darker(style[1], 0.4), 3)
		shade(toast)
		new("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 48),
			PaddingRight = UDim.new(0, 14),
			Parent = toast,
		})
		new("TextLabel", {
			Name = "Icone",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -40, 0.5, 0),
			Size = UDim2.fromOffset(32, 32),
			Font = FONT,
			Text = style[2],
			TextSize = 24,
			TextColor3 = COLORS.white,
			Parent = toast,
		})
		pop(toast, 0.7)
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
		Size = UDim2.fromOffset(500, 340),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = toasts,
	})
	addScale(toasts)

	local function hudCard(parent: Instance, name: string, position: UDim2, size: UDim2): Frame
		local card = new("Frame", {
			Name = name,
			BackgroundColor3 = COLORS.hud,
			BackgroundTransparency = 0.18,
			Position = position,
			Size = size,
			Parent = parent,
		})
		corner(card, 16)
		stroke(card, COLORS.black, 2, 0.45)
		gradient(card, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 175, 190))
		return card
	end

	-- dinheiro, dia/noite, plantas e botoes laterais
	local side = new("Frame", {
		Name = "Lateral",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(220, 380),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	addScale(side)

	local moneyFrame = hudCard(side, "Carteira", UDim2.new(), UDim2.fromOffset(220, 58))
	local coin = new("Frame", {
		Name = "Moeda",
		BackgroundColor3 = COLORS.white,
		Position = UDim2.fromOffset(9, 9),
		Size = UDim2.fromOffset(40, 40),
		Parent = moneyFrame,
	})
	corner(coin, 20)
	gradient(coin, Color3.fromRGB(255, 232, 110), Color3.fromRGB(230, 150, 20))
	stroke(coin, Color3.fromRGB(150, 90, 10), 3)
	local coinInner = new("Frame", {
		BackgroundColor3 = COLORS.white,
		BackgroundTransparency = 0.2,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.56, 0.56),
		Parent = coin,
	})
	corner(coinInner, 12)
	gradient(coinInner, Color3.fromRGB(240, 170, 30), Color3.fromRGB(255, 225, 110))
	local coinShine = new("Frame", {
		BackgroundColor3 = COLORS.white,
		BackgroundTransparency = 0.3,
		Position = UDim2.fromScale(0.22, 0.14),
		Size = UDim2.fromScale(0.22, 0.14),
		Parent = coin,
	})
	corner(coinShine, 6)
	local moneyLabel = new("TextLabel", {
		Name = "Dinheiro",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(58, 4),
		Size = UDim2.new(1, -66, 1, -8),
		Font = FONT,
		Text = Config.CurrencySymbol .. "...",
		TextScaled = true,
		TextColor3 = COLORS.money,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = moneyFrame,
	})
	outline(moneyLabel, Color3.fromRGB(20, 70, 20), 2)
	new("UITextSizeConstraint", { MaxTextSize = 36, Parent = moneyLabel })

	local phaseFrame = hudCard(side, "Fase", UDim2.fromOffset(0, 64), UDim2.fromOffset(220, 62))
	local phaseIcon = text(phaseFrame, "☀️", UDim2.fromOffset(6, 6), UDim2.fromOffset(40, 40), 30, COLORS.white, Enum.TextXAlignment.Center)
	-- ate 2 linhas (a noite mostra se o jardim esta protegido); TextScaled diminui o texto se precisar
	local phaseLabel = text(phaseFrame, "", UDim2.fromOffset(50, 4), UDim2.new(1, -58, 0, 38), 16, COLORS.white)
	phaseLabel.TextScaled = true
	phaseLabel.TextStrokeTransparency = 0.2
	new("UITextSizeConstraint", { MaxTextSize = 16, Parent = phaseLabel })
	local phaseBarBack = new("Frame", {
		BackgroundColor3 = COLORS.black,
		BackgroundTransparency = 0.5,
		Position = UDim2.fromOffset(50, 46),
		Size = UDim2.new(1, -60, 0, 8),
		Parent = phaseFrame,
	})
	corner(phaseBarBack, 4)
	local phaseBar = new("Frame", {
		BackgroundColor3 = PHASE_TEXT.Day[3],
		Size = UDim2.fromScale(0, 1),
		Parent = phaseBarBack,
	})
	corner(phaseBar, 4)

	local plantsFrame = hudCard(side, "Plantas", UDim2.fromOffset(0, 132), UDim2.fromOffset(220, 30))
	local plantsLabel = text(plantsFrame, "🌱 0/" .. Config.MaxPlantsPerGarden .. " plantas", UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), 16, COLORS.white)
	plantsLabel.TextStrokeTransparency = 0.2

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
			Position = UDim2.fromScale(0.5, 0.54),
			Size = UDim2.fromOffset(620, 460),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = gui,
		})
		addScale(frame)
		local shadow = new("Frame", {
			Name = "Sombra",
			BackgroundColor3 = COLORS.black,
			BackgroundTransparency = 0.62,
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
			Parent = frame,
		})
		corner(shadow, 22)
		local body = new("Frame", {
			Name = "Corpo",
			BackgroundColor3 = COLORS.panel,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Parent = frame,
		})
		corner(body, 22)
		stroke(body, COLORS.border, 4)
		gradient(body, COLORS.white, Color3.fromRGB(238, 222, 190))
		local titleBar = new("Frame", {
			Name = "Titulo",
			BackgroundColor3 = COLORS.white,
			Size = UDim2.new(1, 0, 0, 60),
			Parent = body,
		})
		corner(titleBar, 22)
		new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, lighter(accent, 0.35)),
				ColorSequenceKeypoint.new(0.6, accent),
				ColorSequenceKeypoint.new(1, accent),
			}),
			Rotation = 90,
			Parent = titleBar,
		})
		new("Frame", {
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, -22),
			Size = UDim2.new(1, 0, 0, 22),
			Parent = titleBar,
		})
		new("Frame", {
			Name = "Linha",
			BackgroundColor3 = darker(accent, 0.35),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 3),
			Parent = titleBar,
		})
		local titleLabel = text(titleBar, title, UDim2.fromOffset(20, 0), UDim2.new(1, -90, 1, 0), 30, COLORS.white)
		outline(titleLabel, darker(accent, 0.55), 3)
		local closeButton = button(titleBar, "X", COLORS.red, UDim2.new(1, -54, 0, 10), UDim2.fromOffset(42, 40), closePanels)
		closeButton.TextSize = 24
		local info = text(body, "", UDim2.fromOffset(18, 68), UDim2.new(1, -256, 0, 36), 16, COLORS.soft)
		local header = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -18, 0, 68),
			Size = UDim2.fromOffset(220, 36),
			Parent = body,
		})
		local list = new("ScrollingFrame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(10, 110),
			Size = UDim2.new(1, -20, 1, -120),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 8,
			ScrollBarImageColor3 = COLORS.border,
			Parent = body,
		})
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Parent = list,
		})
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), Parent = list })
		local panel = { frame = frame, body = body, info = info, header = header, list = list }
		panels[name] = panel
		return panel
	end

	local seedsPanel = makePanel("Seeds", "🌱 Sementes do Sam", COLORS.green)
	local gearPanel = makePanel("Gear", "🔧 Equipamentos do George", COLORS.blue)
	local eggsPanel = makePanel("Eggs", "🥚 Ovos & Pets da Eloise", COLORS.purple)
	local sellPanel = makePanel("Sell", "💰 Venda do Steven", COLORS.yellow)
	local inventoryPanel = makePanel("Inventory", "🎒 Inventário", COLORS.brown)
	local petsPanel = makePanel("Pets", "🐾 Meus Pets", COLORS.pink)
	local questsPanel = makePanel("Quests", "📜 Missões do Dia", COLORS.teal)
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

	local function shopRow(list: Instance, item, category: string, stock: number, owned: number, subtitle: string, color: Color3, badges: { { any } }?)
		local row = makeRow(list, item.order, 90)
		iconBubble(row, iconOf(item.id, "🌱"), color, item.rarity)
		text(row, item.name, UDim2.fromOffset(84, 6), UDim2.new(1, -250, 0, 28), 22, COLORS.text)
		local x = 84
		rarityPill(row, item.rarity, UDim2.fromOffset(x, 37), 86)
		x += 92
		for _, badge in badges or {} do
			local width = chipWidth(badge[1])
			pill(row, badge[1], badge[2], UDim2.fromOffset(x, 37), width)
			x += width + 6
		end
		text(row, "Você tem: " .. owned, UDim2.fromOffset(x + 2, 37), UDim2.fromOffset(110, 22), 14, COLORS.soft)
		text(row, subtitle, UDim2.fromOffset(84, 62), UDim2.new(1, -250, 0, 22), 13, COLORS.soft)
		text(row, Formulas.formatMoney(item.price), UDim2.new(1, -160, 0, 6), UDim2.fromOffset(148, 26), 22, COLORS.darkGreen, Enum.TextXAlignment.Right)
		local stockLabel = text(row, if stock > 0 then "📦 Estoque: " .. stock else "Esgotado", UDim2.new(1, -160, 0, 31), UDim2.fromOffset(148, 18), 13, if stock > 0 then COLORS.soft else COLORS.red, Enum.TextXAlignment.Right)
		stockLabel.Name = "Estoque"
		local affordable = state and state.sheckles >= item.price
		local label = if stock <= 0 then "Esgotado" elseif affordable then "Comprar" else "Sem dinheiro"
		local buttonColor = if stock <= 0 then COLORS.gray elseif affordable then COLORS.green else COLORS.orange
		button(row, label, buttonColor, UDim2.new(1, -150, 0, 51), UDim2.fromOffset(138, 32), function()
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
					"%s • ⏱️ %s • 💰 ~%s",
					if seed.multiHarvest then "🔁 Várias colheitas" else "1️⃣ Colheita única",
					Formulas.formatTime(seed.growTime),
					Formulas.formatMoney(seed.baseValue)
				)
				local badges = {}
				if seed.defense then
					table.insert(badges, { "🛡️ Defesa", Color3.fromRGB(205, 70, 60) })
				end
				if seed.limited then
					table.insert(badges, { "⏳ Limitada", Color3.fromRGB(235, 120, 40) })
				elseif seed.classic then
					table.insert(badges, { "Clássica", Color3.fromRGB(120, 120, 145) })
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

	local function eggsInfo(): string
		return restockText() .. "  •  Variantes: Grande 10%, Arco-íris 4%, Mega 1%"
	end

	local function renderEggs()
		local panel = eggsPanel
		panel.info.Text = eggsInfo()
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
				table.insert(chances, string.format("%s %s %d%%", iconOf(pet.id, ""), pet.name, math.floor(entry.weight / total * 100 + 0.5)))
			end
			local subtitle = "⏱️ " .. Formulas.formatTime(egg.hatchTime) .. " • " .. table.concat(chances, ", ")
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

	local function mutationChips(row: Instance, mutations: { string }, x: number, y: number, maxX: number)
		if #mutations == 0 then
			text(row, "Sem mutações", UDim2.fromOffset(x, y), UDim2.fromOffset(160, 22), 14, COLORS.soft)
			return
		end
		for index, id in mutations do
			local mutation = Config.Mutations[id]
			if mutation then
				local width = chipWidth(mutation.name)
				if x + width > maxX then
					pill(row, "+" .. (#mutations - index + 1), COLORS.purple, UDim2.fromOffset(x, y), 40)
					return
				end
				local chip = pill(row, mutation.name, mutation.color, UDim2.fromOffset(x, y), width)
				if id == "Rainbow" then
					chip.BackgroundColor3 = COLORS.white
					local shine = chip:FindFirstChildOfClass("UIGradient")
					if shine then
						shine:Destroy()
					end
					new("UIGradient", { Color = RAINBOW, Parent = chip })
				end
				x += width + 6
			end
		end
	end

	local function fruitRow(list: Instance, fruit, order: number, withSell: boolean)
		local row = makeRow(list, order, 72)
		local seed = Config.Seeds[fruit.s]
		iconBubble(row, iconOf(fruit.s, "🍎"), fruitColor(fruit), seed and seed.rarity, 52)
		text(row, fruitTitle(fruit), UDim2.fromOffset(76, 6), UDim2.new(1, -250, 0, 26), 18, COLORS.text)
		mutationChips(row, fruit.m, 76, 40, 380)
		local multiplier = if #fruit.m > 0 then " (x" .. Formulas.formatNumber(Formulas.mutationMultiplier(fruit.m)) .. ")" else ""
		local value = text(row, Formulas.formatMoney(fruit.val), UDim2.new(1, -170, 0, if withSell then 4 else 12), UDim2.fromOffset(158, 26), 20, COLORS.darkGreen, Enum.TextXAlignment.Right)
		value.Name = "Valor"
		if multiplier ~= "" and not withSell then
			text(row, "✨" .. multiplier, UDim2.new(1, -170, 0, 38), UDim2.fromOffset(158, 20), 14, COLORS.purple, Enum.TextXAlignment.Right)
		end
		if withSell then
			button(row, "Vender", COLORS.yellow, UDim2.new(1, -122, 0, 34), UDim2.fromOffset(110, 32), function()
				report(invoke(remotes.Sell, "one", fruit.i, fruit.s, fruit.w))
			end)
		end
	end

	local sellAllButton = button(sellPanel.header, "Vender Tudo", COLORS.green, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), function()
		report(invoke(remotes.Sell, "all"))
	end)
	sellAllButton.TextSize = 20

	local function emptyRow(list: Instance, icon: string, message: string)
		local row = makeRow(list, 1, 84)
		text(row, icon, UDim2.fromOffset(14, 0), UDim2.new(0, 56, 1, 0), 38, COLORS.text, Enum.TextXAlignment.Center)
		text(row, message, UDim2.fromOffset(76, 0), UDim2.new(1, -92, 1, 0), 17, COLORS.text)
	end

	local function renderSell()
		local panel = sellPanel
		panel.info.Text = string.format("🧺 %d fruto(s) • Total: %s", #state.fruits, Formulas.formatMoney(totalValue()))
		clearList(panel.list)
		if #state.fruits == 0 then
			emptyRow(panel.list, "🧺", "Você não tem frutos. Colha frutos maduros no seu jardim!")
			return
		end
		for order, fruit in sortedFruits() do
			fruitRow(panel.list, fruit, order, true)
		end
	end

	local function statBox(parent: Instance, index: number, icon: string, label: string, value: string)
		local column = (index - 1) % 4
		local line = (index - 1) // 4
		local box = new("Frame", {
			BackgroundColor3 = COLORS.white,
			Position = UDim2.new(column * 0.25, 4, 0, 6 + line * 50),
			Size = UDim2.new(0.25, -8, 0, 44),
			Parent = parent,
		})
		corner(box, 10)
		stroke(box, COLORS.cardStroke, 2)
		gradient(box, COLORS.white, Color3.fromRGB(248, 238, 218))
		text(box, icon, UDim2.fromOffset(4, 0), UDim2.new(0, 30, 1, 0), 20, COLORS.text, Enum.TextXAlignment.Center)
		text(box, value, UDim2.fromOffset(36, 2), UDim2.new(1, -40, 0, 22), 16, COLORS.text)
		text(box, label, UDim2.fromOffset(36, 22), UDim2.new(1, -40, 0, 18), 12, COLORS.soft)
	end

	local function renderInventory()
		local panel = inventoryPanel
		panel.info.Text = string.format(
			"🧺 Frutos: %d/%d • Valor: %s",
			#state.fruits,
			state.capacity or Config.MaxFruitsInInventory,
			Formulas.formatMoney(totalValue())
		)
		clearList(panel.list)
		local stats = state.stats or {}
		local statsRow = makeRow(panel.list, 0, 112)
		local entries = {
			{ "🌱", "Plantados", tostring(stats.planted or 0) },
			{ "🧺", "Colhidos", tostring(stats.harvested or 0) },
			{ "💰", "Vendidos", tostring(stats.sold or 0) },
			{ "🪙", "Ganhos", Formulas.formatMoney(stats.earned or 0) },
			{ "🦝", "Roubados", tostring(stats.stolen or 0) },
			{ "😱", "Roubaram de você", tostring(stats.stolenFrom or 0) },
			{ "🥚", "Pets chocados", tostring(stats.hatched or 0) },
			{ "🔮", "Fusões", tostring(stats.merged or 0) },
		}
		for index, entry in entries do
			statBox(statsRow, index, entry[1], entry[2], entry[3])
		end
		if #state.fruits == 0 then
			emptyRow(panel.list, "🌱", "Nenhum fruto ainda. Plante, espere crescer e aperte E para colher!")
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
			"🐾 Equipados %d/%d • 🌿 +%s • 💰 +%s • 🍀 +%s • 📏 +%s",
			equipped,
			Config.MaxPetsEquipped,
			Formulas.formatPercent(bonuses.Growth or 0),
			Formulas.formatPercent(bonuses.Sell or 0),
			Formulas.formatPercent(bonuses.Luck or 0),
			Formulas.formatPercent(bonuses.Size or 0)
		)
		panel.info.Size = UDim2.new(1, -36, 0, 36)
		clearList(panel.list)
		if #state.pets == 0 then
			emptyRow(panel.list, "🥚", "Você ainda não tem pets. Compre um ovo com a Eloise e choque no seu jardim!")
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
			local variant = Formulas.petVariant(pet.v ~= "" and pet.v or nil)
			local row = makeRow(panel.list, order, 92)
			local bubble = iconBubble(row, iconOf(info.id, "🐾"), info.color, info.rarity)
			if variant.id == "Rainbow" then
				local tint = bubble:FindFirstChildOfClass("UIGradient")
				if tint then
					tint.Color = RAINBOW
				end
			end
			local name = info.name .. (if variant.name ~= "" then " " .. variant.name else "")
			text(row, name, UDim2.fromOffset(84, 4), UDim2.new(1, -330, 0, 26), 20, COLORS.text)
			if pet.eq then
				pill(row, "✅ Equipado", COLORS.green, UDim2.new(1, -258, 0, 7), 100)
			end
			rarityPill(row, info.rarity, UDim2.fromOffset(84, 33), 86)
			pill(row, "Nv " .. pet.lvl, COLORS.blue, UDim2.fromOffset(176, 33), 60)
			text(row, table.concat(pet.ab, " • "), UDim2.fromOffset(242, 31), UDim2.new(1, -398, 0, 26), 13, COLORS.text)
			local fraction = if pet.nextXp > 0 then pet.xp / pet.nextXp else 1
			local xpText = if pet.nextXp > 0 then string.format("XP %d / %d", pet.xp, pet.nextXp) else "Nível máximo"
			progressBar(row, fraction, UDim2.fromOffset(84, 62), UDim2.new(1, -250, 0, 18), COLORS.blue, xpText)
			local action = if pet.eq then "unequip" else "equip"
			button(row, if pet.eq then "Guardar" else "Equipar", if pet.eq then COLORS.gray else COLORS.green, UDim2.new(1, -140, 0.5, -10), UDim2.fromOffset(126, 36), function()
				report(invoke(remotes.PetAction, action, pet.id))
			end)
		end
	end

	local function renderQuests()
		local panel = questsPanel
		local now = workspace:GetServerTimeNow()
		panel.info.Text = "⏰ Novas missões em " .. Formulas.formatTime(86400 - now % 86400)
		clearList(panel.list)
		local quests = state.quests or {}
		if #quests == 0 then
			emptyRow(panel.list, "📜", "Carregando missões...")
			return
		end
		for order, quest in quests do
			local row = makeRow(panel.list, order, 86)
			local done = quest.progress >= quest.target
			local color = if quest.claimed then COLORS.gray elseif done then COLORS.green else COLORS.yellow
			iconBubble(row, quest.icon or "📜", color, if done then "Uncommon" else "Legendary")
			text(row, quest.text, UDim2.fromOffset(84, 6), UDim2.new(1, -250, 0, 28), 20, COLORS.text)
			local progress = math.min(quest.progress, quest.target)
			progressBar(row, progress / quest.target, UDim2.fromOffset(84, 44), UDim2.new(1, -250, 0, 22), COLORS.green, string.format("%d / %d", progress, quest.target))
			text(row, "🎁 " .. Formulas.formatMoney(quest.reward), UDim2.new(1, -160, 0, 6), UDim2.fromOffset(148, 26), 19, COLORS.darkGreen, Enum.TextXAlignment.Right)
			local label = if quest.claimed then "Feita ✓" elseif done then "Pegar!" else "Em andamento"
			button(row, label, color, UDim2.new(1, -150, 0, 40), UDim2.fromOffset(138, 34), function()
				report(invoke(remotes.QuestAction, quest.i))
			end)
		end
	end

	local function renderIndex()
		local panel = indexPanel
		panel.info.Text = "Valor = Crescimento x (1 + soma dos climas). Combine mutações para multiplicadores enormes!"
		panel.info.Size = UDim2.new(1, -36, 0, 36)
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
			local row = makeRow(panel.list, nextOrder(), 58)
			local bubble = iconBubble(row, "✨", mutation.color, nil, 40)
			bubble.Position = UDim2.new(0, 10, 0.5, -20)
			local tint = bubble:FindFirstChildOfClass("UIGradient")
			if tint then
				tint.Color = if mutation.rainbow then RAINBOW else ColorSequence.new(lighter(mutation.color, 0.3), mutation.color)
			end
			text(row, mutation.name, UDim2.fromOffset(62, 4), UDim2.new(1, -170, 0, 26), 19, COLORS.text)
			text(row, mutation.source or "", UDim2.fromOffset(62, 30), UDim2.new(1, -170, 0, 22), 14, COLORS.soft)
			local multiplier = "x" .. Formulas.formatNumber(mutation.mult)
			local chip = pill(row, multiplier, if mutation.mult >= 100 then COLORS.red elseif mutation.mult >= 25 then COLORS.orange else COLORS.yellow, UDim2.new(1, -92, 0.5, -13), 80)
			chip.Size = UDim2.fromOffset(80, 26)
			local chipLabel = chip:FindFirstChildOfClass("TextLabel")
			if chipLabel then
				chipLabel.TextSize = 16
			end
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
			local row = makeRow(panel.list, nextOrder(), 44)
			text(row, string.format("%s  ➜  %s (x%s)", table.concat(names, " + "), result.name, Formulas.formatNumber(result.mult)), UDim2.fromOffset(16, 0), UDim2.new(1, -32, 1, 0), 16, COLORS.text)
		end
		sectionRow(panel.list, nextOrder(), "🔮 Fusões secretas (use a Espátula em duas plantas adultas)")
		for _, recipe in Config.MergeRecipes do
			local row = makeRow(panel.list, nextOrder(), 44)
			local a, b, result = Config.Seeds[recipe.a], Config.Seeds[recipe.b], Config.Seeds[recipe.result]
			text(
				row,
				string.format("%s %s  +  %s %s  ➜  %s %s", iconOf(a.id, ""), a.name, iconOf(b.id, ""), b.name, iconOf(result.id, ""), result.name),
				UDim2.fromOffset(16, 0),
				UDim2.new(1, -32, 1, 0),
				16,
				COLORS.text
			)
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
			UDim2.fromOffset(16, 0),
			UDim2.new(1, -32, 1, 0),
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
		local wasOpen = openName == name
		closePanels()
		openName = name
		panel.frame.Visible = true
		if not wasOpen then
			pop(panel.body, 0.85)
		end
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
		{ "📜 Missões", COLORS.teal, "Quests" },
		{ "✨ Mutações", Color3.fromRGB(120, 90, 200), "Index" },
	}
	for index, info in sideButtons do
		local b = button(side, info[1], info[2], UDim2.fromOffset(0, 172 + (index - 1) * 52), UDim2.fromOffset(220, 46), function()
			togglePanel(info[3])
		end)
		b.TextSize = 21
	end

	-- botoes de teleporte no topo
	local top = new("Frame", {
		Name = "Topo",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(680, 48),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	addScale(top)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
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
		local b = button(top, info.label, info.color, UDim2.new(), UDim2.fromOffset(126, 46), function()
			remotes.Teleport:FireServer(info.place)
			if info.panel then
				openPanel(info.panel)
			else
				closePanels()
			end
		end)
		b.LayoutOrder = order
		b.TextSize = 19
	end

	-- faixa do clima
	local weatherBanner = new("Frame", {
		Name = "Clima",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.fromOffset(620, 58),
		BackgroundColor3 = COLORS.white,
		Visible = false,
		Parent = gui,
	})
	corner(weatherBanner, 16)
	local weatherStroke = stroke(weatherBanner, COLORS.black, 3, 0.3)
	local weatherTint = gradient(weatherBanner, COLORS.blue, darker(COLORS.blue, 0.4))
	addScale(weatherBanner)
	local weatherIcon = text(weatherBanner, "", UDim2.fromOffset(8, 5), UDim2.fromOffset(48, 48), 32, COLORS.white, Enum.TextXAlignment.Center)
	local weatherTitle = text(weatherBanner, "", UDim2.fromOffset(62, 4), UDim2.new(1, -74, 0, 26), 19, COLORS.white)
	weatherTitle.TextStrokeTransparency = 0
	local weatherLabel = text(weatherBanner, "", UDim2.fromOffset(62, 29), UDim2.new(1, -74, 0, 24), 14, COLORS.white)
	weatherLabel.TextStrokeTransparency = 0.3

	-- faixa de roubo (quando voce carrega um fruto roubado)
	local carryBanner = new("Frame", {
		Name = "Roubo",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 126),
		Size = UDim2.fromOffset(580, 44),
		BackgroundColor3 = COLORS.white,
		Visible = false,
		Parent = gui,
	})
	corner(carryBanner, 14)
	stroke(carryBanner, darker(COLORS.red, 0.45), 3)
	gradient(carryBanner, lighter(COLORS.red, 0.2), darker(COLORS.red, 0.2))
	addScale(carryBanner)
	local carryLabel = text(carryBanner, "", UDim2.fromOffset(12, 0), UDim2.new(1, -24, 1, 0), 18, COLORS.white, Enum.TextXAlignment.Center)
	carryLabel.TextStrokeColor3 = darker(COLORS.red, 0.6)
	carryLabel.TextStrokeTransparency = 0

	-- dica ao passar o mouse nas plantas
	local tooltip = new("TextLabel", {
		Name = "Dica",
		BackgroundColor3 = Color3.fromRGB(24, 26, 36),
		BackgroundTransparency = 0.12,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0),
		Font = FONT,
		Text = "",
		TextSize = 16,
		TextColor3 = COLORS.white,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	corner(tooltip, 10)
	stroke(tooltip, COLORS.white, 2, 0.75)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 7),
		PaddingBottom = UDim.new(0, 7),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		Parent = tooltip,
	})

	function api.setTooltip(message: string?, x: number?, y: number?)
		if message and x and y then
			tooltip.Text = message
			tooltip.Position = UDim2.fromOffset(x + 18, y + 12)
			tooltip.Visible = true
		else
			tooltip.Visible = false
		end
	end

	-- o dinheiro sobe/desce aos poucos quando muda
	local shownMoney: number? = nil
	local moneyAnimation = 0
	local function showMoney(target: number)
		moneyAnimation += 1
		local id = moneyAnimation
		local start = shownMoney or target
		shownMoney = target
		if start == target then
			moneyLabel.Text = Formulas.formatMoney(target)
			return
		end
		task.spawn(function()
			for step = 1, 10 do
				if moneyAnimation ~= id then
					return
				end
				local alpha = 1 - (1 - step / 10) ^ 3
				moneyLabel.Text = Formulas.formatMoney(math.floor(start + (target - start) * alpha + 0.5))
				task.wait(0.03)
			end
		end)
	end

	function api.setState(newState)
		state = newState
		showMoney(state.sheckles)
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

	local PHASE_LENGTH = {
		Day = Config.DayNight.dayLength,
		Sunset = Config.DayNight.sunsetLength,
		Night = Config.DayNight.nightLength,
	}

	-- atualiza contadores a cada segundo
	task.spawn(function()
		while gui.Parent do
			local now = workspace:GetServerTimeNow()
			local weatherId = workspace:GetAttribute("Weather")
			local weather = if type(weatherId) == "string" then Config.Weather[weatherId] else nil
			if weather then
				local ends = workspace:GetAttribute("WeatherEnds")
				local remaining = if type(ends) == "number" then ends - now else 0
				local base = weather.sky and weather.sky.color or COLORS.blue
				weatherTint.Color = ColorSequence.new(base:Lerp(Color3.new(0, 0, 0), 0.25), base:Lerp(Color3.new(0, 0, 0), 0.6))
				weatherStroke.Color = base:Lerp(Color3.new(0, 0, 0), 0.7)
				weatherIcon.Text = weather.emoji
				weatherTitle.Text = string.format("%s  •  %s", weather.name, Formulas.formatTime(remaining))
				weatherLabel.Text = weather.description
				weatherBanner.Visible = true
			else
				weatherBanner.Visible = false
			end
			local phase = workspace:GetAttribute("Phase")
			local phaseEnds = workspace:GetAttribute("PhaseEnds")
			local phaseInfo = PHASE_TEXT[phase or "Day"] or PHASE_TEXT.Day
			local left = if type(phaseEnds) == "number" then math.max(phaseEnds - now, 0) else 0
			local remaining = if type(phaseEnds) == "number" then Formulas.formatTime(left) else "--:--"
			phaseIcon.Text = phaseInfo[1]
			if phase == "Night" then
				phaseLabel.Text = string.format("%s • %s\n%s", phaseInfo[2], remaining, if myPlotLocked() then "🔒 Jardim protegido" else "🔓 Ladrões à solta!")
			else
				phaseLabel.Text = string.format("%s • %s %s", phaseInfo[2], if phase == "Day" then "noite em" else "termina em", remaining)
			end
			phaseLabel.TextColor3 = phaseInfo[3]
			local length = PHASE_LENGTH[phase or "Day"] or 1
			phaseBar.BackgroundColor3 = phaseInfo[3]
			phaseBar.Size = UDim2.fromScale(math.clamp(1 - left / math.max(length, 1), 0, 1), 1)
			if player:GetAttribute("Carrying") then
				local untilTime = player:GetAttribute("CarryUntil")
				local carryLeft = if type(untilTime) == "number" then untilTime - now else 0
				carryLabel.Text = string.format("🏃 Carregando %s! Leve ao SEU jardim (%s)", tostring(player:GetAttribute("CarryName")), Formulas.formatTime(carryLeft))
				carryBanner.Visible = true
			else
				carryBanner.Visible = false
			end
			if state and (openName == "Seeds" or openName == "Gear" or openName == "Eggs") then
				panels[openName].info.Text = if openName == "Eggs" then eggsInfo() else restockText()
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
