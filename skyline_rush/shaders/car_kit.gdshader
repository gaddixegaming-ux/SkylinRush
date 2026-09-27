// Vehicles from the kit (scripts/car_models.gd): one merged mesh per vehicle,
// "textured" procedurally in the shader so every part reads as the real thing.
//
// Vertex data:
//   COLOR.rgb  base colour of the part (paint colour for bodywork)
//   COLOR.a    glow / 8 (lights, signs)
//   UV.x       material id   0 paint, 1 glass, 2 tyre, 3 hub, 4 headlight,
//              5 tail light, 6 plastic trim, 7 plate, 8 chrome, 9 cargo box,
//              10 sign / light bar, 11 decal ink (lettering)
//   UV.y       rim (negative = red hazard rim like every other obstacle)
//   UV2.x      livery code + 10 * round(length * 10)
//              0 none, 1 taxi checker, 2 police, 3 ambulance, 4 school bus,
//              5 fire truck, 6 racing stripes, 7 ice-cream, 8 city bus
//   UV2.y      vehicle height (m)
// Same curved-world bend as the rest of the world.
shader_type spatial;

global uniform vec2 curve_amount;
global uniform float fake_ao;

varying vec3 lp;
varying vec3 ln;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = min(w.z, 0.0);
	w.x += curve_amount.x * d * d;
	w.y += curve_amount.y * d * d;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
}

