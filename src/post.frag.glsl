in vec2 v_uv;
out vec4 frag;

uniform sampler2D frame;

void main(){
  vec3 truth=texture(frame,v_uv).rgb;

  vec3 brightest=truth;

  for(int y=-1;y<=1;y++){
    for(int x=-1;x<=1;x++){
      vec3 sample=textureOffset(frame,v_uv,ivec2(x,y)).rgb;
      if(distance(truth,sample)<.2&&sample.r>brightest.r&&sample.g>brightest.g&&sample.b>brightest.b){
        brightest=sample;
      }
    }
  }

  frag=vec4(brightest, 1.);
  frag=pow(frag,vec4(1./2.2));
}
