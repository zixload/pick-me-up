local W=workspace
local SS=game:GetService("ServerStorage")
local L=game:GetService("Lighting")
local CS=game:GetService("CollectionService")
local CH=game:GetService("ChangeHistoryService")
CH:SetWaypoint("Avant construction base Pick me up")
assert(not W:FindFirstChild("PMU_Base"), "PMU_Base existe deja")
local backup=Instance.new("Folder") backup.Name="PMU_OriginalScene" backup.Parent=SS
local oldLight=Instance.new("Folder") oldLight.Name="Lighting" oldLight.Parent=backup
for _,x in ipairs(L:GetChildren()) do x.Parent=oldLight end
for _,k in ipairs({"ClockTime","Brightness","Ambient","OutdoorAmbient","ExposureCompensation","EnvironmentDiffuseScale","EnvironmentSpecularScale","GlobalShadows"}) do
 pcall(function() backup:SetAttribute("Lighting_"..k,L[k]) end)
end
for _,x in ipairs(W:GetChildren()) do
 if x.Name~="Terrain" and x.Name~="Camera" then x.Parent=backup end
end
local base=Instance.new("Model") base.Name="PMU_Base" base:SetAttribute("DesignVersion","01 - cour circulaire") base.Parent=W
local function group(name) local x=Instance.new("Model") x.Name=name x.Parent=base return x end
local ground=group("01_Sols_et_Chemins")
local walls=group("02_Enceinte")
local district=group("03_Batiments")
local shrine=group("04_Sanctuaires")
local flora=group("05_Jardins")
local deco=group("06_Mobilier")
local markers=group("07_Reperes_Gameplay")
local colors={
 stone=Color3.fromRGB(103,116,119),light=Color3.fromRGB(164,179,176),
 dark=Color3.fromRGB(56,72,78),roof=Color3.fromRGB(46,67,77),
 wood=Color3.fromRGB(67,56,46),gold=Color3.fromRGB(157,145,106),
 cyan=Color3.fromRGB(117,218,222),grass=Color3.fromRGB(45,76,62),
 path=Color3.fromRGB(137,155,156),warm=Color3.fromRGB(255,198,122)}
local function part(parent,name,size,cf,color,mat,collide)
 local p=Instance.new("Part") p.Name=name p.Size=size p.CFrame=cf p.Color=color or colors.stone
 p.Material=mat or Enum.Material.Slate p.Anchored=true p.TopSurface=Enum.SurfaceType.Smooth
 p.BottomSurface=Enum.SurfaceType.Smooth p.CanCollide=collide~=false
 p.CanTouch=false p.Parent=parent return p
end
local function box(pa,n,x,y,z,sx,sy,sz,c,m,coll) return part(pa,n,Vector3.new(sx,sy,sz),CFrame.new(x,y,z),c,m,coll) end
local function cyl(pa,n,x,y,z,r,h,c,m,coll)
 local p=part(pa,n,Vector3.new(h,r*2,r*2),CFrame.new(x,y,z)*CFrame.Angles(0,0,math.pi/2),c,m,coll)
 p.Shape=Enum.PartType.Cylinder return p
end
local function beam(pa,n,a,b,w,h,c,m,coll)
 local delta=b-a return part(pa,n,Vector3.new(w,h or w,delta.Magnitude),CFrame.lookAt((a+b)/2,b),c,m,coll)
end
local function ring(pa,n,x,y,z,r,w,h,c,m,segments)
 local count=segments or 48
 for i=1,count do
  local a=(i-1)*math.pi*2/count local b=i*math.pi*2/count
  beam(pa,n,Vector3.new(x+math.cos(a)*r,y,z+math.sin(a)*r),Vector3.new(x+math.cos(b)*r,y,z+math.sin(b)*r),w,h,c,m,false)
 end
end
local function light(pa,c,brightness,range)
 local l=Instance.new("PointLight") l.Color=c l.Brightness=brightness l.Range=range l.Shadows=false l.Parent=pa
