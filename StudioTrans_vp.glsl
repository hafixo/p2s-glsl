/*
StudioTrans_vp.glsl - vertex uber shader for all trans studio meshes
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

attribute vec3		attr_Position;
attribute vec2		attr_TexCoord0;
attribute vec3		attr_Normal;
attribute vec3		attr_Tangent;
attribute vec3		attr_Binormal;
attribute float		attr_BoneIndexes;

uniform mat4		u_ModelViewMatrix;
uniform mat4		u_ModelViewProjectionMatrix;
uniform mat4		u_BoneMatrix[MAXSTUDIOBONES];
uniform vec3		u_LightDiffuse[LIGHT_SAMPLES];
uniform vec3		u_LightOrigin[LIGHT_SAMPLES];
uniform vec3		u_LightDir[LIGHT_SAMPLES];
uniform int		u_LightSamples;
uniform float		u_AmbientFactor;
uniform vec3		u_ViewOrigin;
uniform vec3		u_ViewRight;
uniform int		u_ClipPlane;

varying vec3		var_BaseLight;
varying vec2		var_TexDiffuse;

#if defined( STUDIO_CUBEMAP_BPCEM ) || defined( STUDIO_CUBEMAP_SIMPLE )
// NOTE: these variables in model-space
varying vec3		var_Position;
varying vec3		var_EyeDir;
varying vec3		var_Normal;
#endif

#if defined( STUDIO_HAS_LIGHTDIR ) && ( defined( STUDIO_HAS_BUMP ) || defined( STUDIO_HAS_GLOSS ))
varying vec3		var_LightDir;
#endif

#if !defined( STUDIO_FULLBRIGHT ) && defined( STUDIO_HAS_GLOSS )
varying vec3		var_ViewDir;
#endif

#if defined( STUDIO_LIGHT_ONESAMPLE ) || defined( STUDIO_LIGHT_MULTISAMPLE ) || defined( STUDIO_HAS_CHROME )
#define STUDIO_COMPUTE_NORMAL
#endif

#if defined( STUDIO_CUBEMAP_BPCEM ) || defined( STUDIO_CUBEMAP_SIMPLE )
#define STUDIO_COMPUTE_NORMAL
#endif

#if defined( STUDIO_HAS_LIGHTDIR ) && ( defined( STUDIO_HAS_BUMP ) || defined( STUDIO_HAS_GLOSS ))
#define STUDIO_COMPUTE_TANGENT
#define STUDIO_COMPUTE_BINORMAL
#define STUDIO_COMPUTE_NORMAL
#endif

void main( void )
{
	vec4 position = vec4( 0.0, 0.0, 0.0, 1.0 );

	// compute hardware skinning
	mat4 boneMatrix = u_BoneMatrix[int(min(float(attr_BoneIndexes), float(MAXSTUDIOBONES - 1)))];
	position.xyz = ( boneMatrix * vec4( attr_Position, 1.0 )).xyz;

	// transform vertex position into homogenous clip-space
	gl_Position = u_ModelViewProjectionMatrix * position;

	if( bool( u_ClipPlane ))
		gl_ClipVertex = u_ModelViewMatrix * position;

	// compute TBN by request
#ifdef STUDIO_COMPUTE_TANGENT
	vec3 T = ( boneMatrix * vec4( attr_Tangent, 0.0 )).xyz;
#endif
#ifdef STUDIO_COMPUTE_BINORMAL
	vec3 B = ( boneMatrix * vec4( attr_Binormal, 0.0 )).xyz;
#endif
#ifdef STUDIO_COMPUTE_NORMAL
	vec3 N = ( boneMatrix * vec4( attr_Normal, 0.0 )).xyz;
#endif

#ifdef STUDIO_FULLBRIGHT
	// just do nothing
#elif defined( STUDIO_LIGHT_FLATSHADE )
	// compute vertex lighting (ambient only)
	var_BaseLight = ( u_LightDiffuse[0] * u_AmbientFactor ) + ( u_LightDiffuse[0] * 0.8 );
#elif defined( STUDIO_LIGHT_ONESAMPLE )
#if defined( STUDIO_HAS_BUMP )
	var_BaseLight = u_LightDiffuse[0];
#else
	float lightcos = max( dot( N, normalize( u_LightDir[0] )), 0.0 );
#if defined( STUDIO_LIGHT_HALFLAMBERT ) 
	lightcos = (lightcos + 1.0) / 2.0; // do modified hemispherical lighting
#endif
	var_BaseLight = ( u_LightDiffuse[0] * u_AmbientFactor ) + ( u_LightDiffuse[0] * lightcos );
#endif
#if defined( STUDIO_HAS_LIGHTDIR ) && ( defined( STUDIO_HAS_BUMP ) || defined( STUDIO_HAS_GLOSS ))
	var_LightDir = u_LightDir[0];
#endif
#elif defined( STUDIO_LIGHT_MULTISAMPLE )
	// multi point samples
	float lightDists[LIGHT_SAMPLES];
	float maxDist = 0.0;
	int farLight = 0;

	// NOTE: a maximum dist is a 0% weight, a minimum dist is a 100% weight
	for( int i = 0; i < u_LightSamples; i++ )
	{
		lightDists[i] = abs( length( u_LightOrigin[i] - position.xyz ));

		if( lightDists[i] > maxDist )
		{
			maxDist = lightDists[i];
			farLight = i;
		} 
	}

	var_BaseLight = vec3( 0.0 );

#if defined( STUDIO_HAS_LIGHTDIR ) && ( defined( STUDIO_HAS_BUMP ) || defined( STUDIO_HAS_GLOSS ))
	var_LightDir = vec3( 0.0 );
#endif
	// per-vertex lighting should be done in vertex shader
	for( int i = 0; i < u_LightSamples; i++ )
	{
		float weight = 1.0 - ( lightDists[i] / lightDists[farLight] );
#ifdef STUDIO_HAS_BUMP
		var_BaseLight += u_LightDiffuse[i] * weight;
#else
		vec3 L = normalize( u_LightDir[i] );
		float lightcos = max( dot( N, L ), 0.0 );
#if defined( STUDIO_LIGHT_HALFLAMBERT ) 
		lightcos = (lightcos + 1.0) / 2.0; // do modified hemispherical lighting
#endif
		var_BaseLight += (( u_LightDiffuse[i] * u_AmbientFactor ) + ( u_LightDiffuse[i] * lightcos )) * weight;
#endif

#if defined( STUDIO_HAS_LIGHTDIR ) && ( defined( STUDIO_HAS_BUMP ) || defined( STUDIO_HAS_GLOSS ))
		var_LightDir += u_LightDir[i] * weight;
#endif
	}
#if defined( STUDIO_LIGHT_HALFLAMBERT ) 
	var_BaseLight *= ( 1.0 / ( u_LightSamples - 1.5 ));
#endif
#endif

#if defined( STUDIO_HAS_LIGHTDIR ) && ( defined( STUDIO_HAS_BUMP ) || defined( STUDIO_HAS_GLOSS ))
	// transform lightdir into tangent space
	var_LightDir = vec3( dot( var_LightDir, T ), dot( var_LightDir, B ), dot( var_LightDir, N ));
#endif

#if !defined( STUDIO_FULLBRIGHT ) && ( defined( STUDIO_HAS_GLOSS ) || defined( STUDIO_CUBEMAP_BPCEM ) || defined( STUDIO_CUBEMAP_SIMPLE ))
	vec3 eye = normalize( u_ViewOrigin - position.xyz );

	// transform viewdir into tangent space
#ifdef STUDIO_HAS_GLOSS
	var_ViewDir = vec3( dot( eye, T ), dot( eye, B ), dot( eye, N ));
#endif

#if defined( STUDIO_CUBEMAP_BPCEM ) || defined( STUDIO_CUBEMAP_SIMPLE )
	var_EyeDir = eye;
#endif
#endif

#if defined( STUDIO_CUBEMAP_BPCEM ) || defined( STUDIO_CUBEMAP_SIMPLE )
	var_Position = position.xyz;
	var_Normal = N;
#endif

#ifdef STUDIO_HAS_CHROME
	// compute chrome texcoords
	vec3 origin = normalize( -u_ViewOrigin + vec3( boneMatrix[3] ));
	vec3 chromeup = -normalize( cross( origin, u_ViewRight ));
	vec3 chromeright = normalize( cross( origin, -chromeup ));

	var_TexDiffuse.x = ( dot( N, chromeright ) + 1.0 ) * 32.0 * attr_TexCoord0.x;	// calc s coord
	var_TexDiffuse.y = ( dot( N, chromeup ) + 1.0 ) * 32.0 * attr_TexCoord0.y;	// calc t coord
#else
	var_TexDiffuse = attr_TexCoord0;
#endif
}