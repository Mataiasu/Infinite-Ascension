extends Control

const CURSOR_COLOR := Color("#a66cff")
const OUTLINE_COLOR := Color("#070b18")
const SIZE := 18.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    queue_redraw()

func _process(_delta: float) -> void:
    if visible:
        position = get_viewport().get_mouse_position()
        queue_redraw()

func _draw() -> void:
    var points := PackedVector2Array([
        Vector2(0, 0),
        Vector2(0, SIZE),
        Vector2(5, SIZE - 5),
        Vector2(9, SIZE + 2),
        Vector2(12, SIZE),
        Vector2(8, SIZE - 7),
        Vector2(SIZE, SIZE - 8)
    ])
    draw_colored_polygon(points, OUTLINE_COLOR)
    var inner := PackedVector2Array([
        Vector2(2, 2),
        Vector2(2, SIZE - 3),
        Vector2(5, SIZE - 6),
        Vector2(9, SIZE - 1),
        Vector2(10, SIZE - 2),
        Vector2(7, SIZE - 8),
        Vector2(SIZE - 3, SIZE - 9)
    ])
    draw_colored_polygon(inner, CURSOR_COLOR)
