// uniform float exampleUniform;
uniform float awayF;
uniform float alignF;
uniform float coF;
uniform float max_speed;
uniform float max_force;
uniform vec2 box;
uniform float boundaryD;
uniform float separation;
uniform float neighborD;

layout (local_size_x = 8, local_size_y = 8) in;
int resX = int(uTD2DInfos[0].res.b);
int resY = int(uTD2DInfos[0].res.a);

vec2 limit(vec2 v, float m) {
	if(length(v)>m) return normalize(v) * m;
	return v;
}

vec2 align(vec4 v, float n) {
	vec2 vel = v.ba;
	vec2 align_vec = vec2(0);
	bool align_bool = false;
	for(int i=0; i<resX; i++) {
		for(int j=0; j<resY; j++) {
			vec4 other = texelFetch(sTD2DInputs[0], ivec2(i,j), 0);
			if(v.r!=other.r||v.g!=other.g) {
				float d = distance(v.rg, other.rg);
				if (d>0 && d<n) {
					align_bool = true;
					align_vec += other.ba;
				}
			}
		}
	}
	if (align_bool) {
		align_vec = limit(align_vec, max_speed);
		return limit(align_vec - vel, max_force);
	}
	return vec2(0);
}

vec2 away(vec4 v, float sep) {
	vec2 vel = v.ba;
	vec2 away_vec = vec2(0);
	bool away_bool = false;
	for(int i=0; i<resX; i++) {
		for(int j=0; j<resY; j++) {
			vec4 other = texelFetch(sTD2DInputs[0], ivec2(i,j), 0);
			if(v.r!=other.r||v.g!=other.g) {
				float d = distance(v.rg, other.rg);
				if (d>0 && d<sep) {
					away_bool = true;
					away_vec += normalize(v.rg - other.rg);
				}
			}
		}
	}
	if (away_bool) {
		away_vec = normalize(away_vec) * max_speed;
		return limit(away_vec - vel, max_force);
	}
	return vec2(0);
}

vec2 boundary_steer(vec4 v, vec2 box, float d) {
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
		return limit(target_vel - vel, max_force);
	}
	return vec2(0);
}

vec2 steer(vec2 v, vec2 p, vec2 t) {
	vec2 target_vel;
	target_vel.xy = normalize(t - p) * max_speed;
	return limit(target_vel - v, max_force);
}

vec2 cohesion(vec4 v, float n) {
	vec2 vel = v.ba;
	vec2 center = vec2(0);
	int count = 0;
	for(int i=0; i<resX; i++) {
		for(int j=0; j<resY; j++) {
			vec4 other = texelFetch(sTD2DInputs[0], ivec2(i,j), 0);
			if(v.r!=other.r||v.g!=other.g) {
				float d = distance(v.rg, other.rg);
				if (d>0 && d<n) {
					count += 1;
					center += other.rg;
				}
			}
		}
	}
	if(count>0) {
		center = center / count;
		return steer(vel, v.rg, center);
	}
	return vec2(0);
}

void main()
{
	vec4 vehicle = texelFetch(sTD2DInputs[0], ivec2(gl_GlobalInvocationID.xy), 0);
	vec2 pos = vehicle.rg;
	vec2 vel = vehicle.ba;
	vec2 acc = vec2(0);
	// Steer
	acc += away(vehicle, separation) * awayF;
	acc += align(vehicle, neighborD) * alignF;
	acc += cohesion(vehicle, neighborD) * coF;
	acc += boundary_steer(vehicle, box, boundaryD);
	vel += acc;
	vel = limit(vel, max_speed);
	pos += vel;

	vehicle.rg = pos;
	vehicle.ba = vel;
	imageStore(mTDComputeOutputs[0], ivec2(gl_GlobalInvocationID.xy), TDOutputSwizzle(vehicle));
}


