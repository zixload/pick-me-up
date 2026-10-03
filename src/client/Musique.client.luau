-- Musique de fond : jouée en boucle pour chaque joueur, avec une montée douce à l'arrivée.
-- « Celestial Kingdom - Orchestral Dream » (Creator Store), choisie le 03/10/2026.
-- Plus tard, une musique par lieu (base, combat, boss) : voir audio/selection_sfx_v01.md.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local MUSIQUE = "rbxassetid://126726964341960"
local VOLUME = 0.3
local MONTEE = 4   -- secondes

local son = Instance.new("Sound")
son.Name = "Musique_Base"
son.SoundId = MUSIQUE
son.Looped = true
son.Volume = 0
son.Parent = SoundService
son:Play()
TweenService:Create(son, TweenInfo.new(MONTEE), {Volume = VOLUME}):Play()
