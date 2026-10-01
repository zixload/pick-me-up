import bpy,os
from mathutils import Vector
ROOT=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'P1_Lanterne_Pied.blend'))
s=bpy.context.scene
bpy.data.collections['02_CONTEXTE_REMPART_P1'].hide_render=False
bpy.data.collections['02_CONTEXTE_REMPART_P1'].hide_viewport=False
floor=bpy.data.objects['Sol_Presentation']
oldmat=floor.data.materials[0]
context_mat=oldmat.copy()
context_mat.name='Sol_Context_Pierre'
def srgb(c):
    c=c/255
    return c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4
context_mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*[srgb(c) for c in (133,143,149)],1)
floor.data.materials[0]=context_mat
s.world.node_tree.nodes['Background'].inputs[1].default_value=.48
cam=s.camera
cam.location=(16,-24,14)
cam.rotation_euler=(Vector((0,2.2,5.3))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.ortho_scale=19
s.render.resolution_x=1500;s.render.resolution_y=1100
s.render.filepath=os.path.join(ROOT,'previews','03_avec_rempart_P1.png')
bpy.ops.render.render(write_still=True)
print('CONTEXT_FRAMING_OK')