end
local function label(pa,cf,text,w)
 local board=part(pa,"Enseigne",Vector3.new(w or 10,2.1,.35),cf,colors.dark,Enum.Material.Slate,false)
 local gui=Instance.new("SurfaceGui") gui.Face=Enum.NormalId.Front gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud
 gui.PixelsPerStud=45 gui.LightInfluence=.5 gui.Parent=board
 local txt=Instance.new("TextLabel") txt.Size=UDim2.fromScale(1,1) txt.BackgroundTransparency=1
 txt.Text=text txt.TextColor3=colors.light txt.Font=Enum.Font.GothamMedium txt.TextScaled=true txt.Parent=gui
end
-- The stone deck is circular; all details above it stay within the enclosure.
cyl(ground,"Fondation",0,-2,0,145,4,colors.dark,Enum.Material.Rock)
cyl(ground,"Cour",0,.15,0,140,.7,colors.path,Enum.Material.Cobblestone)
ring(ground,"Bordure",0,.65,0,137,2,.7,colors.light,Enum.Material.Concrete,64)
cyl(ground,"Place_Centrale",0,.55,8,25,.6,colors.light,Enum.Material.Concrete)
ring(ground,"Rosace_Exterieure",0,.91,8,21,.25,.08,colors.gold,Enum.Material.Metal)
ring(ground,"Rosace_Interieure",0,.91,8,16,.18,.08,colors.dark,Enum.Material.Metal)
for i=1,12 do
 local a=i*math.pi/6
 beam(ground,"Rayon_Rosace",Vector3.new(math.cos(a)*16,.91,8+math.sin(a)*16),Vector3.new(math.cos(a)*21,.91,8+math.sin(a)*21),.18,.08,colors.gold,Enum.Material.Metal,false)
end
local function path(x,z,sx,sz)
 box(ground,"Allee",x,.7,z,sx,.45,sz,colors.light,Enum.Material.Concrete)
 if sx>sz then
  box(ground,"Bordure_Allee",x,.95,z-sz/2-.35,sx,.35,.6,colors.dark)
  box(ground,"Bordure_Allee",x,.95,z+sz/2+.35,sx,.35,.6,colors.dark)
 else
  box(ground,"Bordure_Allee",x-sx/2-.35,.95,z,.6,.35,sz,colors.dark)
  box(ground,"Bordure_Allee",x+sx/2+.35,.95,z,.6,.35,sz,colors.dark)
 end
end
path(0,71,16,91) path(0,-37,16,66)
path(-48,8,55,12) path(44,8,40,12)
path(-58,-30,12,64) path(-58,56,12,72)
path(49,-57,74,12) path(67,55,12,74)
-- Reusable wall bays with coping, pilasters and recessed panels.
local radius=140 local count=48
for i=1,count do
 local a=(i-.5)*math.pi*2/count
 local cf=CFrame.new(math.cos(a)*radius,0,math.sin(a)*radius)*CFrame.Angles(0,-a,0)
 local len=2*radius*math.tan(math.pi/count)+.25
 part(walls,"Mur_"..i,Vector3.new(4,31,len),cf*CFrame.new(0,15.5,0),colors.stone,Enum.Material.Brick)
 part(walls,"Plinthe",Vector3.new(5,3,len),cf*CFrame.new(0,1.5,0),colors.dark)
 part(walls,"Corniche",Vector3.new(6,2,len+.2),cf*CFrame.new(0,31,0),colors.light)
 part(walls,"Panneau",Vector3.new(.3,20,len-3),cf*CFrame.new(-2.18,16,0),colors.dark,Enum.Material.Slate,false)
 part(walls,"Cadre_Haut",Vector3.new(.5,.65,len-3),cf*CFrame.new(-2.35,26,0),colors.light,nil,false)
 part(walls,"Cadre_Bas",Vector3.new(.5,.65,len-3),cf*CFrame.new(-2.35,6,0),colors.light,nil,false)
 if i%2==0 then
  part(walls,"Contrefort",Vector3.new(7,34,2.5),cf*CFrame.new(-.5,17,len/2),colors.dark)
  part(walls,"Chapiteau",Vector3.new(9,2,4),cf*CFrame.new(-.5,34,len/2),colors.light)
 end
