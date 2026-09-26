extends RefCounted
## Loads the Tripo .glb assets in res://models and prepares them for the game:
##  - "trims" the sheet models (10 skateboards / 10 trees laid out in one mesh)
##    into separate pieces by finding the mesh islands and grouping the ones
##    that touch, then re-centres every piece on its own base,
##  - orients the scooters to face the runner's direction (-Z),
##  - builds curved-world materials for scenery (so trees bend with the road).
## Results are cached, so each file is split only once per session.

const WORLD_TEX := preload("res://shaders/world_tex.gdshader")

static var _cache := {}


## The raw mesh + material of a single-mesh glb.
static func _load_mesh(path: String) -> Array:
	if not ResourceLoader.exists(path):
		return []
	var scene: Node = (load(path) as PackedScene).instantiate()
	var mis := scene.find_children("*", "MeshInstance3D", true, false)
	if mis.is_empty():
		scene.free()
		return []
	var mi: MeshInstance3D = mis[0]
	var mesh: Mesh = mi.mesh
	var mat: Material = mi.get_active_material(0)
	if mat == null and mesh.get_surface_count() > 0:
		mat = mesh.surface_get_material(0)
	var xf := Transform3D()
	var n: Node = mi
	while n != scene and n != null:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	scene.free()
	return [mesh, mat, xf]


## Splits a sheet mesh into pieces. Returns an Array of {mesh, material, size}
## where every mesh sits centred on x/z with its base at y = 0.
## `upright` rotates each piece after splitting (e.g. boards stored standing up).
static func split(path: String, upright := Basis(), min_rel := 0.25, flat := false) -> Array:
	var key := "split:%s:%s" % [path, flat]
	if _cache.has(key):
		return _cache[key]
	var res: Array = []
	var got := _load_mesh(path)
	if got.is_empty():
		_cache[key] = res
		return res
	var mesh: Mesh = got[0]
	var mat: Material = got[1]
	var xf: Transform3D = got[2]
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if idx.is_empty():
		idx.resize(verts.size())
		for i in verts.size():
			idx[i] = i
	var vc := verts.size()
	# union-find over vertices; vertices at the same spot (UV seams) are merged too
	var parent := PackedInt32Array()
	parent.resize(vc)
	for i in vc:
		parent[i] = i
	var by_pos := {}
	for i in vc:
		var q := Vector3i((verts[i] * 2000.0).round())
		if by_pos.has(q):
			_union(parent, i, by_pos[q])
		else:
			by_pos[q] = i
	for t in range(0, idx.size(), 3):
		_union(parent, idx[t], idx[t + 1])
		_union(parent, idx[t], idx[t + 2])
	# islands -> AABBs
	var isl := {}
	for i in vc:
		var r := _find(parent, i)
		if isl.has(r):
			isl[r] = (isl[r] as AABB).expand(verts[i])
		else:
			isl[r] = AABB(verts[i], Vector3.ZERO)
	var roots: Array = isl.keys()
	var boxes: Array = []
	for r in roots:
		boxes.append(isl[r])
	# group islands whose boxes touch (wheels + deck, leaves + trunk ...)
	var total := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		total = total.expand(v)
	var margin := total.size.length() * 0.004
	var group := PackedInt32Array()
	group.resize(roots.size())
	for i in roots.size():
		group[i] = i
	var changed := true
	var gbox: Array = boxes.duplicate()
	while changed:
		changed = false
		for a in roots.size():
			if group[a] != a:
				continue
			for b in range(a + 1, roots.size()):
				if group[b] != b:
					continue
				if _should_merge(gbox[a], gbox[b], margin):
					gbox[a] = (gbox[a] as AABB).merge(gbox[b])
					group[b] = a
					changed = true
		# re-point children of merged groups
		for i in roots.size():
			var g := group[i]
			while group[g] != g:
				g = group[g]
			group[i] = g
	var root_group := {}
	for i in roots.size():
		root_group[roots[i]] = group[i]
	var biggest := 0.0
	for i in roots.size():
		if group[i] == i:
			biggest = maxf(biggest, (gbox[i] as AABB).size.length())
	# build one mesh per big group
	var order: Array = []
	for i in roots.size():
		if group[i] == i and (gbox[i] as AABB).size.length() >= biggest * min_rel:
			order.append(i)
	# sheet order: top row first, then left to right
	order.sort_custom(func(a, b):
		var ba: AABB = gbox[a]
		var bb: AABB = gbox[b]
		var ra := roundi(-(ba.position.y + ba.size.y * 0.5) / (total.size.y * 0.35))
		var rb := roundi(-(bb.position.y + bb.size.y * 0.5) / (total.size.y * 0.35))
		if ra != rb:
			return ra < rb
		return ba.position.x < bb.position.x)
	var vgroup := PackedInt32Array()
	vgroup.resize(vc)
	for i in vc:
		vgroup[i] = root_group[_find(parent, i)]
	# pieces fused in the sheet (touching leaves) come out about twice as wide as
	# the rest: cut them at the emptiest vertical slice
	var widths: Array = []
	for g in order:
		widths.append((gbox[g] as AABB).size.x)
	var sorted_w := widths.duplicate()
	sorted_w.sort()
	var med: float = sorted_w[sorted_w.size() / 2] if not sorted_w.is_empty() else 0.0
	var final_order: Array = []
	var next_id := roots.size() + 1
	for oi in order.size():
		var g: int = order[oi]
		final_order.append(g)
		var bx: AABB = gbox[g]
		if order.size() < 3 or bx.size.x < med * 1.55:
			continue
		var bins := 48
		var hist := PackedInt32Array()
		hist.resize(bins)
		for i in vc:
			if vgroup[i] == g:
				var bi := clampi(int((verts[i].x - bx.position.x) / bx.size.x * bins), 0, bins - 1)
				hist[bi] += 1
		var best := -1
		for bi in range(int(bins * 0.3), int(bins * 0.7)):
			if best < 0 or hist[bi] < hist[best]:
				best = bi
		var cut := bx.position.x + (best + 0.5) / bins * bx.size.x
		for i in vc:
			if vgroup[i] == g and verts[i].x > cut:
				vgroup[i] = next_id
		final_order.append(next_id)
		next_id += 1
	for g in final_order:
		var m := _extract(arrays, idx, vgroup, g, xf, upright, flat)
		if m.is_empty():
			continue
		m["material"] = mat
		res.append(m)
	_cache[key] = res
	return res


