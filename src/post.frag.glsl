in vec2 v_uv;
out vec4 frag;

uniform sampler2D frame;
uniform sampler2D last;

void main(){
  vec3 col;
  ivec2 fragCoord = ivec2(gl_FragCoord.xy);
  if(mod(fragCoord.x, 2) == mod(fragCoord.y, 2)){
    col=textureLod(frame,v_uv,1.).rgb;
  }else{
    col=textureLod(last,v_uv,1.).rgb;
  }
  frag=vec4(col,1);
}
