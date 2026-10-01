"""One review asset: six hand-shaped P1 stones. Blender 4.5."""
import bpy, bmesh, math, random, os, json, array
from mathutils import Vector
ROOT=os.path.dirname(os.path.abspath(__file__))
ASSET='P1_Cailloux_A'
for sub in ('exports','textures','previews'): os.makedirs(os.path.join(ROOT,sub),exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.unit_settings.system='NONE';scene.unit_settings.scale_length=1
def collection(name):
    c=bpy.data.collections.new(name);scene.collection.children.link(c);return c
SOURCE=collection('00_SOURCE_EDITABLE');EXPORT=collection('01_ASSET_EXPORT')
CONTEXT=collection('02_CONTEXTE_REMPART_P1');STAGE=collection('03_PRESENTATION')
def move(ob,c):
    for old in list(ob.users_collection): old.objects.unlink(ob)
    c.objects.link(ob);return ob
def linear(c):
    x=c/255;return x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4
palette=[(84,100,122),(94,109,129),(76,92,111),(105,120,141),
         (89,102,116),(71,87,107),(97,110,125),(82,97,114)]
images={}
for kind in ('Color','Roughness','Metalness'):
    n=512;img=bpy.data.images.new('P1_Cailloux_'+kind,n,n,alpha=True)
    if kind!='Color':img.colorspace_settings.name='Non-Color'
    pixels=array.array('f');rng=random.Random(919)
    for y in range(n):
        for x in range(n):
            idx=(y//256)*4+x//128
            if kind=='Color':
                # Restrained mineral grain; geometry carries the visible detail.
                grain=rng.uniform(-2,2)+.6*math.sin(x*.15)*math.sin(y*.09)
                col=[linear(max(0,min(255,c+grain))) for c in palette[idx]]
            else:col=[.82 if kind=='Roughness' else 0]*3
            pixels.extend((*col,1))
    img.pixels.foreach_set(pixels);img.filepath_raw=os.path.join(ROOT,'textures',img.name+'.png')
    img.file_format='PNG';img.save();img.pack();images[kind]=img
mat=bpy.data.materials.new('P1_Cailloux_Pierre_Gris_Bleu');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF')
for kind,socket in [('Color','Base Color'),('Roughness','Roughness'),('Metalness','Metallic')]:
    node=mat.node_tree.nodes.new('ShaderNodeTexImage');node.image=images[kind]
    mat.node_tree.links.new(node.outputs['Color'],bs.inputs[socket])
def uv_tile(ob,idx):
    me=ob.data;uv=me.uv_layers.new(name='UVMap');uv.active_render=True
    lo=[min(v.co[a] for v in me.vertices) for a in range(3)]
    sz=[max(v.co[a] for v in me.vertices)-lo[a] for a in range(3)]
    for p in me.polygons:
        axis=max(range(3),key=lambda a:abs(p.normal[a]));axes=[(1,2),(0,2),(0,1)][axis]
        for li in p.loop_indices:
            v=me.vertices[me.loops[li].vertex_index].co
            u=(v[axes[0]]-lo[axes[0]])/max(sz[axes[0]],1e-5)
            w=(v[axes[1]]-lo[axes[1]])/max(sz[axes[1]],1e-5)
            uv.data[li].uv=((idx%4+.05+.9*u)/4,(idx//4+.05+.9*w)/2)
def stone(name,xy,size,angle,seed,tile,shape):
    rng=random.Random(seed);n=shape
    outline=[]
    for k in range(n):
        a=2*math.pi*k/n+rng.uniform(-.08,.08)
        r=rng.uniform(.88,1.07);outline.append((math.cos(a)*r,math.sin(a)*r))
    verts=[]
    # Broad asymmetric upper faces, tapered shoulder, level underside.
    for ring,scale,z in [(0,.73,0),(1,1,.29),(2,.76,.75),(3,.43,1)]:
        shiftx=[-.08,0,.05,.16][ring];shifty=[.03,0,-.04,-.12][ring]
        for k,(x,y) in enumerate(outline):
            vz=z if ring==0 else z+rng.uniform(-.07,.07)
            if ring==3: vz=1-.075*(x+1)+rng.uniform(-.018,.018)
            verts.append(((x*scale+shiftx)*size[0]/2,(y*scale+shifty)*size[1]/2,max(0,vz)*size[2]))
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],[]);me.update()
    bm=bmesh.new();bm.from_mesh(me)
    hull=bmesh.ops.convex_hull(bm,input=list(bm.verts),use_existing_faces=False)
    dead=list({g for g in hull['geom_interior']+hull['geom_unused'] if isinstance(g,bmesh.types.BMVert) and g.is_valid})
    if dead:bmesh.ops.delete(bm,geom=dead,context='VERTS')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    ob=bpy.data.objects.new(name,me);SOURCE.objects.link(ob);ob.location=(*xy,0);ob.rotation_euler.z=math.radians(angle)
    bpy.context.view_layer.objects.active=ob;ob.select_set(True)
    bevel=ob.modifiers.new('Aretes_adoucies','BEVEL');bevel.width=min(size)*.045;bevel.segments=2;bevel.affect='EDGES'
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    for p in ob.data.polygons:p.use_smooth=True
    normal=ob.modifiers.new('Normales_ponderees','WEIGHTED_NORMAL');normal.keep_sharp=True;normal.weight=35
    bpy.ops.object.modifier_apply(modifier=normal.name)
    ob.data.update();uv_tile(ob,tile);ob.data.materials.append(mat)
    ob['PartRole']='Pierre';ob['StoneProfile']='Irregular convex stone, flat ground contact'
    ob.select_set(False);return ob
stones=[
    stone('01_Pierre_Plate',(-.48,.26),(1.12,.82,.34),-18,51,0,9),
    stone('02_Pierre_Trapue',(.40,.31),(.76,.65,.49),28,73,1,8),
    stone('03_Pierre_Allongee',(-.34,-.49),(.79,.40,.26),-24,114,2,7),
    stone('04_Fragment_A',(.52,-.43),(.39,.33,.20),16,142,4,7),
    stone('05_Fragment_B',(-1.02,-.33),(.31,.25,.13),-41,155,3,6),
    stone('06_Fragment_C',(.98,.14),(.26,.22,.12),62,176,5,6)]
# Export as one decorative mesh, retaining six editable stones in the source collection.
bpy.ops.object.select_all(action='DESELECT');copies=[]
for p in stones:
    o=p.copy();o.data=p.data.copy();EXPORT.objects.link(o);o.select_set(True);copies.append(o)
bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();ob=bpy.context.object;ob.name=ASSET+'_Pierres'
scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
tri=ob.modifiers.new('Triangulation','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name)
ob['AssetName']=ASSET;ob['PartRole']='Pierres';ob['Pivot']='Ground center';ob.select_set(False)
SOURCE.hide_render=True;SOURCE.hide_viewport=True
wallpath=os.path.join(os.path.dirname(ROOT),'rempart_p1.blend')
names=['P1_Travee_Pierre','P1_Travee_Argent','P1_Pilier_Pierre','P1_Pilier_Argent','P1_Mousse_Pilier_A']
with bpy.data.libraries.load(wallpath,link=False) as (src,dst):dst.objects=[n for n in names if n in src.objects]
for o in dst.objects:
    if o:CONTEXT.objects.link(o);o.location=(0,5.8,0) if 'Pilier' in o.name else (10,5.8,0)
CONTEXT.hide_render=True;CONTEXT.hide_viewport=True
def simple(name,rgb,rough=.9):
    m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*[linear(c) for c in rgb],1);p.inputs['Roughness'].default_value=rough;return m
ground=simple('Sol_Presentation',(120,128,134))
bpy.ops.mesh.primitive_plane_add(size=200);floor=move(bpy.context.object,STAGE)
floor.name='Sol_Presentation';floor.location.z=-.012;floor.data.materials.append(ground)
world=bpy.data.worlds.new('Fond_Presentation');world.use_nodes=True;scene.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(.15,.19,.25,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.5
for name,loc,energy,color in [('Key',(2,-3,5),270,(1,.92,.82)),('Fill',(-3,-1,3),140,(.75,.85,1)),('Rim',(1,3,4),210,(.85,.91,1))]:
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=3
    light=bpy.data.objects.new(name,data);STAGE.objects.link(light);light.location=loc
    light.rotation_euler=(Vector((0,0,0))-light.location).to_track_quat('-Z','Y').to_euler()
cd=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',cd);STAGE.objects.link(cam);scene.camera=cam;cd.type='ORTHO'
def camera(loc,target,scale):
    cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cd.ortho_scale=scale
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT,'exports',ASSET+'.fbx'),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',apply_scale_options='FBX_SCALE_UNITS',use_mesh_modifiers=True,mesh_smooth_type='FACE',path_mode='COPY',embed_textures=True,bake_anim=False,add_leaf_bones=False)
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'exports',ASSET+'.glb'),export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_materials='EXPORT')
bpy.ops.object.select_all(action='DESELECT');ob.data.calc_loop_triangles()
manifest={'asset':ASSET,'reference':'../rempart_p1.blend','units':'1 unit intended as 1 stud','dimensions_xyz':list(ob.dimensions),'pivot':'Ground center, Z=0','source_stones':6,'total_triangles':len(ob.data.loop_triangles),'meshes':[{'mesh':ob.name,'role':'Pierres','triangles':len(ob.data.loop_triangles),'dimensions_xyz':list(ob.dimensions),'pivot_xyz':list(ob.location),'uv_layers':len(ob.data.uv_layers)}],'approval_status':'Awaiting user visual review','roblox_import_status':'Not imported'}
with open(os.path.join(ROOT,'manifest.json'),'w',encoding='utf-8') as f:json.dump(manifest,f,indent=2)
def render(name,res,loc,target,scale):
    scene.render.resolution_x,scene.render.resolution_y=res;camera(loc,target,scale)
    scene.render.filepath=os.path.join(ROOT,'previews',name);bpy.ops.render.render(write_still=True)
render('01_cailloux_34.png',(1500,1100),(3,-4,3.3),(0,0,.16),3.2)
render('02_cailloux_dessus.png',(1500,1100),(0,0,6),(0,0,0),3.1)
CONTEXT.hide_render=False;CONTEXT.hide_viewport=False
floor.data.materials[0]=simple('Sol_Contexte',(105,114,118))
render('03_au_pied_du_rempart.png',(1500,1100),(5,-7,4.2),(0,1,.7),6.8)
CONTEXT.hide_render=True;CONTEXT.hide_viewport=True;floor.data.materials[0]=ground
camera((3,-4,3.3),(0,0,.16),3.2)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,ASSET+'.blend'))
print('ASSET_COMPLETE',json.dumps(manifest))
