class_name MeshMerge
## Static batching for the procedural scenery: every plain primitive (box, cylinder,
## sphere...) that never moves again is folded into one mesh per material and shadow
## setting. A court's surroundings are dozens of little boxes (benches, the umpire's
## chair, posts, fence parts); each was its own draw call, twice with its shadow. On a
## phone's single-threaded WebGL those draw calls are a large share of the frame.
## See docs/PERFORMANCE.md.

## Merges under `root`. `keep`: nodes the owner still touches later (shown or hidden by
## the graphics preset, moved, animated) - they and everything under them stay as they
## are. Returns how many nodes were folded away.
static func merge_static(root: Node3D, keep: Array = []) -> int:
	var groups := {}
	var inv := root.global_transform.affine_inverse()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not _mergeable(mi, root, keep):
			continue
		var key := "%d|%d" % [mi.material_override.get_instance_id(), mi.cast_shadow]
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
		root.add_child(merged)
		for mi in list:
			(mi as Node).queue_free()
		folded += list.size()
	return folded


static func _mergeable(mi: MeshInstance3D, root: Node3D, keep: Array) -> bool:
	if not mi.visible or mi.material_override == null or mi.get_child_count() > 0:
		return false
	if mi.get_script() != null or not (mi.mesh is PrimitiveMesh):
		return false
	if (mi.mesh as PrimitiveMesh).material != null:
		return false
	var p: Node = mi
	while p != null and p != root:
		if keep.has(p) or (p != mi and p.get_script() != null) or not (p is Node3D):
			return false
		p = p.get_parent()
	return p == root