end
local function lantern(cf,pa)
 part(pa,"Pied_Lanterne",Vector3.new(.45,7,.45),cf*CFrame.new(0,3.5,0),colors.dark,Enum.Material.Metal)
 part(pa,"Socle_Lanterne",Vector3.new(1.4,.5,1.4),cf*CFrame.new(0,.75,0),colors.light)
 local p=part(pa,"Lanterne",Vector3.new(.85,1.5,.85),cf*CFrame.new(0,7.7,0),colors.warm,Enum.Material.Neon,false)
 part(pa,"Chapeau_Lanterne",Vector3.new(1.4,.35,1.4),cf*CFrame.new(0,8.6,0),colors.dark)
 light(p,colors.warm,.75,16)
end
-- Hollow, enterable houses built from the same restrained stone/wood kit.
local function house(name,x,z,w,d,angle)
 local h=11 local m=Instance.new("Model") m.Name=name m.Parent=district m:SetAttribute("FacilityId",name)
 CS:AddTag(m,"PMU_Facility")
 local origin=CFrame.new(x,0,z)*CFrame.Angles(0,angle or 0,0)
 local function p(n,sx,sy,sz,px,py,pz,c,mat,coll)
  return part(m,n,Vector3.new(sx,sy,sz),origin*CFrame.new(px,py,pz),c,mat,coll)
 end
 p("Fondation",w+2,1.2,d+2,0,1,0,colors.dark)
 p("Sol",w,.35,d,0,1.85,0,colors.wood,Enum.Material.WoodPlanks)
 p("Mur_Fond",w,h,.8,0,h/2+1.7,-d/2,colors.stone,Enum.Material.Brick)
 p("Mur_Gauche",.8,h,d,-w/2,h/2+1.7,0,colors.stone,Enum.Material.Brick)
 p("Mur_Droit",.8,h,d,w/2,h/2+1.7,0,colors.stone,Enum.Material.Brick)
 local fw=(w-6)/2
 p("Facade_Gauche",fw,h,.8,-3-fw/2,h/2+1.7,d/2,colors.stone,Enum.Material.Brick)
 p("Facade_Droite",fw,h,.8,3+fw/2,h/2+1.7,d/2,colors.stone,Enum.Material.Brick)
 p("Linteau",6,3,.9,0,11.2,d/2,colors.light)
 p("Encadrement",.55,8,.95,-3.2,5.8,d/2+.2,colors.light)
 p("Encadrement",.55,8,.95,3.2,5.8,d/2+.2,colors.light)
 for _,side in ipairs({-1,1}) do
  p("Angle",.8,h+1,1,side*w/2,7,d/2,colors.dark)
  p("Angle",.8,h+1,1,side*w/2,7,-d/2,colors.dark)
  local win=p("Fenetre",3,3,.14,side*(w/2-3),7.5,d/2+.46,Color3.fromRGB(199,182,125),Enum.Material.Glass,false)
  win.Transparency=.15
  p("Montant_Fenetre",.15,3,.2,side*(w/2-3),7.5,d/2+.56,colors.dark,nil,false)
  p("Traverse_Fenetre",3,.15,.2,side*(w/2-3),7.5,d/2+.56,colors.dark,nil,false)
  local span=w/2+1.5 local rise=5 local slen=math.sqrt(span*span+rise*rise)
  local roof=part(m,"Toit_Ardoise",Vector3.new(slen,.8,d+3),origin*CFrame.new(side*span/2,15.2,0)*CFrame.Angles(0,0,-side*math.atan(rise/span)),colors.roof,Enum.Material.Slate)
  for j=1,5 do
   local xx=side*span*j/6 local yy=17.7-5*j/6
   part(m,"Joint_Toiture",Vector3.new(.14,.14,d+3.1),origin*CFrame.new(xx,yy+.45,0),colors.dark,nil,false)
  end
 end
 p("Faitage",.9,.6,d+3.5,0,18,0,colors.gold,Enum.Material.Metal)
 p("Ceinture",w+1,.65,d+1,0,12.8,0,colors.dark)
 p("Marche",8,.5,4,0,1,d/2+2,colors.light)
 p("Marche",9,.35,2,0,.65,d/2+4,colors.light)
 p("Cheminee",2,5,2,-w/4,16,-d/4,colors.dark,Enum.Material.Brick)
 p("Chapeau_Cheminee",2.8,.6,2.8,-w/4,18.8,-d/4,colors.light)
 label(m,origin*CFrame.new(0,11.5,d/2+.8)*CFrame.Angles(0,math.pi,0),string.upper(name:gsub("_"," ")),math.min(w-2,15))
 lantern(origin*CFrame.new(w/2+3,0,d/2+2),m)
 local marker=p("InteractionPoint",1,1,1,0,3,d/2+5,colors.cyan,nil,false)
 marker.Transparency=1 CS:AddTag(marker,"PMU_InteractionPoint")
 return m
