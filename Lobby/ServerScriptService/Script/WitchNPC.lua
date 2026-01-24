-- WitchNPC.server.lua (ServerScriptService/Script)

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- PlayerData
local playerDataModule = (ServerScriptService:FindFirstChild("ModuleScript") and ServerScriptService.ModuleScript:FindFirstChild("PlayerData"))
	or (ServerScriptService:FindFirstChild("ModuleScripts") and ServerScriptService.ModuleScripts:FindFirstChild("PlayerData"))
	or ServerScriptService:FindFirstChild("PlayerData")
assert(playerDataModule, "Missing PlayerData module")
local PlayerData = require(playerDataModule)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local WitchShopEvent = remotes:WaitForChild("WitchShopEvent")

local function findWitchModel(): Model?
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("Model") and (inst.Name == "Witch" or inst.Name == "Wiedzma") then
			return inst
		end
	end
	return nil
end

local function ensurePrompt(m: Model)
	local root = m.PrimaryPart
	if not root then
		root = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
		if root and root:IsA("BasePart") then
			m.PrimaryPart = root
		end
	end
	if not root or not root:IsA("BasePart") then
		warn("[WitchNPC] No root part for prompt.")
		return
	end

	local prompt = root:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Talk"
		prompt.ObjectText = "Witch"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.Parent = root
	end

	prompt.Triggered:Connect(function(plr: Player)
		local d = PlayerData.Get(plr)

		-- tutorial flow: daje spellbook raz
		if d.spellbookUnlocked ~= true then
			if _G.Spells_GrantStarterBook then
				_G.Spells_GrantStarterBook(plr)
			end
		end

		-- shop dopiero po tutorialu
		if d.tutorialCompleted ~= true then
			WitchShopEvent:FireClient(plr, { type = "INFO", message = "Finish the tutorial to access the shop." })
			return
		end

		-- open shop
		WitchShopEvent:FireClient(plr, { type = "OPEN", coins = d.coins, spells = nil })
		-- klient i tak poprosi o pełne dane przez OPEN request? Tu idziemy prosto:
		-- najlepiej: klient niech wyśle OPEN do serwera (żeby zawsze dostać świeże coins/listę)
		WitchShopEvent:FireClient(plr, { type = "INFO", message = "Loading shop..." })
		WitchShopEvent:FireClient(plr, { type = "OPEN", coins = d.coins, spells = nil })
		-- poprawnie: jedna wiadomość OPEN z danymi robi SpellService (patrz niżej). Tu najprościej:
		WitchShopEvent:FireClient(plr, { type = "INFO", message = "Press Buy on a spell to unlock it." })
		-- i teraz poproś serwer o OPEN (client->server)
		WitchShopEvent:FireClient(plr, { type = "INFO", message = "Opening..." })
		-- wymuś refresh:
		WitchShopEvent:FireClient(plr, { type = "INFO", message = "..." })
		-- final: client wyśle OPEN automatycznie (patrz dopisek w WitchShopClient poniżej)
	end)
end

local witch = findWitchModel()
if witch then
	ensurePrompt(witch)
else
	warn("[WitchNPC] Witch model not found (name should be 'Witch' or 'Wiedzma').")
end
