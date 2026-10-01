"""Build an original modular palace enclosure in Blender 4.5.

Run: blender --background --python build_wall_kit.py
All source geometry remains editable in the SOURCE collection. Export geometry
is triangulated, UV mapped into one shared atlas, and has consistent foot pivots.
"""
import bpy
import math
import random
import json
from pathlib import Path
from mathutils import Vector
from array import array

OUT = Path(__file__).resolve().parent
EXPORT = OUT / "exports"
TEX = OUT / "textures"
PREVIEW = OUT / "previews"
for directory in (EXPORT, TEX, PREVIEW):
    directory.mkdir(parents=True, exist_ok=True)
random.seed(712)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for col in list(bpy.data.collections):
    if col.name != "Collection":
        bpy.data.collections.remove(col)
scene = bpy.context.scene
scene.unit_settings.system = "NONE"
scene.unit_settings.scale_length = 1
scene["unit_convention"] = "1 Blender unit = 1 intended Roblox stud; bay spacing 16"
scene["design"] = "Original ivory palace enclosure inspired by user references"
root = bpy.data.collections.get("Collection")
root.name = "00_SOURCE_EDITABLE"
exports = bpy.data.collections.new("01_EXPORT_MODULES")
scene.collection.children.link(exports)
demo = bpy.data.collections.new("02_ASSEMBLAGE_DEMO")
scene.collection.children.link(demo)
display = bpy.data.collections.new("03_PRESENTATION")
scene.collection.children.link(display)

PALETTE = [
    ("Pierre_Ivoire", (0.76, 0.66, 0.51), 0.82, 0.0),
    ("Moulure_Claire", (0.92, 0.83, 0.65), 0.72, 0.0),
    ("Panneau_Creme", (0.84, 0.74, 0.58), 0.85, 0.0),
    ("Pierre_Ombre", (0.49, 0.38, 0.29), 0.90, 0.0),
    ("Or_Vieilli", (0.66, 0.40, 0.10), 0.39, 0.72),
    ("Feuille_Sombre", (0.16, 0.25, 0.065), 0.92, 0.0),
    ("Feuille_Verte", (0.31, 0.40, 0.11), 0.90, 0.0),
    ("Feuille_Claire", (0.48, 0.54, 0.20), 0.92, 0.0),
]
source_mats = []
for index, (name, color, rough, metal) in enumerate(PALETTE):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    mat["atlas_tile"] = index
    source_mats.append(mat)

def move_to(obj, col):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    col.objects.link(obj)
    return obj

def material(obj, index):
    obj.data.materials.append(source_mats[index])
    return obj

current = None
def begin(name):
    global current
    current = bpy.data.collections.new(name)
    root.children.link(current)
    return current

