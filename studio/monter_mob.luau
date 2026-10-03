-- Monte un mob à partir de son FBX importé (Model avec un MeshPart à os + AnimationController) :
--   * pièce racine invisible (HumanoidRootPart) centrée sur le bassin (os Hips ou HumanoidRootPart), sans rotation :
--     le modèle doit regarder vers -Z (vérifié pour les rigs Mixamo exportés par mixamo_vers_roblox.py) ;
--   * Humanoid à la place de l'AnimationController (son Animator joue les os) : hauteur des hanches calculée
--     d'après le bas du maillage, pas d'os Neck exigé, pas de démembrement à la mort ;
--   * maillage soudé à la racine, sans collision ni masse ; sauvegardes d'animation retirées de la copie.
-- Le résultat va dans ServerStorage.Mobs.<NOM>. À lancer en mode édition.
local SOURCE, NOM = "Gobelin_Guerrier_mixamo_rig", "Gobelin_Guerrier"

local ServerStorage = game:GetService("ServerStorage")
local source = workspace:FindFirstChild(SOURCE)
assert(source, "importer d'abord " .. SOURCE)
local m = source:Clone()
m.Name = NOM
local piece = m:FindFirstChild(NOM)
local bassin = piece:FindFirstChild("Hips", true) or piece:FindFirstChild("HumanoidRootPart", true)
for _, c in m:GetChildren() do
	if c:IsA("AnimationController") or c.Name == "AnimSaves" or c.Name == "InitialPoses" then c:Destroy() end
end
local bas = piece.Position.Y - piece.Size.Y / 2
local racine = Instance.new("Part")
racine.Name = "HumanoidRootPart"
racine.Size = Vector3.new(piece.Size.X * 0.4, piece.Size.Y * 0.38, piece.Size.Z * 0.5)
racine.CFrame = CFrame.new(piece.Position.X, bassin.WorldPosition.Y, piece.Position.Z)
racine.Transparency, racine.CanCollide, racine.CanTouch = 1, true, false
racine.Parent = m
piece.CanCollide, piece.Massless, piece.Anchored = false, true, false
local soudure = Instance.new("WeldConstraint")
soudure.Part0, soudure.Part1 = racine, piece
soudure.Parent = racine
m.PrimaryPart = racine
local h = Instance.new("Humanoid")
h.RigType = Enum.HumanoidRigType.R15
h.AutomaticScalingEnabled = false
h.RequiresNeck = false
h.BreakJointsOnDeath = false
h.HipHeight = (racine.Position.Y - racine.Size.Y / 2) - bas
h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
Instance.new("Animator").Parent = h
h.Parent = m
local dossier = ServerStorage:FindFirstChild("Mobs") or Instance.new("Folder")
dossier.Name, dossier.Parent = "Mobs", ServerStorage
local ancien = dossier:FindFirstChild(NOM)
if ancien then ancien:Destroy() end
m:PivotTo(CFrame.new(0, racine.Size.Y / 2 + h.HipHeight, 0))
m.Parent = dossier
return string.format("%s monté dans ServerStorage.Mobs : racine %s, hanches %.2f studs", NOM, tostring(racine.Size), h.HipHeight)
