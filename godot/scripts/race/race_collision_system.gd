class_name RaceCollisionSystem
extends RefCounted

## Physical collision contract shared by the deterministic race simulation,
## the scene-tree colliders and camera queries. Vehicle contact is resolved from
## the oriented BoxShape3D nodes themselves instead of duplicated 2D envelopes.

const VEHICLE_LAYER := 1 << 4
const TRACK_SURFACE_LAYER := 1 << 5
const TRACK_BARRIER_LAYER := 1 << 6
const HAZARD_LAYER := 1 << 7
const CAMERA_COLLISION_MASK := TRACK_SURFACE_LAYER | TRACK_BARRIER_LAYER

const COLLIDER_NAME := &"RaceCollisionArea"
const SHAPE_NAME := &"RaceCollisionShape"
const MIN_AXIS_LENGTH_SQUARED := 0.000001


static func install_vehicle_collider(root: Node3D, racer_id: String, size: Vector3) -> Area3D:
	var collider := root.get_node_or_null(NodePath(String(COLLIDER_NAME))) as Area3D
	if collider == null:
		collider = Area3D.new()
		collider.name = COLLIDER_NAME
		root.add_child(collider)
	collider.collision_layer = VEHICLE_LAYER
	collider.collision_mask = VEHICLE_LAYER | HAZARD_LAYER
	collider.monitoring = true
	collider.monitorable = true
	collider.position = Vector3(0.0, maxf(0.8, size.y) * 0.5, 0.0)
	collider.set_meta("racer_id", racer_id)
	collider.set_meta("collision_kind", "oriented_box_3d")

	var shape_node := collider.get_node_or_null(NodePath(String(SHAPE_NAME))) as CollisionShape3D
	if shape_node == null:
		shape_node = CollisionShape3D.new()
		shape_node.name = SHAPE_NAME
		collider.add_child(shape_node)
	var box := BoxShape3D.new()
	box.size = Vector3(
		clampf(size.x, 1.0, 12.0),
		clampf(size.y, 0.8, 10.0),
		clampf(size.z, 1.0, 12.0)
	)
	shape_node.shape = box
	shape_node.disabled = false
	collider.set_meta("collision_size", box.size)
	return collider


static func vehicle_collider(root: Node3D) -> Area3D:
	return root.get_node_or_null(NodePath(String(COLLIDER_NAME))) as Area3D


static func collision_shape(root: Node3D) -> CollisionShape3D:
	var collider := vehicle_collider(root)
	if collider == null:
		return null
	return collider.get_node_or_null(NodePath(String(SHAPE_NAME))) as CollisionShape3D


static func contact_between(first: Node3D, second: Node3D) -> Dictionary:
	var first_shape := collision_shape(first)
	var second_shape := collision_shape(second)
	if first_shape == null or second_shape == null:
		return {"colliding": false}
	var first_box := first_shape.shape as BoxShape3D
	var second_box := second_shape.shape as BoxShape3D
	if first_box == null or second_box == null:
		return {"colliding": false}
	return _box_contact(
		first_shape.global_transform,
		first_box.size,
		second_shape.global_transform,
		second_box.size
	)


static func _box_contact(
	first_transform: Transform3D,
	first_size: Vector3,
	second_transform: Transform3D,
	second_size: Vector3
) -> Dictionary:
	var first_scale := first_transform.basis.get_scale().abs()
	var second_scale := second_transform.basis.get_scale().abs()
	var first_axes: Array[Vector3] = [
		first_transform.basis.x.normalized(),
		first_transform.basis.y.normalized(),
		first_transform.basis.z.normalized(),
	]
	var second_axes: Array[Vector3] = [
		second_transform.basis.x.normalized(),
		second_transform.basis.y.normalized(),
		second_transform.basis.z.normalized(),
	]
	var first_half := Vector3(
		first_size.x * first_scale.x,
		first_size.y * first_scale.y,
		first_size.z * first_scale.z
	) * 0.5
	var second_half := Vector3(
		second_size.x * second_scale.x,
		second_size.y * second_scale.y,
		second_size.z * second_scale.z
	) * 0.5
	var axes: Array[Vector3] = []
	axes.append_array(first_axes)
	axes.append_array(second_axes)
	for first_axis: Vector3 in first_axes:
		for second_axis: Vector3 in second_axes:
			var cross_axis := first_axis.cross(second_axis)
			if cross_axis.length_squared() > MIN_AXIS_LENGTH_SQUARED:
				axes.append(cross_axis.normalized())

	var center_delta := second_transform.origin - first_transform.origin
	var minimum_overlap := INF
	var collision_normal := Vector3.RIGHT
	for candidate: Vector3 in axes:
		if candidate.length_squared() <= MIN_AXIS_LENGTH_SQUARED:
			continue
		var axis := candidate.normalized()
		var first_radius := _projected_radius(first_axes, first_half, axis)
		var second_radius := _projected_radius(second_axes, second_half, axis)
		var overlap := first_radius + second_radius - absf(center_delta.dot(axis))
		if overlap <= 0.0:
			return {"colliding": false}
		if overlap < minimum_overlap:
			minimum_overlap = overlap
			collision_normal = axis if center_delta.dot(axis) >= 0.0 else -axis

	return {
		"colliding": true,
		"normal": collision_normal,
		"penetration": minimum_overlap,
		"point": (first_transform.origin + second_transform.origin) * 0.5,
	}


static func _projected_radius(axes: Array[Vector3], half_extents: Vector3, axis: Vector3) -> float:
	return (
		half_extents.x * absf(axes[0].dot(axis))
		+ half_extents.y * absf(axes[1].dot(axis))
		+ half_extents.z * absf(axes[2].dot(axis))
	)
