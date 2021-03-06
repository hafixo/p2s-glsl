/*
StudioPlight_fp.glsl - fragment uber shader for sun light for studio meshes
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

uniform sampler2DShadow	u_ShadowMap0;
uniform sampler2DShadow	u_ShadowMap1;
uniform sampler2DShadow	u_ShadowMap2;
uniform sampler2DShadow	u_ShadowMap3;

uniform sampler2D		u_ColorMap;
uniform sampler2D		u_NormalMap;
uniform sampler2D		u_GlossMap;

uniform vec3		u_LightDiffuse;
uniform float		u_RefractScale;
uniform float		u_AmbientFactor;
uniform float		u_GlossExponent;
uniform float		u_TexelSize;	// shadowmap resolution
uniform mat4		u_ViewMatrix;
uniform mat4		u_ShadowMatrix[MAX_SHADOWMAPS];
uniform vec4		u_ShadowSplitDist;

varying vec2		var_TexDiffuse;

#ifdef STUDIO_HAS_GLOSS
varying vec3		var_ViewDir;
#endif

#if defined( STUDIO_HAS_BUMP ) || defined( STUDIO_HAS_GLOSS )
varying vec3		var_LightDir;
#endif

#ifdef STUDIO_HAS_SHADOWS
varying vec3		var_Position;
#endif

varying float		var_LightCos;

#ifdef STUDIO_HAS_SHADOWS
#include "shadow_sun.h"
#endif

void main( void )
{
	// compute the diffuse term
	vec4 diffuse = texture2D( u_ColorMap, var_TexDiffuse );

#ifdef STUDIO_ALPHATEST
	if( diffuse.a <= STUDIO_ALPHA_THRESHOLD )
	{
		discard;
		return;
	}
#endif//STUDIO_ALPHATEST

	vec3 light = u_LightDiffuse;
	vec3 gloss = vec3( 0.0 );

#if defined( STUDIO_HAS_BUMP ) || defined( STUDIO_HAS_GLOSS )
	vec3 L = normalize( var_LightDir );
#if defined( STUDIO_HAS_BUMP )
	vec3 N = normalmap2D( u_NormalMap, var_TexDiffuse );
#endif
#endif

#if defined STUDIO_HAS_BUMP
	light *= max( dot( N, L ), 0.0 );
#else
	light *= RemapVal( var_LightCos, -1.0, 1.0, 0.0, 1.0 );// fast ugly approximation of subsurface scattering
#endif

#ifdef STUDIO_HAS_SHADOWS
	float shadow = ComputeShadowParallel( var_Position, var_LightCos );
	light *= mix( shadow, 0.0, u_RefractScale );
#endif

#if defined( STUDIO_HAS_GLOSS )
	vec3 V = normalize( var_ViewDir );
	vec4 glossmap = texture2D( u_GlossMap, var_TexDiffuse );
#ifdef STUDIO_GLOSSMAP_ROUGHNESS
	glossmap.a = RemapVal( glossmap.a, 0.0, 1.0, 256.0, 1.0 );
#else//STUDIO_GLOSSMAP_ROUGHNESS
	glossmap.a = u_GlossExponent;
#endif//STUDIO_GLOSSMAP_ROUGHNESS

#if defined( STUDIO_SIMPLE_GLOSS ) || !defined( STUDIO_HAS_BUMP )
	// inverse lightdir because we don't have a normalmap
	L.x = -L.x, L.y = -L.y;
	glossmap.rgb *= light * pow( max( dot( V, L ), 0.0 ), glossmap.a );
#elif defined( STUDIO_BLINN_GLOSS )
	// compute half angle in tangent space (Doom3 style gloss)
	vec3 H = normalize( L + V );
	glossmap.rgb *= light * pow( max( dot( N, H ), 0.0 ), glossmap.a );
#elif defined( STUDIO_PHONG_GLOSS )
	glossmap.rgb *= light * pow( max( dot( reflect( -L, N ), V ), 0.0 ), glossmap.a );
#endif
	gloss += glossmap.rgb;
#endif// STUDIO_HAS_GLOSSMAP

#ifdef STUDIO_ALPHA_GLASS
	diffuse.rgb = ((diffuse.rgb * u_AmbientFactor) + (diffuse.rgb * light)) * diffuse.a;
#else
	diffuse.rgb = ((diffuse.rgb * u_AmbientFactor) + (diffuse.rgb * light) * SUN_SCALE);
#endif
	diffuse.rgb += gloss;

	// compute final color
	gl_FragColor = diffuse;
}