end
house("Dortoirs",-87,-54,22,19,0)
house("Dortoirs_Annexe",-88,-13,22,19,0)
house("Cantine",-91,35,26,24,-math.pi/2)
house("Forge",-37,55,25,22,math.pi/2)
house("Atelier",-38,93,20,18,math.pi/2)
house("Infirmerie",34,90,22,22,0)
house("Administration",98,-45,22,24,-math.pi/2)
-- Training court with an accessible boundary and props.
local training=Instance.new("Model") training.Name="Entrainement" training.Parent=district
training:SetAttribute("FacilityId","Training") CS:AddTag(training,"PMU_Facility")
box(training,"Plateau",-66,.9,-91,45,.7,31,Color3.fromRGB(140,134,116),Enum.Material.Sand)
for _,x in ipairs({-88,-44}) do box(training,"Muret",x,1.6,-91,.8,1,32,colors.light) end
box(training,"Muret",-66,1.6,-106,45,1,.8,colors.light)
for i=1,4 do
 local x=-82+(i-1)*10
 box(training,"Mannequin_Pied",x,2.8,-98,.6,4,.6,colors.wood,Enum.Material.Wood)
 box(training,"Mannequin_Corps",x,4.5,-98,2.5,3,1.4,Color3.fromRGB(144,112,72),Enum.Material.Wood)
 box(training,"Mannequin_Bras",x,5,-98,4,.45,.5,colors.wood,Enum.Material.Wood)
 local head=box(training,"Mannequin_Tete",x,6.7,-98,1.2,1.2,1.2,colors.wood) head.Shape=Enum.PartType.Ball
end
label(training,CFrame.new(-66,3,-75)*CFrame.Angles(0,math.pi,0),"ENTRAINEMENT",16)
-- Northern rotunda: colonnade, raised stone platform, stepped dome and magic rosette.
local function rotunda(name,x,z,r,roofed)
 local m=Instance.new("Model") m.Name=name m.Parent=shrine m:SetAttribute("FacilityId",name) CS:AddTag(m,"PMU_Facility")
 cyl(m,"Socle",x,1,z,r+4,1.4,colors.dark)
 cyl(m,"Plateau",x,1.9,z,r+2,.5,colors.light,Enum.Material.Concrete)
 ring(m,"Anneau_Metal",x,2.21,z,r-2,.3,.07,colors.gold,Enum.Material.Metal)
 for i=1,12 do
  local a=i*math.pi/6 local px=x+math.cos(a)*r local pz=z+math.sin(a)*r
  cyl(m,"Base_Colonne",px,2.8,pz,1.5,1.2,colors.dark)
  cyl(m,"Colonne",px,10,pz,.8,13.5,colors.light)
  cyl(m,"Chapiteau",px,16.9,pz,1.5,1,colors.gold,Enum.Material.Metal)
 end
 if roofed then
  cyl(m,"Entablement",x,18,z,r+2,1.8,colors.dark)
  ring(m,"Corniche",x,19.2,z,r+1,.8,.5,colors.gold,Enum.Material.Metal)
  local domeR=r+1
  for i=0,12 do
   local yy=i*.8 local rr=math.sqrt(math.max(1,domeR*domeR-(yy*1.6)^2))
   cyl(m,"Dome",x,19.8+yy,z,rr,.82,colors.roof,Enum.Material.Slate)
  end
  cyl(m,"Couronnement",x,30.2,z,2,1.8,colors.gold,Enum.Material.Metal)
 else
  ring(m,"Couronne",x,18,z,r+.5,1.4,1.6,colors.dark)
 end
 return m
