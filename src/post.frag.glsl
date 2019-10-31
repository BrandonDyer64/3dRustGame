in vec2 v_uv;
out vec4 frag;

uniform sampler2D frame;

#define INV_SQRT_OF_2PI.39894228040143267793994605993439// 1.0/SQRT_OF_2PI
#define INV_PI.31830988618379067153776752674503

vec4 smart_denoise(sampler2D tex,vec2 uv,float sigma,float kSigma,float threshold){
  float radius=round(kSigma*sigma);
  float radQ=radius*radius;
  
  float invSigmaQx2=.5/(sigma*sigma);// 1.0/(sigma^2*2.0)
  float invSigmaQx2PI=INV_PI*invSigmaQx2;// 1.0/(sqrt(PI)*sigma)
  
  float invThresholdSqx2=.5/(threshold*threshold);// 1.0/(sigma^2*2.0)
  float invThresholdSqrt2PI=INV_SQRT_OF_2PI/threshold;// 1.0/(sqrt(2*PI)*sigma)
  
  vec4 centrPx=texture(tex,uv);
  
  float zBuff=0.;
  vec4 aBuff=vec4(0.);
  vec2 size=vec2(textureSize(tex,0));
  
  for(float x=-radius;x<=radius;x++){
    float pt=sqrt(radQ-x*x);// pt=yRadius: have circular trend
    for(float y=-pt;y<=pt;y++){
      vec2 d=vec2(x,y)/size;
      
      float blurFactor=exp(-dot(d,d)*invSigmaQx2)*invSigmaQx2;
      
      vec4 walkPx=texture(tex,uv+d);
      
      vec4 dC=walkPx-centrPx;
      float deltaFactor=exp(-dot(dC,dC)*invThresholdSqx2)*invThresholdSqrt2PI*blurFactor;
      
      zBuff+=deltaFactor;
      aBuff+=deltaFactor*walkPx;
    }
  }
  return aBuff/zBuff;
}

void main(){
  // vec3 truth=texture(frame,v_uv).rgb;
  
  // vec3 brightest=truth;
  
  // for(int y=-1;y<=1;y++){
    //   for(int x=-1;x<=1;x++){
      //     vec3 sample=textureOffset(frame,v_uv,ivec2(x,y)).rgb;
      //     if(distance(truth,sample)<.2){
        //       if(sample.r>brightest.r) brightest.r=sample.r;
        //       if(sample.g>brightest.g) brightest.g=sample.g;
        //       if(sample.b>brightest.b) brightest.b=sample.b;
      //     }
    //   }
  // }
  
  // frag=vec4(brightest,1.);
  // frag=pow(frag,vec4(1./2.2));
  frag=smart_denoise(frame,v_uv,3.,1.,.1);
}
