shader_type spatial;
render_mode unshaded;
uniform int kind=0;
void fragment() {
	if(kind==0) {
		float x=(UV.x-0.5)*2.0;
		float row=fract(UV.y*3.0);
		float line=abs(row-(0.68-abs(x)*0.36));
		float aa=max(fwidth(UV.y*3.0),0.002);
		float arrow=(1.0-smoothstep(0.05-aa,0.05+aa,line))*(1.0-smoothstep(0.55,0.60,abs(x)));
		ALBEDO=mix(vec3(0.55,0.96,0.23),vec3(0.025,0.095,0.15),arrow);
	} else if(kind==1) {
		vec2 p=UV*vec2(16.0,2.0);
		vec2 footprint=max(fwidth(p),vec2(0.0001));
		vec2 hi=1.0-abs(mod(p+footprint*0.5,2.0)-1.0);
		vec2 lo=1.0-abs(mod(p-footprint*0.5,2.0)-1.0);
		vec2 average=clamp((hi-lo)/footprint,-1.0,1.0);
		float tile=0.5-0.5*average.x*average.y;
		ALBEDO=mix(vec3(0.025,0.035,0.07),vec3(0.86,0.94,1.0),tile);
	} else {
		ALBEDO=vec3(0.42,0.61,0.82);
	}
}
