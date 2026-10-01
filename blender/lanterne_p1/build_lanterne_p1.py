"""One review asset: P1 standing lantern. Run with Blender 4.5 in background."""
import bpy, math, os, random, json, array
from mathutils import Vector

ROOT = os.path.dirname(os.path.abspath(__file__))
for sub in ('exports', 'textures', 'previews'):
    os.makedirs(os.path.join(ROOT, sub), exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = 'NONE'
scene.unit_settings.scale_length = 1

def coll(name):
    c = bpy.data.collections.new(name)
    scene.collection.children.link(c)
    return c
SOURCE = coll('00_SOURCE_EDITABLE')
EXPORT = coll('01_ASSET_EXPORT')
CONTEXT = coll('02_CONTEXTE_REMPART_P1')
STAGE = coll('03_PRESENTATION')

def move(ob, target):
    for c in list(ob.users_collection): c.objects.unlink(ob)
    target.objects.link(ob)
    return ob

def srgb(x):
    x = x / 255
    return x / 12.92 if x <= .04045 else ((x + .055) / 1.055) ** 2.4

swatches = [((84,100,122),.78,0), ((31,42,54),.5,.8),
            ((205,212,222),.32,1), ((88,128,56),.9,0),
            ((63,78,96),.82,0), ((105,120,141),.76,0),
            ((113,99,72),.9,0), ((155,160,163),.45,.85)]
N = 512
def atlas(kind):
    img = bpy.data.images.new('P1_Lanterne_' + kind, N, N, alpha=True)
    if kind != 'Color': img.colorspace_settings.name = 'Non-Color'
    rng = random.Random(192)
    pix = array.array('f')
    for y in range(N):
        for x in range(N):
            idx = (y // (N//2))*4 + x//(N//4)
            rgb, rough, metal = swatches[idx]
            if kind == 'Color':
                noise = rng.uniform(-1.5,1.5) if idx != 2 else rng.uniform(-.5,.5)
                col = [srgb(max(0,min(255,c+noise))) for c in rgb]
            else:
                v = rough if kind == 'Roughness' else metal
                col = [v]*3
            pix.extend((*col,1))
    img.pixels.foreach_set(pix)
    img.filepath_raw = os.path.join(ROOT,'textures',img.name+'.png')
    img.file_format = 'PNG'
    img.save()
    img.pack()
    return img
images = {k:atlas(k) for k in ('Color','Roughness','Metalness')}
mat = bpy.data.materials.new('P1_Atlas_Pierre_Fer_Argent_Mousse')
mat.use_nodes = True
bs = mat.node_tree.nodes.get('Principled BSDF')
for kind, socket in [('Color','Base Color'),('Roughness','Roughness'),('Metalness','Metallic')]:
    t = mat.node_tree.nodes.new('ShaderNodeTexImage')
    t.image = images[kind]
    mat.node_tree.links.new(t.outputs['Color'],bs.inputs[socket])

def simple_mat(name,rgb,rough=.5,metal=0):
    m = bpy.data.materials.new(name); m.use_nodes=True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*[srgb(x) for x in rgb],1)
    p.inputs['Roughness'].default_value=rough
    p.inputs['Metallic'].default_value=metal
    m.diffuse_color=(*[srgb(x) for x in rgb],1)
    return m
glass = simple_mat('P1_Verre_Ambre', (234,217,180), .16)
gb=glass.node_tree.nodes.get('Principled BSDF')
gb.inputs['Alpha'].default_value=.18
gb.inputs['IOR'].default_value=1.45
glass.surface_render_method='DITHERED'
glass.diffuse_color=(*[srgb(x) for x in (234,217,180)],.18)
coremat=simple_mat('P1_Coeur_Lumineux_Ivoire', (255,218,146), .32)
cb=coremat.node_tree.nodes.get('Principled BSDF')
cb.inputs['Emission Color'].default_value=(*[srgb(x) for x in (255,205,117)],1)
cb.inputs['Emission Strength'].default_value=2.2

def uv_tile(ob,idx):
    me=ob.data
    for layer in list(me.uv_layers): me.uv_layers.remove(layer)
    uv=me.uv_layers.new(name='UVMap'); uv.active_render=True
    mins=[min(v.co[a] for v in me.vertices) for a in range(3)]
    sizes=[max(v.co[a] for v in me.vertices)-mins[a] for a in range(3)]
    for p in me.polygons:
        axis=max(range(3),key=lambda a:abs(p.normal[a]))
        axes=[(1,2),(0,2),(0,1)][axis]
        for li in p.loop_indices:
            v=me.vertices[me.loops[li].vertex_index].co
            u=(v[axes[0]]-mins[axes[0]])/max(sizes[axes[0]],1e-5)
            w=(v[axes[1]]-mins[axes[1]])/max(sizes[axes[1]],1e-5)
            uv.data[li].uv=((idx%4+.05+.9*u)/4,(idx//4+.05+.9*w)/2)

groups={'Structure':[], 'Vitres':[], 'Coeur':[], 'Mousse':[]}
def finish(ob,name,idx=1,group='Structure',bevel=0,smooth=False):
    ob.name=name; move(ob,SOURCE)
    bpy.context.view_layer.objects.active=ob
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=ob.modifiers.new('Chanfreins','BEVEL');mod.width=bevel;mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.data.update()
    ob.data.materials.clear()
    ob.data.materials.append(glass if group=='Vitres' else coremat if group=='Coeur' else mat)
    uv_tile(ob,idx)
    if smooth:
        for p in ob.data.polygons: p.use_smooth=True
        mod=ob.modifiers.new('Normales_ponderees','WEIGHTED_NORMAL');mod.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    ob['PartRole']=group
    groups[group].append(ob)
    ob.select_set(False)
    return ob

def box(name,loc,size,idx=1,group='Structure',bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    ob=bpy.context.object;ob.dimensions=size
    return finish(ob,name,idx,group,bevel)

def lathe(name,profile,idx=1,n=12,group='Structure',smooth=False):
    verts=[(r*math.cos(2*math.pi*k/n+math.pi/4),r*math.sin(2*math.pi*k/n+math.pi/4),z) for r,z in profile for k in range(n)]
    faces=[]
    for i in range(len(profile)-1):
        for k in range(n):
            a=i*n+k;b=i*n+(k+1)%n
            faces.append((a,b,b+n,a+n))
    faces.extend([tuple(reversed(range(n))),tuple((len(profile)-1)*n+k for k in range(n))])
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    ob=bpy.data.objects.new(name,me);SOURCE.objects.link(ob)
    return finish(ob,name,idx,group,0,smooth)

def beam(name,a,b,w,idx=1):
    va,vb=Vector(a),Vector(b)
    ob=box(name,(va+vb)/2,(w,w,(vb-va).length),idx,bevel=.009)
    ob.rotation_euler=(vb-va).to_track_quat('Z','Y').to_euler()
    return ob

# Stone plinth echoes the two projecting bases of the real P1 wall.
box('Socle_Pierre_Bas',(0,0,.19),(1.78,1.78,.38),0,bevel=.09)
box('Socle_Pierre_Fut',(0,0,.62),(1.38,1.38,.52),0,bevel=.045)
box('Socle_Pierre_Couronnement',(0,0,.97),(1.59,1.59,.18),5,bevel=.035)
for side in [-1,1]:
    box('Socle_Panneau_Encadre',(0,side*.706,.64),(.85,.025,.28),4,bevel=.015)
box('Platine_Ancrage',(0,0,1.085),(.77,.77,.09),1,bevel=.025)
for x in [-.27,.27]:
    for y in [-.27,.27]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.055,location=(x,y,1.145))
        finish(bpy.context.object,'Rivet_Ancrage',2)

lathe('Pied_Metal',[(.34,1.12),(.34,1.28),(.3,1.4),(.25,1.49),(.25,1.85),(.205,2.02)],n=12)
lathe('Bague_Argent_Basse',[(.255,1.76),(.277,1.8),(.277,1.87),(.24,1.9)],2,n=12)
lathe('Fut_Octogonal',[(.205,1.95),(.185,3.8),(.17,5.95),(.21,6.14)],n=12)
lathe('Bague_Argent_Haute',[(.175,5.76),(.205,5.79),(.205,5.88),(.173,5.91)],2,n=12)
lathe('Chapiteau_Fut',[(.21,6.04),(.26,6.11),(.28,6.22),(.4,6.4),(.55,6.49),(.56,6.62)],n=12)
lathe('Liseret_Sous_Cage',[(.525,6.5),(.57,6.54),(.57,6.59),(.55,6.62)],2,n=12)

# Four-sided cage, deliberately readable at Roblox third-person camera distance.
box('Plateau_Cage',(0,0,6.73),(1.38,1.38,.16),1,bevel=.04)
box('Liseret_Cage_Bas',(0,0,6.835),(1.32,1.32,.055),2,bevel=.014)
bottom=.51;top=.64;z0=6.87;z1=8.29
for sx in [-1,1]:
    for sy in [-1,1]:
        beam('Montant_Cage',(sx*bottom,sy*bottom,z0),(sx*top,sy*top,z1),.105)
        beam('Filet_Argent_Montant',(sx*(bottom+.016),sy*(bottom+.016),z0+.045),(sx*(top+.016),sy*(top+.016),z1-.025),.024,2)
for side in [-1,1]:
    beam('Traverse_Mediane',(side*.548,-.55,7.3),(side*.548,.55,7.3),.052)
    beam('Traverse_Mediane',(-.55,side*.548,7.3),(.55,side*.548,7.3),.052)
    for sign in [-1,1]:
        beam('Ornement_Entretoise',(sign*.44,side*.527,6.93),(0,side*.553,7.26),.035)
        beam('Ornement_Entretoise',(side*.527,sign*.44,6.93),(side*.553,0,7.26),.035)

def pane(name,pts):
    me=bpy.data.meshes.new(name);me.from_pydata(pts,[],[(0,1,2,3)]);me.update()
    ob=bpy.data.objects.new(name,me);SOURCE.objects.link(ob)
    finish(ob,name,0,'Vitres')
for side in [-1,1]:
    pane('Vitre_Ambre',[(-.46,side*.516,6.91),(.46,side*.516,6.91),(.59,side*.632,8.26),(-.59,side*.632,8.26)])
    pane('Vitre_Ambre',[(side*.516,-.46,6.91),(side*.516,.46,6.91),(side*.632,.59,8.26),(side*.632,-.59,8.26)])

box('Entablement_Cage',(0,0,8.35),(1.5,1.5,.16),1,bevel=.035)
box('Liseret_Cage_Haut',(0,0,8.455),(1.59,1.59,.05),2,bevel=.012)
# Low pyramidal roof with a layered eave and visible diagonal ribs.
lathe('Toit_Pyramidal',[(1.15,8.49),(1.15,8.58),(.25,9.12),(.17,9.17)],n=4)
for sx in [-1,1]:
    for sy in [-1,1]:
        beam('Nervure_Toit',(sx*.796,sy*.796,8.595),(sx*.16,sy*.16,9.145),.042,7)
lathe('Fleuron_Toit',[(.16,9.16),(.16,9.22),(.085,9.29),(.12,9.38),(.02,9.59)],2,n=8)
lathe('Suspente_Cristal',[(.045,7.95),(.045,8.31)],2,n=8)
lathe('Berceau_Cristal',[(.21,6.98),(.27,7.035),(.27,7.095),(.2,7.13)],2,n=8)
lathe('Cristal_Ivoire',[(.025,7.09),(.17,7.22),(.215,7.63),(.14,7.85),(.015,8.0)],n=8,group='Coeur')

# Small independent moss patches around the stone foot; they can be hidden.
rng=random.Random(32)
for k in range(4):
    cx=rng.uniform(-.63,.63);side=-1 if k<2 else 1
    pts=[(cx-.14,side*.896,.06),(cx+.15,side*.896,.06),
         (cx+.11,side*.898,.17),(cx+.015,side*.898,.25),(cx-.13,side*.898,.18)]
    me=bpy.data.meshes.new('Mousse');me.from_pydata(pts,[],[(0,1,2,3,4)]);me.update()
    ob=bpy.data.objects.new('Mousse_Pied',me);SOURCE.objects.link(ob)
    finish(ob,'Mousse_Pied',3,'Mousse')

def merge(group,parts):
    bpy.ops.object.select_all(action='DESELECT')
    copies=[]
    for p in parts:
        o=p.copy();o.data=p.data.copy();EXPORT.objects.link(o);o.select_set(True);copies.append(o)
    bpy.context.view_layer.objects.active=copies[0]
    bpy.ops.object.join()
    ob=bpy.context.object;ob.name='P1_Lanterne_Pied_'+group
    scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    mod=ob.modifiers.new('Triangulation','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
    ob['AssetName']='P1_Lanterne_Pied';ob['PartRole']=group
    ob['Pivot']='Ground center / centre au sol';ob.select_set(False)
    return ob
export_objects=[merge(k,v) for k,v in groups.items()]
SOURCE.hide_render=True;SOURCE.hide_viewport=True

# Existing rempart is appended for context only, never included in exports.
wallpath=os.path.join(os.path.dirname(ROOT),'rempart_p1.blend')
wallnames=['P1_Travee_Pierre','P1_Travee_Argent','P1_Pilier_Pierre','P1_Pilier_Argent','P1_Mousse_Travee_A','P1_Mousse_Pilier_A']
with bpy.data.libraries.load(wallpath,link=False) as (src,dst):
    dst.objects=[n for n in wallnames if n in src.objects]
wall_src={o.name:o for o in dst.objects if o}
for name,ob in wall_src.items():
    CONTEXT.objects.link(ob)
    ob.location=(0,5,0) if 'Pilier' not in name else (-10,5,0)
for name in ['P1_Pilier_Pierre','P1_Pilier_Argent','P1_Mousse_Pilier_A']:
    if name in wall_src:
        ob=wall_src[name].copy();CONTEXT.objects.link(ob);ob.location=(10,5,0)
CONTEXT.hide_render=True;CONTEXT.hide_viewport=True

groundmat=simple_mat('Presentation_Sol',(94,105,113),.9)
bpy.ops.mesh.primitive_plane_add(size=200)
floor=move(bpy.context.object,STAGE);floor.name='Sol_Presentation';floor.data.materials.append(groundmat);floor.location.z=-.01

world=bpy.data.worlds.new('Fond_Presentation');world.use_nodes=True;scene.world=world
bg=world.node_tree.nodes.get('Background');bg.inputs[0].default_value=(.12,.16,.22,1);bg.inputs[1].default_value=.4
def light(name,kind,loc,energy,color,size=5,target=(0,0,5)):
    d=bpy.data.lights.new(name,kind);d.energy=energy;d.color=color
    if kind=='AREA':d.shape='DISK';d.size=size
    elif kind=='POINT':d.shadow_soft_size=.28
    ob=bpy.data.objects.new(name,d);STAGE.objects.link(ob);ob.location=loc
    ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
    return ob
key=light('Key','AREA',(4,-5,11),850,(1,.88,.73),5)
fill=light('Fill','AREA',(-4,-2,6),500,(.65,.8,1),5)
rim=light('Rim','AREA',(1,4,10),1050,(.7,.84,1),4)
warm=light('Lumiere_Ambre_Presentation','POINT',(0,0,7.55),18,(1,.58,.2))
warm['Note']='Preview light; configure a PointLight in Roblox after import.'

camdata=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',camdata);STAGE.objects.link(cam);scene.camera=cam
camdata.type='ORTHO'
def camera(loc,target,scale):
    cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();camdata.ortho_scale=scale

scene.render.engine='CYCLES';scene.cycles.samples=48
scene.cycles.use_denoising=True
scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
scene.render.image_settings.file_format='PNG'
scene.use_nodes=True
nt=scene.node_tree;nt.nodes.clear();rl=nt.nodes.new('CompositorNodeRLayers');gl=nt.nodes.new('CompositorNodeGlare')
gl.glare_type='FOG_GLOW';gl.quality='HIGH';gl.threshold=1.5
out=nt.nodes.new('CompositorNodeComposite');nt.links.new(rl.outputs['Image'],gl.inputs['Image']);nt.links.new(gl.outputs['Image'],out.inputs['Image'])

# Canonical export: the single asset, with four independently configurable meshes.
bpy.ops.object.select_all(action='DESELECT')
for o in export_objects:o.select_set(True)
bpy.context.view_layer.objects.active=export_objects[0]
bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT,'exports','P1_Lanterne_Pied.fbx'),use_selection=True,
    object_types={'MESH'},axis_forward='-Z',axis_up='Y',apply_scale_options='FBX_SCALE_UNITS',
    use_mesh_modifiers=True,mesh_smooth_type='FACE',path_mode='COPY',embed_textures=True,bake_anim=False,
    add_leaf_bones=False)
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'exports','P1_Lanterne_Pied.glb'),export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_materials='EXPORT')
bpy.ops.object.select_all(action='DESELECT')
metadata=[]
for ob in export_objects:
    ob.data.calc_loop_triangles()
    metadata.append({'mesh':ob.name,'role':ob['PartRole'],'triangles':len(ob.data.loop_triangles),
                     'dimensions_xyz':list(ob.dimensions),'pivot_xyz':list(ob.location),'uv_layers':len(ob.data.uv_layers)})
