"""One review asset: one flat P1 garden rock. Blender 4.5."""
import bpy, bmesh, math, random, os, json, array
from mathutils import Vector
ROOT=os.path.dirname(os.path.abspath(__file__))
ASSET='P1_Roche_Plate'
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
         (89,102,116),(71,87,107),(88,128,56),(71,103,47)]
images={}
for kind in ('Color','Roughness','Metalness'):
    n=512;img=bpy.data.images.new('P1_Roche_'+kind,n,n,alpha=True)
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
mat=bpy.data.materials.new('P1_Roche_Pierre_Gris_Bleu');mat.use_nodes=True
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

def uv_stone(ob):
    uv_tile(ob,0)
    for p in ob.data.polygons:
        # Same P1 stone swatches as the approved pebbles; discreet face variation.
        idx=1 if p.normal.z>.85 and p.center.z>.65 else 2 if p.normal.z<-.5 else 0
        if p.normal.y>.75 and p.normal.z<.3:idx=4
        for li in p.loop_indices:
            u,v=ob.data.uv_layers.active.data[li].uv
            ob.data.uv_layers.active.data[li].uv=(u+(idx%4)/4,v+(idx//4)/2)

# Deliberately designed contour: low, broad slab, clipped corners and a side recess.
outline=[(-1.62,-.36),(-1.34,-.85),(-.80,-1.02),(-.16,-.98),(.34,-1.10),
         (.88,-.88),(1.19,-.63),(1.05,-.23),(1.64,-.05),(1.50,.49),
         (.85,.96),(.07,1.10),(-.77,.99),(-1.35,.56)]
n=len(outline);verts=[];rng=random.Random(282)
for ring in range(4):
    for i,(x,y) in enumerate(outline):
        if ring==0:xx,yy,z=x*.72,y*.76,0
        elif ring==1:xx,yy,z=x,y,.20-.035*x+rng.uniform(-.025,.025)
        elif ring==2:xx,yy,z=x*.95-.015,y*.94+.01,.67-.075*x+rng.uniform(-.032,.032)
        else:xx,yy=x*.73-.13,y*.73+.035;z=.92-.115*xx+.025*yy
        verts.append((xx,yy,z))
faces=[tuple(reversed(range(n)))]
for ring in range(3):
    for i in range(n):
        j=(i+1)%n;faces.append((ring*n+i,ring*n+j,(ring+1)*n+j,(ring+1)*n+i))
faces.append(tuple(3*n+i for i in range(n)))
me=bpy.data.meshes.new('Roche_Plate_Silhouette');me.from_pydata(verts,[],faces);me.update()
bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
rock=bpy.data.objects.new('Roche_Plate_Source',me);SOURCE.objects.link(rock)
bpy.context.view_layer.objects.active=rock;rock.select_set(True)
bevel=rock.modifiers.new('Petites_aretes_usees','BEVEL');bevel.width=.028;bevel.segments=2
bevel.limit_method='ANGLE';bevel.angle_limit=.17;bevel.harden_normals=True
bpy.ops.object.modifier_apply(modifier=bevel.name)
# Broad planes remain readable, softened only at the small bevels.
for p in rock.data.polygons:p.use_smooth=True
normal=rock.modifiers.new('Normales_ponderees','WEIGHTED_NORMAL');normal.keep_sharp=True;normal.weight=70
bpy.ops.object.modifier_apply(modifier=normal.name)
rock.data.update();uv_stone(rock);rock.data.materials.append(mat)
rock['PartRole']='Pierre';rock['Shape']='Broad sloping top, side recess, flat underside';rock.select_set(False)

# Moss conforms to the existing rock via ray casting. Its thin, irregular islands
# are independent geometry and do not change the underlying stone silhouette.
patches=[]
def moss_patch(name,center,rx,ry,seed,tile):
    rng=random.Random(seed);m=17;points=[center]
    for i in range(m):
        a=2*math.pi*i/m;r=rng.uniform(.69,1.06)
        points.append((center[0]+math.cos(a)*rx*r,center[1]+math.sin(a)*ry*r))
    verts=[]
    for x,y in points:
        hit,loc,norm,index=rock.ray_cast(Vector((x,y,4)),Vector((0,0,-1)))
        assert hit,(name,x,y)
        loc+=norm*.006;verts.append(tuple(loc))
    faces=[(0,i+1,(i+1)%m+1) for i in range(m)]
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    # Shorter triangles follow the beveled shoulder without cutting through it.
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.subdivide_edges(bm,edges=list(bm.edges),cuts=3,use_grid_fill=True)
    for v in bm.verts:
        hit,loc,norm,index=rock.ray_cast(Vector((v.co.x,v.co.y,4)),Vector((0,0,-1)))
        assert hit,(name,tuple(v.co))
        v.co=loc+norm*.014
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free();mesh.update()
    ob=bpy.data.objects.new(name,mesh);SOURCE.objects.link(ob);mesh.materials.append(mat)
    uv_tile(ob,tile);ob['PartRole']='Mousse';patches.append(ob);return ob
moss_patch('Mousse_Rebord_Arriere',(-.70,.52),.39,.24,352,6)
moss_patch('Mousse_Ilot_Arriere',(-.23,.64),.17,.11,393,6)
moss_patch('Mousse_Ilot_Cote',(-1.08,.18),.10,.18,432,7)

def export_group(parts,role):
    bpy.ops.object.select_all(action='DESELECT');copies=[]
    for p in parts:
        o=p.copy();o.data=p.data.copy();EXPORT.objects.link(o);o.select_set(True);copies.append(o)
    bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();o=bpy.context.object;o.name=ASSET+'_'+role
    scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    tri=o.modifiers.new('Triangulation','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name)
    o['AssetName']=ASSET;o['PartRole']=role;o['Pivot']='Ground center';o.select_set(False);return o
stone_export=export_group([rock],'Pierre');moss_export=export_group(patches,'Mousse')
export_objects=[stone_export,moss_export];SOURCE.hide_render=True;SOURCE.hide_viewport=True

# Presentation-only references, never included in the two export meshes.
wallpath=os.path.join(os.path.dirname(ROOT),'rempart_p1.blend')
names=['P1_Travee_Pierre','P1_Travee_Argent','P1_Pilier_Pierre','P1_Pilier_Argent','P1_Mousse_Pilier_A']
with bpy.data.libraries.load(wallpath,link=False) as (src,dst):dst.objects=[n for n in names if n in src.objects]
for o in dst.objects:
    if o:CONTEXT.objects.link(o);o.location=(0,6.1,0) if 'Pilier' in o.name else (10,6.1,0)
pebblepath=os.path.join(os.path.dirname(ROOT),'cailloux_p1','P1_Cailloux_A.blend')
with bpy.data.libraries.load(pebblepath,link=False) as (src,dst):dst.objects=['P1_Cailloux_A_Pierres']
pebbles=dst.objects[0];CONTEXT.objects.link(pebbles);pebbles.location=(2.3,-.1,0)
pebbles.rotation_euler.z=math.radians(-20)
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
for name,loc,energy,color in [('Key',(2,-3,5),350,(1,.92,.82)),('Fill',(-3,-1,3),190,(.75,.85,1)),('Rim',(1,3,4),260,(.85,.91,1))]:
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.color=color;data.shape='DISK';data.size=3.8
    light=bpy.data.objects.new(name,data);STAGE.objects.link(light);light.location=loc
    light.rotation_euler=(Vector((0,0,.5))-light.location).to_track_quat('-Z','Y').to_euler()
cd=bpy.data.cameras.new('Camera');cam=bpy.data.objects.new('Camera',cd);STAGE.objects.link(cam);scene.camera=cam;cd.type='ORTHO'
def camera(loc,target,scale):
    cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cd.ortho_scale=scale
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'

# Explicit selection excludes floor, existing wall and approved pebbles.
bpy.ops.object.select_all(action='DESELECT')
for o in export_objects:o.select_set(True)
bpy.context.view_layer.objects.active=stone_export
bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT,'exports',ASSET+'.fbx'),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',apply_scale_options='FBX_SCALE_UNITS',use_mesh_modifiers=True,mesh_smooth_type='FACE',path_mode='COPY',embed_textures=True,bake_anim=False,add_leaf_bones=False)
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'exports',ASSET+'.glb'),export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_materials='EXPORT')
bpy.ops.object.select_all(action='DESELECT')
metadata=[]
for o in export_objects:
    o.data.calc_loop_triangles()
    metadata.append({'mesh':o.name,'role':o['PartRole'],'triangles':len(o.data.loop_triangles),'dimensions_xyz':list(o.dimensions),'pivot_xyz':list(o.location),'uv_layers':len(o.data.uv_layers)})
