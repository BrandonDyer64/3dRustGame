in vec2 v_uv;
out vec4 frag;

uniform sampler2D frame;

void main(){
  frag=vec4(textureLod(frame,v_uv,1.).rgb,1);
}
