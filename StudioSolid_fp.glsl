/*
StudioDiffuse_fp.glsl - draw solid and alpha-test surfaces
Copyright (C) 2014 Uncle Mike

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
*/

#include "const.h"
#include "mathlib.h"

uniform sampler2D		u_ColorMap;
uniform sampler2D		u_NormalMap;
uniform sampler2D		u_GlossMap;
uniform samplerCube		u_EnvMap0;
uniform samplerCube		u_EnvMap1;
uniform sampler2D		u_GlowMap;

uniform float		u_ReflectScale;
uniform float		u_GlossExponent;
uniform float		u_AmbientFactor;
uniform float		u_FresnelExponent;
uniform vec3		u_ViewOrigin;
uniform vec3		u_BoxMins[2];
uniform vec3		u_BoxMaxs[2];
uniform vec3		u_CubeOrigin[2];
uniform float		u_LerpFactor;

varying vec3		var_BaseLight;
varying vec2		var_TexDiffuse;

#if defined( STUDIO_CUBEMAP_BPCEM ) || defined( STUDIO_CUBEMAP_SIMPLE )
// NOTE: these variables in model-space
varying vec3		var_Position;
varying vec3		var_EyeDir;
varying vec3		var_Normal;
#endif

#if !defined( STUDIO_FULLBRIGHT ) && ( defined( STUDIO_HAS_BUMP ) || defined( STUDIO_HAS_GLOSS ) || defined( STUDIO_LIGHTVEC_DEBUG ))
varying vec3		var_LightDir;
#endif

#if !defined( STUDIO_FULLBRIGHT ) && defined( STUDIO_HAS_GLOSS )
varying vec3		var_ViewDir;
#endif

