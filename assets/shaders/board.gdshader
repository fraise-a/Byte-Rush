shader_type spatial;
varying vec3 world_pos;
void vertex() { world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
float filtered_grid(vec2 p) {
	vec2 footprint=max(fwidth(p),vec2(0.0001));
	vec2 distance=abs(fract(p-0.5)-0.5)/footprint;
	vec2 lines=1.0-smoothstep(vec2(0.45),vec2(1.25),distance);
	vec2 fade=1.0-smoothstep(vec2(0.30),vec2(0.75),footprint);
	return max(lines.x*fade.x,lines.y*fade.y);
}
void fragment() {
	vec2 p=world_pos.xz/12.0;
	float grid=filtered_grid(p);
	float trace=filtered_grid(p*0.25);
	ALBEDO=mix(vec3(0.025,0.15,0.23),vec3(0.08,0.3,0.43),grid*0.65);
	EMISSION=vec3(0.015,0.11,0.16)*grid+vec3(0.015,0.03,0.06)*trace;
	ROUGHNESS=0.8;
}
