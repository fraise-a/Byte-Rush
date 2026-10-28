shader_type sky;
void sky() {
	float height=smoothstep(-0.08,0.8,EYEDIR.y);
	vec3 horizon=vec3(0.38,0.13,0.27);
	vec3 zenith=vec3(0.035,0.022,0.15);
	vec3 base=mix(horizon,zenith,height);
	float haze=pow(1.0-clamp(abs(EYEDIR.y),0.0,1.0),12.0);
	base+=vec3(0.12,0.055,0.04)*haze;
	vec3 sun_direction=normalize(vec3(0.90,0.30,-0.35));
	float disk=smoothstep(0.985,0.988,dot(EYEDIR,sun_direction));
	float phase=EYEDIR.y*75.0;
	float edge=max(fwidth(phase)*6.28318,0.02);
	float stripe=smoothstep(-0.45-edge,-0.45+edge,sin(phase*6.28318));
	float bands=mix(stripe,1.0,smoothstep(0.27,0.31,EYEDIR.y));
	vec3 sunset=mix(vec3(1.0,0.12,0.27),vec3(1.0,0.68,0.22),smoothstep(0.15,0.42,EYEDIR.y));
	COLOR=mix(base,sunset,disk*bands);
}
