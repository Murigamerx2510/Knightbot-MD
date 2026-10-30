-- DayNightService: ciclo de dia (7,5 min), por do sol (30 s) e noite (2 min), igual ao GAG2.
-- A noite libera os roubos, acende os postes e deixa frutos Lunares.
-- O ciclo usa os.time(), entao e o mesmo em todos os servidores.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local GardenService = require(script.Parent.GardenService)
local Sync = require(script.Parent.Sync)

local DayNightService = {}

local offset = 0 -- usado pelos comandos de teste para pular de fase
local currentPhase = ""
local currentIndex = -1
local listeners: { (string, number) -> () } = {}
local lights: { PointLight } = {}

function DayNightService.now(): number
	return os.time() + offset
end

function DayNightService.getPhase(): (string, number, number, number)
	return Formulas.dayPhase(DayNightService.now())
end

function DayNightService.isNight(): boolean
	return (DayNightService.getPhase()) == "Night"
end

-- callback(fase, numeroDoCiclo) quando a fase muda
function DayNightService.onPhaseChanged(callback: (string, number) -> ())
	table.insert(listeners, callback)
end

-- Comando de teste: pula para o inicio de uma fase
function DayNightService.skipTo(phaseName: string)
	local dn = Config.DayNight
	local cycle = dn.dayLength + dn.sunsetLength + dn.nightLength
	local target = if phaseName == "Night" then dn.dayLength + dn.sunsetLength elseif phaseName == "Sunset" then dn.dayLength else 0
	local t = DayNightService.now() % cycle
	local delta = (target - t) % cycle
	offset += delta + 0.01
end

local function update()
	local phase, remaining, clockTime, index = DayNightService.getPhase()
	Lighting.ClockTime = clockTime
	workspace:SetAttribute("Phase", phase)
	workspace:SetAttribute("PhaseEnds", os.time() + remaining)
	if phase ~= currentPhase or index ~= currentIndex then
		local previous = currentPhase
		currentPhase = phase
		currentIndex = index
		GardenService.setPhase(phase, index)
		for _, light in lights do
			light.Enabled = phase ~= "Day"
		end
		if previous ~= "" then
			if phase == "Night" then
				Sync.notifyAll("🌙 A noite chegou! Ladrões podem roubar jardins sem o dono por perto. Fique no seu jardim ou use defesas!", "rare")
			elseif phase == "Day" then
				Sync.notifyAll("☀️ Amanheceu! Os jardins estão seguros de novo.", "info")
			end
		end
		for _, callback in listeners do
			task.spawn(callback, phase, index)
		end
	end
	return phase
end

function DayNightService.start(map)
	lights = map.lights or {}
	workspace:SetAttribute("StealingEnabled", Config.Stealing.enabled)
	update()
	task.spawn(function()
		local elapsed = 0
		while true do
			task.wait(0.5)
			elapsed += 0.5
			local ok, result = pcall(update)
			if not ok then
				warn("[Jardim] Erro no ciclo do dia: " .. tostring(result))
			elseif result == "Night" and elapsed >= 1 then
				elapsed = 0
				GardenService.applyWeatherMutation("Moonlit", Config.DayNight.moonlitChance)
			end
		end
	end)
end

return DayNightService
