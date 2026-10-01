"""Second single review asset: wall lantern, using the approved P1 cage."""
import bpy, os, math, json
from mathutils import Vector
ROOT=os.path.dirname(os.path.abspath(__file__))
for folder in ['exports','textures','previews']: os.makedirs(os.path.join(ROOT,folder),exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene;s.unit_settings.system='NONE';s.unit_settings.scale_length=1
def collection(name):
    c=bpy.data.collections.new(name);s.collection.children.link(c);return c
SOURCE=collection('00_SOURCE_EDITABLE')
EXPORT=collection('01_ASSET_EXPORT')
CONTEXT=collection('02_CONTEXTE_REMPART_P1')
STAGE=collection('03_PRESENTATION')
basepath=os.path.join(os.path.dirname(ROOT),'lanterne_p1','P1_Lanterne_Pied.blend')
prefixes=['Plateau_Cage','Liseret_Cage_Bas','Montant_Cage','Filet_Argent_Montant','Traverse_Mediane',
          'Ornement_Entretoise','Vitre_Ambre','Entablement_Cage','Liseret_Cage_Haut','Toit_Pyramidal',
          'Nervure_Toit','Fleuron_Toit','Suspente_Cristal','Berceau_Cristal','Cristal_Ivoire']
with bpy.data.libraries.load(basepath,link=False) as (src,dst):
    # Export meshes have a different name; these are the editable component sources.
    dst.objects=[n for n in src.objects if any(n==p or n.startswith(p+'.') for p in prefixes)]
groups={'Structure':[],'Vitres':[],'Coeur':[]}
for o in dst.objects:
    if o:
        SOURCE.objects.link(o)
        o.hide_render=False;o.hide_viewport=False
        o.location+=Vector((0,-1.75,-7.55))
        role=o.get('PartRole','Structure');groups[role].append(o)
mat=bpy.data.materials['P1_Atlas_Pierre_Fer_Argent_Mousse']
for img in bpy.data.images:
    if img.name.startswith('P1_Lanterne_'):
        img.filepath_raw=os.path.join(ROOT,'textures',img.name+'.png');img.file_format='PNG';img.save();img.pack()

def srgb(c):
    c=c/255;return c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4
def simple(name,rgb,rough=.8):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(*[srgb(c) for c in rgb],1)
    p.inputs['Roughness'].default_value=rough
    return m
def uv_tile(o,index):
    me=o.data
    for l in list(me.uv_layers):me.uv_layers.remove(l)
    uv=me.uv_layers.new(name='UVMap');uv.active_render=True
    mn=[min(v.co[a] for v in me.vertices) for a in range(3)]
    dims=[max(v.co[a] for v in me.vertices)-mn[a] for a in range(3)]
    for p in me.polygons:
        axis=max(range(3),key=lambda a:abs(p.normal[a]));axes=[(1,2),(0,2),(0,1)][axis]
        for li in p.loop_indices:
            v=me.vertices[me.loops[li].vertex_index].co
            a=(v[axes[0]]-mn[axes[0]])/max(dims[axes[0]],1e-6)
            b=(v[axes[1]]-mn[axes[1]])/max(dims[axes[1]],1e-6)
            uv.data[li].uv=((index%4+.05+.9*a)/4,(index//4+.05+.9*b)/2)
def finish(o,name,idx=1,bevel=0):
    o.name=name
    for c in list(o.users_collection):c.objects.unlink(o)
    SOURCE.objects.link(o)
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        m=o.modifiers.new('Chanfrein','BEVEL');m.width=bevel;m.segments=2
        bpy.ops.object.modifier_apply(modifier=m.name)
    o.data.materials.clear();o.data.materials.append(mat);o.data.update();uv_tile(o,idx)
    o['PartRole']='Structure';groups['Structure'].append(o);o.select_set(False)
    return o
def box(name,loc,size,idx=1,bevel=.02):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.dimensions=size
    return finish(o,name,idx,bevel)
def beam(name,a,b,w,idx=1):
    a,b=Vector(a),Vector(b);o=box(name,(a+b)/2,(w,w,(b-a).length),idx,.009)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def lathe(name,profile,idx=1,n=12,cy=-1.75):
    verts=[(r*math.cos(2*math.pi*k/n+math.pi/4),cy+r*math.sin(2*math.pi*k/n+math.pi/4),z) for r,z in profile for k in range(n)]
    faces=[]
    for j in range(len(profile)-1):
        for k in range(n):faces.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
    faces.extend([tuple(reversed(range(n))),tuple((len(profile)-1)*n+k for k in range(n))])
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    o=bpy.data.objects.new(name,me);SOURCE.objects.link(o);return finish(o,name,idx)

# Back of stone pad is at Y=0, flush with the wall. Fixture projects toward -Y.
box('Platine_Pierre_P1',(0,-.09,0),(1.04,.18,2.45),0,.045)
box('Platine_Argent',(0,-.205,0),(.86,.05,2.15),2,.025)
box('Platine_Fer',(0,-.246,0),(.74,.055,2.03),1,.018)
for x in [-.275,.275]:
    for z in [-.86,.86]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.058,location=(x,-.293,z))
        finish(bpy.context.object,'Rivet_Mural',2)
# Silver lozenge on the backplate links the angular cage and the P1 metalwork.
o=box('Embleme_Platine',(0,-.294,.46),(.23,.016,.23),2,.012);o.rotation_euler.y=math.pi/4
box('Pied_Console',(0,-.32,-.91),(.36,.15,.28),1,.025)
beam('Console_Porteuse',(0,-.35,-.91),(0,-1.75,-.91),.145)
beam('Filet_Console',(0,-.39,-.823),(0,-1.7,-.823),.023,2)

# Cast curved brace below the arm. Catmull-Rom profile, rectangular cross-section.
controls=[(-.35,-1.02),(-.40,-1.31),(-.72,-1.52),(-1.11,-1.53),(-1.48,-1.31),(-1.75,-.92)]
points=[]
padded=[controls[0]]+controls+[controls[-1]]
for i in range(1,len(padded)-2):
    p0,p1,p2,p3=[Vector(v) for v in padded[i-1:i+3]]
    for j in range(8):
        t=j/8
        points.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
points.append(Vector(controls[-1]))
verts=[]
for i,p in enumerate(points):
    tangent=points[min(i+1,len(points)-1)]-points[max(0,i-1)]
    normal=Vector((-tangent.y,tangent.x)).normalized()
    for x,sign in [(-.065,-1),(.065,-1),(.065,1),(-.065,1)]:
        q=p+normal*(sign*.05);verts.append((x,q.x,q.y))
faces=[(3,2,1,0)]
for i in range(len(points)-1):
    for k in range(4):faces.append((i*4+k,i*4+(k+1)%4,(i+1)*4+(k+1)%4,(i+1)*4+k))
faces.append(tuple((len(points)-1)*4+k for k in range(4)))
me=bpy.data.meshes.new('Console_Courbe');me.from_pydata(verts,[],faces);me.update()
o=bpy.data.objects.new('Console_Courbe',me);SOURCE.objects.link(o);finish(o,'Console_Courbe',1,.008)
lathe('Embout_Sous_Cage',[(.045,-1.23),(.125,-1.15),(.125,-1.02),(.26,-.87),(.26,-.83)],1,n=8)
lathe('Bague_Embout',[(.16,-1.01),(.2,-.96),(.2,-.92),(.21,-.9)],2,n=8)

def merged(role,parts):
    bpy.ops.object.select_all(action='DESELECT')
    copies=[]
    for part in parts:
        o=part.copy();o.data=part.data.copy();EXPORT.objects.link(o);o.select_set(True);copies.append(o)
    bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();o=bpy.context.object
    o.name='P1_Lanterne_Murale_'+role;s.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    m=o.modifiers.new('Triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=m.name)
    o['AssetName']='P1_Lanterne_Murale';o['PartRole']=role;o['Pivot']='Center of backplate at wall contact Y=0'
    o.select_set(False);return o
exports=[merged(role,parts) for role,parts in groups.items()]
SOURCE.hide_render=True;SOURCE.hide_viewport=True

wallpath=os.path.join(os.path.dirname(ROOT),'rempart_p1.blend')
with bpy.data.libraries.load(wallpath,link=False) as (src,dst):
    dst.objects=[n for n in ['P1_Pilier_Pierre','P1_Pilier_Argent','P1_Mousse_Pilier_A','P1_Travee_Pierre','P1_Travee_Argent','P1_Mousse_Travee_A'] if n in src.objects]
for ob in dst.objects:
    if ob:
        CONTEXT.objects.link(ob)
        # Front of projecting pilier face is at -4.45; place it behind Y=0.
        ob.location=(0,4.45,-7.5) if 'Pilier' in ob.name else (10,4.45,-7.5)
CONTEXT.hide_render=True;CONTEXT.hide_viewport=True

floor_mat=simple('Sol_Presentation',(93,104,115))
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-1.9));floor=bpy.context.object;floor.name='Sol_Presentation'
for c in list(floor.users_collection):c.objects.unlink(floor)
STAGE.objects.link(floor);floor.data.materials.append(floor_mat)
world=bpy.data.worlds.new('Fond');world.use_nodes=True;s.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.16,.22,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.42
def light(name,kind,loc,energy,color,size=4,target=(0,-1,.3)):
    d=bpy.data.lights.new(name,kind);d.energy=energy;d.color=color
    if kind=='AREA':d.shape='DISK';d.size=size
    else:d.shadow_soft_size=.15
    o=bpy.data.objects.new(name,d);STAGE.objects.link(o);o.location=loc
    o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
light('Key','AREA',(4,-5,6),500,(1,.88,.74))
light('Fill','AREA',(-4,-3,3),350,(.66,.82,1))
light('Rim','AREA',(2,2,5),600,(.7,.85,1))
light('Lumiere_Presentation','POINT',(0,-1.75,0),12,(1,.58,.2))
cd=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',cd);STAGE.objects.link(cam);s.camera=cam;cd.type='ORTHO'
def aim(loc,target,scale):
    cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cd.ortho_scale=scale
s.render.engine='CYCLES';s.cycles.samples=48;s.cycles.use_denoising=True
s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG'
s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast'
s.use_nodes=True;nt=s.node_tree;nt.nodes.clear()
a=nt.nodes.new('CompositorNodeRLayers');g=nt.nodes.new('CompositorNodeGlare');g.glare_type='FOG_GLOW';g.threshold=1.5;g.quality='HIGH'
c=nt.nodes.new('CompositorNodeComposite');nt.links.new(a.outputs['Image'],g.inputs['Image']);nt.links.new(g.outputs['Image'],c.inputs['Image'])

bpy.ops.object.select_all(action='DESELECT')
for o in exports:o.select_set(True)
bpy.context.view_layer.objects.active=exports[0]
bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT,'exports','P1_Lanterne_Murale.fbx'),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',apply_scale_options='FBX_SCALE_UNITS',use_mesh_modifiers=True,mesh_smooth_type='FACE',path_mode='COPY',embed_textures=True,bake_anim=False,add_leaf_bones=False)
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'exports','P1_Lanterne_Murale.glb'),export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_materials='EXPORT')
bpy.ops.object.select_all(action='DESELECT')
meta=[]
for o in exports:
    o.data.calc_loop_triangles();meta.append({'mesh':o.name,'role':o['PartRole'],'triangles':len(o.data.loop_triangles),'dimensions_xyz':list(o.dimensions),'pivot_xyz':list(o.location),'uv_layers':len(o.data.uv_layers)})