## Merge when one piece is small next to the other (a wheel, a leaf clump)
## or when the two boxes really overlap. Two trees whose canopies only
## brush each other stay separate.
static func _should_merge(a: AABB, b: AABB, margin: float) -> bool:
	var ga := a.grow(margin)
	if not ga.intersects(b):
		return false
	var la := a.size.length()
	var lb := b.size.length()
	if minf(la, lb) < maxf(la, lb) * 0.45:
		return true
	var inter := ga.intersection(b)
	var vi := inter.size.x * inter.size.y * inter.size.z
	var vmin := minf(a.size.x * a.size.y * a.size.z, b.size.x * b.size.y * b.size.z)
	return vi > vmin * 0.25


static func _extract(arrays: Array, idx: PackedInt32Array, vgroup: PackedInt32Array, g: int, xf: Transform3D, rot: Basis, flat := false) -> Dictionary:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms = arrays[Mesh.ARRAY_NORMAL]
	var uvs = arrays[Mesh.ARRAY_TEX_UV]
	var remap := {}
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nu := PackedVector2Array()
	var ni := PackedInt32Array()
	var full := Transform3D(rot, Vector3.ZERO) * xf
	for t in range(0, idx.size(), 3):
		if vgroup[idx[t]] != g:
			continue
		for k in 3:
			var vi := idx[t + k]
			if not remap.has(vi):
				remap[vi] = nv.size()
				nv.append(full * verts[vi])
				if norms != null and norms.size() > vi:
					nn.append((full.basis * norms[vi]).normalized())
				if uvs != null and uvs.size() > vi:
					nu.append(uvs[vi])
			ni.append(remap[vi])
	if nv.is_empty():
		return {}
	if flat:
		var fb := _flat_basis(nv)
		for i in nv.size():
			nv[i] = fb * nv[i]
		for i in nn.size():
			nn[i] = (fb * nn[i]).normalized()
	var box := AABB(nv[0], Vector3.ZERO)
	for v in nv:
		box = box.expand(v)
	var off := Vector3(box.position.x + box.size.x * 0.5, box.position.y, box.position.z + box.size.z * 0.5)
	for i in nv.size():
		nv[i] -= off
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = nv
	out[Mesh.ARRAY_INDEX] = ni
	if nn.size() == nv.size():
		out[Mesh.ARRAY_NORMAL] = nn
	if nu.size() == nv.size():
		out[Mesh.ARRAY_TEX_UV] = nu
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return {"mesh": am, "size": box.size}