def block(name, center, size, mat=0, bevel=0.055):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    material(obj, mat)
    if bevel:
        mod = obj.modifiers.new("Aretes_adoucies", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.affect = "EDGES"
    move_to(obj, current)
    return obj

def frame(name, x, y, z, width, height, section, depth, mat=1):
    block(name + "_G", (x-width/2, y, z), (section, depth, height+section), mat, 0.022)
    block(name + "_D", (x+width/2, y, z), (section, depth, height+section), mat, 0.022)
    block(name + "_H", (x, y, z+height/2), (width-section, depth, section), mat, 0.022)
    block(name + "_B", (x, y, z-height/2), (width-section, depth, section), mat, 0.022)

def tube(name, points, radius, mat=4, sides=5):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 1
    curve.bevel_depth = radius
    curve.bevel_resolution = 0
    curve.resolution_u = 1
    curve.use_fill_caps = True
    spline = curve.splines.new("POLY")
    spline.points.add(len(points)-1)
    for v, co in zip(spline.points, points):
        v.co = (*co, 1)
    obj = bpy.data.objects.new(name, curve)
    current.objects.link(obj)
    material(obj, mat)
    return obj

def leaf(name, center, width, length, tilt=0, mat=4, front=-1):
    # Solid folded leaf, low triangle count, no alpha transparency required.
    x, y, z = center
    outline = [(0, -length/2), (-width*.40, -length*.20),
               (-width/2, length*.15), (-width*.20, length*.38),
               (0, length/2), (width*.20, length*.38),
               (width/2, length*.15), (width*.40, -length*.20)]
    coords=[]
    for xx, zz in outline:
        coords.append((x+xx*math.cos(tilt)-zz*math.sin(tilt), y,
                       z+xx*math.sin(tilt)+zz*math.cos(tilt)))
    coords.extend([(x, y+front*width*.16, z), (x, y-front*.025, z)])
    faces=[]
    for i in range(8):
        faces.append((i, (i+1)%8, 8))
        faces.append(((i+1)%8, i, 9))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(coords, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    current.objects.link(obj)
    material(obj, mat)
    return obj

def rosette(name, x, y, z, r=0.38, mat=4):
    for i in range(6):
        a=i*math.tau/6
        leaf(name, (x+math.sin(a)*r*.50,y,z+math.cos(a)*r*.50),
             r*.62,r*1.18,-a,mat)

def scroll(name, x, y, z, scale=1, sign=1):
    # Continuous S-shaped scroll terminating in a diminishing curl.
    pts=[]
    for i in range(24):
        a=i/23*math.pi*2.0
        r=(.52-.38*i/23)*scale
        pts.append((x+sign*(.52*scale+r*math.cos(a)),y,z+r*math.sin(a)))
    tube(name,pts,.055*scale)
    leaf(name+"_Feuille", (x+sign*.27*scale,y-.045,z-.36*scale),
         .34*scale,.70*scale,sign*.7,4)

def lathe(name, x, y, z, profile, mat=1, segments=10):
    verts=[]
    for height, radius in profile:
        for i in range(segments):
            a=i*math.tau/segments
            verts.append((x+radius*math.cos(a), y+radius*math.sin(a), z+height))
    faces=[]
    for j in range(len(profile)-1):
        for i in range(segments):
            ni=(i+1)%segments
            faces.append((j*segments+i,j*segments+ni,(j+1)*segments+ni,(j+1)*segments+i))
    faces.extend([tuple(reversed(range(segments))),
                  tuple((len(profile)-1)*segments+i for i in range(segments))])
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    current.objects.link(obj)
    material(obj,mat)
    # Side normals are smooth; cap normals remain flat.
    for poly in mesh.polygons[:-2]:
        poly.use_smooth=True
    return obj

# 16-stud bay. The structural wall and its lower frieze are one asset.
wall_col=begin("A_Mur_Panneau_16")
block("Corps_Mur",(8,0,12),(16,1.25,24),0,.075)
block("Plinthe_Basse",(8,-.12,.30),(16,1.52,.60),1,.06)
block("Socle_Biseau",(8,-.10,.78),(16,1.45,.34),0,.04)
block("Soubassement",(8,-.72,2.35),(16,.25,2.80),0,.035)
frame("Cadre_Socle",8,-.92,2.28,12.95,2.13,.16,.15,1)
block("Bandeau_Bas",(8,-.16,4.10),(16,1.66,.35),1,.05)
block("Ombre_Bandeau",(8,-.71,4.40),(16,.23,.18),3,.02)
block("Panneau_Encadre",(8,-.665,12.9),(12.74,.12,15.68),2,.015)
frame("Moulure_Exterieure",8,-.80,12.9,13.28,16.20,.25,.29,1)
frame("Filet_Ombre",8,-.86,12.9,12.87,15.78,.07,.11,3)
frame("Moulure_Interieure",8,-.88,12.9,12.61,15.51,.10,.15,1)
block("Bandeau_Superieur",(8,-.15,21.53),(16,1.70,.38),1,.04)
block("Fond_Frise",(8,-.73,22.65),(16,.23,1.72),2,.025)
block("Filet_Frise_Bas",(8,-.90,21.85),(16,.17,.15),4,.02)
block("Filet_Frise_Haut",(8,-.90,23.46),(16,.17,.15),4,.02)
for x in (2,6,10,14):
    rosette("Fleur_Frise",x,-1.01,22.64,.30)
    scroll("Volute_Frise",x,-1.0,22.67,1.02,1)
    scroll("Volute_Frise",x,-1.0,22.67,1.02,-1)

# Separate pillars mask joints and support upper cap posts.
pillar_col=begin("B_Pilier_Orne")
block("Pied",(0,-.12,.26),(3.15,2.65,.52),1,.07)
block("Socle",(0,-.12,.73),(2.85,2.38,.42),0,.04)
block("Socle_Corps",(0,-.12,2.39),(2.48,2.15,2.94),0,.06)
frame("Cadre_Socle_Pilier",0,-1.24,2.37,1.89,2.15,.12,.16,1)
block("Socle_Couronnement",(0,-.12,4.10),(2.97,2.43,.44),1,.055)
block("Fut_Pilastre",(0,-.12,12.92),(1.91,1.88,17.21),0,.06)
block("Face_Fut",(0,-1.11,12.9),(1.39,.19,15.98),1,.035)
for x in (-.76,.76):
    block("Filet_Fut",(x,-1.22,12.9),(.10,.10,15.88),2,.015)
block("Astragale",(0,-.12,21.35),(2.08,2.00,.28),4,.04)
block("Chapiteau_Fond",(0,-.12,22.42),(2.42,2.17,1.82),4,.05)
for x in (-.87,-.44,0,.44,.87):
    leaf("Acanthe_Grande",(x,-1.25,22.16),.41,1.38,x*.20,4)
    leaf("Acanthe_Petite",(x,-1.32,22.64),.30,.71,-x*.28,4)
for side in (-1,1):
    scroll("Volute_Chapiteau",side*.25,-1.36,22.81,.72,side)
rosette("Fleur_Chapiteau",0,-1.39,22.50,.31)
block("Abaque",(0,-.12,23.58),(2.92,2.52,.40),1,.05)
block("Entablement_Pilier",(0,-.12,24.40),(3.17,2.70,1.24),0,.045)
block("Corniche_Pilier",(0,-.12,25.12),(3.48,2.97,.28),1,.05)
block("Poste_Parapet",(0,-.12,26.64),(2.55,2.23,2.74),0,.05)
frame("Cadre_Poste",0,-1.29,26.65,1.95,1.91,.13,.16,1)
block("Chapeau_Poste_Bas",(0,-.12,28.10),(2.98,2.60,.23),1,.05)
block("Chapeau_Poste_Haut",(0,-.12,28.37),(3.27,2.88,.31),1,.05)

cornice_col=begin("C_Corniche_16")
for name,z,w,d,y,mat in [
    ("Larmier",23.86,.32,1.68,-.12,1),
    ("Fascia",24.14,.25,1.76,-.12,0),
    ("Douce",24.39,.25,1.91,-.15,1),
    ("Ombre_Corniche",24.58,.13,1.97,-.17,3),
    ("Table_Corniche",24.76,.27,2.18,-.18,1),
    ("Couronnement",24.98,.18,2.29,-.18,1),
]:
    block(name,(8,y,z),(16,d,w),mat,.035)

balustrade_col=begin("D_Balustrade_16")
block("Lisse_Basse",(8,-.08,25.27),(16,1.25,.38),1,.045)
profile=[(0,.22),(.12,.22),(.17,.14),(.36,.11),(.59,.17),
         (.79,.20),(.92,.14),(1.14,.095),(1.30,.11),(1.39,.21),(1.52,.21)]
for i in range(12):
    lathe("Balustre_%02d"%i, .67+i*1.333,-.11,25.48,profile)
block("Main_Courante",(8,-.08,27.17),(16,1.43,.37),1,.055)
block("Filet_Main_Courante",(8,-.08,27.41),(16,1.50,.15),0,.035)

# A 90-degree corner pillar has a second ornamented face.
corner_col=begin("E_Pilier_Angle_90")
for obj in pillar_col.objects:
    dup=obj.copy()
    dup.data=obj.data.copy()
    corner_col.objects.link(dup)
    dup.name="Angle_"+obj.name
for obj in list(pillar_col.objects):
    if any(key in obj.name for key in ("Cadre_", "Face_Fut", "Filet_Fut", "Acanthe", "Volute", "Fleur")):
        dup=obj.copy()
        dup.data=obj.data.copy()
        dup.rotation_euler.z=math.pi/2
        dup.location=(-obj.location.y,obj.location.x,obj.location.z)
        corner_col.objects.link(dup)
        dup.name="Retour_"+obj.name

ivy_col=begin("F_Lierre_Grimpant")
for branch in range(4):
    base_x=-1.05+branch*.70
    pts=[]
    height=5.4+branch*.72
    for i in range(25):
        z=i/24*height
        x=base_x+.35*math.sin(z*1.35+branch)
        pts.append((x,-.10,z))
    tube("Tige_Principale",pts,.035,5)
    for i in range(2,24):
        p=pts[i]
        side=1 if i%2 else -1
        xx=p[0]+side*random.uniform(.22,.42)
        zz=p[2]+random.uniform(.04,.20)
        tube("Petiole",[p,(xx,-.12,zz)],.014,5)
        leaf("Feuille_Lierre",(xx,-.17,zz),random.uniform(.29,.43),
             random.uniform(.38,.62),side*random.uniform(.4,.85),random.choice((5,6,6,7)))
        if i%5==0:
            rosette("Fleur_Ivoire",xx,-.21,zz,.11,1)

hedge_col=begin("G_Haie_8")
for i in range(16):
    x=.24+i*.50
    for layer in range(2):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,
            location=(x,(-.3 if layer else .20)+random.uniform(-.16,.16),.76+random.uniform(-.10,.18)))
        obj=bpy.context.object
        obj.name="Feuillage_Haie"
        obj.scale=(.64,.78,.62 if layer else .83)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        material(obj,random.choice((5,6,6,7)))
        move_to(obj,current)

# Shared atlas. Flat painterly colours with subtle stone grain, rather than
# baked highlights; the lighting remains correct when imported into Studio.
SIZE=1024
def make_atlas(name,kind):
    img=bpy.data.images.new(name,width=SIZE,height=SIZE,alpha=False)
    img.colorspace_settings.name="sRGB" if kind=="color" else "Non-Color"
    pixels=array("f")
    for y in range(SIZE):
        for x in range(SIZE):
            tile=(y//512)*4+x//256
            _,color,rough,metal=PALETTE[tile]
            if kind=="color":
                grain=1+random.uniform(-.016,.016)
                broad=1+.012*math.sin(x*.067)*math.sin(y*.047)
                rgb=[min(1,c*grain*broad) for c in color]
            else:
                rgb=[rough if kind=="roughness" else metal]*3
            pixels.extend((*rgb,1))
    img.pixels.foreach_set(pixels)
    img.filepath_raw=str(TEX/(name+".png"))
    img.file_format="PNG"
    img.save()
    return img

colormap=make_atlas("PMU_Muraille_Color", "color")
roughmap=make_atlas("PMU_Muraille_Roughness", "roughness")
metalmap=make_atlas("PMU_Muraille_Metalness", "metalness")
atlas=bpy.data.materials.new("PMU_Muraille_Atlas_PBR")
atlas.use_nodes=True
bsdf=atlas.node_tree.nodes.get("Principled BSDF")
for img,socket in [(colormap,"Base Color"),(roughmap,"Roughness"),(metalmap,"Metallic")]:
    node=atlas.node_tree.nodes.new("ShaderNodeTexImage")
    node.image=img
    node.interpolation="Linear"
    atlas.node_tree.links.new(node.outputs["Color"],bsdf.inputs[socket])
atlas.diffuse_color=(.84,.74,.58,1)

module_cols=[wall_col,pillar_col,cornice_col,balustrade_col,corner_col,ivy_col,hedge_col]
module_names=["PMU_Mur_Panneau_16","PMU_Pilier_Orne","PMU_Corniche_16",
              "PMU_Balustrade_16","PMU_Pilier_Angle_90","PMU_Lierre_Grimpant","PMU_Haie_8"]
modules={}
report=[]
for source,name in zip(module_cols,module_names):
    objs=[]
    for obj in source.objects:
        dup=obj.copy()
        dup.data=obj.data.copy()
        exports.objects.link(dup)
        bpy.ops.object.select_all(action="DESELECT")
        dup.select_set(True)
        bpy.context.view_layer.objects.active=dup
        bpy.ops.object.convert(target="MESH")
        dup=bpy.context.object
        for mod in list(dup.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
        # Store a palette tile in the temporary material index before joining.
        for poly in dup.data.polygons:
            poly.material_index=0
        objs.append(dup)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs: obj.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
    bpy.ops.object.join()
    obj=bpy.context.object
    obj.name=name
    obj.data.name=name+"_Mesh"
    # Common pivot at the assembly's ground level. Upper parts retain their
    # intended Z height so all four layers assemble at the same pivot.
    scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    mesh=obj.data
    for old_uv in list(mesh.uv_layers):
        mesh.uv_layers.remove(old_uv)
    uv=mesh.uv_layers.new(name="UVMap")
    uv.active_render=True
    for poly in mesh.polygons:
        tile=mesh.materials[poly.material_index].get("atlas_tile",0)
        col,row=tile%4,tile//4
        n=poly.normal
        major=max(range(3),key=lambda axis:abs(n[axis]))
        axes=[axis for axis in range(3) if axis!=major]
        for li in poly.loop_indices:
            v=mesh.vertices[mesh.loops[li].vertex_index].co
            # Stay well inside each atlas tile to prevent mip bleed.
            u=.08+.84*((v[axes[0]]*.11)%1)
            vv=.06+.88*((v[axes[1]]*.07)%1)
            uv.data[li].uv=((col+u)/4,(row+vv)/2)
        poly.material_index=0
    mesh.materials.clear()
    mesh.materials.append(atlas)
    triangulate=obj.modifiers.new("Triangulation_Export", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=triangulate.name)
    obj["grid_studs"]=16 if "16" in name else 8 if "Haie" in name else 0
    obj["pivot"]="Ground-left for horizontal modules; ground-centre for pillars/ivy"
    obj["source_collection"]=source.name
    obj["collision_recommendation"]="Box for wall and pillar; CanCollide false for ornaments/foliage"
    modules[name]=obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.export_scene.fbx(filepath=str(EXPORT/(name+".fbx")),use_selection=True,
        object_types={"MESH"},global_scale=1,apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",axis_forward="-Z",axis_up="Y",
        use_mesh_modifiers=True,mesh_smooth_type="FACE",use_tspace=False,
        add_leaf_bones=False,bake_anim=False,path_mode="COPY",embed_textures=True)
    bpy.ops.export_scene.gltf(filepath=str(EXPORT/(name+".glb")),export_format="GLB",
        use_selection=True,export_materials="EXPORT",export_yup=True)
    bb=[obj.matrix_world@Vector(v) for v in obj.bound_box]
    size=[round(max(v[i] for v in bb)-min(v[i] for v in bb),4) for i in range(3)]
    report.append({"asset":name,"triangles":len(mesh.polygons),"vertices":len(mesh.vertices),
        "dimensions_blender_xyz":size,"pivot_xyz":list(obj.location),
        "uv_layers":len(mesh.uv_layers),"material_slots":len(mesh.materials),
        "fbx":name+".fbx","glb":name+".glb"})
    print("EXPORTED",name,len(mesh.polygons),flush=True)

def instance(name,location=(0,0,0),angle=0,col=demo):
    obj=modules[name].copy()
    obj.data=modules[name].data
    col.objects.link(obj)
    obj.location=location
    obj.rotation_euler.z=angle
    obj.name="DEMO_"+name
    return obj

def bay(x,y,a):
    for name in (module_names[0],module_names[2],module_names[3]):
        instance(name,(x,y,0),a)

for x in (0,16,32): bay(x,0,0)
for y in (0,16): bay(48,y,math.pi/2)
for x in (0,16,32): instance(module_names[1],(x,0,0))
instance(module_names[4],(48,0,0))
instance(module_names[1],(48,16,0),math.pi/2)
instance(module_names[1],(48,32,0),math.pi/2)
for x in (0,16,32): instance(module_names[5],(x,-1.65,.55))
instance(module_names[5],(49.65,16,.55),math.pi/2)
for x in (2.9,10.5,18.9,26.5,34.9,42.5):
    instance(module_names[6],(x,-1.4,0))
for y in (2.9,10.5,18.9,26.5):
    instance(module_names[6],(49.4,y,0),math.pi/2)

# Place source and canonical exports in hidden collections, never in renders.
root.hide_render=True
root.hide_viewport=True
exports.hide_render=True
exports.hide_viewport=True
current=display
ground=block("Sol_Presentation",(22,6,-.33),(115,105,.55),2,.20)
ground.data.materials.clear()
mat=bpy.data.materials.new("Sol_Studio")
mat.diffuse_color=(.23,.25,.23,1)
mat.use_nodes=True
mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value=(.23,.25,.23,1)
mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value=.95
ground.data.materials.append(mat)

def camera(name,location,target,ortho):
    data=bpy.data.cameras.new(name)
    obj=bpy.data.objects.new(name,data)
    display.objects.link(obj)
    obj.location=location
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()
    data.type="ORTHO"
    data.ortho_scale=ortho
    data.lens=48
    return obj

hero_cam=camera("Camera_Assemblage",(86,-104,65),(24,7,13),76)
detail_cam=camera("Camera_Detail",(24,-40,29),(15,-.5,20.5),27)
scene.camera=hero_cam
def area(name,location,power,size,color,target):
    data=bpy.data.lights.new(name,"AREA")
    data.energy=power
    data.shape="DISK"
    data.size=size
    data.color=color
    obj=bpy.data.objects.new(name,data)
    display.objects.link(obj)
    obj.location=location
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat("-Z","Y").to_euler()

area("Key_Softbox",(12,-32,62),21000,38,(1,.85,.68),(24,0,13))
area("Fill_Softbox",(75,-3,38),12500,35,(.72,.82,1),(24,2,14))
area("Rim_Softbox",(12,48,57),23000,30,(1,.91,.73),(24,10,15))
world=bpy.data.worlds.new("Monde_Studio")
world.use_nodes=True
world.node_tree.nodes["Background"].inputs[0].default_value=(.40,.45,.50,1)
world.node_tree.nodes["Background"].inputs[1].default_value=.45
scene.world=world
scene.render.engine="CYCLES"
scene.cycles.samples=40
scene.cycles.use_denoising=True
scene.render.resolution_x=1600
scene.render.resolution_y=1100
scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.view_settings.view_transform="AgX"
scene.view_settings.look="AgX - Medium High Contrast"
scene.render.film_transparent=False

text=bpy.data.texts.new("LIRE_MOI")
text.write("KIT MURAILLES PICK ME UP — V01\n\n"
 "01_EXPORT_MODULES : 7 meshes exportables, atlas PBR commun.\n"
 "00_SOURCE_EDITABLE : pieces et ornements avant fusion.\n"
 "02_ASSEMBLAGE_DEMO : 5 travees avec retour a 90 degres.\n"
 "Les collections SOURCE et EXPORT sont masquees au depart.\n"
 "Largeur nominale 16 unites/studs, pilier aux joints tous les 16.\n"
 "Tous les modules de mur/corniche/balustrade partagent le pivot au sol.\n"
 "Dans Roblox: ancrer les meshes; collision Box sur le mur et les piliers,\n"
 "desactiver les collisions des ornements et plantes.\n"
 "Le rendu Blender ne vaut pas validation de l'import Studio.\n")
for area_ui in bpy.context.screen.areas:
    if area_ui.type=="VIEW_3D":
        area_ui.spaces.active.region_3d.view_perspective="CAMERA"
        area_ui.spaces.active.shading.type="MATERIAL"

report_path=OUT/"manifest.json"
report_path.write_text(json.dumps({"kit":"PMU_Murailles_V01","spacing":16,
    "height_max":28.525,"assets":report},indent=2),encoding="utf-8")
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"PMU_Murailles_V01.blend"))
print("BLEND_SAVED",flush=True)
scene.render.filepath=str(PREVIEW/"01_assemblage.png")
bpy.ops.render.render(write_still=True)
scene.camera=detail_cam
scene.render.filepath=str(PREVIEW/"02_detail.png")
bpy.ops.render.render(write_still=True)
scene.camera=hero_cam

# Separate module contact sheet. Full-height shared pivots stay consistent.
sheet=bpy.data.collections.new("04_PLANCHE_MODULES")
scene.collection.children.link(sheet)
layout=[(module_names[0],(-31,0,0)),(module_names[1],(-6,0,0)),
        (module_names[4],(5,0,0)),(module_names[2],(15,0,-15)),
        (module_names[3],(15,0,-7)),(module_names[5],(36,0,0)),
        (module_names[6],(42,0,0))]
for name,loc in layout: instance(name,loc,0,sheet)
label_mat=bpy.data.materials.new("Texte_Planche")
label_mat.diffuse_color=(.88,.87,.77,1)
label_mat.use_nodes=True
label_nodes=label_mat.node_tree.nodes
label_nodes.clear()
label_output=label_nodes.new("ShaderNodeOutputMaterial")
label_emission=label_nodes.new("ShaderNodeEmission")
label_emission.inputs["Color"].default_value=(.83,.82,.74,1)
label_mat.node_tree.links.new(label_emission.outputs[0],label_output.inputs["Surface"])
for name,loc in layout:
    data=bpy.data.curves.new("Label", "FONT")
    data.body=name.replace("PMU_","").replace("_"," ")
    data.size=.72
    data.align_x="CENTER"
    obj=bpy.data.objects.new("Label_"+name,data)
    sheet.objects.link(obj)
    obj.location=(loc[0]+(8 if "16" in name else 4 if "Haie" in name else 0),-2.5,-1.7)
    if "Corniche" in name: obj.location.z=7.2
    elif "Balustrade" in name: obj.location.z=16.3
    obj.rotation_euler=(math.pi/2,0,0)
    obj.data.materials.append(label_mat)
demo.hide_render=True
ground.hide_render=True
sheet_cam=camera("Camera_Planche",(10,-100,30),(10,0,13),92)
scene.camera=sheet_cam
scene.render.resolution_x=2000
scene.render.resolution_y=1000
scene.render.filepath=str(PREVIEW/"03_modules.png")
bpy.ops.render.render(write_still=True)
sheet.hide_render=True
sheet.hide_viewport=True
demo.hide_render=False
ground.hide_render=False
scene.camera=hero_cam
scene.render.resolution_x=1600
scene.render.resolution_y=1100

# Circular layout uses the SAME straight modules. Consecutive bays meet at
# exact chord endpoints; pillar width masks the small angle between panels.
circle=bpy.data.collections.new("05_ENCEINTE_CIRCULAIRE_48")
scene.collection.children.link(circle)
radius=16/(2*math.sin(math.pi/48))
for i in range(48):
    a=i*math.tau/48
    b=(i+1)*math.tau/48
    p=(radius*math.cos(a),radius*math.sin(a),0)
    q=(radius*math.cos(b),radius*math.sin(b),0)
    angle=math.atan2(q[1]-p[1],q[0]-p[0])
    for name in (module_names[0],module_names[2],module_names[3]):
        instance(name,p,angle,circle)
    instance(module_names[1],p,a+math.pi/2,circle)
circle["bay_count"]=48
circle["radius_studs"]=radius
circle.hide_render=True
circle.hide_viewport=True
for img in (colormap,roughmap,metalmap): img.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"PMU_Murailles_V01.blend"))
print("DONE",str(OUT),flush=True)
