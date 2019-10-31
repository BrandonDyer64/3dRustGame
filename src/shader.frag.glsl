in vec2 v_uv;
out vec4 frag;

uniform float time;
uniform float delta;

uniform vec3 cam_pos;
uniform vec3 cam_dir;
uniform vec3 cam_prev_pos;
uniform vec3 cam_prev_dir;

uniform sampler2D history;

#define STEPS 512
#define EPSILON.01

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
  return sqrt(u)*(cos(a)*uu+sin(a)*vv)+sqrt(1.-u)*nor;
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

float sdf_scene(vec3 sample_point){
  float dist=1.;
  dist=min(dist,sdf_floor(sample_point,-1.));
  dist=min(dist,sdf_ceil(sample_point,3.+EPSILON*2.));
  dist=min(dist,sdf_box(sample_point,vec3(.5,.5,1.)));
  dist=min(dist,sdf_sphere(sample_point+vec3(1,0,.5),.5));
  dist=max(dist,-sdf_sphere(sample_point-cam_pos,.1));
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
  vec3 view_dir=ray_dir(110.,vec2(1),v_uv);
  vec3 pos=cam_pos;
  
  mat3 view_to_world=view_matrix(pos,pos+cam_dir,vec3(0.,0.,1.));
  
  vec3 dir=view_to_world*view_dir;
  
  vec3 tcol=vec3(0.);
  vec3 fcol=vec3(1.);
  
  vec3 hit_pos=vec3(0);
  
  for(int i=0;i<STEPS;i++){
    float dist=sdf_scene(pos);
    pos+=dir*dist;
    
    if(pos.z>3){
      // tcol+=dir.y>.0?dir*.5+.5:vec3(0);
      tcol+=dir*.5+.5;
      break;
    }
    
    if(dist<EPSILON){
      if(hit_pos==vec3(0)){
        hit_pos=vec3(pos);
      }
      fcol*=.9;
      vec3 normal=get_normal(pos);
      float seed=rand(gl_FragCoord.xy/10.);
      if(mod(seed+time,1.)<.9){
        dir=cosine_direction(seed+13.829+time,normal);
      }else{
        dir=reflect(dir,normal);
      }
      pos+=normal*EPSILON*3;
    }
  }
  
  mat3 old_view_to_world=view_matrix(cam_prev_pos,cam_prev_pos+cam_prev_dir,vec3(0.,0.,1.));
  vec3 old_dir=normalize(hit_pos-cam_prev_pos);
  vec3 old_view_dir=inverse(old_view_to_world)*old_dir;
  vec2 old_uv=undo_ray_dir(110.,vec2(1),normalize(old_view_dir));
  
  pos=vec3(cam_prev_pos);
  dir=vec3(old_dir);
  
  for(int i=0;i<STEPS;i++){
    float dist=sdf_scene(pos);
    pos+=dir*dist;
    
    if(dist<EPSILON){
      break;
    }
  }
  
  vec3 hcol=texture(history,old_uv).rgb;
  bool contained=old_uv.x>0.&&old_uv.x<1.&&old_uv.y>0.&&old_uv.y<1.;
  if(distance(hit_pos,pos)<EPSILON&&contained){
    frag=vec4(mix(tcol*fcol,hcol,.95),1);
  }else{
    frag=vec4(tcol*fcol,1);
  }
}
