Shader "Reference/ProceduralBurningFlame"
{
    Properties
    {
        _LocalClock ("Paused host clock", Float) = 0
        _Phase ("Independent phase", Float) = 0
        _Opacity ("Lifetime opacity", Float) = 1
        _Grave ("Spectral palette", Float) = 0
        _Heat ("Local heat", Float) = 1
        _Medium ("Flame / ground / smoke / ember", Float) = 0
        _Cull ("Surface culling", Float) = 0
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Transparent" "Queue"="Transparent" }
        Pass
        {
            Tags { "LightMode"="SRPDefaultUnlit" }
            Cull [_Cull] ZWrite Off ZTest LEqual
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #pragma target 3.0
            #pragma vertex Vert
            #pragma fragment Frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            CBUFFER_START(UnityPerMaterial)
                float _LocalClock, _Phase, _Opacity, _Grave, _Heat, _Medium, _Cull;
            CBUFFER_END
            struct Attributes
            {
                float4 positionOS:POSITION;
                float2 uv:TEXCOORD0;
                float2 tongue:TEXCOORD1;
                half4 color:COLOR;
            };
            struct Varyings
            {
                float4 positionCS:SV_POSITION;
                float2 uv:TEXCOORD0;
                float3 combustion:TEXCOORD1;
                float3 positionOS:TEXCOORD2;
                float3 normalWS:TEXCOORD3;
                float3 positionWS:TEXCOORD4;
                half4 color:COLOR;
            };
            float Hash(float2 p)
            {
                float3 q = frac(float3(p.xyx) * .1031);
                q += dot(q, q.yzx + 33.33);
                return frac((q.x + q.y) * q.z);
            }
            float Noise(float2 p)
            {
                float2 cell = floor(p), f = frac(p);
                f = f * f * (3 - 2 * f);
                return lerp(lerp(Hash(cell), Hash(cell + float2(1,0)), f.x),
                    lerp(Hash(cell + float2(0,1)), Hash(cell + 1), f.x), f.y);
            }
            float Fbm(float2 p)
            {
                return Noise(p) * .57 + Noise(p * 2.03 + 7.1) * .29 + Noise(p * 4.11 - 3.7) * .14;
            }
            // A spatial centerline and circular radius, independent of camera direction.
            void Lobe(float v, float id, float detached, float seed, out float3 center,
                out float radius, out float life)
            {
                float t = _LocalClock * (1.38 + frac(seed * 3.7) * .49);
                float phase = seed * 6.283185;
                float azimuth = id * 2.399963 + phase * .19;
                float2 radial = float2(cos(azimuth), sin(azimuth));
                float2 lateral = float2(-radial.y, radial.x);
                float height = id < .5 ? .97 : .57 + .26 * Hash(float2(id,4));
                height *= .90 + .10 * sin(t * 2.6 + phase);
                float tip = v * v * v;
                float bend = sin(v * 4.7 - t * 2.6 + phase) * v * .075;
                float roll = tip * .18 * sin(v * 2.7 + sin(t * 1.7 + phase) * .8);
                float2 root = radial * (id < .5 ? 0 : .20);
                float2 xz = root + radial * (bend + roll)
                    + lateral * (sin(v * 5.3 - t * 2.1 + phase) * v * .085);
                center = float3(xz.x, v * height - tip * .04, xz.y);
                radius = (.145 + .02 * sin(phase)) * pow(saturate(1-v), .80)
                    * smoothstep(0,.07,v) * (1 + .24 * sin(v * 9 - t * 3.2 + phase));
                life = 1;
                if (detached > .5)
                {
                    float age = frac(t * .50 + seed);
                    life = pow(max(0,sin(age * 3.141593)),2);
                    xz = radial * (.16 + age * .10) + lateral * sin(v * 5 + phase + age * 4) * .06;
                    center = float3(xz.x, .55 + age * .64 + v * .30, xz.y);
                    radius = .045 * pow(saturate(sin(v * 3.141593)), .8) * (.4 + life * .6);
                }
            }
            Varyings Vert(Attributes input)
            {
                Varyings output;
                output.combustion = float3(0,1,0);
                output.normalWS = float3(0,1,0);
                if (_Medium < .5)
                {
                    float id = input.tongue.x, detached = input.tongue.y;
                    float seed = Hash(float2(id + 3,17)) + _Phase;
                    float v = input.uv.y;
                    float3 center, neighbor;
                    float radius, life, rNeighbor, unused;
                    Lobe(v, id, detached, seed, center, radius, life);
                    // One neighboring sample gives the tangent and taper, including at both caps.
                    float stepDirection = v < .99 ? 1 : -1;
                    Lobe(v + stepDirection*.008, id, detached, seed, neighbor, rNeighbor, unused);
                    float3 delta = (neighbor-center)*stepDirection;
                    float distance = length(delta);
                    float3 tangent = delta / max(.001,distance);
                    float3 axis = abs(tangent.y) > .9 ? float3(1,0,0) : float3(0,1,0);
                    float3 side = normalize(cross(axis,tangent));
                    float3 right = cross(tangent,side);
                    float angle = input.uv.x * 6.283185;
                    float3 radial = right * cos(angle) + side * sin(angle);
                    // Round lobe ripples close at the circular seam, retaining real X/Z thickness.
                    float ripple = 1 + .12 * sin(angle * 3 + v * 8 - _LocalClock * 4.5 + seed * 7);
                    input.positionOS.xyz = center + radial * radius * ripple;
                    float slope = (rNeighbor-radius)*stepDirection / max(.001,distance);
                    output.normalWS = TransformObjectToWorldNormal(normalize(radial-tangent*slope));
                    output.combustion = float3(seed, life, detached);
                }
                output.positionOS = input.positionOS.xyz;
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS = TransformWorldToHClip(output.positionWS);
                output.uv = input.uv; output.color = input.color;
                return output;
            }
            half3 Palette(float heat)
            {
                float hot = smoothstep(.68, 1, heat);
                half3 warm = lerp(half3(.46,.028,.003), half3(1.32,.32,.012), smoothstep(.12,.62,heat));
                warm = lerp(warm, half3(2.3,1.38,.32), hot);
                half3 spectral = lerp(half3(.18,.025,.31), half3(.055,.78,.46), smoothstep(.20,.65,heat));
                spectral = lerp(spectral, half3(.60,1.8,1.12), hot);
                return lerp(warm, spectral, _Grave);
            }
            half4 Frag(Varyings input):SV_Target
            {
                float2 uv = input.uv;
                float t = _LocalClock, opacity = saturate(_Opacity) * input.color.a;
                if (_Medium > 2.5)
                {
                    float r = length((uv - .5) * 2);
                    float body = 1 - smoothstep(.10,1,r);
                    return half4(Palette(.85), body * body * opacity);
                }
                if (_Medium > .5)
                {
                    float2 p = uv * 2 - 1;
                    float noise = Fbm(p * 3 + float2(t * .18, -t * .25) + _Phase * 7);
                    float fold = .5 + .5 * sin(length(p) * 18 + noise * 8 - t * 1.6);
                    float mask = _Medium > 1.5 || _Grave > .5
                        ? 1 - smoothstep(.30,1,length(p)) : 1 - smoothstep(.25,1,abs(p.y));
                    if (_Medium > 1.5 || _Grave > .5)
                    {
                        half3 fog = lerp(half3(.055,.026,.09), half3(.25,.15,.34), noise);
                        fog += half3(.035,.12,.09) * fold * noise * .4;
                        return half4(fog, mask * (.26 + noise * .48) * opacity);
                    }
                    return half4(Palette(.60 + fold * .20), mask * (.40 + noise * .45) * opacity);
                }
                float seed = input.combustion.x, v = uv.y;
                // Sample spatial coordinates rather than an unwrapped across-sheet UV.
                // Both projections agree across the closed circular seam and keep flowing upward.
                float3 p = input.positionOS * float3(5,4,5) + float3(seed*13,-t*2.7,seed*7);
                float fine = Noise(p.xz * 2.1 + p.y * .38);
                float noise = Noise(p.xy)*.58 + Noise(p.zy + 17.3)*.30 + fine*.12;
                float density = smoothstep(.10,.85,noise);
                float3 view = GetWorldSpaceNormalizeViewDir(input.positionWS);
                float thickness = saturate(dot(normalize(input.normalWS),view));
                // A soft limb and internal hot belly imply thickness without an illuminated shell.
                float limb = pow(thickness,1.4);
                float root = smoothstep(0,.10,v);
                float tip = (1-smoothstep(.60,.99,v)) * pow(saturate(1-v),.25);
                float cavities = smoothstep(.18,.50,noise + fine*.16);
                float coverage = limb * root * tip * (.32 + density*.68)
                    * lerp(.24,1,cavities) * input.combustion.y;
                float core = pow(thickness,2.2) * (1-v*.55);
                float heat = saturate((.18 + core*(.64+density*.20) + fine*.08) * _Heat);
                // Raise the body modestly, concentrating HDR energy inside the hot belly.
                // The existing soft limb still takes both color and coverage to a dim edge.
                float glow = core*core*(.65+density*.35)*_Heat;
                half3 hotColor = lerp(half3(1.85,1.30,.42),half3(.62,1.70,1.02),_Grave);
                half3 color = Palette(heat)*1.25 + hotColor*glow;
                return half4(color,coverage*opacity*.68*lerp(1,.55,input.combustion.z));
            }
            ENDHLSL
        }
    }
}
