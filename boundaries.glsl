// uniform float exampleUniform;
uniform float target_d;
uniform float max_speed;
uniform float max_force;
uniform vec2 box;

layout (local_size_x = 8, local_size_y = 8) in;

vec2 boundary_continue(vec2 v, vec2 box) {
	// re-enter on the other side
	// v: postion of the object
	// box: width and height of the region
	// returns the new postion 
	float x = v.r;
	float y = v.g;
	if(x>box.r/2) v.r = -box.r/2;
	else if(x<-box.r/2) v.r = box.r/2;
	if(y>box.g/2) v.g = -box.g/2;
	else if(y<-box.g/2) v.g = box.g/2;
	return v.rg;
}

vec4 boundary_bounce(vec4 v, vec2 box) {
	// bounce back
	// v: postion and velocity of the object
	// box: width and height of the region
	// returns updated object vectors
	float x = v.r;
	float y = v.g;
	if(x>box.r/2 || x<-box.r/2) v.b = -v.b;
	if(y>box.g/2 || y<-box.g/2) v.a = -v.a;
	return v;
}

vec4 boundary_steer(vec4 v, vec2 box, float d) {
	// steer away from the bounary
	// v: postion and velocity of the object
	// box: width and height of the region
	// d: start steering away from this distance
	float x = v.r;
	float y = v.g;
	vec2 vel = v.ba;
	vec2 target_vel = vec2(v.b, v.a);
	bool atWall = false;
	if(x>box.r/2-d || x<-box.r/2+d) {
		target_vel.x = -sign(x) * max_speed;
		atWall = true;
	}
	if(y>box.g/2-d || y<-box.g/2+d) {
		target_vel.y = -sign(y) * max_speed;
		atWall = true;
	}
	if(atWall) {
		vec2 steer = normalize(target_vel - vel) * max_force;
		vel += steer;
		if(length(vel)>max_speed) vel = normalize(vel) * max_speed;
		v.ba = vel;
		v.rg += vel;
	}
	return v;
}

vec2 steer(vec2 v, vec2 p, vec2 t) {
	vec2 target_vel;
	target_vel.xy = normalize(t - p) * max_speed;
	vec2 steer = normalize(target_vel - v) * max_force;
	// Update velocity
	v += steer;
	if(length(v)>max_speed) v = normalize(v) * max_speed;
	return v;
}

void main()
{
	vec4 vehicle = texelFetch(sTD2DInputs[0], ivec2(gl_GlobalInvocationID.xy), 0);
	vec4 noise = texelFetch(sTD2DInputs[1], ivec2(gl_GlobalInvocationID.xy), 0);
	vec2 pos = vehicle.rg;
	vec2 vel = vehicle.ba;
	
	// Target
	vec2 target = pos + normalize(vel) * target_d;
	target.x += cos(noise.r) * target_d / 2;
	target.y += sin(noise.r) * target_d / 2;
	// Steer
	vel = steer(vel, pos, target);
	pos += vel;

	vehicle.rg = pos;
	vehicle.ba = vel;
	vehicle = boundary_steer(vehicle, box, 0);
	imageStore(mTDComputeOutputs[0], ivec2(gl_GlobalInvocationID.xy), TDOutputSwizzle(vehicle));
}