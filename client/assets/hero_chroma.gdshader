shader_type canvas_item;
// 色键透明 — 黑色背景(0,0,0) → 100% 透明
uniform vec4 key_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float tolerance : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (distance(c.rgb, key_color.rgb) < tolerance) {
		COLOR.a = 0.0;
	} else {
		COLOR = c;
	}
}
