Shader "Custom/ParticleUpdate" {
	Properties{
		_FirstPos("firstPos",2D) = "black"{}
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		ZTest Always
		ZWrite On
		Cull Back

		CGINCLUDE

		uniform sampler2D
			_MrTex0,
			_MrTex1;
		uniform float3 _Pos;
		sampler2D _FirstPos;
			
		struct appdata
		{
			float4 vertex : POSITION;
		};

		struct v2f {
			float4 vertex : SV_POSITION;
			float2 uv : TEXCOORD0;
		};

		struct pOut{
			float4 position : COLOR0;
			float4 velocity : COLOR1;
		};


		v2f vert (appdata v)
		{
			v2f o;
			o.vertex = v.vertex;
			o.uv = (v.vertex.xy/v.vertex.w+1.0)*0.5;
			return o;
		}
		
		float3 firstPos(float2 uv){
			float3 pos = half3(uv.x,0,uv.y);
			pos.xz -= 0.5;
			pos = normalize(pos)*max(abs(pos.x),abs(pos.z));
			pos.y += 0.5;
			return pos * 100;
		}
		pOut frag_initialize(v2f i){
			float4
				position = float4(firstPos(i.uv),0),
				velocity = 0;
			
			pOut o;
			o.position = position;
			o.velocity = velocity;
			return o;
		}

		pOut frag_update (v2f i)
		{
			float4
				position = tex2D(_MrTex0, i.uv),
				velocity = tex2D(_MrTex1, i.uv);
			
			velocity.y -= unity_DeltaTime.x * saturate(length(sin(position.xz+_Time.x)))*10;
			velocity = velocity * 0.99;
			position += velocity * unity_DeltaTime.x;
			
			if(length(position.xyz) > 100)
				position.xyz = firstPos(i.uv);
			
			velocity.w = 1.0;
			position.w = 1.0;
			
			pOut o;
			o.position = position;
			o.velocity = velocity;
			return o;
		}
		
		ENDCG

		Pass {
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_initialize
			#pragma target 3.0
			#pragma glsl
			ENDCG
		}
		Pass {
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_update
			#pragma target 3.0
			#pragma glsl
			ENDCG
		}
	}
}