void main( void )
{
	// compute the diffuse term
	vec4 diffuse = texture2D( u_ColorMap, var_TexDiffuse );

#ifdef STUDIO_ALPHATEST
	// Valve "alpha-tested magnification"
	diffuse.a *= smoothstep( STUDIO_ALPHA_THRESHOLD, 1.0, diffuse.a ); 

	if( diffuse.a <= STUDIO_ALPHA_THRESHOLD )
	{
		discard;
		return;
	}
#endif

#if !defined( STUDIO_FULLBRIGHT ) && defined( STUDIO_HAS_BUMP )
	vec3 N = normalmap2D( u_NormalMap, var_TexDiffuse );
#endif

#if !defined( STUDIO_FULLBRIGHT ) && ( defined( STUDIO_HAS_GLOSS ) || defined( STUDIO_HAS_BUMP ) || defined( STUDIO_LIGHTVEC_DEBUG ))
	vec3 L = normalize( var_LightDir );
#endif

#if !defined( STUDIO_FULLBRIGHT ) && defined( STUDIO_HAS_GLOSS )
	vec3 V = normalize( var_ViewDir );
#endif
	vec3 light = vec3( 1.0 );

#ifndef STUDIO_FULLBRIGHT
#ifdef STUDIO_HAS_BUMP
#ifdef STUDIO_LIGHTVEC_DEBUG
	light = ( normalize( N + L ) + 1.0 ) * 0.5;
#else
	light = (( var_BaseLight * u_AmbientFactor ) + ( var_BaseLight * max( dot( N, L ), 0.0 ))); 
#endif
#else
#if defined( STUDIO_LIGHTVEC_DEBUG ) && !defined( STUDIO_LIGHT_FLATSHADE )
	light = ( L + 1.0 ) * 0.5;
#else
	light = var_BaseLight;
#endif
#endif

#ifdef STUDIO_HAS_GLOSS
	// compute the specular term
	vec4 glossmap = texture2D( u_GlossMap, var_TexDiffuse );
#ifdef STUDIO_GLOSSMAP_ROUGHNESS
	glossmap.a = RemapVal( glossmap.a, 0.0, 1.0, 256.0, 1.0 );
#else//STUDIO_GLOSSMAP_ROUGHNESS
	glossmap.a = u_GlossExponent;
#endif//STUDIO_GLOSSMAP_ROUGHNESS
#endif//STUDIO_HAS_GLOSS

#if defined( STUDIO_CUBEMAP_BPCEM ) || defined( STUDIO_CUBEMAP_SIMPLE )
	vec3 I = normalize( var_Position - u_ViewOrigin ); // in model space
	vec3 NW = normalize( var_Normal );
#if defined( STUDIO_CUBEMAP_SIMPLE )
	vec3 R = normalize( reflect( I, NW ));
	vec3 srcColor0 = textureCube( u_EnvMap0, R ).rgb;
	vec3 srcColor1 = textureCube( u_EnvMap1, R ).rgb;
#elif defined( STUDIO_CUBEMAP_BPCEM )
	vec3 R1 = bpcem( reflect( I, NW ), u_BoxMaxs[0], u_BoxMins[0], u_CubeOrigin[0], var_Position );
	vec3 R2 = bpcem( reflect( I, NW ), u_BoxMaxs[1], u_BoxMins[1], u_CubeOrigin[1], var_Position );
	vec3 srcColor0 = textureCube( u_EnvMap0, R1 ).rgb;
	vec3 srcColor1 = textureCube( u_EnvMap1, R2 ).rgb;
#endif
	float eta = fresnel( normalize( var_EyeDir ), NW, u_FresnelExponent, u_ReflectScale ); // fresnel

#ifdef STUDIO_HAS_GLOSS
	eta = saturate( eta * glossmap.r ); // reflection factor based on specular map
#endif
	vec3 envColor0 = mix( light, srcColor0, eta );
	vec3 envColor1 = mix( light, srcColor1, eta );
	diffuse.rgb *= mix( envColor0, envColor1, u_LerpFactor );
#else//defined( STUDIO_CUBEMAP_BPCEM ) || defined( STUDIO_CUBEMAP_SIMPLE )
	diffuse.rgb *= light;
#endif//defined( STUDIO_CUBEMAP_BPCEM ) || defined( STUDIO_CUBEMAP_SIMPLE )

#ifdef STUDIO_HAS_GLOSS
	vec3 specular = glossmap.rgb;
#if defined( STUDIO_SIMPLE_GLOSS ) || !defined( STUDIO_HAS_BUMP )
	// inverse lightdir because we don't have a normalmap
	L.x = -L.x, L.y = -L.y;
	specular *= var_BaseLight * pow( max( dot( V, L ), 0.0 ), glossmap.a );
#elif defined( STUDIO_BLINN_GLOSS )
	// compute half angle in tangent space (Doom3 style gloss)
	vec3 H = normalize( L + V );
	specular *= var_BaseLight * pow( max( dot( N, H ), 0.0 ), glossmap.a );
#elif defined( STUDIO_PHONG_GLOSS )
	specular *= var_BaseLight * pow( max( dot( reflect( -L, N ), V ), 0.0 ), glossmap.a );
#endif
	diffuse.rgb += specular * GLOSS_SCALE;
#endif// STUDIO_HAS_GLOSS

#if defined( STUDIO_LIGHTMAP_DEBUG ) || defined( STUDIO_LIGHTVEC_DEBUG )
	diffuse.rgb = light;
#endif

#ifdef STUDIO_HAS_LUMA
	diffuse.rgb += texture2D( u_GlowMap, var_TexDiffuse ).rgb;
#endif//STUDIO_HAS_LUMA
#endif//STUDIO_FULLBRIGHT

#ifdef STUDIO_FOG_EXP
	float fogFactor = saturate( exp2( -gl_Fog.density * ( gl_FragCoord.z / gl_FragCoord.w )));
	diffuse.rgb = mix( gl_Fog.color.rgb, diffuse.rgb, fogFactor );
#endif
	// compute final color
	gl_FragColor = vec4( diffuse.rgb, 1.0 );
}