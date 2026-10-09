class_name MeshMerge
## Static batching for the procedural scenery: every plain primitive (box, cylinder,
## sphere...) that never moves again is folded into one mesh per material and shadow
## setting. A court's surroundings are dozens of little boxes (benches, the umpire's
## chair, posts, fence parts); each was its own draw call, twice with its shadow. On a
## phone's single-threaded WebGL those draw calls are a large share of the frame.
## See docs/PERFORMANCE.md.

## Merges under `root`. `keep`: nodes the owner still touches later (shown or hidden by
## the graphics preset, moved, animated) - they and everything under them stay as they
## are. `by_look`: plain opaque materials that look the same (colour, roughness...) count
## as one material even when each box was given its own copy (`_plain` of the park's
## furniture makes one per box); single-surface meshes from code (ArrayMesh) are folded
## too, when their vertex layout is the same. Returns how many nodes were folded away.
static func merge_static(root: Node3D, keep: Array = [], by_look := false) -> int:
	var groups := {}
	var inv := root.global_transform.affine_inverse()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not _mergeable(mi, root, keep, by_look):
			continue
		var key := "%s|%d|%d" % [_material_key(mi.material_override, by_look), mi.cast_shadow, (mi.mesh as ArrayMesh).surface_get_format(0) if mi.mesh is ArrayMesh else -1]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(mi)
	var folded := 0
	for key in groups:
		var list: Array = groups[key]
		if list.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi in list:
			var m := mi as MeshInstance3D
			st.append_from(m.mesh, 0, inv * m.global_transform)
		var merged := MeshInstance3D.new()
		merged.name = "Merged"
		merged.mesh = st.commit()
		var first := list[0] as MeshInstance3D
		merged.material_override = first.material_override
		merged.cast_shadow = first.cast_shadow
		if by_look:   # as far as the farthest of them was drawn (none: all the way)
			var far := 0.0
			for mi in list:
				var r := (mi as MeshInstance3D).visibility_range_end
				if r <= 0.0:
					far = 0.0
					break
				far = maxf(far, r)
			merged.visibility_range_end = far
			merged.visibility_range_end_margin = first.visibility_range_end_margin
		root.add_child(merged)
		for mi in list:
			(mi as Node).queue_free()
		folded += list.size()
	return folded


## What decides that two meshes may share a draw call: the material's identity, or (by_look)
## its look, for a plain opaque StandardMaterial3D.
static func _material_key(m: Material, by_look: bool) -> String:
	var sm := m as StandardMaterial3D
	if by_look and sm != null and sm.next_pass == null and sm.albedo_texture == null and sm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and not sm.emission_enabled and sm.normal_texture == null:
		return "%s|%.2f|%.2f|%d|%d|%d|%d|%d|%d|%.2f|%d" % [sm.albedo_color.to_html(), sm.roughness, sm.metallic, sm.shading_mode, sm.cull_mode, sm.diffuse_mode, sm.specular_mode, int(sm.vertex_color_use_as_albedo), int(sm.rim_enabled), sm.rim, int(sm.vertex_color_is_srgb)]
	return str(m.get_instance_id())


static func _mergeable(mi: MeshInstance3D, root: Node3D, keep: Array, by_look := false) -> bool:
	if not mi.visible or mi.material_override == null or mi.get_child_count() > 0:
		return false
	if mi.get_script() != null or mi.mesh == null:
		return false
	if mi.mesh is PrimitiveMesh:
		if (mi.mesh as PrimitiveMesh).material != null:
			return false
	elif not (by_look and mi.mesh is ArrayMesh and mi.mesh.get_surface_count() == 1 and mi.mesh.surface_get_material(0) == null):
		return false
	if mi.visibility_range_begin > 0.0:
		return false
	var p: Node = mi
	while p != null and p != root:
		if keep.has(p) or (p != mi and p.get_script() != null) or not (p is Node3D):
			return false
		p = p.get_parent()
	return p == root
