extends NavigationRegion3D

@export_range(1.0, 100.0, 0.5) var navigation_half_extent: float = 11.5


func _ready() -> void:
	var navigation_mesh := NavigationMesh.new()
	navigation_mesh.vertices = PackedVector3Array(
		[
			Vector3(-navigation_half_extent, 0.0, -navigation_half_extent),
			Vector3(navigation_half_extent, 0.0, -navigation_half_extent),
			Vector3(navigation_half_extent, 0.0, navigation_half_extent),
			Vector3(-navigation_half_extent, 0.0, navigation_half_extent),
		]
	)
	navigation_mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	self.navigation_mesh = navigation_mesh
