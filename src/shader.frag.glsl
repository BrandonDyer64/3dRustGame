in vec2 v_uv;
out vec4 frag;

uniform float time;
uniform float delta;

#define EPSILON.001

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

float sdf_scene(vec3 sample_point){
  return distance(sample_point,vec3(0))-1.;
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

float shortest_distance_to_surface(vec3 eye,vec3 marching_direction){
  float depth=.01;
  for(int i=0;i<512;i++){
    vec3 pos=eye+depth*marching_direction;
    float dist=sdf_scene(pos);
    if(dist<EPSILON){
      return depth;
    }
    depth+=dist;
  }
  return-1.;
}

void main(){
  vec3 view_dir=ray_dir(90.,vec2(1),v_uv);
  vec3 pos=vec3(5.*sin(time),5.*cos(time),.0001);
  
  mat3 view_to_world=view_matrix(pos,vec3(0),vec3(0.,0.,1.));
  
  vec3 dir=view_to_world*view_dir;
  vec3 transmit=vec3(1);
  vec3 light=vec3(0);
  float dist=shortest_distance_to_surface(pos,dir);
  if(dist<0){
    light+=transmit*(dir/2.+.5);
  }else{
    light+=reflect(dir,get_normal(pos+dir*dist))/2.+.5;
  }
  
  frag=vec4(light,1);
}