bm=bmesh.new();bm.from_mesh(stone_export.data)
assert all(e.is_manifold for e in bm.edges),'Stone must be a closed manifold'
assert bm.calc_volume(signed=True)>0,'Stone must have outward-facing normals'
assert min(v.co.z for v in bm.verts)>=-.0001,'Ground contact must stay at Z=0'
volume=bm.calc_volume(signed=True);bm.free()
manifest={'asset':ASSET,'reference':'../rempart_p1.blend + approved P1_Cailloux_A','units':'1 unit intended as 1 stud','dimensions_xyz':list(stone_export.dimensions),'pivot':'Ground center, Z=0','total_triangles':sum(m['triangles'] for m in metadata),'meshes':metadata,'stone_manifold':True,'stone_volume':volume,'moss_optional':True,'approval_status':'Awaiting user visual review','roblox_import_status':'Not imported'}
with open(os.path.join(ROOT,'manifest.json'),'w',encoding='utf-8') as f:json.dump(manifest,f,indent=2)
def render(name,loc,target,scale):
    scene.render.resolution_x=1500;scene.render.resolution_y=1100;camera(loc,target,scale)
    scene.render.filepath=os.path.join(ROOT,'previews',name);bpy.ops.render.render(write_still=True)
render('01_roche_plate_34.png',(4,-6,4.0),(0,0,.44),4.55)
moss_export.hide_render=True
render('02_roche_sans_mousse.png',(4,-6,4.0),(0,0,.44),4.55)
moss_export.hide_render=False
render('03_roche_dessus.png',(0,0,7),(0,0,0),4.0)
CONTEXT.hide_render=False;CONTEXT.hide_viewport=False
floor.data.materials[0]=simple('Sol_Contexte',(105,114,118))
render('04_avec_rempart_et_cailloux.png',(6,-9,5.1),(.6,1,.8),8.8)
CONTEXT.hide_render=True;CONTEXT.hide_viewport=True;floor.data.materials[0]=ground
camera((4,-6,4.0),(0,0,.44),4.55)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,ASSET+'.blend'))
print('ASSET_COMPLETE',json.dumps(manifest))

