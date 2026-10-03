-- Offres du jour : cadeau gratuit quotidien et marché de 3 échanges payés en or, renouvelés à 4 h (heure de Paris).
-- Le serveur tire les échanges, vérifie l'or et les limites, puis donne le contenu. Catalogue : Config/Offres.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Donnees = require(script.Parent.Donnees)
local Config = require(ReplicatedStorage.Shared.Config.Offres)
local Calendrier = require(ReplicatedStorage.Shared.Config.Quetes)
local Materiaux = require(ReplicatedStorage.Shared.Config.Materiaux)

local Offres = {}
local hasard = Random.new()

local function distant(classe, nom)
	local reseau = ReplicatedStorage:FindFirstChild("Reseau") or Instance.new("Folder")
	reseau.Name = "Reseau"
	reseau.Parent = ReplicatedStorage
	local r = reseau:FindFirstChild(nom) or Instance.new(classe)
	r.Name = nom
	r.Parent = reseau
	return r
end

-- nouveau jour : cadeau de nouveau disponible, nouveaux échanges tirés
local function renouveler(o)
	local jour = Calendrier.calendrier(os.time()).jour
	if o.Jour == jour then return end
	o.Jour, o.Cadeau, o.Echanges = jour, false, {}
	local pool = table.clone(Config.ECHANGES)
	for _ = 1, math.min(Config.NB_ECHANGES, #pool) do
		local e = table.remove(pool, hasard:NextInteger(1, #pool))
		table.insert(o.Echanges, {id = e.id, achats = 0})
	end
end

local function etat(joueur: Player)
	local d = Donnees.profil(joueur)
	if not d then return nil end
	renouveler(d.Offres)
	return {cadeau = d.Offres.Cadeau, echanges = d.Offres.Echanges,
		prochainJour = Calendrier.calendrier(os.time()).prochainJour}
end

local function ajouter(x, contenu)
	x.Or += contenu.Or or 0
	for id, n in contenu.Materiaux or {} do
		if Materiaux.NOMS[id] then x.Materiaux[id] = (x.Materiaux[id] or 0) + n end
	end
end

function Offres.demarrer()
	local Lire = distant("RemoteFunction", "LireOffres")           -- client -> serveur : offres du jour
	local Cadeau = distant("RemoteFunction", "PrendreCadeau")      -- client -> serveur : -> ok, message, état
	local Echanger = distant("RemoteFunction", "EchangerOffre")    -- client -> serveur : (id) -> ok, message, état
	Lire.OnServerInvoke = etat
	Cadeau.OnServerInvoke = function(joueur)
		local d = Donnees.profil(joueur)
		if not d then return false, "Your progress hasn't loaded yet." end
		renouveler(d.Offres)
		if d.Offres.Cadeau then return false, "Already claimed today. Come back tomorrow!", etat(joueur) end
		Donnees.modifier(joueur, function(x)
			x.Offres.Cadeau = true
			ajouter(x, Config.CADEAU.contenu)
		end)
		return true, "Gift claimed!", etat(joueur)
	end
	Echanger.OnServerInvoke = function(joueur, id)
		local d = Donnees.profil(joueur)
		if not d then return false, "Your progress hasn't loaded yet." end
		if type(id) ~= "string" then return false, "Unknown offer." end
		renouveler(d.Offres)
		local offre = Config.echange(id)
		local entree = nil
		for _, e in d.Offres.Echanges do
			if e.id == id then entree = e end
		end
		if not offre or not entree then return false, "This offer isn't available today.", etat(joueur) end
		if entree.achats >= offre.limite then return false, "Sold out for today.", etat(joueur) end
		if d.Or < offre.prix then return false, `You need {offre.prix - d.Or} more gold.`, etat(joueur) end
		Donnees.modifier(joueur, function(x)
			x.Or -= offre.prix
			entree.achats += 1
			ajouter(x, offre.contenu)
		end)
		return true, "Trade complete!", etat(joueur)
	end
end

return Offres