end
local hall=rotunda("Salle_Invocation",12,-82,18,true)
ring(hall,"Cercle_Invocation",12,2.3,-82,10,.3,.1,colors.cyan,Enum.Material.Neon,40)
ring(hall,"Cercle_Invocation",12,2.3,-82,5,.2,.1,colors.cyan,Enum.Material.Neon,32)
for i=1,8 do
 local a=i*math.pi/4
 beam(hall,"Glyphe",Vector3.new(12+math.cos(a)*6,2.3,-82+math.sin(a)*6),Vector3.new(12+math.cos(a)*9,2.3,-82+math.sin(a)*9),.25,.1,colors.gold,Enum.Material.Metal,false)
end
label(hall,CFrame.new(12,5,-60)*CFrame.Angles(0,math.pi,0),"INVOCATION",14)
local portal=rotunda("Faille_SpatioTemporelle",78,29,20,false)
for i=1,56 do
 local a=(i-1)*math.pi*2/56 local b=i*math.pi*2/56
 local aa=Vector3.new(78+math.cos(a)*8,11+math.sin(a)*8,29)
 local bb=Vector3.new(78+math.cos(b)*8,11+math.sin(b)*8,29)
 beam(portal,"Arche_Faille",aa,bb,.9,.9,colors.dark,Enum.Material.Metal,false)
 beam(portal,"Liseret_Faille",aa+Vector3.new(0,0,.6),bb+Vector3.new(0,0,.6),.2,.2,colors.cyan,Enum.Material.Neon,false)
end
local veil=part(portal,"Voile_Faille",Vector3.new(.16,15,15),CFrame.new(78,11,29)*CFrame.Angles(0,math.pi/2,0),colors.cyan,Enum.Material.Neon,false)
veil.Shape=Enum.PartType.Cylinder veil.Transparency=.58 light(veil,colors.cyan,1.2,25)
ring(portal,"Sceau_Sol",78,2.3,29,14,.3,.1,colors.cyan,Enum.Material.Neon,48)
for _,dx in ipairs({-12,12}) do
 box(portal,"Obelisque",78+dx,6,32,2.5,8,2.5,colors.dark)
 box(portal,"Rune_Obelisque",78+dx,6,33.3,.2,5,.12,colors.cyan,Enum.Material.Neon,false)
end
label(portal,CFrame.new(78,4,52)*CFrame.Angles(0,math.pi,0),"FAILLE",10)
-- Garden beds soften the architecture and leave main circulation open.
local beds={{-30,-27,25,24},{-29,26,24,19},{31,47,22,28},{44,-91,15,25},{-106,81,26,21},{102,80,22,25}}
for _,b in ipairs(beds) do
 box(flora,"Jardin",b[1],.8,b[2],b[3],.45,b[4],colors.grass,Enum.Material.Grass)
 for _,s in ipairs({-1,1}) do
  box(flora,"Bordure",b[1]+s*b[3]/2,1,b[2],.6,.5,b[4]+.6,colors.light)
  box(flora,"Bordure",b[1],1,b[2]+s*b[4]/2,b[3]+.6,.5,.6,colors.light)
 end
end
local pack=game.ReplicatedStorage.PMU_AssetLibrary:FindFirstChild("Yasu's Stylized Tree Pack")
local trees=pack.Models_Trees.Models
local bushes=pack.Models_Bushes.Models
local function plant(source,name,x,z,scale,rotation)
 local p=source:Clone() p.Name=name p:ScaleTo(scale) p.Parent=flora
 p:PivotTo(CFrame.new(x,0,z)*CFrame.Angles(0,rotation or 0,0))
 local cf,sz=p:GetBoundingBox()
 p:PivotTo(p:GetPivot()+Vector3.new(0,1-cf.Position.Y+sz.Y/2,0))
 for _,v in ipairs(p:GetDescendants()) do if v:IsA("BasePart") then v.Anchored=true v.CanCollide=false v.CanTouch=false end end
 return p
