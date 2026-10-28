shader_type spatial;
float filtered_grid(vec2 p) {
	vec2 footprint=max(fwidth(p),vec2(0.0001));
	vec2 distance=abs(fract(p-0.5)-0.5)/footprint;
	vec2 lines=1.0-smoothstep(vec2(0.45),vec2(1.25),distance);
	// Sub-pixel cells must fade out rather than turn into an unstable solid pattern.
	vec2 fade=1.0-smoothstep(vec2(0.30),vec2(0.75),footprint);
	return max(lines.x*fade.x,lines.y*fade.y);
}
void fragment() {
	float grid=filtered_grid(vec2(UV.x*3.0,UV.y*0.45));
	float center=step(0.065,UV.x)*step(UV.x,0.935);
	ALBEDO=COLOR.rgb*(1.0+grid*0.16*center);
	EMISSION=vec3(0.025,0.05,0.07)*grid*center;
	ROUGHNESS=0.78;
	METALLIC=0.04;
}