pts=[ob.matrix_world@Vector(c) for ob in export_objects for c in ob.bound_box]
dims=[max(p[i] for p in pts)-min(p[i] for p in pts) for i in range(3)]
manifest={'asset':'P1_Lanterne_Pied','reference':'../rempart_p1.blend','units':'1 unit intended as 1 stud',
          'dimensions_xyz':dims,'total_triangles':sum(x['triangles'] for x in metadata),'meshes':metadata,
          'approval_status':'Awaiting user visual review','roblox_import_status':'Not imported',
          'glass_note':'Separate mesh: configure transparency in Roblox.',
          'light_note':'Emission and render point light are presentation settings; configure runtime light in Roblox.'}
with open(os.path.join(ROOT,'manifest.json'),'w',encoding='utf-8') as f:json.dump(manifest,f,indent=2)

def render(filename,res,loc,target,scale):
    scene.render.resolution_x,scene.render.resolution_y=res
    camera(loc,target,scale);scene.render.filepath=os.path.join(ROOT,'previews',filename)
    bpy.ops.render.render(write_still=True)

render('01_lanterne_entiere.png',(1100,1500),(12,-17,11),(0,0,4.7),11.2)
render('02_detail_cage.png',(1500,1100),(7,-11,10.5),(0,0,7.9),3.65)
CONTEXT.hide_render=False;CONTEXT.hide_viewport=False
floor.data.materials[0]=simple_mat('Sol_Context_Pierre',(133,143,149),.9)
bg.inputs[1].default_value=.48
render('03_avec_rempart_P1.png',(1500,1100),(16,-24,14),(0,2.2,5.3),19)
CONTEXT.hide_render=True;CONTEXT.hide_viewport=True
floor.data.materials[0]=groundmat;bg.inputs[1].default_value=.4
render('04_lanterne_face.png',(1100,1500),(0,-25,6.5),(0,0,4.7),11.2)
camera((12,-17,11),(0,0,4.7),11.2)
scene.render.resolution_x=1100;scene.render.resolution_y=1500
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.clip_end=500
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'P1_Lanterne_Pied.blend'))
print('ASSET_COMPLETE',json.dumps(manifest))
