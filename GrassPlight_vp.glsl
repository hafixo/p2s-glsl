/*
GrassSunLight_vp.glsl - vertex uber shader for sun light for grass meshes
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

attribute vec3		attr_Position;
attribute vec4		attr_Normal;
attribute float		attr_BoneIndexes;	// gl_VertexID emulation (already preserved by & 15)

uniform mat4		u_ModelMatrix;
uniform mat4		u_ModelViewMatrix;
uniform mat4		u_ModelViewProjectionMatrix;
uniform float		u_GrassFadeStart;
uniform float		u_GrassFadeDist;
uniform float		u_GrassFadeEnd;
uniform vec3		u_ViewOrigin;
uniform int		u_ClipPlane;
uniform vec3		u_LightDir;
uniform float		u_RealTime;

varying vec2		var_TexDiffuse;
varying vec3		var_LightDir;
varying vec3		var_Normal;

#ifdef GRASS_HAS_SHADOWS
varying vec3		var_Position;
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

	if( bool( u_ClipPlane ))
		gl_ClipVertex = u_ModelViewMatrix * position;

#ifdef GRASS_HAS_SHADOWS
	var_Position = (u_ModelMatrix * position).xyz; // in world space
#endif
	var_TexDiffuse = GetTexCoordsForVertex( int( attr_BoneIndexes ));

	var_Normal = GetNormalForVertex( int( attr_BoneIndexes )); // -1 colinear, 1 opposite

	var_LightDir = ( u_LightDir ); // FIXME: should we normalize up?
}