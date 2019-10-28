in vec2 v_uv;
out vec4 frag;

uniform float time;
uniform float delta;

void main(){
  frag=vec4(v_uv+time,1,1);
}
