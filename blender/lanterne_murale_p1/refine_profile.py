import bpy,os
from mathutils import Vector
ROOT=os.path.dirname(os.path.abspath(__file__))
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'P1_Lanterne_Murale.blend'))
s=bpy.context.scene
s.camera.location=(12,-3,3)
s.camera.rotation_euler=(Vector((0,-1,.2))-s.camera.location).to_track_quat('-Z','Y').to_euler()
s.camera.data.ortho_scale=5.5
s.render.resolution_x=1500;s.render.resolution_y=1300
s.render.filepath=os.path.join(ROOT,'previews','02_profil_fixation.png')
bpy.ops.render.render(write_still=True)
context=bpy.data.collections['02_CONTEXTE_REMPART_P1']
context.hide_render=False;context.hide_viewport=False
bpy.data.objects['Sol_Presentation'].location.z=-7.5
s.camera.location=(8,-13,5)
s.camera.rotation_euler=(Vector((0,-.55,.1))-s.camera.location).to_track_quat('-Z','Y').to_euler()
s.camera.data.ortho_scale=7.5
s.render.filepath=os.path.join(ROOT,'previews','03_sur_rempart_P1.png')
bpy.ops.render.render(write_still=True)
print('PROFILE_COMPLETE')