end
local tp={{-30,-27},{-29,26},{31,47},{44,-91},{-108,80},{102,80},{-112,-63},{-106,-98},{-112,-25},{-122,13},{-105,57},{-74,101},{-29,119},{30,119},{93,92},{119,52},{121,7},{109,-81},{76,-104},{-31,-119}}
for i,v in ipairs(tp) do plant(trees["Tree_"..string.format("%02d",i%6+1)],"Arbre_"..i,v[1],v[2],.33+(i%3)*.05,i*.8) end
for i,b in ipairs(beds) do
 for j=1,6 do
  local a=j*math.pi/3 local xx=b[1]+math.cos(a)*b[3]*.28 local zz=b[2]+math.sin(a)*b[4]*.28
  plant(bushes["Bush_0"..(j%3+1)],"Buisson",xx,zz,.27,j)
 end
end
for _,p in ipairs({{-12,80},{12,80},{-12,43},{12,43},{-12,-35},{12,-35},{-46,8},{40,8},{55,-57},{90,57}}) do lantern(CFrame.new(p[1],0,p[2]),deco) end
local function bench(x,z,a)
 local cf=CFrame.new(x,0,z)*CFrame.Angles(0,a or 0,0)
 part(deco,"Banc_Assise",Vector3.new(7,.45,2),cf*CFrame.new(0,2.4,0),colors.wood,Enum.Material.WoodPlanks)
 part(deco,"Banc_Dossier",Vector3.new(7,2,.35),cf*CFrame.new(0,3.5,-.8),colors.wood,Enum.Material.WoodPlanks)
 for _,s in ipairs({-1,1}) do part(deco,"Banc_Pied",Vector3.new(.55,2,1.7),cf*CFrame.new(s*2.5,1.4,0),colors.dark) end
end
bench(-25,1,math.pi/2) bench(-25,19,math.pi/2) bench(27,1,-math.pi/2) bench(27,19,-math.pi/2)
-- Small central memory monument.
cyl(deco,"Socle_Monument",0,1.4,8,3,1,colors.dark)
local crystal=part(deco,"Cristal_Memoire",Vector3.new(2,4,2),CFrame.new(0,4.5,8)*CFrame.Angles(0,math.pi/4,.12),colors.cyan,Enum.Material.Glass,false)
crystal.Transparency=.18 light(crystal,colors.cyan,.6,12)
local spawn=Instance.new("SpawnLocation") spawn.Name="Spawn_Heros" spawn.Size=Vector3.new(8,.4,8)
spawn.CFrame=CFrame.new(0,1.3,90) spawn.Anchored=true spawn.Neutral=true spawn.Transparency=1
spawn.CanCollide=false spawn.CanTouch=false spawn.Duration=0 spawn.Parent=markers CS:AddTag(spawn,"PMU_HeroSpawn")
L.ClockTime=16.8 L.Brightness=2.3 L.Ambient=Color3.fromRGB(86,110,123)
L.OutdoorAmbient=Color3.fromRGB(117,138,143) L.ExposureCompensation=.15 L.GlobalShadows=true
L.EnvironmentDiffuseScale=.65 L.EnvironmentSpecularScale=.7
local atmosphere=Instance.new("Atmosphere") atmosphere.Name="PMU_Atmosphere" atmosphere.Density=.2 atmosphere.Offset=.1
atmosphere.Color=Color3.fromRGB(174,210,220) atmosphere.Decay=Color3.fromRGB(77,98,125) atmosphere.Haze=1.2 atmosphere.Glare=.12 atmosphere.Parent=L
local bloom=Instance.new("BloomEffect") bloom.Name="PMU_Bloom" bloom.Intensity=.2 bloom.Size=18 bloom.Threshold=1.4 bloom.Parent=L
local cc=Instance.new("ColorCorrectionEffect") cc.Name="PMU_Etalonnage" cc.Saturation=-.12 cc.Contrast=.08 cc.TintColor=Color3.fromRGB(224,239,245) cc.Parent=L
W.CurrentCamera.CameraType=Enum.CameraType.Fixed W.CurrentCamera.CFrame=CFrame.lookAt(Vector3.new(220,240,260),Vector3.new(0,0,0))
CH:SetWaypoint("Base circulaire Pick me up - premiere version")
local parts=0 for _,v in ipairs(base:GetDescendants()) do if v:IsA("BasePart") then parts+=1 end end
return game:GetService("HttpService"):JSONEncode({base=base:GetFullName(),parts=parts,originals=backup:GetFullName(),facilities=#CS:GetTagged("PMU_Facility")})
