/*
BmodelDlight_fp.glsl - fragment uber shader for all dlight types for bmodel surfaces
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

uniform sampler2D		u_ProjectMap;
#define u_AttnXYMap		u_ProjectMap	// just for consistency
uniform sampler1D		u_AttnZMap;
uniform sampler2D		u_ColorMap;
uniform sampler2D		u_DetailMap;
uniform sampler2D		u_NormalMap;
uniform sampler2D		u_GlossMap;

#ifdef BMODEL_HAS_SHADOWS
#ifdef DLIGHT_PROJECTION
#include "shadow_proj.h"
#elif defined( DLIGHT_OMNI )
#include "shadow_omni.h"
#endif
#endif

uniform vec3		u_LightDiffuse;
uniform vec2		u_ScreenSizeInv;
uniform float		u_RefractScale;
uniform float		u_GlossExponent;
uniform mat4		u_LightModelViewMatrix;
uniform mat4		u_LightProjectionMatrix;

varying vec2		var_TexDiffuse;
varying vec3		var_AttnXYZCoord;

#ifdef BMODEL_HAS_DETAIL
varying vec2		var_TexDetail;
#endif

#ifdef DLIGHT_PROJECTION
varying vec4		var_ProjCoord;
#endif

#ifdef BMODEL_HAS_GLOSSMAP
varying vec3		var_ViewDir;
#endif

#if defined( BMODEL_HAS_NORMALMAP ) || defined( BMODEL_HAS_GLOSSMAP )
varying vec3		var_LightDir;
#endif

varying float		var_LightCos;

#ifdef BMODEL_MIRROR
varying vec4		var_TexMirror;	// mirror coords
#endif

#ifdef BMODEL_HAS_SHADOWS
varying vec4		var_ShadowCoord;
#endif

void main( void )
{
	vec4 diffuse;

#ifdef BMODEL_MIRROR
	vec4 projCoord = var_TexMirror;
#ifdef BMODEL_HAS_NORMALMAP
	vec3 N = normalmap2D( u_NormalMap, var_TexDiffuse );
	projCoord.x += N.x * u_RefractScale;
	projCoord.y -= N.y * u_RefractScale;
	projCoord.z += N.z * u_RefractScale;
#endif//BMODEL_HAS_NORMALMAP
	diffuse = texture2DProj( u_ColorMap, projCoord );
#else//BMODEL_MIRROR
	// compute the diffuse term
	diffuse = texture2D( u_ColorMap, var_TexDiffuse );

#ifdef BMODEL_ALPHATEST
	if( diffuse.a <= BMODEL_ALPHA_THRESHOLD )
	{
		discard;
		return;
	}
#endif//BMODEL_ALPHATEST
#endif//BMODEL_MIRROR

#ifdef BMODEL_HAS_DETAIL
	vec4 detail = texture2D( u_DetailMap, var_TexDetail );
	diffuse.rgb *= texture2D( u_DetailMap, var_TexDetail ).rgb * DETAIL_SCALE;
#endif//BMODEL_HAS_DETAIL

	vec3 light = vec3( 1.0 );
	vec3 gloss = vec3( 0.0 );

#ifndef BMODEL_FULLBRIGHT
#ifdef DLIGHT_PROJECTION
	// compute light projection
	light = texture2DProj( u_ProjectMap, var_ProjCoord ).rgb * u_LightDiffuse;

	// linear attenuation texture
	light *= texture1D( u_AttnZMap, var_AttnXYZCoord.z ).r;

#if defined( BMODEL_HAS_NORMALMAP ) || defined( BMODEL_HAS_GLOSSMAP )
	vec3 L = normalize( var_LightDir );
#if defined( BMODEL_HAS_NORMALMAP )
	vec3 N = normalmap2D( u_NormalMap, var_TexDiffuse );
#endif
#endif

#if defined BMODEL_HAS_NORMALMAP && !defined( BMODEL_MIRROR )
	light *= max( dot( N, L ), 0.0 );
#else
	light *= max( var_LightCos, 0.0 );
#endif

#ifdef BMODEL_HAS_SHADOWS
	light *= ShadowProj( var_ShadowCoord, u_ScreenSizeInv );
#endif

#if defined( BMODEL_HAS_GLOSSMAP ) && !defined( BMODEL_MIRROR )
	vec3 V = normalize( var_ViewDir );
	vec4 glossmap = texture2D( u_GlossMap, var_TexDiffuse );
#ifdef BMODEL_GLOSSMAP_ROUGHNESS
	glossmap.a = RemapVal( glossmap.a, 0.0, 1.0, 256.0, 1.0 );
#else//BMODEL_GLOSSMAP_ROUGHNESS
	glossmap.a = u_GlossExponent;
#endif//BMODEL_GLOSSMAP_ROUGHNESS

#if defined( BMODEL_SIMPLE_GLOSS ) || !defined( BMODEL_HAS_NORMALMAP )
	// inverse lightdir because we don't have a normalmap
	L.x = -L.x, L.y = -L.y;
	glossmap.rgb *= light * pow( max( dot( V, L ), 0.0 ), glossmap.a );
#elif defined( BMODEL_BLINN_GLOSS )
	// compute half angle in tangent space (Doom3 style gloss)
	vec3 H = normalize( L + V );
	glossmap.rgb *= light * pow( max( dot( N, H ), 0.0 ), glossmap.a );
#elif defined( BMODEL_PHONG_GLOSS )
	glossmap.rgb *= light * pow( max( dot( reflect( -L, N ), V ), 0.0 ), glossmap.a );
#endif
	gloss += glossmap.rgb;
#endif// BMODEL_HAS_GLOSSMAP

#elif defined( DLIGHT_OMNI )
	light = u_LightDiffuse;

	// attenuation XY (original code using GL_ONE_MINUS_SRC_ALPHA)
	float attnXY = texture2D( u_AttnXYMap, var_AttnXYZCoord.xy ).a;
	// attenuation Z (original code using GL_ONE_MINUS_SRC_ALPHA)
	float attnZ = texture1D( u_AttnZMap, var_AttnXYZCoord.z ).a;
	// apply attenuation
	light *= ( 1.0 - ( attnXY + attnZ ));

#if defined( BMODEL_HAS_NORMALMAP ) || defined( BMODEL_HAS_GLOSSMAP )
	vec3 L = normalize( var_LightDir );
#if defined( BMODEL_HAS_NORMALMAP )
	vec3 N = normalmap2D( u_NormalMap, var_TexDiffuse );
#endif
#endif

#if defined( BMODEL_HAS_NORMALMAP ) && !defined( BMODEL_MIRROR )
	light *= max( dot( N, L ), 0.0 );
#else
	light *= max( var_LightCos, 0.0 );
#endif

#ifdef BMODEL_HAS_SHADOWS
	light *= ShadowOmni( u_LightProjectionMatrix, (u_LightModelViewMatrix * var_ShadowCoord).xyz, u_ScreenSizeInv );
#endif

#if defined( BMODEL_HAS_GLOSSMAP ) && !defined( BMODEL_MIRROR )
	vec3 V = normalize( var_ViewDir );
	vec4 glossmap = texture2D( u_GlossMap, var_TexDiffuse );
#ifdef BMODEL_GLOSSMAP_ROUGHNESS
	glossmap.a = RemapVal( glossmap.a, 0.0, 1.0, 256.0, 1.0 );
#else//BMODEL_GLOSSMAP_ROUGHNESS
	glossmap.a = u_GlossExponent;
#endif//BMODEL_GLOSSMAP_ROUGHNESS

#if defined( BMODEL_SIMPLE_GLOSS ) || !defined( BMODEL_HAS_NORMALMAP )
	// inverse lightdir because we don't have a normalmap
	L.x = -L.x, L.y = -L.y;
	glossmap.rgb *= light * pow( max( dot( V, L ), 0.0 ), glossmap.a );
#elif defined( BMODEL_BLINN_GLOSS )
	// compute half angle in tangent space (Doom3 style gloss)
	vec3 H = normalize( L + V );
	glossmap.rgb *= light * pow( max( dot( N, H ), 0.0 ), glossmap.a );
#elif defined( BMODEL_PHONG_GLOSS )
	glossmap.rgb *= light * pow( max( dot( reflect( -L, N ), V ), 0.0 ), glossmap.a );
#endif
	gloss += glossmap.rgb;
#endif// BMODEL_HAS_GLOSSMAP

#endif
#endif
	diffuse.rgb *= light.rgb * DLIGHT_SCALE;
	diffuse.rgb += gloss;

	// compute final color
	gl_FragColor = diffuse;
}