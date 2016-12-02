/*
BmodelSolid_fp.glsl - fragment uber shader for all solid bmodel surfaces
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

// texture units
uniform sampler2D		u_ColorMap;
uniform sampler2D		u_LightMap;
uniform sampler2D		u_DeluxeMap;
uniform sampler2D		u_DetailMap;
uniform sampler2D		u_NormalMap;
uniform sampler2D		u_GlossMap;
uniform sampler2D		u_GlowMap;
uniform samplerCube		u_EnvMap;

// uniforms
uniform vec3		u_ViewOrigin;
uniform float		u_ReflectScale;
uniform float		u_RefractScale;
uniform float		u_GlossExponent;
uniform float		u_AmbientFactor;
uniform float		u_FresnelExponent;
uniform float		u_LightStyleValues[MAX_LIGHTSTYLES];
uniform vec3		u_BoxMins;
uniform vec3		u_BoxMaxs;
uniform vec3		u_CubeOrigin;
uniform float		u_LerpFactor;

// shared variables
varying vec2		var_TexDiffuse;

#if !defined( BMODEL_NOLIGHTMAP ) && !defined( BMODEL_FULLBRIGHT )
varying vec2		var_TexLight[MAXLIGHTMAPS];

#if defined( allow_gpu_shader4 )
flat varying int		var_LightStyles[MAXLIGHTMAPS];
#else
varying float		var_LightStyles[MAXLIGHTMAPS];
#endif

#endif

#ifdef BMODEL_HAS_DETAIL
varying vec2		var_TexDetail;
#endif

#if defined( BMODEL_HAS_GLOSSMAP ) || defined( BMODEL_MIRROR )
varying vec3		var_ViewDir;
#endif

#if defined( BMODEL_CUBEMAP_BPCEM ) || defined( BMODEL_CUBEMAP_SIMPLE )
// NOTE: these variables in model-space
varying vec3		var_Position;
varying vec3		var_EyeDir;
varying vec3		var_Normal;
#endif

#ifdef BMODEL_MIRROR
varying vec4		var_TexMirror;	// mirror coords
#endif

void main( void )
{
	vec3 light = vec3( 0.0 );
	vec3 gloss = vec3( 0.0 );
	vec4 diffuse;

#ifdef BMODEL_MIRROR
	vec4 projCoord = var_TexMirror;
#ifdef BMODEL_HAS_NORMALMAP
	vec3 N = normalmap2D( u_NormalMap, var_TexDiffuse );
	projCoord.x += N.x * u_RefractScale * 2.0;
	projCoord.y -= N.y * u_RefractScale * 2.0;
	projCoord.z += N.z * u_RefractScale * 2.0;
#endif//BMODEL_HAS_NORMALMAP
	diffuse = texture2DProj( u_ColorMap, projCoord );
#else//BMODEL_MIRROR
	// compute the diffuse term
	diffuse = texture2D( u_ColorMap, var_TexDiffuse );

#ifdef BMODEL_ALPHATEST
	// Valve "alpha-tested magnification"
	diffuse.a *= smoothstep( BMODEL_ALPHA_THRESHOLD, 1.0, diffuse.a ); 

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

#ifdef BMODEL_FULLBRIGHT
	// just do nothing
#elif defined( BMODEL_NOLIGHTMAP )
	diffuse.rgb = vec3( 0.0 ); // this face doesn't have lightmap
#else//do lightmapping
	vec3 L = vec3( 0.0 );
	vec3 srcL = vec3( 0.0 );
	vec3 N = vec3( 0.0 ); // stub
	vec4 glossmap = vec4( 0.0 );
	vec3 V = vec3( 0.0 );

#if defined( BMODEL_HAS_DELUXEMAP ) && defined( BMODEL_HAS_NORMALMAP )
	// compute material normal
	N = normalmap2D( u_NormalMap, var_TexDiffuse );
#endif//(BMODEL_HAS_DELUXEMAP && BMODEL_HAS_NORMALMAP)

#if defined( BMODEL_HAS_GLOSSMAP ) && defined( BMODEL_HAS_DELUXEMAP )
	vec3 srcV = var_ViewDir; // not normalized
	V = normalize( srcV );
#endif

#if defined( BMODEL_HAS_GLOSSMAP ) && defined( BMODEL_HAS_DELUXEMAP )
	// compute the specular term
	glossmap = texture2D( u_GlossMap, var_TexDiffuse );
#ifdef BMODEL_GLOSSMAP_ROUGHNESS
	glossmap.a = RemapVal( glossmap.a, 0.0, 1.0, 256.0, 1.0 );
#else//BMODEL_GLOSSMAP_ROUGHNESS
	glossmap.a = u_GlossExponent;
#endif//BMODEL_GLOSSMAP_ROUGHNESS
#endif//(BMODEL_HAS_GLOSSMAP && BMODEL_HAS_DELUXEMAP)

#if defined( BMODEL_CUBEMAP_BPCEM ) || defined( BMODEL_CUBEMAP_SIMPLE )
	vec3 I = normalize( var_Position - u_ViewOrigin ); // in model space
	vec3 NW = normalize( var_Normal );
#if defined( BMODEL_CUBEMAP_SIMPLE )
	vec3 R = normalize( reflect( I, NW ));
#elif defined( BMODEL_CUBEMAP_BPCEM )
	vec3 R = bpcem( reflect( I, NW ), u_BoxMaxs, u_BoxMins, u_CubeOrigin, var_Position );
#endif
	vec3 refcolor = textureCube( u_EnvMap, R ).rgb;
	float eta = fresnel( normalize( var_EyeDir ), NW, u_FresnelExponent, u_ReflectScale ); // fresnel

#if defined( BMODEL_HAS_GLOSSMAP ) && defined( BMODEL_HAS_DELUXEMAP )
	eta = saturate( eta * glossmap.r ); // reflection factor based on specular map
#endif
	// add to final light some reflect color
	diffuse.rgb = mix( diffuse.rgb, refcolor, eta );
#endif

#ifdef BMODEL_ALLSTYLES

#if defined( allow_gpu_shader4 )
	for( int map = 0; map < MAXLIGHTMAPS && var_LightStyles[map] != 255; map++ ) // add all the styles
#else
	for( int map = 0; map < MAXLIGHTMAPS && var_LightStyles[map] != 255.0; map++ ) // add all the styles
#endif

#else//BMODEL_ALLSTYLES
	int map = 0; // single style
#endif//BMODEL_ALLSTYLES
	{

#if defined( allow_gpu_shader4 )
		float scale = u_LightStyleValues[var_LightStyles[map]];
#else
		float scale = u_LightStyleValues[int(var_LightStyles[map])];
#endif

#if defined( BMODEL_HAS_DELUXEMAP ) && ( defined( BMODEL_HAS_NORMALMAP ) || defined( BMODEL_HAS_GLOSSMAP ) || defined( BMODEL_DELUXEMAP_DEBUG ))
		// compute light vector
		srcL = ( 2.0 * ( texture2D( u_DeluxeMap, var_TexLight[map] ).xyz - 0.5 ));
		L = normalize( srcL );
#endif//(BMODEL_HAS_DELUXEMAP && ( BMODEL_HAS_NORMALMAP || BMODEL_HAS_GLOSSMAP ))

#ifdef BMODEL_DELUXEMAP_DEBUG
		light += ( N * ( 1.0 / MAXLIGHTMAPS ) + srcL ) * scale;
#else
		vec3 baselight = texture2D( u_LightMap, var_TexLight[map] ).rgb;

#if defined( BMODEL_HAS_DELUXEMAP ) && defined( BMODEL_HAS_NORMALMAP )
		float factor = RemapVal( dot( N, L ), -abs( u_AmbientFactor ), 1.0, 0.0, 1.0 );
		light += baselight * factor * scale * BUMP_SCALE;
#else//(BMODEL_HAS_DELUXEMAP && BMODEL_HAS_NORMALMAP)
		light += baselight * scale;
#endif//BMODEL_HAS_DELUXEMAP
#endif

#if defined( BMODEL_HAS_GLOSSMAP ) && defined( BMODEL_HAS_DELUXEMAP ) && !defined( BMODEL_DELUXEMAP_DEBUG )
		// compute the specular term
		vec3 specular = glossmap.rgb;

#if defined( BMODEL_SIMPLE_GLOSS ) || !defined( BMODEL_HAS_NORMALMAP )
		// inverse lightdir because we don't have a normalmap
		L.x = -L.x, L.y = -L.y;
		specular *= baselight * pow( max( dot( V, L ), 0.0 ), glossmap.a );
#elif defined( BMODEL_BLINN_GLOSS )
		// compute half angle in tangent space (Doom3 style gloss)
		vec3 H = normalize( srcV + srcL ); // g-cont. i'm keep both vectors not normalized especially
		specular *= baselight * pow( max( dot( N, H ), 0.0 ), glossmap.a );
#elif defined( BMODEL_PHONG_GLOSS )
		specular *= baselight * pow( max( dot( reflect( -L, N ), V ), 0.0 ), glossmap.a );
#endif
		gloss += specular * scale;
#endif//(BMODEL_HAS_GLOSSMAP && BMODEL_HAS_DELUXEMAP)
	}

	// convert values back to normal range and clamp it
	light = min(( light * LIGHTMAP_SHIFT ), 1.0 );
	gloss = min(( gloss * GLOSSMAP_SHIFT ), 1.0 );

#ifdef BMODEL_LIGHTMAP_DEBUG
	// apply lighting to surface
	diffuse.rgb = light;
#elif defined( BMODEL_DELUXEMAP_DEBUG )
	light = normalize( light );	// expand to range [-1..1]
	diffuse.rgb = ( light + 1.0 ) * 0.5; // convert range to [0..1]		
#else
	// apply lighting to surface
	diffuse.rgb *= light;
	diffuse.rgb += gloss;
#endif
#endif// BMODEL_FULLBRIGHT

#ifdef BMODEL_HAS_LUMA
	diffuse.rgb += texture2D( u_GlowMap, var_TexDiffuse ).rgb;
#endif//BMODEL_HAS_LUMA

#ifdef BMODEL_FOG_EXP
	float fogFactor = saturate( exp2( -gl_Fog.density * ( gl_FragCoord.z / gl_FragCoord.w )));
	diffuse.rgb = mix( gl_Fog.color.rgb, diffuse.rgb, fogFactor );
#endif//BMODEL_FOG_EXP

	gl_FragColor = vec4( diffuse.rgb, 1.0 );
}