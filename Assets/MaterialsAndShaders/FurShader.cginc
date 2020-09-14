#include "UnityCG.cginc"

struct vertexInput
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
    float3 normal : NORMAL;
};

struct vertexOutput
{
    float3 worldNormal : TEXCOORD1;
    float3 worldPos : TEXCOORD2;
    float3 previousWorldPos : TEXCOORD3;
    float2 uv : TEXCOORD0;
    float4 vertex : SV_POSITION;
    float3 normal : NORMAL;
};

struct tessellationFactors
{
    float edge[3] : SV_TESSFACTOR;
    float inside : SV_INSIDETESSFACTOR;
};

struct geometryOutput
{
    float3 worldNormal : TEXCOORD1;
    float3 worldPos : TEXCOORD2;
    float3 previousWorldPos : TEXCOORD4;
    float2 uv : TEXCOORD0;
    float4 vertex : SV_POSITION;
    int index : TEXCOORD3;
};

float _FurLength;
float _FurDensity;
float _FinLength;
sampler2D _MainTex;
float4 _MainTex_ST;
sampler2D _FurNoiseTex;
float _NoiseMultiplier;
float _Rigidness;
float _RimPower;
int _Iteration;
float _FinThreshold;
float _TessellationUniform;
float4x4 _PreviousFrameModelMatrix;
float4x4 _CurrentFrameInverseModelMatrix;
float4x4 _CurrentFrameModelMatrix;

// BaseVertexShader
vertexOutput baseVert(vertexInput i)
{
    vertexOutput o;
    o.vertex = UnityObjectToClipPos(i.vertex);
    o.uv = i.uv;
    o.normal = i.normal;
    o.worldNormal = UnityObjectToWorldNormal(i.normal);
    o.worldPos = mul(unity_ObjectToWorld, i.vertex).xyz;
    o.previousWorldPos = mul(_PreviousFrameModelMatrix, i.vertex).xyz;
    return o;
}

// BaseFragmentShader
fixed4 baseFrag(vertexOutput i) : SV_Target
{
    // sample the texture
    fixed4 col = tex2D(_MainTex, i.uv);

    return col;
}

// FinsVert
vertexOutput finsVert(vertexInput i)
{
    vertexOutput o;
    o.vertex = i.vertex;
    o.normal = i.normal;
    o.uv = i.uv;
    o.worldNormal = UnityObjectToWorldNormal(i.normal);
    o.worldPos = mul(unity_ObjectToWorld, i.vertex).xyz;
    o.previousWorldPos = mul(_PreviousFrameModelMatrix, i.vertex).xyz;
    
    return o;
}

// patchConstantFunction
tessellationFactors patchConstantFunction(InputPatch<vertexInput, 3> patch)
{
    tessellationFactors f;
    f.edge[0] = _TessellationUniform;
    f.edge[1] = _TessellationUniform;
    f.edge[2] = _TessellationUniform;
    f.inside = _TessellationUniform;

    return f;
}

// FinsHullShader
[UNITY_domain("tri")]
[UNITY_outputcontrolpoints(3)]
[UNITY_outputtopology("triangle_cw")]
[UNITY_partitioning("integer")]
[UNITY_patchconstantfunc("patchConstantFunction")]
vertexInput finsHull(InputPatch<vertexInput, 3> patch, uint id : SV_OUTPUTCONTROLPOINTID)
{
    return patch[id];
}

// FinsDomainShader
[UNITY_domain("tri")]
vertexOutput finsDomain(tessellationFactors factors, OutputPatch<vertexInput, 3> patch, float3 barycentricCoordinates : SV_DOMAINLOCATION)
{
    vertexInput i;
    #define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) i.fieldName = \
    patch[0].fieldName * barycentricCoordinates.x + \
    patch[1].fieldName * barycentricCoordinates.y + \
    patch[2].fieldName * barycentricCoordinates.z;

    MY_DOMAIN_PROGRAM_INTERPOLATE(vertex)
    MY_DOMAIN_PROGRAM_INTERPOLATE(normal)

    return finsVert(i);
}

