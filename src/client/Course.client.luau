-- Shift maintenu : course ; relâchement, saisie ou perte de focus : marche.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Deplacement"))
local joueur = Players.LocalPlayer
local humanoide: Humanoid? = nil
local piste: AnimationTrack? = nil
local touches = {}
local generation = 0

local function bloque(): boolean
	return joueur:GetAttribute("Fige") == true or joueur:GetAttribute("KO") == true
end

local function actualiserVitesse()
	if not humanoide then return end
	local course = next(touches) ~= nil and UserInputService:GetFocusedTextBox() == nil
	local ralenti = humanoide:GetAttribute("PMU_RalentiCombat")
	humanoide.WalkSpeed = if humanoide.Health <= 0 or bloque() then 0
		elseif ralenti then Config.vitesseMarche * ralenti
		elseif course then Config.vitesseCourse else Config.vitesseMarche
end

local function relacher()
	table.clear(touches)
	actualiserVitesse()
end

local function preparer(personnage: Model)
	generation += 1
	local numero = generation
	if piste then piste:Stop(0); piste:Destroy(); piste = nil end
	humanoide = nil
	relacher()
	local h = personnage:WaitForChild("Humanoid") :: Humanoid
	local animateur = h:WaitForChild("Animator") :: Animator
	if numero ~= generation or joueur.Character ~= personnage then return end
	humanoide = h
	h:GetAttributeChangedSignal("PMU_RalentiCombat"):Connect(function()
		if humanoide == h then actualiserVitesse() end
	end)
	h.Died:Connect(function()
		if humanoide == h then relacher() end
	end)
	actualiserVitesse()
	local animation = Instance.new("Animation")
	animation.AnimationId = Config.animations[h.RigType.Name]
	local ok, resultat = pcall(function() return animateur:LoadAnimation(animation) end)
	animation:Destroy()
	if not ok then warn(`[Course] Chargement de l'animation impossible : {resultat}`); return end
	if numero ~= generation then resultat:Destroy(); return end
	piste = resultat
	piste.Priority = Enum.AnimationPriority.Movement
	piste.Looped = true
end

-- Shift pour courir ; le verrouillage souris du jeu reste sur Ctrl.
ContextActionService:BindActionAtPriority("PMU_Courir", function(_, etat, entree)
	if etat == Enum.UserInputState.End or etat == Enum.UserInputState.Cancel then
		touches[entree.KeyCode] = nil
	elseif etat == Enum.UserInputState.Begin then
		if UserInputService:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		touches[entree.KeyCode] = true
	end
	actualiserVitesse()
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
UserInputService.WindowFocusReleased:Connect(relacher)
UserInputService.TextBoxFocused:Connect(relacher)
joueur:GetAttributeChangedSignal("Fige"):Connect(actualiserVitesse)
joueur:GetAttributeChangedSignal("KO"):Connect(actualiserVitesse)

RunService.Heartbeat:Connect(function()
	local h, p = humanoide, piste
	if not h or not p then return end
	local etat = h:GetState()
	local auSol = etat == Enum.HumanoidStateType.Running
	local racine = h.RootPart
	local vitesse = if racine then (racine.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude else 0
	local courir = next(touches) ~= nil and h.Health > 0 and auSol and not bloque()
		and h.MoveDirection.Magnitude > 0.1 and vitesse > 0.5
		and not h:GetAttribute("PMU_RalentiCombat")
	if courir then
		if not p.IsPlaying then p:Play(Config.fondu) end
		p:AdjustSpeed(math.clamp(vitesse / Config.vitesseAnimation, 0.5, 2.5))
	elseif p.IsPlaying then p:Stop(Config.fondu) end
end)

joueur.CharacterRemoving:Connect(function()
	generation += 1
	relacher()
	if piste then piste:Stop(0); piste:Destroy(); piste = nil end
	humanoide = nil
end)
joueur.CharacterAdded:Connect(preparer)
if joueur.Character then task.spawn(preparer, joueur.Character) end
