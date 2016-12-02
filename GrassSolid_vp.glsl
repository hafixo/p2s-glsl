/*
GrassSolid_vp.glsl - vertex uber shader for grass meshes
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
attribute vec4		attr_Normal;
attribute vec4		attr_LightColor;
attribute vec4		attr_LightStyles;
attribute float		attr_BoneIndexes;	// gl_VertexID emulation (already preserved by & 15)

uniform mat4		u_ModelViewMatrix;
uniform mat4		u_ModelViewProjectionMatrix;
uniform float		u_LightStyleValues[MAX_LIGHTSTYLES];
uniform vec3		u_ViewOrigin;
uniform int		u_ClipPlane;
uniform float		u_RealTime;
uniform float		u_GrassFadeStart;
uniform float		u_GrassFadeDist;
uniform float		u_GrassFadeEnd;
uniform float		u_AmbientFactor;
uniform vec3		u_LightDiffuse;
uniform vec3		u_LightDir;
	
varying vec2		var_TexDiffuse;
varying vec4		var_FrontLight;
varying vec4		var_BackLight;

#define UnpackLight( c )	fract( c * vec3( 1.0, 256.0, 65536.0 ))

void main( void )
{
#ifdef GRASS_SKYBOX
	float dist = GRASS_ANIM_DIST + 1.0;	// disable animation
	float scale = 1.0;			// keep constant size
#else	
	float dist = distance( u_ViewOrigin, attr_Position );
	float scale = clamp( ( u_GrassFadeEnd - dist ) / u_GrassFadeDist, 0.0, 1.0 );
#endif
	int vertexID = int( attr_BoneIndexes ) - int( 4.0 * floor( attr_BoneIndexes * 0.25 )); // equal to gl_VertexID & 3
	vec4 position = vec4( attr_Position + attr_Normal.xyz * ( attr_Normal.w * scale ), 1.0 );	// in object space

	if( bool( dist < GRASS_ANIM_DIST ) && bool( vertexID == 1 || vertexID == 2 ))
	{
		position.x += sin( position.z + u_RealTime * 0.5 );
		position.y += cos( position.z + u_RealTime * 0.5 );
	}

	gl_Position = u_ModelViewProjectionMatrix * position;

	var_TexDiffuse = GetTexCoordsForVertex( int( attr_BoneIndexes ));

	if( bool( u_ClipPlane ))
		gl_ClipVertex = u_ModelViewMatrix * position;

#ifdef GRASS_SKYBOX
	vec3 N = GetNormalForVertex( int( attr_BoneIndexes ));
	vec3 L = normalize( u_LightDir );

	var_FrontLight.rgb = u_LightDiffuse * max( dot( N, L ), u_AmbientFactor );
	var_BackLight.rgb = u_LightDiffuse * max( dot( -N, L ), u_AmbientFactor );
#else

#ifdef GRASS_ALLSTYLES
	int styles[MAXLIGHTMAPS];
	vec3 light[MAXLIGHTMAPS];

	// setup lightstyles and clamp it
	styles[0] = clamp( int( attr_LightStyles.x ), 0, 255 );
	styles[1] = clamp( int( attr_LightStyles.y ), 0, 255 );
	styles[2] = clamp( int( attr_LightStyles.z ), 0, 255 );
	styles[3] = clamp( int( attr_LightStyles.w ), 0, 255 );

	light[0] = UnpackLight( attr_LightColor.x );
	light[1] = UnpackLight( attr_LightColor.y );
	light[2] = UnpackLight( attr_LightColor.z );
	light[3] = UnpackLight( attr_LightColor.w );

	var_FrontLight = vec4( 0.0, 0.0, 0.0, 1.0 );

	// add all the styles
	for( int map = 0; map < MAXLIGHTMAPS && styles[map] != 255; map++ )
	{
		var_FrontLight.rgb += light[map] * u_LightStyleValues[styles[map]] * GRASS_SCALE;
	}
#else
	var_FrontLight.rgb = UnpackLight( attr_LightColor.x ) * u_LightStyleValues[int(attr_LightStyles.x)] * GRASS_SCALE;
#endif// GRASS_ALLSTYLES
#endif// GRASS_SKYBOX
}