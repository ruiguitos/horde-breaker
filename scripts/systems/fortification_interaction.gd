extends Area3D


func interact(player: Node) -> bool:
	var fortification_site := get_parent()
	if fortification_site == null or not fortification_site.has_method(&"interact"):
		push_error("FortificationInteraction requires an interactive parent node.")
		return false
	return bool(fortification_site.call(&"interact", player))
