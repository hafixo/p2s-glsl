/*
BmodelTrans_fp.glsl - fragment uber shader for all trans bmodel surfaces
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

uniform sampler2D		u_ColorMap;
uniform sampler2D		u_NormalMap;
uniform sampler2D		u_DetailMap;
uniform sampler2D		u_GlossMap;
uniform sampler2D		u_LightMap;
uniform sampler2D		u_DeluxeMap;
uniform sampler2D		u_DepthMap;	// screen copy
uniform samplerCube		u_EnvMap;

uniform vec4		u_RenderColor;
uniform vec3		u_ViewOrigin;
uniform vec2		u_ScreenSizeInv;
uniform float		u_AmbientFactor;
uniform float		u_GlossExponent;
uniform float		u_FresnelExponent;
uniform float		u_AberrationScale;
uniform float		u_RefractScale;
uniform float		u_ReflectScale;
uniform float		u_LightStyleValues[MAX_LIGHTSTYLES];
uniform vec3		u_BoxMins;
uniform vec3		u_BoxMaxs;
uniform vec3		u_CubeOrigin;

varying vec2		var_TexDiffuse;

#if !defined( BMODEL_NOLIGHTMAP ) && ( defined (BMODEL_ALPHA_GLASS) || defined( BMODEL_HAS_GLOSSMAP ))
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

#if defined( BMODEL_HAS_GLOSSMAP ) || defined( BMODEL_WATER )
varying vec3		var_ViewDir;
#endif

#if defined( BMODEL_CUBEMAP_BPCEM ) || defined( BMODEL_CUBEMAP_SIMPLE )
// NOTE: these variables in model-space
varying vec3		var_Position;
varying vec3		var_Normal;
varying vec3		var_EyeDir;
#endif

#ifdef BMODEL_WATER
varying vec4		var_TexMirror;	// mirror coords
#endif

void main( void )
{
	vec4 diffuse = vec4( 0.0 );
	vec3 gloss = vec3( 0.0 );
	float diffuseAlpha = 1.0;

	// compute diffuse term
#ifndef BMODEL_WATER
#ifdef BMODEL_TRANS_COLOR
	diffuse.rgb = u_RenderColor.rgb;				// kRenderTransColor
#else
	diffuse = texture2D( u_ColorMap, var_TexDiffuse );	// kRenderTransTexture, kRenderTransAdd
#ifdef BMODEL_ALPHA_GLASS
	diffuseAlpha = diffuse.a;
#endif
#endif
	diffuse.a = RemapVal( u_RenderColor.a, 0.0, 1.0, 0.5, 1.0 );
#endif
	vec3 screenmap = vec3( 1.0 );

	// compute material normal
#if defined( BMODEL_HAS_NORMALMAP ) && ( defined( BMODEL_REFRACTION ) || defined( BMODEL_ABERRATION ) || defined( BMODEL_ALPHA_GLASS ) || defined( BMODEL_HAS_GLOSSMAP ) || defined( BMODEL_WATER ))
	vec3 N = normalmap2D( u_NormalMap, var_TexDiffuse );
#endif

// compute screen space lighting for transparent objects
#if defined( BMODEL_TRANS_TEXTURE ) || defined( BMODEL_WATER )
	vec2 screenCoord = gl_FragCoord.xy * u_ScreenSizeInv;

#if defined( BMODEL_HAS_NORMALMAP ) && ( defined( BMODEL_REFRACTION ) || defined( BMODEL_ABERRATION ))

#ifdef BMODEL_REFRACTION
	screenCoord.x -= N.x * u_RefractScale * screenCoord.x;
	screenCoord.y -= N.y * u_RefractScale * screenCoord.y;
	screenCoord.x = clamp( screenCoord.x, 0.01, 0.99 );
	screenCoord.y = clamp( screenCoord.y, 0.01, 0.99 );
#endif

#ifdef BMODEL_ABERRATION
	vec2 screenCoord2;

	screenCoord2 = screenCoord;
	screenCoord2.x -= N.x * u_AberrationScale * screenCoord2.x;
	screenCoord2.y -= N.x * u_AberrationScale * screenCoord2.y;
	screenCoord.x = clamp( screenCoord.x, 0.01, 0.99 );
	screenCoord.y = clamp( screenCoord.y, 0.01, 0.99 );
	screenmap.r = texture2D( u_DepthMap, screenCoord2 ).r;

	screenCoord2 = screenCoord;
	screenCoord2.x -= N.y * u_AberrationScale * screenCoord2.x;
	screenCoord2.y -= N.y * u_AberrationScale * screenCoord2.y;
	screenCoord.x = clamp( screenCoord.x, 0.01, 0.99 );
	screenCoord.y = clamp( screenCoord.y, 0.01, 0.99 );
	screenmap.g = texture2D( u_DepthMap, screenCoord2 ).g;

	screenCoord2 = screenCoord;
	screenCoord2.x -= N.z * u_AberrationScale * screenCoord2.x;
	screenCoord2.y -= N.z * u_AberrationScale * screenCoord2.y;
	screenCoord.x = clamp( screenCoord.x, 0.01, 0.99 );
	screenCoord.y = clamp( screenCoord.y, 0.01, 0.99 );
	screenmap.b = texture2D( u_DepthMap, screenCoord2 ).b;
#else
	screenmap = texture2D( u_DepthMap, screenCoord ).xyz;
#endif

#else
	screenmap = texture2D( u_DepthMap, screenCoord ).xyz;
#endif
#endif

#if defined( BMODEL_WATER ) || ( defined( BMODEL_HAS_GLOSSMAP ) && defined( BMODEL_HAS_DELUXEMAP ))
	vec3 srcV = var_ViewDir; // not normalized
	vec3 V = normalize( srcV );
#endif

#if defined( BMODEL_HAS_GLOSSMAP ) && defined( BMODEL_HAS_DELUXEMAP )
	// compute the specular term
	vec4 glossmap = texture2D( u_GlossMap, var_TexDiffuse );
#ifdef BMODEL_GLOSSMAP_ROUGHNESS
	glossmap.a = RemapVal( glossmap.a, 0.0, 1.0, 256.0, 1.0 );
#else//BMODEL_GLOSSMAP_ROUGHNESS
	glossmap.a = u_GlossExponent;
#endif//BMODEL_GLOSSMAP_ROUGHNESS
#endif//(BMODEL_HAS_GLOSSMAP && BMODEL_HAS_DELUXEMAP)

#ifdef BMODEL_WATER
#if defined( BMODEL_HAS_NORMALMAP ) && defined( BMODEL_REFLECTION )
	vec4 projCoord = var_TexMirror;
#if defined( BMODEL_HAS_NORMALMAP ) && defined( BMODEL_REFRACTION )
	projCoord.x += N.x * u_RefractScale * 100.0;
	projCoord.y -= N.y * u_RefractScale * 100.0;
	projCoord.z += N.z * u_RefractScale * 100.0;
#endif
	vec3 mirror = texture2DProj( u_ColorMap, projCoord ).rgb;
	float eta = fresnel( V, N, u_FresnelExponent, u_ReflectScale );
	diffuse.rgb = mix( screenmap, mirror, eta );
#else
	diffuse.rgb = screenmap;
#endif
	diffuse.rgb *= u_RenderColor.rgb; // apply custom color
#elif defined( BMODEL_CUBEMAP_BPCEM ) || defined( BMODEL_CUBEMAP_SIMPLE )
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
	screenmap = mix( screenmap, refcolor, eta );
#endif

#ifdef BMODEL_HAS_DETAIL
	vec4 detail = texture2D( u_DetailMap, var_TexDetail );
	diffuse.rgb *= texture2D( u_DetailMap, var_TexDetail ).rgb * DETAIL_SCALE;
#endif//BMODEL_HAS_DETAIL
	vec3 light = vec3( 0.0 );

#if !defined( BMODEL_NOLIGHTMAP ) && ( defined (BMODEL_ALPHA_GLASS) || defined( BMODEL_HAS_GLOSSMAP ))
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
		vec3 baselight = texture2D( u_LightMap, var_TexLight[map] ).rgb;

#if defined ( BMODEL_HAS_DELUXEMAP ) && (defined( BMODEL_ALPHA_GLASS ) || defined( BMODEL_HAS_GLOSSMAP ))
		vec3 srcL = normalize( 2.0 * ( texture2D( u_DeluxeMap, var_TexLight[map] ).xyz - 0.5 ));
		vec3 L = normalize( srcL );
#endif

#if defined( BMODEL_HAS_DELUXEMAP ) && defined( BMODEL_HAS_NORMALMAP )
		float factor = RemapVal( dot( N, L ), -abs( u_AmbientFactor ), 1.0, 0.0, 1.0 );
		light += baselight * factor * scale * BUMP_SCALE;
#else//(BMODEL_HAS_DELUXEMAP && BMODEL_HAS_NORMALMAP)
		light += baselight * scale;
#endif//BMODEL_HAS_DELUXEMAP

#if defined( BMODEL_HAS_GLOSSMAP ) && defined( BMODEL_HAS_DELUXEMAP )
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
#endif//(BMODEL_HAS_GLOSSMAP && BMODEL_HAS_DELUXEMAP)

	// convert values back to normal range and clamp it
	light = min(( light * LIGHTMAP_SHIFT ), 1.0 );
	gloss = min(( gloss * GLOSSMAP_SHIFT ), 1.0 );

#if ( defined( BMODEL_TRANS_TEXTURE ) || defined( BMODEL_TRANS_COLOR )) && !defined( BMODEL_WATER )
#ifdef BMODEL_ALPHA_GLASS
	// combine solid texture with window
	diffuse.rgb = mix(( diffuse.rgb * screenmap * GLASS_SCALE ), ( diffuse.rgb * light ), diffuseAlpha );
#else
	// normal glass texture
	diffuse.rgb = mix( screenmap, diffuse.rgb, diffuse.a );
	diffuse.rgb *= screenmap * GLASS_SCALE;
#endif
#endif
	diffuse.rgb += gloss;

#ifdef BMODEL_FOG_EXP
	float fogFactor = saturate( exp2( -gl_Fog.density * ( gl_FragCoord.z / gl_FragCoord.w )));
	diffuse.rgb = mix( gl_Fog.color.rgb, diffuse.rgb, fogFactor );
#endif//BMODEL_FOG_EXP

	gl_FragColor = diffuse;
}