pts=[o.matrix_world@Vector(b) for o in exports for b in o.bound_box]
manifest={'asset':'P1_Lanterne_Murale','reference':'Approved standing lantern P1 + rempart_p1.blend','dimensions_xyz':[max(p[i] for p in pts)-min(p[i] for p in pts) for i in range(3)],'bounds_min':[min(p[i] for p in pts) for i in range(3)],'bounds_max':[max(p[i] for p in pts) for i in range(3)],'pivot':'Backplate center at wall contact, face -Y','units':'1 unit intended as 1 stud','total_triangles':sum(e['triangles'] for e in meta),'meshes':meta,'approval_status':'Awaiting user visual review','roblox_import_status':'Not imported'}
with open(os.path.join(ROOT,'manifest.json'),'w',encoding='utf-8') as f:json.dump(manifest,f,indent=2)
def render(name,res,loc,target,scale):
    s.render.resolution_x,s.render.resolution_y=res;aim(loc,target,scale)
    s.render.filepath=os.path.join(ROOT,'previews',name);bpy.ops.render.render(write_still=True)
render('01_lanterne_murale.png',(1500,1300),(8,-11,6),(0,-.85,.2),5.2)
render('02_profil_fixation.png',(1500,1300),(12,-3,3),(0,-1,.2),5.5)
CONTEXT.hide_render=False;CONTEXT.hide_viewport=False
floor.location.z=-7.5
render('03_sur_rempart_P1.png',(1500,1300),(8,-13,5),(0,-.55,.1),7.5)
CONTEXT.hide_render=True;CONTEXT.hide_viewport=True
floor.location.z=-1.9
aim((8,-11,6),(0,-.85,.2),5.2);s.render.resolution_x=1500;s.render.resolution_y=1300
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'P1_Lanterne_Murale.blend'))
print('ASSET_COMPLETE',json.dumps(manifest))
