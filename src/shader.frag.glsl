in vec2 v_uv;
out vec4 frag;

uniform float time;
uniform float delta;

uniform vec2 iResolution;

uniform vec3 cam_pos;
uniform vec3 cam_dir;
uniform vec3 cam_prev_pos;
uniform vec3 cam_prev_dir;

uniform sampler2D history;

#define STEPS 128
#define EPSILON.01
#define MAX_BOUNCES 3

float rand(vec2 co){
  return fract(sin(dot(co.xy,vec2(12.9898,78.233)))*43758.5453);
}

float hash(float seed){
  return fract(sin(seed)*43758.5453);
}

vec3 cosine_direction(in float seed,in vec3 nor){
  float u=hash(78.233+seed);
  float v=hash(10.873+seed);
  
  float ks=(nor.z>=0.)?1.:-1.;//do not use sign(nor.z), it can produce 0.0
  float ka=1./(1.+abs(nor.z));
  float kb=-ks*nor.x*nor.y*ka;
  vec3 uu=vec3(1.-nor.x*nor.x*ka,ks*kb,-ks*nor.x);
  vec3 vv=vec3(kb,ks-nor.y*nor.y*ka*ks,-nor.y);
  
  float a=6.2831853*v;
  return normalize(sqrt(u)*(cos(a)*uu+sin(a)*vv)+sqrt(1.-u)*nor);
}

vec3 ray_dir(float fieldOfView,vec2 size,vec2 fragCoord){
  vec2 xy=fragCoord-size*.5;
  float z=size.y/tan(radians(fieldOfView)*.5);
  return normalize(vec3(xy,-z));
}

vec2 undo_ray_dir(float fieldOfView,vec2 size,vec3 view_dir){
  float z=size.y/tan(radians(fieldOfView)*.5);
  vec2 fragCoord=(view_dir.xy*(-z/view_dir.z))+size*.5;
  return fragCoord;
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

bool is_block(ivec3 vox){
  return mod(vox,3)==0;
}

float sdf_scene(vec3 p,vec3 dir){
  float dist=1.;
  ivec3 d=ivec3(
    dir.x>0?1:-1,
    dir.y>0?1:-1,
    dir.z>0?1:-1
  );
  ivec3 vox=ivec3(floor(p));
  dist=min(dist,sdf_ceil(p,4));
  dist=min(dist,sdf_floor(p,-20));
  for(int x=0;x<=1;x++){
    for(int y=0;y<=1;y++){
      for(int z=0;z<=1;z++){
        ivec3 inner_vox=ivec3(x*d.x,y*d.y,z*d.z)+vox;
        if(is_block(inner_vox)){
          dist=min(dist,sdf_box(p-vec3(inner_vox)-.5,vec3(.5)));
        }
      }
    }
  }
  dist=max(dist,-sdf_sphere(p-cam_pos,.2));
  return dist;
}

vec3 get_normal(vec3 pos,vec3 dir){
  return normalize(
    vec3(
      sdf_scene(vec3(pos.x+EPSILON,pos.y,pos.z),dir)-sdf_scene(vec3(pos.x-EPSILON,pos.y,pos.z),dir),
      sdf_scene(vec3(pos.x,pos.y+EPSILON,pos.z),dir)-sdf_scene(vec3(pos.x,pos.y-EPSILON,pos.z),dir),
      sdf_scene(vec3(pos.x,pos.y,pos.z+EPSILON),dir)-sdf_scene(vec3(pos.x,pos.y,pos.z-EPSILON),dir)
    )
  );
}

void main(){
  vec3 view_dir=ray_dir(110.,iResolution,gl_FragCoord.xy);
  vec3 pos=cam_pos;
  
  mat3 view_to_world=view_matrix(pos,pos+cam_dir,vec3(0.,0.,1.));
  
  vec3 dir=view_to_world*view_dir;
  vec3 rand_vec=vec3(
    rand(gl_FragCoord.xy*123.23+time)-.5,
    rand(gl_FragCoord.xy*13.87+time)-.5,
    rand(gl_FragCoord.xy*97.51-time)-.5
  );
  dir=normalize(dir+rand_vec*.0001);
  
  vec3 tcol=vec3(.0);
  vec3 fcol=vec3(1.);
  
  vec3 hit_pos=vec3(0);
  int bounces=0;
  
  for(int i=0;i<STEPS;i++){
    float dist=sdf_scene(pos,dir);
    pos+=dir*dist;
    
    if(dist<EPSILON){
      if(pos.z>3.){
        // tcol+=dir.y>.0?dir*.5+.5:vec3(0);
        // tcol+=dir*.5+.5;
        tcol+=vec3(1);
        break;
      }
      if(hit_pos==vec3(0)){
        hit_pos=vec3(pos);
      }
      if(bounces>MAX_BOUNCES)break;
      bounces++;
      vec3 normal=get_normal(pos,dir);
      // fcol*=normal*.5+.5;
      fcol*=.8;
      float seed=rand(gl_FragCoord.xy/10.);
      vec3 diffuse=cosine_direction(seed+13.829+time,normal);
      vec3 reflection=reflect(dir,normal);
      dir=normalize(mix(diffuse,reflection,.9));
      // dir=diffuse;
      pos+=normal*EPSILON*3;
    }
  }
  
  mat3 old_view_to_world=view_matrix(cam_prev_pos,cam_prev_pos+cam_prev_dir,vec3(0.,0.,1.));
  vec3 old_dir=normalize(hit_pos-cam_prev_pos);
  vec3 old_view_dir=inverse(old_view_to_world)*old_dir;
  vec2 old_coord=undo_ray_dir(110.,iResolution,normalize(old_view_dir));
  
  pos=vec3(cam_prev_pos);
  dir=vec3(old_dir);
  
  for(int i=0;i<STEPS;i++){
    float dist=sdf_scene(pos,dir);
    pos+=dir*dist;
    
    if(dist<EPSILON){
      break;
    }
  }
  
  vec4 texel=texture(history,old_coord/iResolution.xy).rgba;
  vec3 hcol=texel.rgb;
  bool contained=old_coord.x>0.&&old_coord.x<iResolution.x&&old_coord.y>0.&&old_coord.y<iResolution.y;
  if(contained){
    float mixture=min(1/(distance(hit_pos,pos)*100.+1.04),texel.a);
    float newalpha=min(mixture+.3,1.);
    frag=vec4(mix(tcol*fcol,hcol,mixture)/newalpha,newalpha);
  }else{
    frag=vec4((tcol*fcol)*10,.1);
  }
  if(gl_FragCoord.x<5&&gl_FragCoord.y<5&&gl_FragCoord.x>4&&gl_FragCoord.y>4){
    frag=vec4(0,0,0,1);
  }
}
