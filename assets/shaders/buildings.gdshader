shader_type spatial;
// Edificios del suelo de cubos (FloorCubes): el color de cada uno llega por instancia (COLOR).
// Las fachadas llevan ventanas suaves alineadas por pisos y las azoteas un borde (parapeto):
// detalle justo para que se lean como edificios, sin competir con las fichas.
// Compatibility: solo funciones simples, sin texturas.

uniform float base_y = -1.9;        // altura del suelo donde apoyan los edificios
uniform float floor_h = 0.28;       // alto de un piso: las ventanas se alinean con él
uniform float col_w = 0.32;         // ancho de una columna de ventanas
uniform float half_ext = 0.45;      // semilado del cubo sin escalar (FloorCubes.SIDE / 2)
uniform float bevel = 0.05;         // bisel del cubo base: se mantiene del mismo tamaño en las torres
uniform vec3 glass = vec3(0.80, 0.86, 0.96);   // tinte de las ventanas (multiplica al color)
uniform float roof_dark = 0.07;     // cuánto se oscurece el centro de la azotea

varying vec3 w_pos;
varying vec3 l_nrm;
varying vec3 l_pos;
varying vec3 s_scale;
varying vec4 v_col;

void vertex() {
	vec3 sc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	// El bisel de arriba y abajo mide siempre lo mismo en el mundo, sea baja o alta la torre
	// (si no, la escala vertical lo estiraría hasta parecer un techo en pendiente).
	float d = max(0.5 - abs(VERTEX.y), 0.0);
	if (d < bevel + 0.001 && sc.y > 1.0) {
		VERTEX.y = sign(VERTEX.y) * (0.5 - d / sc.y);
	}
	l_nrm = NORMAL;
	l_pos = VERTEX;
	s_scale = sc;
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_col = COLOR;
	// El motor divide la normal por la escala: se la multiplicamos antes para que llegue intacta.
	NORMAL = normalize(NORMAL * sc);
}

void fragment() {
	vec3 albedo = v_col.rgb;
	float side = 1.0 - smoothstep(0.35, 0.65, abs(l_nrm.y));   // 1 en fachadas, 0 en azoteas
	float roof = smoothstep(0.65, 0.9, l_nrm.y);                // 1 en azoteas
	// Ventanas: cuadrícula por pisos y columnas a lo largo de cada fachada
	float along = w_pos.x * abs(l_nrm.z) + w_pos.z * abs(l_nrm.x);
	vec2 f = fract(vec2(along / col_w, (w_pos.y - base_y) / floor_h));
	float wx = smoothstep(0.16, 0.26, f.x) * (1.0 - smoothstep(0.74, 0.84, f.x));
	float wy = smoothstep(0.22, 0.32, f.y) * (1.0 - smoothstep(0.68, 0.78, f.y));
	albedo *= mix(vec3(1.0), glass, wx * wy * side);
	// Azotea: parapeto claro en el borde y centro apenas más oscuro
	vec2 e = (vec2(half_ext) - abs(l_pos.xz)) * s_scale.xz;
	float edge = min(e.x, e.y);
	float parapet = 1.0 - smoothstep(0.04, 0.09, edge);
	albedo *= 1.0 - roof * roof_dark * (1.0 - parapet);
	ALBEDO = albedo;
	ROUGHNESS = 0.55;
	METALLIC = 0.0;
}
