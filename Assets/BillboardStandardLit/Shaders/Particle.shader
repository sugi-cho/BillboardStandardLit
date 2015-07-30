Shader "Custom/Particle" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
		_Radius ("radius", Float) = 0.5
	}
	CGINCLUDE
	
	#include "HLSLSupport.cginc"
	#include "UnityShaderVariables.cginc"
	
	#include "UnityCG.cginc"
	#include "Lighting.cginc"
	#include "UnityPBSLighting.cginc"
	
	uniform int _TexSize;
	uniform int _Offset;
	uniform sampler2D 
		_MrTex0,
		_MrTex1;
	sampler2D _MainTex;
	
	struct Input {
		float2 uv_MainTex;
		half3 worldCenterPos;
		half3 viewCenterPos;
		half3 viewRight;
		half3 viewUp;
		half3 viewForward;
	};
	
	half _Glossiness;
	half _Metallic;
	fixed4 _Color;
	
	half _Radius;
	
	void surf (Input IN, inout SurfaceOutputStandard o, inout half3 worldPos, inout half depth) {
		half3 viewNormal;
		viewNormal.xy = IN.uv_MainTex * 2.0 - 1.0;
		half r2 = dot(viewNormal.xy, viewNormal.xy);
		if(r2 > 1.0)
			discard;
		viewNormal.z = sqrt(1.0 - r2);
		
		half4 viewPos = half4(IN.viewCenterPos.xyz + viewNormal * _Radius,1.0);
		half4 clipPos = mul(UNITY_MATRIX_P, viewPos);
		#if defined(SHADER_TARGET_GLSL)
		    depth = (clipPos.z/clipPos.w) * 0.5 + 0.5;
		#else
		    depth = clipPos.z/clipPos.w;
		#endif
		if(depth <= 0)
			discard;
		
		half3 normal = viewNormal.x*IN.viewRight + viewNormal.y*IN.viewUp + viewNormal.z*IN.viewForward;
		normal = normalize(normal);
		worldPos = IN.worldCenterPos + normal*_Radius;
			
		fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
		o.Albedo = c.rgb;
		o.Metallic = _Metallic;
		o.Smoothness = _Glossiness;
		o.Normal = normal;
		o.Alpha = c.a;
	}
	
	
	// vertex-to-fragment interpolation data
	struct v2f_surf {
		float4 pos : SV_POSITION;
		float2 pack0 : TEXCOORD0; // _MainTex
		half3 sh : TEXCOORD1; // SH
		half3 worldCenterPos : TEXCOORD2;
		half3 viewCenterPos : TEXCOORD3;
		half3 viewRight : TEXCOORD4;
		half3 viewUp : TEXCOORD5;
		half3 viewForward : TEXCOORD6;
	};
	float4 _MainTex_ST;
	
	// vertex shader
	v2f_surf vert_surf (appdata_full v) {
		float2 uv = float2(frac((v.texcoord1.x+_Offset)/_TexSize), (v.texcoord1.x+_Offset)/_TexSize/_TexSize);
		float3 pos = tex2Dlod(_MrTex0,float4(uv,0,0));
		v.vertex.xyz += pos;
		
		v2f_surf o;
		UNITY_INITIALIZE_OUTPUT(v2f_surf,o);
		
		//world空間上における、view空間内のx,y,z軸の方向
		o.viewRight = UNITY_MATRIX_V[0].xyz;
		o.viewUp = UNITY_MATRIX_V[1].xyz;
		o.viewForward = UNITY_MATRIX_V[2].xyz;
		
		v.vertex.xy -= v.texcoord.xy-0.5;
		v.vertex = mul(_Object2World, v.vertex);
		o.worldCenterPos = v.vertex.xyz;
		v.vertex = mul(UNITY_MATRIX_V, v.vertex);
		o.viewCenterPos = v.vertex.xyz;
		v.vertex.xy += (v.texcoord.xy*2.0-1.0) * _Radius;
		
		o.pos = mul (UNITY_MATRIX_P, v.vertex);
		o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
		fixed3 worldNormal = o.viewForward;
		
		o.sh = ShadeSH3Order (half4(worldNormal, 1.0));
		return o;
	}
	
	// fragment shader
	void frag_surf (v2f_surf IN,
		out half4 outDiffuse : SV_Target0,
		out half4 outSpecSmoothness : SV_Target1,
		out half4 outNormal : SV_Target2,
		out half4 outEmission : SV_Target3,
		out half outDepth : SV_Depth) 
	{
	// prepare and unpack data
		Input surfIN;
		UNITY_INITIALIZE_OUTPUT(Input,surfIN);
		surfIN.uv_MainTex = IN.pack0.xy;
		surfIN.worldCenterPos = IN.worldCenterPos;
		surfIN.viewCenterPos = IN.viewCenterPos;
		surfIN.viewRight = IN.viewRight;
		surfIN.viewUp = IN.viewUp;
		surfIN.viewForward = IN.viewForward;
		
		#ifdef UNITY_COMPILER_HLSL
			SurfaceOutputStandard o = (SurfaceOutputStandard)0;
		#else
			SurfaceOutputStandard o;
		#endif
		
		o.Albedo = 0.0;
		o.Emission = 0.0;
		o.Alpha = 0.0;
		o.Occlusion = 1.0;
		o.Normal = IN.viewForward;
		half3 worldPos;
		// call surface function
		surf (surfIN, o, worldPos, outDepth);
		fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
		
		// Setup lighting environment
		UnityGI gi;
		UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
		gi.indirect.diffuse = 0;
		gi.indirect.specular = 0;
		gi.light.color = 0;
		gi.light.dir = half3(0,1,0);
		gi.light.ndotl = LambertTerm (o.Normal, gi.light.dir);
		// Call GI (lightmaps/SH/reflections) lighting function
		UnityGIInput giInput;
		UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);
		giInput.light = gi.light;
		giInput.worldPos = worldPos;
		giInput.worldViewDir = worldViewDir;
		giInput.atten = 1.0;
		
		giInput.ambient = IN.sh;
		
		giInput.probeHDR[0] = unity_SpecCube0_HDR;
		giInput.probeHDR[1] = unity_SpecCube1_HDR;
		
		#if UNITY_SPECCUBE_BLENDING || UNITY_SPECCUBE_BOX_PROJECTION
			giInput.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
		#endif
		
		#if UNITY_SPECCUBE_BOX_PROJECTION
			giInput.boxMax[0] = unity_SpecCube0_BoxMax;
			giInput.probePosition[0] = unity_SpecCube0_ProbePosition;
			giInput.boxMax[1] = unity_SpecCube1_BoxMax;
			giInput.boxMin[1] = unity_SpecCube1_BoxMin;
			giInput.probePosition[1] = unity_SpecCube1_ProbePosition;
		#endif
		
		LightingStandard_GI(o, giInput, gi);
		
		// call lighting function to output g-buffer
		outEmission = LightingStandard_Deferred (o, worldViewDir, gi, outDiffuse, outSpecSmoothness, outNormal);
		outDiffuse.a = 1.0;
		
		#ifndef UNITY_HDR_ON
			outEmission.rgb = exp2(-outEmission.rgb);
		#endif
	}
	ENDCG

	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		Pass {
			Name "DEFERRED"
			Tags { "LightMode" = "Deferred" }
			
			CGPROGRAM
			#pragma vertex vert_surf
			#pragma fragment frag_surf
			#pragma target 3.0
			#pragma exclude_renderers nomrt
			#pragma multi_compile_prepassfinal noshadow
			ENDCG
		}
	}
	FallBack "Diffuse"
}