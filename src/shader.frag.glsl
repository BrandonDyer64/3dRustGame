in vec2 v_uv;
out vec4 frag;

uniform int frame_num;

uniform float time;
uniform float delta;

uniform vec2 iResolution;

uniform vec3 cam_pos;
uniform vec3 cam_dir;
uniform vec3 cam_prev_pos;
uniform vec3 cam_prev_dir;

uniform sampler2D history;

#define STEPS 64
#define EPSILON .001
#define MAX_BOUNCES 2

float rand(vec2 co)
{
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

float hash(float seed)
{
    return fract(sin(seed) * 43758.5453);
}

float noise(vec2 n)
{
    const vec2 d = vec2(0., 1.);
    vec2 b = floor(n), f = smoothstep(vec2(0.), vec2(1.), fract(n));
    return mix(
        mix(rand(b), rand(b + d.yx), f.x),
        mix(rand(b + d.xy), rand(b + d.yy), f.x),
        f.y);
}

vec3 mod289(vec3 x)
{
    return x - floor(x * (1. / 289.)) * 289.;
}

vec4 mod289(vec4 x)
{
    return x - floor(x * (1. / 289.)) * 289.;
}

vec4 permute(vec4 x)
{
    return mod289(((x * 34.) + 1.) * x);
}

vec4 taylorInvSqrt(vec4 r)
{
    return 1.79284291400159 - .85373472095314 * r;
}

float snoise(vec3 v)
{
    const vec2 C = vec2(1. / 6., 1. / 3.);
    const vec4 D = vec4(0., .5, 1., 2.);

    // First corner
    vec3 i = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);

    // Other corners
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1. - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);

    //   x0 = x0 - 0.0 + 0.0 * C.xxx;
    //   x1 = x0 - i1  + 1.0 * C.xxx;
    //   x2 = x0 - i2  + 2.0 * C.xxx;
    //   x3 = x0 - 1.0 + 3.0 * C.xxx;
    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
    vec3 x3 = x0 - D.yyy; // -1.0+3.0*C.x = -0.5 = -D.y

    // Permutations
    i = mod289(i);
    vec4 p = permute(
        permute(
            permute(i.z + vec4(0., i1.z, i2.z, 1.)) + i.y
            + vec4(0., i1.y, i2.y, 1.))
        + i.x + vec4(0., i1.x, i2.x, 1.));

    // Gradients: 7x7 points over a square, mapped onto an octahedron.
    // The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
    float n_ = .142857142857; // 1.0/7.0
    vec3 ns = n_ * D.wyz - D.xzx;

    vec4 j = p - 49. * floor(p * ns.z * ns.z); //  mod(p,7*7)

    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7. * x_); // mod(j,N)

    vec4 x = x_ * ns.x + ns.yyyy;
    vec4 y = y_ * ns.x + ns.yyyy;
    vec4 h = 1. - abs(x) - abs(y);

    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);

    // vec4 s0 = vec4(lessThan(b0,0.0))*2.0 - 1.0;
    // vec4 s1 = vec4(lessThan(b1,0.0))*2.0 - 1.0;
    vec4 s0 = floor(b0) * 2. + 1.;
    vec4 s1 = floor(b1) * 2. + 1.;
    vec4 sh = -step(h, vec4(0.));

    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);

    // Normalise gradients
    vec4 norm = taylorInvSqrt(
        vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    // Mix final noise value
    vec4 m = max(
        .6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.);
    m = m * m;
    return 42.
        * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

vec3 cosine_direction(in float seed, in vec3 nor)
{
    float u = hash(78.233 + seed);
    float v = hash(10.873 + seed);

    float ks = (nor.z >= 0.)
        ? 1.
        : -1.; // do not use sign(nor.z), it can produce 0.0
    float ka = 1. / (1. + abs(nor.z));
    float kb = -ks * nor.x * nor.y * ka;
    vec3 uu = vec3(1. - nor.x * nor.x * ka, ks * kb, -ks * nor.x);
    vec3 vv = vec3(kb, ks - nor.y * nor.y * ka * ks, -nor.y);

    float a = 6.2831853 * v;
    return normalize(
        sqrt(u) * (cos(a) * uu + sin(a) * vv) + sqrt(1. - u) * nor);
}

vec3 ray_dir(float fieldOfView, vec2 size, vec2 fragCoord)
{
    vec2 xy = fragCoord - size * .5;
    float z = size.y / tan(radians(fieldOfView) * .5);
    return normalize(vec3(xy, -z));
}

vec2 undo_ray_dir(float fieldOfView, vec2 size, vec3 view_dir)
{
    float z = size.y / tan(radians(fieldOfView) * .5);
    vec2 fragCoord = (view_dir.xy * (-z / view_dir.z)) + size * .5;
    return fragCoord;
}

mat3 view_matrix(vec3 eye, vec3 center, vec3 up)
{
    vec3 f = normalize(center - eye);
    vec3 s = normalize(cross(f, up));
    vec3 u = cross(s, f);
    return mat3(s, u, -f);
}

float sdf_sphere(vec3 p, float r)
{
    return length(p) - r;
}

float sdf_box(vec3 p, vec3 b)
{
    vec3 q = abs(p) - b;
    return length(max(q, 0.)) + min(max(q.x, max(q.y, q.z)), 0.);
}

float sdf_floor(vec3 p, float h)
{
    return p.z - h;
}

float sdf_ceil(vec3 p, float h)
{
    return h - p.z;
}

bool is_block(ivec3 vox)
{
    if (vox.z < -50)
        return true;
    if (vox.x < 3. && vox.x > -3 && vox.y < 3 && vox.y > -3)
        return true;
    if (vox.x < 20. && vox.x > 17 && vox.y < 20 && vox.y > 17)
        return false;
    // return snoise(vox*.05)>vox.z*.05+2;
    vec2 fvox = sin(vox.xy * .097357) + cos(vox.xy * .41389) * .2;
    return fvox.x * fvox.y > vox.z * .05 + 2;
}

float sdf_scene(vec3 p, vec3 dir)
{
    float dist = 1.;
    ivec3 d = ivec3(dir.x > 0 ? 1 : -1, dir.y > 0 ? 1 : -1, dir.z > 0 ? 1 : -1);
    ivec3 vox = ivec3(floor(p));
    int is_x = 0;
    int is_y = 0;
    int is_z = 0;
    for (int x = 0; x <= 1; x++) {
        for (int y = 0; y <= 1; y++) {
            for (int z = 0; z <= 1; z++) {
                ivec3 checked_vox = ivec3(x * d.x, y * d.y, z * d.z) + vox;
                if (is_block(checked_vox)) {
                    is_x |= x;
                    is_y |= y;
                    is_z |= z;
                    dist = min(
                        dist, sdf_box(p - vec3(checked_vox) - .5, vec3(.5)));
                }
            }
        }
    }
    dist = max(dist, -sdf_sphere(p - cam_pos, .2));
    return dist;
}

vec3 get_normal(vec3 pos, vec3 dir)
{
    return normalize(vec3(
        sdf_scene(vec3(pos.x + EPSILON, pos.y, pos.z), dir)
            - sdf_scene(vec3(pos.x - EPSILON, pos.y, pos.z), dir),
        sdf_scene(vec3(pos.x, pos.y + EPSILON, pos.z), dir)
            - sdf_scene(vec3(pos.x, pos.y - EPSILON, pos.z), dir),
        sdf_scene(vec3(pos.x, pos.y, pos.z + EPSILON), dir)
            - sdf_scene(vec3(pos.x, pos.y, pos.z - EPSILON), dir)));
}

void main()
{
    float mixture = 1.;
    vec3 view_dir = ray_dir(110., iResolution, gl_FragCoord.xy);
    // float motion_blur_dist=rand(gl_FragCoord.xy*0.13247+time);
    float motion_blur_dist = 0;
    vec3 pos = mix(cam_pos, cam_prev_pos, motion_blur_dist);

    mat3 view_to_world = view_matrix(
        pos,
        pos + mix(cam_dir, cam_prev_dir, motion_blur_dist),
        vec3(0., 0., 1.));

    vec3 dir = view_to_world * view_dir;

    vec3 tcol = vec3(.0);
    vec3 fcol = vec3(1.);

    vec3 hit_pos = vec3(0);
    int bounces = 1;
    float total_distance = 0;
    bool do_sky = true;

    for (int i = 0; i < STEPS; i++) {
        if (total_distance > 150)
            break;
        float dist = sdf_scene(pos, dir);
        total_distance += dist;
        pos += dir * dist;

        if (dist < EPSILON * bounces) {
            if (pos.z > 3)
                break;
            if (pos.x <= 4. && pos.x >= -4 && pos.y <= 4 && pos.y >= -4) {
                do_sky = false;
                if (mod(floor(time * .2), 2) == 0) {
                    tcol += vec3(1, .655, .149);
                }
                break;
            }
            if (bounces > MAX_BOUNCES) {
                do_sky = false;
                break;
            }
            bounces++;
            vec3 normal = get_normal(pos, dir);
            if (normal.z > .5 || mod(pos.z, 1.) > .8) {
                fcol *= vec3(.22, .557, .235);
            } else {
                fcol *= vec3(.306, .204, .18);
            }
            tcol += .1;
            // float seed=rand(gl_FragCoord.xy/10.);
            float seed = rand((floor(pos.xy * 32.) + floor(pos.z * 32.)) * .01);
            vec3 diffuse = cosine_direction(seed + time, normal);
            vec3 reflection = reflect(dir, normal);
            bool do_reflect = pos.z < -50 + EPSILON;
            if (do_reflect && bounces == 2) {
                fcol = vec3(.6, .6, 1.);
            } else if (hit_pos == vec3(0)) {
                hit_pos = vec3(pos);
            }
            dir = normalize(mix(reflection, diffuse, do_reflect ? 0. : 1.));
            // dir=diffuse;
            pos += normal * EPSILON * 3;
        }
    }
    if (do_sky) {
        tcol += vec3(.506, .831, .98) * 1.;
    }

    mat3 old_view_to_world = view_matrix(
        cam_prev_pos, cam_prev_pos + cam_prev_dir, vec3(0., 0., 1.));
    vec3 old_dir = normalize(hit_pos - cam_prev_pos);
    vec3 old_view_dir = inverse(old_view_to_world) * old_dir;
    vec2 old_coord = undo_ray_dir(110., iResolution, normalize(old_view_dir));

    pos = vec3(cam_prev_pos);
    dir = vec3(old_dir);
    int i;
    for (i = 0; i < STEPS * .2; i++) {
        float dist = sdf_scene(pos, dir);
        pos += dir * dist;

        if (dist < EPSILON) {
            bool do_reflect = pos.z < -50 + EPSILON;
            if (do_reflect && bounces == 2) {
                vec3 normal = get_normal(pos, dir);
                dir = reflect(dir, normal);
                pos += normal * EPSILON * 3;
            } else {
                break;
            }
        }
    }
    if (i >= STEPS * .2) {
        pos = hit_pos;
    }

    vec4 texel = textureLod(history, old_coord / iResolution.xy, 1.).rgba;
    vec3 hcol = texel.rgb;
    bool contained = old_coord.x > 0. && old_coord.x < iResolution.x
        && old_coord.y > 0. && old_coord.y < iResolution.y;
    contained = contained && floor(hit_pos.x * 16.) == floor(pos.x * 16.)
        && floor(hit_pos.y * 16.) == floor(pos.y * 16.)
        && floor(hit_pos.z * 16.) == floor(pos.z * 16.);
    if (contained) {
        mixture = min(mixture, texel.a);
        mixture = min(mixture, 1 / (distance(hit_pos, pos) * 1. + 1.01));
        mixture = min(mixture, 1 - distance(cam_dir, cam_prev_dir) * 4.);
        mixture = min(mixture, 1 - distance(cam_pos, cam_prev_pos));
        mixture = max(mixture, 0);
        float newalpha = min(mixture + .3, 1.);
        frag = vec4(mix(tcol * fcol, hcol, mixture) / newalpha, newalpha);
    } else {
        frag = vec4((tcol * fcol) * 10, .1);
    }
}
