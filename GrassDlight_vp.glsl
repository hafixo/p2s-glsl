/*
GrassDlight_vp.glsl - vertex uber shader for all dlight types for grass meshes
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
attribute float		attr_BoneIndexes;	// gl_VertexID emulation (already preserved by & 15)

uniform mat4		u_ModelViewMatrix;
uniform mat4		u_ModelViewProjectionMatrix;
uniform mat4		u_TextureMatrix;
uniform mat4		u_ShadowMatrix;
uniform float		u_GrassFadeStart;
uniform float		u_GrassFadeDist;
uniform float		u_GrassFadeEnd;
uniform vec3		u_LightOrigin;
uniform float		u_LightRadius;
uniform vec3		u_LightDir;
uniform int		u_ClipPlane;
uniform vec3		u_ViewOrigin;
uniform float		u_RealTime;

varying vec2		var_TexDiffuse;
varying vec3		var_AttnXYZCoord;
varying vec3		var_LightDir;
varying vec3		var_Normal;

#ifdef DLIGHT_PROJECTION
varying vec4		var_ProjCoord;
#endif

#ifdef GRASS_HAS_SHADOWS
varying vec4		var_ShadowCoord;
#endif

void main( void )
{
	float dist = distance( u_ViewOrigin, attr_Position );
	float scale = clamp( ( u_GrassFadeEnd - dist ) / u_GrassFadeDist, 0.0, 1.0 );

	int vertexID = int( attr_BoneIndexes ) - int( 4.0 * floor( attr_BoneIndexes * 0.25 )); // equal to gl_VertexID & 3
	vec4 position = vec4( attr_Position + attr_Normal.xyz * ( attr_Normal.w * scale ), 1.0 ); // in object space

	if( bool( dist < GRASS_ANIM_DIST ) && bool( vertexID == 1 || vertexID == 2 ))
	{
		position.x += sin( position.z + u_RealTime * 0.5 );
		position.y += cos( position.z + u_RealTime * 0.5 );
	}

	gl_Position = u_ModelViewProjectionMatrix * position;

	var_TexDiffuse = GetTexCoordsForVertex( int( attr_BoneIndexes ));

	if( bool( u_ClipPlane ))
		gl_ClipVertex = u_ModelViewMatrix * position;

#ifdef DLIGHT_PROJECTION
	vec4 texCoord, planeS;

	// compute texcoords for projection texture
	texCoord.s = dot( position, vec4( 1.0, 0.0, 0.0, 0.0 ));
	texCoord.t = dot( position, vec4( 0.0, 1.0, 0.0, 0.0 ));
	texCoord.p = dot( position, vec4( 0.0, 0.0, 1.0, 0.0 ));
	texCoord.q = dot( position, vec4( 0.0, 0.0, 0.0, 1.0 ));

	var_ProjCoord = u_TextureMatrix * texCoord;

	// compute texcoords for attenuation Z texture
	planeS.xyz = -( u_LightDir / u_LightRadius );
	planeS.w = -( dot( -u_LightDir, u_LightOrigin ) / u_LightRadius );
	var_AttnXYZCoord = vec3( 0.0, 0.0, dot( position, planeS ));

#ifdef GRASS_HAS_SHADOWS
	// compute texcoords for shadowmap
	var_ShadowCoord = u_ShadowMatrix * texCoord;
#endif
	var_LightDir = normalize( u_LightDir );

#elif defined( DLIGHT_OMNI )
	// compute texcoords for attenuationXYZ
	float r = 1.0f / (u_LightRadius * 2.0f);
	var_AttnXYZCoord.x = dot( position, vec4( r, 0, 0, -u_LightOrigin.x * r + 0.5f ));
	var_AttnXYZCoord.y = dot( position, vec4( 0, r, 0, -u_LightOrigin.y * r + 0.5f ));
	var_AttnXYZCoord.z = dot( position, vec4( 0, 0, r, -u_LightOrigin.z * r + 0.5f ));

#ifdef GRASS_HAS_SHADOWS
	// compute texcoords for shadowmap
	var_ShadowCoord = vec4( (u_ModelViewMatrix * position).xyz, 1.0 );
#endif
	var_LightDir = normalize( u_LightOrigin - position.xyz );

#endif
	var_Normal = GetNormalForVertex( int(attr_BoneIndexes));
}