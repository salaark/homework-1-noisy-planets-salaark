#version 300 es

// Planet Simulation Shader Technique (PSST)
// Created By Salaar Kohari 2018

precision highp float;

uniform mat4 u_Model;       // The matrix that defines the transformation of object
uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
uniform float u_Time;

in vec4 vs_Pos;             // The array of vertex positions passed to the shader
in vec4 vs_Nor;             // The array of vertex normals passed to the shader
in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex.
out vec4 fs_Col;            // The color of each vertex.
out vec4 fs_Pos;
out float fs_Height;

//4D NOISE FUNCTION (by Ian McEwan, Ashima Arts)
vec4 permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);}
float permute(float x){return floor(mod(((x*34.0)+1.0)*x, 289.0));}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159 - 0.85373472095314 * r;}
float taylorInvSqrt(float r){return 1.79284291400159 - 0.85373472095314 * r;}

vec4 grad4(float j, vec4 ip) {
  const vec4 ones = vec4(1.0, 1.0, 1.0, -1.0);
  vec4 p,s;

  p.xyz = floor( fract (vec3(j) * ip.xyz) * 7.0) * ip.z - 1.0;
  p.w = 1.5 - dot(abs(p.xyz), ones.xyz);
  s = vec4(lessThan(p, vec4(0.0)));
  p.xyz = p.xyz + (s.xyz*2.0 - 1.0) * s.www; 

  return p;
}

float noise(vec4 v) {
  const vec2  C = vec2( 0.138196601125010504, 0.309016994374947451);

  vec4 i  = floor(v + dot(v, C.yyyy) );
  vec4 x0 = v -   i + dot(i, C.xxxx);

  vec4 i0;

  vec3 isX = step( x0.yzw, x0.xxx );
  vec3 isYZ = step( x0.zww, x0.yyz );
  i0.x = isX.x + isX.y + isX.z;
  i0.yzw = 1.0 - isX;

  i0.y += isYZ.x + isYZ.y;
  i0.zw += 1.0 - isYZ.xy;

  i0.z += isYZ.z;
  i0.w += 1.0 - isYZ.z;

  vec4 i3 = clamp( i0, 0.0, 1.0 );
  vec4 i2 = clamp( i0-1.0, 0.0, 1.0 );
  vec4 i1 = clamp( i0-2.0, 0.0, 1.0 );

  vec4 x1 = x0 - i1 + 1.0 * C.xxxx;
  vec4 x2 = x0 - i2 + 2.0 * C.xxxx;
  vec4 x3 = x0 - i3 + 3.0 * C.xxxx;
  vec4 x4 = x0 - 1.0 + 4.0 * C.xxxx;

  i = mod(i, 289.0); 
  float j0 = permute( permute( permute( permute(i.w) + i.z) + i.y) + i.x);
  vec4 j1 = permute( permute( permute( permute (
             i.w + vec4(i1.w, i2.w, i3.w, 1.0 ))
           + i.z + vec4(i1.z, i2.z, i3.z, 1.0 ))
           + i.y + vec4(i1.y, i2.y, i3.y, 1.0 ))
           + i.x + vec4(i1.x, i2.x, i3.x, 1.0 ));

  vec4 ip = vec4(1.0/294.0, 1.0/49.0, 1.0/7.0, 0.0) ;

  vec4 p0 = grad4(j0,   ip);
  vec4 p1 = grad4(j1.x, ip);
  vec4 p2 = grad4(j1.y, ip);
  vec4 p3 = grad4(j1.z, ip);
  vec4 p4 = grad4(j1.w, ip);

  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;
  p4 *= taylorInvSqrt(dot(p4,p4));

  vec3 m0 = max(0.6 - vec3(dot(x0,x0), dot(x1,x1), dot(x2,x2)), 0.0);
  vec2 m1 = max(0.6 - vec2(dot(x3,x3), dot(x4,x4)            ), 0.0);
  m0 = m0 * m0;
  m1 = m1 * m1;
  return 49.0 * ( dot(m0*m0, vec3( dot( p0, x0 ), dot( p1, x1 ), dot( p2, x2 )))
               + dot(m1*m1, vec2( dot( p3, x3 ), dot( p4, x4 ) ) ) ) ;

}

//Custom fractal brownian motion based on noise function
float fbm(vec4 p) {
    float n = 0.0;
    float w = 0.5;
    for (int i = 0; i < 4; i++) {
        n += noise(p) * w;
        w *= 0.5;
        p *= 2.0;
        p += vec4(100);
    }
    return n;
}

const vec4 lightPos = vec4(5, 5, 3, 1); //The position of our virtual light.

void main() {
    fs_Col = vs_Col;

    mat3 invTranspose = mat3(u_ModelInvTr);
    vec4 normal = vec4(invTranspose * vec3(vs_Nor), 0);
    fs_Nor = normal;

    float height = (fbm(vec4(vs_Pos.xyz,u_Time*0.0005))/2.0+1.0)/1.5;
	height = clamp(height, 0.49, 1.0);
	height = height*2.0-1.0;
	height = clamp(height, 0.34, 1.0);
	if(height < 0.35) {
		height -= abs(sin((vs_Pos.z+u_Time*0.002)*15.0)/15.0);
	}
    fs_Height = height;
    vec4 pos = vs_Pos + (normal*height);
    fs_Pos = pos;

    vec4 modelposition = u_Model * pos;   // Temporarily store the transformed vertex positions for use below
    fs_LightVec = lightPos - modelposition;  // Compute the direction in which the light source lies
    gl_Position = u_ViewProj * modelposition;// gl_Position renders the final positions of the geometry's vertices
}