void fragment() {
	int id = int(UV.x + 0.5);
	float code = UV2.x;
	int liv = int(mod(code + 0.5, 10.0));
	float len = floor((code + 0.5) / 10.0) / 10.0;
	float h = UV2.y;
	vec3 col = COLOR.rgb;
	float rough = 0.4;
	float metal = 0.0;
	vec3 emis = COLOR.rgb * COLOR.a * 8.0;
	float refl = 0.0;          // fake environment reflection strength
	bool side = abs(ln.x) > 0.6;
	float hy = lp.y / max(h, 0.1);   // 0 at the ground, 1 at the roof
	float zf = lp.z / max(len, 0.1) + 0.5;  // 0 at the back, 1 at the front

	if (id == 0 || id == 9) {
		// ---------------- bodywork: clear-coated metallic paint
		rough = id == 0 ? 0.16 : 0.45;
		metal = id == 0 ? 0.45 : 0.05;
		float flake = hash3(floor(lp * 160.0));
		rough += (flake - 0.5) * 0.1;
		col *= 0.96 + flake * 0.08;
		refl = id == 0 ? 0.35 : 0.1;
		// liveries painted in the shader
		if (liv == 1 && side && hy > 0.3 && hy < 0.4) {
			// taxi checker band
			float c = mod(floor(lp.z * 9.0) + floor(lp.y * 9.0), 2.0);
			col = mix(vec3(0.03), vec3(0.95), c);
		} else if (liv == 2 && hy < 0.42) {
			col = vec3(0.03, 0.06, 0.2);  // police: dark lower body
		} else if (liv == 2 && side && hy > 0.42 && hy < 0.47) {
			col = vec3(0.1, 0.3, 0.95);
		} else if (liv == 3 && side && hy > 0.35 && hy < 0.47) {
			col = vec3(0.9, 0.08, 0.08);  // ambulance red band
		} else if (liv == 3 && side && hy > 0.47 && hy < 0.5) {
			col = vec3(0.1, 0.3, 0.9);
		} else if (liv == 4 && side && (abs(hy - 0.38) < 0.02 || abs(hy - 0.62) < 0.015)) {
			col = vec3(0.03);             // school bus black rub-strips
		} else if (liv == 5 && side && hy > 0.4 && hy < 0.46) {
			col = vec3(0.97, 0.95, 0.85); // fire truck white stripe
		} else if (liv == 6 && abs(lp.x) > 0.12 && abs(lp.x) < 0.3 && !side) {
			col = vec3(0.97);             // racing stripes over hood + roof
		} else if (liv == 7 && hy < 0.35) {
			col = vec3(0.97, 0.97, 0.98); // ice-cream van: white skirt
		} else if (liv == 7 && side && hy > 0.35 && hy < 0.4) {
			float wave = 0.37 + sin(lp.z * 5.0) * 0.02;
			col = hy < wave ? vec3(1.0, 0.55, 0.75) : col;
		} else if (liv == 8 && side && hy > 0.3 && hy < 0.34) {
			col *= 0.35;                  // city bus accent line
		}
		// panel seams: doors on the sides, bonnet line on top
		if (id == 0 && side && hy > 0.12 && hy < 0.62) {
			float s1 = abs(zf - 0.62);
			float s2 = abs(zf - 0.38);
			if (min(s1, s2) * len < 0.012) col *= 0.3;
			// door handles
			if (abs(hy - 0.52) < 0.012 && (abs(zf - 0.56) * len < 0.07 || abs(zf - 0.32) * len < 0.07)) {
				col = vec3(0.75);
				metal = 0.9;
			}
		}
		if (id == 0 && ln.y > 0.6 && abs(zf - 0.75) * len < 0.01) col *= 0.4;
		// road grime + contact darkening near the sills
		col *= mix(0.55, 1.0, smoothstep(0.0, 0.3, hy));
	} else if (id == 1) {
		// ---------------- tinted glass
		col = vec3(0.03, 0.045, 0.07);
		rough = 0.04;
		metal = 0.5;
		refl = 0.45;
	} else if (id == 2) {
		// ---------------- rubber with tread grooves
		col = vec3(0.045);
		rough = 0.85;
		if (!side) {
			float g = step(0.5, fract((lp.y + lp.z) * 18.0));
			col *= 0.7 + 0.5 * g;
		} else {
			// sidewall lettering ring
			col *= 0.9 + 0.3 * step(0.93, hash3(floor(lp * 60.0)));
		}
	} else if (id == 3 || id == 8) {
		// ---------------- chrome (hubs, trim)
		col = vec3(0.78, 0.8, 0.84);
		rough = 0.12;
		metal = 1.0;
		refl = 0.8;
	} else if (id == 4 || id == 5) {
		// ---------------- lamps with a lens pattern
		float lens = 0.75 + 0.25 * step(0.5, fract(lp.x * 22.0)) * step(0.5, fract(lp.y * 22.0));
		col = id == 4 ? vec3(1.0, 0.97, 0.9) : vec3(0.9, 0.05, 0.03);
		emis = col * (id == 4 ? 3.2 : 2.4) * lens;
		rough = 0.1;
	} else if (id == 6) {
		// ---------------- textured black plastic
		col = vec3(0.07, 0.07, 0.08) * (0.85 + 0.3 * hash3(floor(lp * 90.0)));
		rough = 0.7;
	} else if (id == 7) {
		// ---------------- number plate: white, blue band, dark characters
		col = vec3(0.95, 0.95, 0.9);
		float u = fract(lp.x * 1.8 + 0.5);
		if (u < 0.12) col = vec3(0.1, 0.25, 0.8);
		else if (abs(fract(lp.y * 9.0) - 0.5) < 0.3 && step(0.35, hash3(floor(vec3(lp.x * 22.0, 0.0, 0.0)))) > 0.5) col = vec3(0.08);
		rough = 0.5;
	} else if (id == 10) {
		rough = 0.3;
	} else if (id == 11) {
		rough = 0.5;
		emis *= 0.6;
	}

	// fake environment reflection: sky above, dark ground below, bright horizon band
	if (refl > 0.0) {
		vec3 r = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
		vec3 env = mix(vec3(0.25, 0.22, 0.28), vec3(0.75, 0.82, 1.0), smoothstep(-0.2, 0.5, r.y));
		env += vec3(1.0, 0.9, 0.85) * exp(-abs(r.y) * 14.0) * 0.8;
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		emis += env * refl * (0.08 + fres * 0.5);
	}
	float rim = UV.y;
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 rim_c = rim < 0.0 ? vec3(1.0, 0.22, 0.12) : vec3(1.0, 0.92, 1.0);
	emis += rim_c * fr * abs(rim) * 0.8;
	col *= mix(1.0, mix(0.6, 1.0, smoothstep(0.0, 0.5, hy)), fake_ao * 0.6);

	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.02, 1.0);
	METALLIC = metal;
	EMISSION = emis;
}
