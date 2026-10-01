import bpy,os,json,struct
ROOT=os.path.dirname(os.path.abspath(__file__))
ASSET='P1_Cailloux_A'
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,ASSET+'.blend'))
# Keep the inherited atlas locally and embedded in the delivered files.
for img in bpy.data.images:
    if img.name.startswith('P1_Cailloux_'):
        img.filepath_raw=os.path.join(ROOT,'textures',img.name+'.png');img.file_format='PNG';img.save();img.pack()
bpy.ops.object.select_all(action='DESELECT')
export=list(bpy.data.collections['01_ASSET_EXPORT'].objects)
for o in export:o.select_set(True)
bpy.context.view_layer.objects.active=export[0]
bpy.ops.export_scene.fbx(filepath=os.path.join(ROOT,'exports',ASSET+'.fbx'),use_selection=True,object_types={'MESH'},axis_forward='-Z',axis_up='Y',apply_scale_options='FBX_SCALE_UNITS',use_mesh_modifiers=True,mesh_smooth_type='FACE',path_mode='COPY',embed_textures=True,bake_anim=False,add_leaf_bones=False)
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'exports',ASSET+'.glb'),export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_materials='EXPORT')
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,ASSET+'.blend'))
with open(os.path.join(ROOT,'manifest.json'),encoding='utf-8') as f:manifest=json.load(f)
expected={m['mesh']:m for m in manifest['meshes']}
with open(os.path.join(ROOT,'exports',ASSET+'.glb'),'rb') as f:data=f.read()
magic,version,length=struct.unpack_from('<III',data,0)
assert magic==0x46546c67 and version==2 and length==len(data)
size,typ=struct.unpack_from('<II',data,12)
gltf=json.loads(data[20:20+size].decode('utf-8'))
assert len(gltf['meshes'])==1
assert all('bufferView' in i for i in gltf.get('images',[]))
tris=sum(gltf['accessors'][p['indices']]['count']//3 for m in gltf['meshes'] for p in m['primitives'])
assert tris==manifest['total_triangles']
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT,'exports',ASSET+'.fbx'))
objects=[o for o in bpy.data.objects if o.type=='MESH']
assert set(o.name for o in objects)==set(expected)
checks=[]
for o in objects:
    e=expected[o.name];o.data.calc_loop_triangles()
    assert len(o.data.loop_triangles)==e['triangles']
    assert len(o.data.uv_layers)==1
    assert max(abs(o.dimensions[i]-e['dimensions_xyz'][i]) for i in range(3))<.001
    assert o.location.length<.001
    assert all(0<=l.uv.x<=1 and 0<=l.uv.y<=1 for l in o.data.uv_layers.active.data)
    checks.append({'mesh':o.name,'triangles':len(o.data.loop_triangles),'dimensions_xyz':list(o.dimensions),'pivot_xyz':list(o.location),'uv_layers':1})
images=[]
for img in bpy.data.images:
    if img.source=='FILE':
        assert len(img.pixels)>0
        images.append(img.name)
assert len(images)>=3
result={'status':'PASS','fbx_roundtrip':checks,'embedded_images':images,'glb_meshes':1,'glb_triangles':tris,'scope':'Export integrity in Blender; Roblox import pending.'}
with open(os.path.join(ROOT,'verification.json'),'w',encoding='utf-8') as f:json.dump(result,f,indent=2)
print('VERIFICATION_PASS',json.dumps(result))

