import bpy
from pathlib import Path
root=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(root/"PMU_Murailles_V01.blend"))
scene=bpy.context.scene
sheet=bpy.data.collections["04_PLANCHE_MODULES"]
for obj in sheet.objects:
    if obj.type=="FONT":
        if "Corniche" in obj.name: obj.location.z=7.2
        elif "Balustrade" in obj.name: obj.location.z=16.3
mat=bpy.data.materials["Texte_Planche"]
mat.use_nodes=True
nodes=mat.node_tree.nodes
nodes.clear()
out=nodes.new("ShaderNodeOutputMaterial")
emission=nodes.new("ShaderNodeEmission")
emission.inputs["Color"].default_value=(.83,.82,.74,1)
emission.inputs["Strength"].default_value=1.0
mat.node_tree.links.new(emission.outputs[0],out.inputs["Surface"])
demo=bpy.data.collections["02_ASSEMBLAGE_DEMO"]
ground=bpy.data.objects["Sol_Presentation"]
demo.hide_render=True
ground.hide_render=True
sheet.hide_render=False
sheet.hide_viewport=False
scene.camera=bpy.data.objects["Camera_Planche"]
scene.render.resolution_x=2000
scene.render.resolution_y=1000
scene.cycles.samples=24
scene.render.filepath=str(root/"previews"/"03_modules.png")
bpy.ops.render.render(write_still=True)
sheet.hide_render=True
sheet.hide_viewport=True
demo.hide_render=False
ground.hide_render=False
scene.camera=bpy.data.objects["Camera_Assemblage"]
scene.render.resolution_x=1600
scene.render.resolution_y=1100
scene.cycles.samples=40
bpy.ops.wm.save_as_mainfile(filepath=str(root/"PMU_Murailles_V01.blend"))
print("SHEET_POLISHED",flush=True)