## For flat things (boards): a rotation putting the longest axis along Z and
## the thinnest along Y, with the side the wheels stick out of pointing down.
static func _flat_basis(pts: PackedVector3Array) -> Basis:
	var c := Vector3.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var cov := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	for p in pts:
		var d := p - c
		for i in 3:
			for j in 3:
				cov[i][j] += d[i] * d[j]
	var axes: Array = []
	var m := cov.duplicate(true)
	for k in 3:
		var v := Vector3(0.577, 0.577, 0.577)
		if k == 1:
			v = Vector3(0.3, -0.8, 0.52)
		for it in 60:
			var nv := Vector3(m[0][0] * v.x + m[0][1] * v.y + m[0][2] * v.z,
				m[1][0] * v.x + m[1][1] * v.y + m[1][2] * v.z,
				m[2][0] * v.x + m[2][1] * v.y + m[2][2] * v.z)
			for a in axes:
				nv -= a * nv.dot(a)
			if nv.length() < 1e-9:
				break
			v = nv.normalized()
		axes.append(v)
	var ax_len: Vector3 = axes[0]
	var ax_n: Vector3 = axes[0].cross(axes[1]).normalized()
	# wheels: the extreme along the normal that is further from the centre
	var lo := 0.0
	var hi := 0.0
	var mid := 0.0
	for p in pts:
		var d := (p - c).dot(ax_n)
		lo = minf(lo, d)
		hi = maxf(hi, d)
		mid += d
	mid /= pts.size()
	if hi - mid > mid - lo:
		ax_n = -ax_n
	var ax_x := ax_n.cross(ax_len).normalized()
	# rows of the new basis: x, up (normal), forward (length)
	return Basis(ax_x, ax_n, ax_len).transposed()


static func _find(p: PackedInt32Array, i: int) -> int:
	while p[i] != i:
		p[i] = p[p[i]]
		i = p[i]
	return i


static func _union(p: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(p, a)
	var rb := _find(p, b)
	if ra != rb:
		p[maxi(ra, rb)] = mini(ra, rb)


## A whole (single-object) model, rotated so its front faces -Z, centred with
## its base at y = 0 and scaled so its length along z is `length`.
static func whole(path: String, yaw: float, length: float) -> Dictionary:
	var key := "whole:%s:%.3f:%.3f" % [path, yaw, length]
	if _cache.has(key):
		return _cache[key]
	var got := _load_mesh(path)
	var out := {}
	if not got.is_empty():
		var mesh: Mesh = got[0]
		var xf: Transform3D = Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO) * got[2]
		var box := xf * mesh.get_aabb()
		var s := length / maxf(box.size.z, 0.001)
		var off := Vector3(box.position.x + box.size.x * 0.5, box.position.y, box.position.z + box.size.z * 0.5)
		var t := Transform3D(Basis().scaled(Vector3.ONE * s), -off * s) * xf
		out = {"mesh": mesh, "material": got[1], "xform": t, "size": box.size * s}
	_cache[key] = out
	return out


## Curved-world version of a textured material (for scenery that scrolls).
static func world_material(src: Material, tint := Color.WHITE) -> ShaderMaterial:
	var key := "wm:%d:%s" % [src.get_instance_id() if src else 0, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = WORLD_TEX
	if src is BaseMaterial3D:
		m.set_shader_parameter("albedo_tex", (src as BaseMaterial3D).albedo_texture)
	m.set_shader_parameter("tint", tint)
	_cache[key] = m
	return m
