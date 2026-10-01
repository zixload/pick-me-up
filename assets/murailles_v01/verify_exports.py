"""Read-only validation of exported FBX geometry through Blender re-import."""
import bpy
import json
import struct
from pathlib import Path
from mathutils import Vector

root=Path(__file__).resolve().parent
manifest=json.loads((root/"manifest.json").read_text(encoding="utf-8"))
checks=[]
for asset in manifest["assets"]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(root/"exports"/asset["fbx"]))
    meshes=[obj for obj in bpy.context.scene.objects if obj.type=="MESH"]
    assert len(meshes)==1, (asset["asset"],len(meshes))
    obj=meshes[0]
    coords=[obj.matrix_world@v.co for v in obj.data.vertices]
    size=[max(v[i] for v in coords)-min(v[i] for v in coords) for i in range(3)]
    expected=asset["dimensions_blender_xyz"]
    assert max(abs(a-b) for a,b in zip(size,expected)) < .002, (asset["asset"],size,expected)
    triangles=sum(len(poly.vertices)-2 for poly in obj.data.polygons)
    assert triangles==asset["triangles"]
    assert len(obj.data.uv_layers)==1
    assert all(len(poly.vertices)==3 for poly in obj.data.polygons)
    assert len(obj.data.materials)==1
    uv=obj.data.uv_layers.active
    assert all(0<=item.uv.x<=1 and 0<=item.uv.y<=1 for item in uv.data)
    images=[node.image for mat in obj.data.materials if mat and mat.use_nodes
            for node in mat.node_tree.nodes if node.type=="TEX_IMAGE" and node.image]
    assert images, asset["asset"]+" missing embedded images"
    for img in images:
        # Blender loads imported images lazily until pixels are accessed.
        assert len(img.pixels)>0, (asset["asset"],img.filepath)
        assert img.has_data, (asset["asset"],img.filepath)
    blob=(root/"exports"/asset["glb"]).read_bytes()
    assert blob[:4]==b"glTF"
    json_length=struct.unpack_from("<I",blob,12)[0]
    doc=json.loads(blob[20:20+json_length])
    primitives=[p for m in doc["meshes"] for p in m["primitives"]]
    glb_triangles=sum(doc["accessors"][p["indices"]]["count"]//3 for p in primitives)
    assert glb_triangles==triangles
    assert all("TEXCOORD_0" in p["attributes"] for p in primitives)
    assert len(doc["materials"])==1
    assert all("bufferView" in image for image in doc["images"])
    checks.append({"asset":asset["asset"],"fbx_roundtrip":"PASS","glb_structure":"PASS",
        "triangles":triangles,"uv_layers":1,"embedded_images":len(images),
        "dimensions_blender_xyz":[round(v,4) for v in size]})
    print("PASS",asset["asset"],triangles,flush=True)
(root/"verification.json").write_text(json.dumps({"status":"PASS",
    "scope":"Blender FBX re-import; Roblox Studio import not yet tested",
    "assets":checks},indent=2),encoding="utf-8")
print("ALL_EXPORTS_PASS",flush=True)
