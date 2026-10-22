class_name UITestHelpers
extends RefCounted
## Shared helpers for driving screens headlessly.


static func find(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for c in root.get_children():
		var r := find(c, node_name)
		if r != null:
			return r
	return null


static func find_all(root: Node, cls: String, out: Array = []) -> Array:
	if root.is_class(cls):
		out.append(root)
	for c in root.get_children():
		find_all(c, cls, out)
	return out


static func press(root: Node, node_name: String) -> bool:
	var b := find(root, node_name) as BaseButton
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true


static func screen(path: String) -> Control:
	return (load(path) as PackedScene).instantiate()
