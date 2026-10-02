-- Bâtiments de la base : nom affiché, modèles à afficher, construction, coût, position de la borne.
-- Les valeurs sont un premier jet, à rééquilibrer ensemble. Positions : centres du plan directeur ×1,5.
-- Règles de progression (décidées le 02/10/2026) :
--   * les lots de LOTS s'améliorent contre de l'or et des matériaux ; le niveau qui fait changer
--     de style est en plus verrouillé tant que l'étage de Tour du palier n'est pas franchi ;
--   * les lots d'AUTOMATIQUES ne s'achètent pas : leur style suit l'étage atteint dans la Tour ;
--   * le niveau du joueur (combat, compétences) ne joue aucun rôle ici.
-- Champs d'un lot :
--   depart   : niveau au premier lancement (1 = construit, 0 = emplacement réservé à construire)
--   parent   : {LotId, niveau} que doit atteindre ce bâtiment pour qu'on puisse construire le lot
--   cout     : coût en or du niveau 2 ; chaque niveau suivant coûte CROISSANCE fois plus
--   dosage   : poids des deux matériaux du palier visé (1 par défaut)
--   visuels  : lots de ServerStorage.Batiments affichés selon le palier
local Batiments = {}

Batiments.NIVEAU_MAX = 20
Batiments.CROISSANCE = 1.35
-- palier de style : niveau de bâtiment qui le fait apparaître, étage de Tour qui le déverrouille.
-- Trois paliers pour l'instant (02/10/2026) : P1 pierre gris-bleu, P2 roche noir nuit, P3 quartz et or.
Batiments.SEUILS_PALIERS = {
	{palier = 1, niveau = 1, etage = 0},
	{palier = 2, niveau = 5, etage = 10},
	{palier = 3, niveau = 20, etage = 50},
}
-- matériaux d'une amélioration : cout / MATERIAUX_DIVISEUR unités au niveau 2, puis
-- MATERIAUX_CROISSANCE fois plus par niveau ; le niveau qui change de style en demande MATERIAUX_SEUIL fois plus
Batiments.MATERIAUX_DIVISEUR = 20
Batiments.MATERIAUX_CROISSANCE = 1.18
Batiments.MATERIAUX_SEUIL = 2

Batiments.ORDRE = {
	"Invocation", "Chambre_Synthese", "Entrainement", "Terrain_Magique", "Academie_Magie", "Station_Transfert",
	"Logements", "Logements_Annexe", "Cantine", "Forge", "Traitement_Metaux", "Menuiserie",
	"Infirmerie", "Administration",
}

Batiments.LOTS = {
	-- nom : affiché au joueur, donc en anglais (noms anglais du webtoon)
	Invocation = {nom = "Summoning Hall", visuels = {"Invocation"}, depart = 1, cout = 300, position = {18, -123}},
	Chambre_Synthese = {nom = "Synthesis Chamber", visuels = {"Chambre_Synthese"}, depart = 0, parent = {"Invocation", 5},
		cout = 1000, position = {75, -135}},
	Entrainement = {nom = "Training Center", visuels = {"Entrainement"}, depart = 1, cout = 250, position = {-84, -126}},
	Terrain_Magique = {nom = "Magic Training Grounds", visuels = {"Terrain_Magique"}, depart = 0, parent = {"Entrainement", 10},
		cout = 2000, position = {-33, -151.5}},
	Academie_Magie = {nom = "Magic Academy", visuels = {"Academie_Magie"}, depart = 0, parent = {"Entrainement", 10},
		cout = 1500, position = {82.5, -40.5}},
	Station_Transfert = {nom = "Transfer Station", visuels = {"Station_Transfert"}, depart = 0, parent = {"Entrainement", 15},
		cout = 2500, position = {-45, -84}},
	Logements = {nom = "Lodging", visuels = {"Logements"}, depart = 1, cout = 200, dosage = {0.6, 1.4}, position = {-130.5, -78}},
	Logements_Annexe = {nom = "Lodging Annex", visuels = {"Logements_Annexe"}, depart = 1, cout = 200, dosage = {0.6, 1.4},
		position = {-132, -16.5}},
	Cantine = {nom = "Restaurant", visuels = {"Cantine"}, depart = 1, cout = 200, position = {-139.5, 52.5}},
	Forge = {nom = "Smithy", visuels = {"Forge"}, depart = 1, cout = 250, dosage = {1.4, 0.6}, position = {-52.5, 82.5}},
	Traitement_Metaux = {nom = "Metal Processing", visuels = {"Traitement_Metaux"}, depart = 1, cout = 250, dosage = {1.4, 0.6},
		position = {-54, 138}},
	Menuiserie = {nom = "Woodworking Shop", visuels = {"Menuiserie"}, depart = 0, parent = {"Forge", 5}, cout = 600,
		dosage = {0.6, 1.4}, position = {-91.5, 132}},
	Infirmerie = {nom = "Infirmary", visuels = {"Infirmerie"}, depart = 1, cout = 200, position = {51, 138}},
	Administration = {nom = "Administration", visuels = {"Administration"}, depart = 1, cout = 200, position = {144, -67.5}},
}

-- Lots dont le style suit la Tour (la place fait partie du sol de l'enceinte)
Batiments.AUTOMATIQUES = {
	Enceinte = {nom = "Rampart & Pavement", visuels = {"Rempart", "Sol"}},
	Faille = {nom = "Space-Time Rift", visuels = {"Faille"}},
}

return Batiments
