shader_type canvas_item;
render_mode unshaded;

// Fondo de las pantallas: degradado de malla (focos de color muy suaves) con
// fichas redondeadas flotando en profundidad, viñeta y un grano fino que evita
// el bandeado de los degradados.
//
// Se calcula en la GPU, así que se ve nítido en cualquier pantalla y respira
// despacio; el tema claro u oscuro solo cambia los colores. No hay imágenes:
// lo configura `UiTheme.backdrop()` desde `scripts/ui_theme.gd`.

uniform vec2 res = vec2(960.0, 1707.0);   // tamaño lógico del lienzo
uniform vec4 base_top : source_color = vec4(0.97, 0.99, 1.0, 1.0);
uniform vec4 base_bottom : source_color = vec4(0.76, 0.85, 0.98, 1.0);
// Focos del degradado: xy = centro (UV), z = radio (fracción del alto), w = intensidad
uniform vec4 blob0 = vec4(0.12, 0.06, 0.62, 0.60);
uniform vec4 blob1 = vec4(0.95, 0.22, 0.60, 0.50);
uniform vec4 blob2 = vec4(0.85, 0.88, 0.55, 0.45);
uniform vec4 blob3 = vec4(0.10, 0.95, 0.52, 0.38);
uniform vec4 col0 : source_color = vec4(0.89, 0.84, 1.0, 1.0);
uniform vec4 col1 : source_color = vec4(0.65, 0.79, 1.0, 1.0);
uniform vec4 col2 : source_color = vec4(0.71, 0.94, 0.86, 1.0);
uniform vec4 col3 : source_color = vec4(1.0, 0.89, 0.66, 1.0);
uniform vec3 tile_col : source_color = vec3(1.0);
uniform float tile_amount : hint_range(0.0, 1.0) = 0.42;
uniform float tile_scale = 0.13;          // lado de la celda (fracción del alto)
uniform float tile_edge : hint_range(0.0, 1.0) = 0.90;  // apagado hacia los bordes
uniform float vignette : hint_range(0.0, 1.0) = 0.24;
uniform float grain : hint_range(0.0, 0.1) = 0.018;
uniform float speed = 0.05;               // velocidad de la respiración

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Distancia con signo a un cuadrado redondeado centrado en el origen.
float rbox(vec2 p, vec2 h, float r) {
	vec2 q = abs(p) - max(h - vec2(r), vec2(0.0));
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// Fichas flotando: una por celda de una cuadrícula, cada una con su desplazamiento,
// giro, tamaño y opacidad; las de abajo quedan más cerca y por eso son más grandes.
float tiles(vec2 px, vec2 uv) {
	float cell = tile_scale * res.y;
	vec2 g = px / cell;
	float a = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 id = floor(g) + vec2(float(i), float(j));
			if (hash21(id) < 0.32) {
				continue;   // algunas celdas quedan vacías
			}
			vec2 c = (id + vec2(0.5) + (vec2(hash21(id + 4.7), hash21(id + 9.1)) - 0.5) * 0.36) * cell;
			vec2 d = px - c;
			float near = clamp(c.y / res.y * 1.2 - 0.06, 0.0, 1.0);
			float side = mix(0.012, 0.026, hash21(id + 1.3)) * res.y * mix(0.85, 1.20, near);
			float ang = (hash21(id + 2.9) - 0.5) * 1.2;
			float ca = cos(ang);
			float sa = sin(ang);
			d = vec2(d.x * ca - d.y * sa, d.x * sa + d.y * ca);
			float s = rbox(d, vec2(side), side * 0.30);
			a = max(a, (1.0 - smoothstep(-1.0, 1.0, s)) * mix(0.35, 1.0, hash21(id + 6.1)));
		}
	}
	// Se apagan hacia los bordes para que el patrón no se corte
	vec2 e = abs(uv - 0.5) * 2.0;
	float fade = (1.0 - smoothstep(0.70, 1.0, e.x)) * (1.0 - smoothstep(0.78, 1.0, e.y));
	return a * mix(1.0, fade, tile_edge);
}

// Un foco del degradado de malla, con el radio respirando despacio.
void add_blob(inout vec3 col, inout float a, vec2 px, vec4 b, vec4 bc, float t, float ph) {
	float r = max(b.z * res.y * (1.0 + 0.05 * sin(t * 0.5 + ph)), 1.0);
	float k = b.w * bc.a * pow(1.0 - clamp(length(px - b.xy * res) / r, 0.0, 1.0), 1.5);
	col = mix(col, bc.rgb, k);
	a = max(a, k);
}

void fragment() {
	float t = TIME * speed;
	vec2 px = UV * res + vec2(sin(t), cos(t * 0.8)) * res.y * 0.012;
	vec4 base = mix(base_top, base_bottom, smoothstep(0.0, 1.0, UV.y));
	vec3 col = base.rgb;
	float a = base.a;
	add_blob(col, a, px, blob0, col0, t, 0.0);
	add_blob(col, a, px, blob1, col1, t, 1.7);
	add_blob(col, a, px, blob2, col2, t, 3.1);
	add_blob(col, a, px, blob3, col3, t, 4.6);
	// Viñeta: el centro queda más claro que las esquinas
	col *= 1.0 - vignette * smoothstep(0.30, 1.02, length((UV - 0.5) * vec2(1.35, 1.0)) * 1.2);
	if (tile_amount > 0.0) {
		float tt = tiles(px, UV);
		col = mix(col, tile_col, tt * tile_amount);
		a = max(a, tt * tile_amount);
	}
	col += (hash21(FRAGCOORD.xy) - 0.5) * grain;   // grano: rompe las bandas del degradado
	COLOR = vec4(col, a);
}
