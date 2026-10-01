import bpy, os, json, struct
from mathutils import Vector
ROOT=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'P1_Lanterne_Pied.blend'))
export=list(bpy.data.collections['01_ASSET_EXPORT'].objects)
bpy.ops.object.select_all(action='DESELECT')
for ob in export: ob.select_set(True)
bpy.context.view_layer.objects.active=export[0]
# Re-export from explicit asset selection, excluding all presentation geometry.
bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT,'exports','P1_Lanterne_Pied.fbx'),use_selection=True,
    object_types={'MESH'},axis_forward='-Z',axis_up='Y',apply_scale_options='FBX_SCALE_UNITS',
    use_mesh_modifiers=True,mesh_smooth_type='FACE',path_mode='COPY',embed_textures=True,bake_anim=False,add_leaf_bones=False)
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'exports','P1_Lanterne_Pied.glb'),export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_materials='EXPORT')
bpy.ops.object.select_all(action='DESELECT')
with open(os.path.join(ROOT,'manifest.json'),encoding='utf-8') as f: manifest=json.load(f)
expected={x['mesh']:x for x in manifest['meshes']}
with open(os.path.join(ROOT,'exports','P1_Lanterne_Pied.glb'),'rb') as f:
    data=f.read()
magic,version,length=struct.unpack_from('<III',data,0)
assert magic==0x46546c67 and version==2 and length==len(data)
size,typ=struct.unpack_from('<II',data,12)
gltf=json.loads(data[20:20+size].decode('utf-8'))
assert len(gltf['meshes'])==4, 'Unexpected geometry in GLB'
assert all('bufferView' in i for i in gltf.get('images',[])), 'External GLB textures'
glb_tris=sum(gltf['accessors'][p['indices']]['count']//3 for m in gltf['meshes'] for p in m['primitives'])
assert glb_tris==manifest['total_triangles']
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT,'exports','P1_Lanterne_Pied.fbx'))
objs=[o for o in bpy.data.objects if o.type=='MESH']
assert set(o.name for o in objs)==set(expected), [o.name for o in objs]
checks=[]
for o in objs:
    e=expected[o.name]
    o.data.calc_loop_triangles()
    assert len(o.data.loop_triangles)==e['triangles']
    assert len(o.data.uv_layers)==1
    assert max(abs(o.dimensions[i]-e['dimensions_xyz'][i]) for i in range(3))<.001
    assert o.location.length<.001, (o.name,list(o.location))
    assert all(0<=loop.uv.x<=1 and 0<=loop.uv.y<=1 for loop in o.data.uv_layers.active.data)
    checks.append({'mesh':o.name,'dimensions':list(o.dimensions),'triangles':len(o.data.loop_triangles),'uv':1,'pivot':list(o.location)})
loaded=[]
for img in bpy.data.images:
    if img.source=='FILE':
        assert len(img.pixels)>0, img.name
        loaded.append(img.name)
assert len(loaded)>=3
result={'status':'PASS','fbx_roundtrip':checks,'embedded_images':loaded,'glb_meshes':4,'glb_triangles':glb_tris,
        'scope':'Blender export integrity; Roblox import and live lighting still pending.'}
with open(os.path.join(ROOT,'verification.json'),'w',encoding='utf-8') as f:json.dump(result,f,indent=2)
print('VERIFICATION_PASS',json.dumps(result))