// FinsGeometryShader
[maxvertexcount(4)]
void finsGeom(lineadj vertexOutput IN[4], inout TriangleStream<geometryOutput> triStream)
{
    geometryOutput o;
    
    // triangle's normals
    //float3 N1 = normalize(cross(IN[0].worldPos - IN[1].worldPos, IN[3].worldPos - IN[1].worldPos));
    //float3 N2 = normalize(cross(IN[2].worldPos - IN[1].worldPos, IN[0].worldPos - IN[1].worldPos));

    float3 N1 = normalize(cross(IN[0].vertex.xyz - IN[1].vertex.xyz, IN[3].vertex.xyz - IN[1].vertex.xyz));
    float3 N2 = normalize(cross(IN[0].vertex.xyz - IN[1].vertex.xyz, IN[2].vertex.xyz - IN[1].vertex.xyz));

    float3 worldN1 = UnityObjectToWorldNormal(N1);
    float3 worldN2 = UnityObjectToWorldNormal(N2);

    // triangles's barycentric
    float3 barycentric1 = (IN[0].worldPos + IN[1].worldPos + IN[3].worldPos) / 3;
    float3 barycentric2 = (IN[0].worldPos + IN[1].worldPos + IN[2].worldPos) / 3;

    // viewDir
    float3 viewDir1 = normalize(_WorldSpaceCameraPos.xyz - barycentric1);
    float3 viewDir2 = normalize(_WorldSpaceCameraPos.xyz - barycentric2);

    // if silhouette
    float eyeDotN1 = dot(viewDir1, worldN1);
    float eyeDotN2 = dot(viewDir2, worldN2);

    if(eyeDotN1 * eyeDotN2 < 0 || abs(eyeDotN1) < _FinThreshold || abs(eyeDotN2) < _FinThreshold)
    {   
        o.vertex = UnityObjectToClipPos(IN[0].vertex);
        o.uv = TRANSFORM_TEX(IN[0].uv, _MainTex);
        o.worldNormal = UnityObjectToWorldNormal(N2);
        o.worldPos = IN[0].worldPos;
        o.previousWorldPos = IN[0].previousWorldPos;
        o.index = 0;
        triStream.Append(o);

        o.vertex = UnityObjectToClipPos(IN[1].vertex);
        o.uv = TRANSFORM_TEX(IN[1].uv, _MainTex);
        o.worldNormal = UnityObjectToWorldNormal(N2);
        o.worldPos = IN[1].worldPos;
        o.previousWorldPos = IN[1].previousWorldPos;
        o.index = 0;
        triStream.Append(o);


        fixed3 pos = IN[0].vertex.xyz + N2 * _FinLength;
        o.vertex = UnityObjectToClipPos(fixed4(pos, 1.0));
        o.uv = TRANSFORM_TEX(IN[0].uv, _MainTex);
        o.worldNormal = UnityObjectToWorldNormal(N2);
        o.worldPos = mul(unity_ObjectToWorld, float4(pos, 1.0)).xyz;
        o.previousWorldPos = mul(_PreviousFrameModelMatrix, float4(pos, 1.0)).xyz;
        o.index = 1;
        triStream.Append(o);

        pos = IN[1].vertex.xyz + N2 * _FinLength;
        o.vertex = UnityObjectToClipPos(fixed4(pos, 1.0));
        o.uv = TRANSFORM_TEX(IN[1].uv, _MainTex);
        o.worldNormal = UnityObjectToWorldNormal(N2);
        o.worldPos = mul(unity_ObjectToWorld, float4(pos, 1.0)).xyz;
        o.previousWorldPos = mul(_PreviousFrameModelMatrix, float4(pos, 1.0)).xyz;
        o.index = 1;
        triStream.Append(o);

        triStream.RestartStrip();
    }
}

// FinsFragmentShader
fixed4 finsFrag(geometryOutput i) : SV_Target
{
    fixed alpha = tex2D(_FurNoiseTex, i.uv * _NoiseMultiplier).r;
    fixed3 col = tex2D(_MainTex, i.uv).rgb - pow(1 - i.index * 0.1, 3) * 0.1;

    fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
    half rim = 1.0 - saturate(dot(viewDir, i.worldNormal));
    col += pow(rim, _RimPower);

    alpha = clamp(alpha - pow(i.index * 0.1, 2) * _FurDensity, 0, 1);

    return fixed4(col, alpha);
}

// FurVertexShader
vertexOutput furVert(vertexInput i)
{
    vertexOutput o;
    o.vertex = i.vertex;
    o.uv = i.uv;
    o.normal = i.normal;
    o.worldNormal = UnityObjectToWorldNormal(i.normal);
    o.worldPos = mul(unity_ObjectToWorld, i.vertex).xyz;
    return o;
}

// FurGeometryShader
[maxvertexcount(MAXCOUNT)]
void furGeom(triangle vertexOutput IN[3], inout TriangleStream<geometryOutput> triStream)
{
    geometryOutput o;

    for (int i = 1; i <= _Iteration; i++)
    {
        for(int j = 0; j < 3; j++)
        {
            float3 pos = IN[j].vertex.xyz + IN[j].normal * _FurLength * i * 0.1;
            float4 gravity = float4(0,-1,0,0) * (1 -_Rigidness);

            float4 vertexMotionDir = float4(mul(_CurrentFrameModelMatrix, IN[j].vertex).xyz - IN[j].previousWorldPos, 0) * (1 -_Rigidness);

            float4 MotionDir = gravity - vertexMotionDir;

            pos += clamp(mul(_CurrentFrameInverseModelMatrix, MotionDir).xyz, -1, 1) * pow(i * 0.1, 3) * _FurLength;
            
            o.vertex = UnityObjectToClipPos(float4(pos, 1.0));
            o.uv = TRANSFORM_TEX(IN[j].uv, _MainTex);
            o.worldNormal = UnityObjectToWorldNormal(IN[j].normal);
            o.worldPos = mul(unity_ObjectToWorld, float4(pos, 1.0)).xyz;
            o.previousWorldPos = mul(_PreviousFrameModelMatrix, float4(pos, 1.0)).xyz;
            o.index = i;
            triStream.Append(o);
       }
       triStream.RestartStrip();
    }
}

fixed4 furFrag(geometryOutput i) : SV_Target
{
    fixed alpha = tex2D(_FurNoiseTex, i.uv * _NoiseMultiplier).r;
    fixed3 col = tex2D(_MainTex, i.uv).rgb - pow(1 - i.index * 0.1, 3) * 0.1;

    fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
    half rim = 1.0 - saturate(dot(viewDir, i.worldNormal));
    col += pow(rim, _RimPower);

    alpha = clamp(alpha - pow(i.index * 0.1, 2) * _FurDensity, 0, 1);

    return fixed4(col, alpha);
}