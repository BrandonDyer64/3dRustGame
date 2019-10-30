in vec2 v_uv;
out vec4 frag;

uniform float time;
uniform float delta;

#define STEPS 256
#define EPSILON.001

float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float hash(float seed){
    return fract(sin(seed)*43758.5453);
}

vec3 cosine_direction(in float seed,in vec3 nor){
  float u=hash(78.233+seed);
  float v=hash(10.873+seed);
  
  vec3 tc=vec3(1.+nor.z-nor.xy*nor.xy,-nor.x*nor.y)/(1.+nor.z);
  vec3 uu=vec3(tc.x,tc.z,-nor.x);
  vec3 vv=vec3(tc.z,tc.y,-nor.y);
  
  float a=6.2831853*v;
  return sqrt(u)*(cos(a)*uu+sin(a)*vv)+sqrt(1.-u)*nor;
}

vec3 ray_dir(float fieldOfView,vec2 size,vec2 fragCoord){
  vec2 xy=fragCoord-size/2.;
  float z=size.y/tan(radians(fieldOfView)/2.);
  return normalize(vec3(xy,-z));
}

mat3 view_matrix(vec3 eye,vec3 center,vec3 up){
  vec3 f=normalize(center-eye);
  vec3 s=normalize(cross(f,up));
  vec3 u=cross(s,f);
  return mat3(s,u,-f);
}

float sdf_sphere(vec3 p,float r){
  return length(p)-r;
}

float sdf_box(vec3 p,vec3 b){
  vec3 q=abs(p)-b;
  return length(max(q,0.))+min(max(q.x,max(q.y,q.z)),0.);
}

float sdf_floor(vec3 p,float h){
  return p.z-h;
}

float sdf_ceil(vec3 p,float h){
  return h-p.z;
}

float sdf_scene(vec3 sample_point){
  float dist=1.;
  dist=min(dist,sdf_floor(sample_point,-1.));
  dist=min(dist,sdf_box(sample_point,vec3(.5,.5,1.)));
  dist=min(dist,sdf_sphere(sample_point+vec3(1,0,.5),.5));
  return dist;
}

vec3 get_normal(vec3 pos){
  return normalize(
    vec3(
      sdf_scene(vec3(pos.x+EPSILON,pos.y,pos.z))-sdf_scene(vec3(pos.x-EPSILON,pos.y,pos.z)),
      sdf_scene(vec3(pos.x,pos.y+EPSILON,pos.z))-sdf_scene(vec3(pos.x,pos.y-EPSILON,pos.z)),
      sdf_scene(vec3(pos.x,pos.y,pos.z+EPSILON))-sdf_scene(vec3(pos.x,pos.y,pos.z-EPSILON))
    )
  );
}

void main(){
  vec3 view_dir=ray_dir(90.,vec2(1),v_uv);
  vec3 pos=vec3(5.*sin(time),5.*cos(time),.0001);

  mat3 view_to_world=view_matrix(pos,vec3(0),vec3(0.,0.,1.));

  vec3 dir=view_to_world*view_dir;

  vec3 tcol=vec3(0.);
  vec3 fcol=vec3(1.);

  for(int i=0;i<STEPS;i++){
    float dist=sdf_scene(pos);
    pos+=dir*dist;

    if(pos.z>3) {
      tcol+=fcol*(dir*.5+.5);
      break;
    }
    
    if(dist<EPSILON){
      fcol*=0.9;
      vec3 normal=get_normal(pos);
      float seed=rand(floor((gl_FragCoord.xy)/1.)*1.);
      dir=cosine_direction(seed*1293.39829*time,normal);
      pos+=normal*EPSILON*3;
    }
  }
  
  frag=vec4(tcol,1);
}
