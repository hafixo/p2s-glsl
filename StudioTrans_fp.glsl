/*
StudioTrans_fp.glsl - fragment uber shader for all trans studio meshes
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
uniform sampler2D		u_DepthMap;	// screen copy
uniform samplerCube		u_EnvMap;

uniform vec3		u_ViewOrigin;
uniform vec2		u_ScreenSizeInv;
uniform vec4		u_RenderColor;
uniform float		u_GlossExponent;
uniform float		u_FresnelExponent;
uniform float		u_AberrationScale;
uniform float		u_AmbientFactor;
uniform float		u_RefractScale;
uniform float		u_ReflectScale;
uniform vec3		u_CubeOrigin;
uniform vec3		u_BoxMins;
uniform vec3		u_BoxMaxs;

varying vec3		var_BaseLight;
varying vec2		var_TexDiffuse;

#if defined( STUDIO_CUBEMAP_BPCEM ) || defined( STUDIO_CUBEMAP_SIMPLE )
// NOTE: these variables in model-space
varying vec3		var_Position;
varying vec3		var_EyeDir;
varying vec3		var_Normal;
#endif

#if !defined( STUDIO_FULLBRIGHT ) && ( defined( STUDIO_HAS_BUMP ) || defined( STUDIO_HAS_GLOSS ) || defined( STUDIO_ALPHA_GLASS ))
varying vec3		var_LightDir;
#endif

#if !defined( STUDIO_FULLBRIGHT ) && defined( STUDIO_HAS_GLOSS )
varying vec3		var_ViewDir;
#endif

void main( void )
{
	vec4 diffuse = vec4( 0.0 );
	vec3 gloss = vec3( 0.0 );
	float diffuseAlpha = 1.0;

	// compute diffuse term
#ifdef STUDIO_TRANS_COLOR
	diffuse = u_RenderColor;
	diffuse.a = RemapVal( u_RenderColor.a, 0.0, 1.0, 0.5, 1.0 );
#else
	diffuse = texture2D( u_ColorMap, var_TexDiffuse );
#ifdef STUDIO_ALPHA_GLASS
	diffuseAlpha = diffuse.a;
#endif
#endif

#ifdef STUDIO_ADDITIVE_FIXED
	diffuse.a = 0.5;
#elif defined( STUDIO_ADDITIVE ) || defined( STUDIO_TRANS_TEXTURE )
	diffuse.a = RemapVal( u_RenderColor.a, 0.0, 1.0, 0.5, 1.0 );
#endif
	vec3 screenmap = vec3( 1.0 );

	// compute material normal
#if defined( STUDIO_HAS_BUMP ) && ( defined( STUDIO_REFRACTION ) || defined( STUDIO_ABERRATION ) || defined( STUDIO_ALPHA_GLASS ) || defined( STUDIO_HAS_GLOSS ))
	vec3 N = normalmap2D( u_NormalMap, var_TexDiffuse );
#endif

// compute screen space lighting for transparent objects
#if defined( STUDIO_TRANS_TEXTURE ) || defined( STUDIO_ALPHA_GLASS )
	vec2 screenCoord = gl_FragCoord.xy * u_ScreenSizeInv;

#if defined( STUDIO_HAS_BUMP ) && ( defined( STUDIO_REFRACTION ) || defined( STUDIO_ABERRATION ))

#ifdef STUDIO_REFRACTION
	screenCoord.x += N.x * u_RefractScale * screenCoord.x;
	screenCoord.y -= N.y * u_RefractScale * screenCoord.y;
#endif

#ifdef STUDIO_ABERRATION
	vec2 screenCoord2;

	screenCoord2 = screenCoord;
	screenCoord2.x += N.x * u_AberrationScale * screenCoord2.x;
	screenCoord2.y -= N.x * u_AberrationScale * screenCoord2.y;
	screenmap.r = texture2D( u_DepthMap, screenCoord2 ).r;

	screenCoord2 = screenCoord;
	screenCoord2.x += N.y * u_AberrationScale * screenCoord2.x;
	screenCoord2.y -= N.y * u_AberrationScale * screenCoord2.y;
	screenmap.g = texture2D( u_DepthMap, screenCoord2 ).g;

	screenCoord2 = screenCoord;
	screenCoord2.x += N.z * u_AberrationScale * screenCoord2.x;
	screenCoord2.y -= N.z * u_AberrationScale * screenCoord2.y;
	screenmap.b = texture2D( u_DepthMap, screenCoord2 ).b;
#else
	screenmap = texture2D( u_DepthMap, screenCoord ).xyz;
#endif

#else
	screenmap = texture2D( u_DepthMap, screenCoord ).xyz;
#endif
#endif

#if defined( STUDIO_HAS_GLOSS ) && defined( STUDIO_HAS_LIGHTDIR )
	// compute the specular term
	vec4 glossmap = texture2D( u_GlossMap, var_TexDiffuse );
#ifdef STUDIO_GLOSSMAP_ROUGHNESS
	glossmap.a = RemapVal( glossmap.a, 0.0, 1.0, 256.0, 1.0 );
#else//STUDIO_GLOSSMAP_ROUGHNESS
	glossmap.a = u_GlossExponent;
#endif//STDUIO_GLOSSMAP_ROUGHNESS
#endif//(STUDIO_HAS_GLOSS && STUDIO_HAS_LIGHTDIR)

#if defined( STUDIO_CUBEMAP_BPCEM ) || defined( STUDIO_CUBEMAP_SIMPLE )
	vec3 I = normalize( var_Position - u_ViewOrigin ); // in model space
	vec3 NW = normalize( var_Normal );
#if defined( STUDIO_CUBEMAP_SIMPLE )
	vec3 R = normalize( reflect( I, NW ));
#elif defined( STUDIO_CUBEMAP_BPCEM )
	vec3 R = bpcem( reflect( I, NW ), u_BoxMaxs, u_BoxMins, u_CubeOrigin, var_Position );
#endif
	vec3 refcolor = textureCube( u_EnvMap, R ).rgb;
	float eta = fresnel( normalize( var_EyeDir ), NW, u_FresnelExponent, u_ReflectScale ); // fresnel

#if defined( STUDIO_HAS_GLOSS ) && defined( STUDIO_HAS_LIGHTDIR )
	eta = saturate( eta * glossmap.r ); // reflection factor based on specular map
#endif
	// add to final light some reflect color
	screenmap = mix( screenmap, refcolor, eta );
#endif
	vec3 light = vec3( 1.0 );

#if defined( STUDIO_HAS_LIGHTDIR ) && ( defined( STUDIO_HAS_GLOSS ) || defined( STUDIO_ALPHA_GLASS ))
	vec3 L = normalize( var_LightDir );
#endif

// compute lighting for solidity parts of alpha-glass
#if !defined( STUDIO_FULLBRIGHT ) && defined( STUDIO_ALPHA_GLASS )
#if defined( STUDIO_HAS_BUMP ) && defined( STUDIO_HAS_LIGHTDIR )
	light = (( var_BaseLight * u_AmbientFactor ) + ( var_BaseLight * max( dot( N, L ), 0.0 ))); 
#else
	light = var_BaseLight;
#endif
#endif

#if defined( STUDIO_HAS_GLOSS ) && defined( STUDIO_HAS_LIGHTDIR )
	vec3 V = normalize( var_ViewDir );
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
	gloss = specular * GLOSS_SCALE;
#endif// STUDIO_HAS_GLOSS

#if defined( STUDIO_TRANS_TEXTURE ) || defined( STUDIO_TRANS_COLOR )
#ifdef STUDIO_ALPHA_GLASS
	diffuse.rgb = mix( diffuse.rgb * screenmap * 1.2, diffuse.rgb * light, diffuseAlpha ); // combine solid texture with window
#else// STUDIO_ALPHA_GLASS
	diffuse.rgb = mix( screenmap, diffuse.rgb * screenmap, diffuse.a ); // normal glass texture
#endif// STUDIO_ALPHA_GLASS
	diffuse.rgb += gloss;
#endif

#if !defined( STUDIO_FULLBRIGHT ) && ( defined( STUDIO_ADDITIVE ) || defined( STUDIO_ADDITIVE_FIXED ))
	// NOTE: in GoldSrc "additive" mode using LightForPoint for lighting additive surfaces
	diffuse.rgb *= var_BaseLight;
#endif

#ifdef STUDIO_FOG_EXP
	float fogFactor = saturate( exp2( -gl_Fog.density * ( gl_FragCoord.z / gl_FragCoord.w )));
	diffuse.rgb = mix( gl_Fog.color.rgb, diffuse.rgb, fogFactor );
#endif
	gl_FragColor = vec4( diffuse.rgb, 1.0 );
}