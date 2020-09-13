Shader "Unlit/Fur"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _FurNoiseTex ("Texture", 2D) = "white" {}
        _FurLength("Fur Length", Range(0,1)) = 0.2
        _FurDensity("Fur Density", Range(0.1,10)) = 0.2
        _FinLength("Fin Length", Range(0,1)) = 0.2
        _FinThreshold("Fin Threshold", Range(-1, 1)) = 0.1
        _NoiseMultiplier("Multiplier", Range(0,10)) = 1
        _RimPower("Rim Power", Range(1, 256)) = 16
        [IntRange]_Iteration("Fur Iteretion", Range(5, 20)) = 10
        _TessellationUniform("Tessellation Uniform", Range(1, 64)) = 1
    }
    SubShader
    {
        Tags { "Queue" = "Transparent" }

        Pass
        {
            Cull off
            CGPROGRAM
            #define MAXCOUNT 0
            #pragma vertex baseVert
            #pragma fragment baseFrag
            #include "FurShader.cginc"
            ENDCG
        }

        Pass
        {
            ZWrite off
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma target 4.6
            #define MAXCOUNT 0
            #pragma vertex finsVert
            #pragma hull finsHull
            #pragma domain finsDomain
            #pragma geometry finsGeom
            #pragma fragment finsFrag
            #include "FurShader.cginc"
            ENDCG
        }

        Pass
        {
            ZWrite off
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #define MAXCOUNT 60
            #pragma vertex furVert
            #pragma geometry furGeom
            #pragma fragment furFrag
            #include "FurShader.cginc"
            ENDCG
        }
    }
}
