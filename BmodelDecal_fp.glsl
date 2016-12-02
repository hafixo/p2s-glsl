/*
BmodelDecal_fp.glsl - fragment uber shader for bmodel decals
Copyright (C) 2015 Uncle Mike

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

uniform sampler2D		u_DecalMap;
uniform sampler2D		u_ColorMap;	// surface under decal
uniform sampler2D		u_GlossMap;
uniform sampler2D		u_DepthMap;
uniform sampler2D		u_NormalMap;	// refraction

uniform float		u_GlossExponent;
uniform float		u_FresnelExponent;
uniform vec2		u_ParallaxScale;	// may be used to reimplement POM
uniform int		u_ParallaxSteps;	// may be used to reimplement POM
uniform float		u_RefractScale;
uniform float		u_ReflectScale;
uniform float		u_RealTime;
uniform vec3		u_LightDir;	// already in tangent space

varying vec3		var_ViewDir;

#ifdef DECAL_REFLECTION
varying vec4		var_TexMirror;	// mirror coords
#endif

void main( void )
{
#ifdef DECAL_ALPHATEST
	if( texture2D( u_ColorMap, gl_TexCoord[1].xy ).a <= BMODEL_ALPHA_THRESHOLD )
	{
		discard;
		return;
	}
#endif
	float alphaValue;

#ifdef DECAL_PARALLAX_SIMPLE
	float offset = texture2D( u_DepthMap, gl_TexCoord[0].xy ).r * 0.04 - 0.02;
	vec2 var_TexDiffuse = ( offset * normalize( var_ViewDir ).xy + gl_TexCoord[0].xy );
#else
	vec2 var_TexDiffuse = gl_TexCoord[0].xy;
#endif
	vec4 diffuse = texture2D( u_DecalMap, var_TexDiffuse );

	// NOTE: this texture never exceeds 0.5 or alpha will stop working
	float alpha = (( diffuse.r * 2.0 ) + ( diffuse.g * 2.0 ) + ( diffuse.b * 2.0 )) / 3.0;

	if( alpha >= 0.5 ) alphaValue = 0.0;
	else alphaValue = (0.5 - alpha);

#ifdef DECAL_PUDDLE
	diffuse = vec4( 0.19, 0.16, 0.11, 1.0 ); // replace with puddle color
#endif

#ifdef DECAL_HAS_NORMALMAP
#ifdef DECAL_PUDDLE
	vec2 tc_Normal0 = var_TexDiffuse * 0.1;
	tc_Normal0.s += u_RealTime * 0.005;
	tc_Normal0.t -= u_RealTime * 0.005;

	vec2 tc_Normal1 = var_TexDiffuse * 0.1;
	tc_Normal1.s -= u_RealTime * 0.005;
	tc_Normal1.t += u_RealTime * 0.005;

	vec3 N0 = normalmap2D( u_NormalMap, tc_Normal0 );
	vec3 N1 = normalmap2D( u_NormalMap, tc_Normal1 );
	vec3 N = normalize( N0 + N1 );
#else
	vec3 N = normalmap2D( u_NormalMap, var_TexDiffuse );
#endif
#endif

#if defined( DECAL_HAS_GLOSSMAP ) || defined( DECAL_REFRACTION )
	// compute light and view vectors
	vec3 L = normalize( u_LightDir );
	vec3 V = normalize( var_ViewDir );
#endif

#ifdef DECAL_REFLECTION
	vec4 projCoord = var_TexMirror;

#ifdef DECAL_REFRACTION
	projCoord.x += N.x * u_RefractScale * 2.0;
	projCoord.y -= N.y * u_RefractScale * 2.0;
	projCoord.z += N.z * u_RefractScale * 2.0;
#endif
	vec3 mirror = texture2DProj( u_DepthMap, projCoord ).rgb * BUMP_SCALE;
	float eta = fresnel( V, vec3( 0.0, 0.0, 1.0 ), u_FresnelExponent, u_ReflectScale );
	diffuse.rgb = mix( diffuse.rgb, mirror, eta );
#endif

#ifdef DECAL_HAS_GLOSSMAP
	// compute the specular term
	vec4 specular = texture2D( u_GlossMap, var_TexDiffuse );
#ifdef DECAL_GLOSSMAP_ROUGHNESS
	specular.a = RemapVal( specular.a, 0.0, 1.0, 256.0, 1.0 );
#else//DECAL_GLOSSMAP_ROUGHNESS
	specular.a = u_GlossExponent;
#endif//DECAL_GLOSSMAP_ROUGHNESS

#if defined( DECAL_SIMPLE_GLOSS ) || !defined( DECAL_HAS_NORMALMAP )
	// inverse lightdir because we don't have a normalmap
	L.x = -L.x, L.y = -L.y;
	specular.rgb *= pow( max( dot( V, L ), 0.0 ), specular.a );
#elif defined( DECAL_BLINN_GLOSS )
	// compute half angle in tangent space (Doom3 style gloss)
	vec3 H = normalize( L + V );
	specular.rgb *= pow( max( dot( N, H ), 0.0 ), specular.a );
#elif defined( DECAL_PHONG_GLOSS )
	specular.rgb *= pow( max( dot( reflect( -L, N ), V ), 0.0 ), specular.a );
#endif
	diffuse.rgb += specular.rgb * alphaValue;
#endif

#ifdef DECAL_PUDDLE
	diffuse.rgb = mix( diffuse.rgb, vec3( 0.5, 0.5, 0.5 ), alpha );
#endif
	
#ifdef DECAL_FOG_EXP
	float fogFactor = clamp( exp2( -gl_Fog.density * ( gl_FragCoord.z / gl_FragCoord.w )), 0.0, 1.0 );
	diffuse.rgb = mix( vec3( 0.5, 0.5, 0.5 ), diffuse.rgb, fogFactor ); // mixing to base
#endif
	gl_FragColor = diffuse;
}