/*
StudioPlight_vp.glsl - vertex uber shader for sun light for studio meshes
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

attribute vec3		attr_Position;
attribute vec3		attr_Normal;
attribute vec3		attr_Tangent;
attribute vec3		attr_Binormal;
attribute float		attr_BoneIndexes;
attribute vec2		attr_TexCoord0;

uniform vec3		u_LightDir;
uniform vec3		u_ViewOrigin;
uniform vec3		u_ViewRight;
uniform mat4		u_ModelMatrix;
uniform mat4		u_ModelViewMatrix;
uniform mat4		u_ModelViewProjectionMatrix;
uniform mat4		u_BoneMatrix[MAXSTUDIOBONES];
uniform int		u_ClipPlane;

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

void main( void )
{
	vec4 position = vec4( 0.0, 0.0, 0.0, 1.0 );

	// compute hardware skinning
	mat4 boneMatrix = u_BoneMatrix[int(min(float(attr_BoneIndexes), float(MAXSTUDIOBONES - 1)))];
	position.xyz = ( boneMatrix * vec4( attr_Position, 1.0 )).xyz;

	// compute TBN by request
#if defined( STUDIO_HAS_BUMP ) || defined( STUDIO_HAS_GLOSS )
	vec3 T = ( boneMatrix * vec4( attr_Tangent, 0.0 )).xyz;
	vec3 B = ( boneMatrix * vec4( attr_Binormal, 0.0 )).xyz;
#endif
	vec3 N = ( boneMatrix * vec4( attr_Normal, 0.0 )).xyz;

	// transform vertex position into homogenous clip-space
	gl_Position = u_ModelViewProjectionMatrix * position;

	if( bool( u_ClipPlane ))
		gl_ClipVertex = u_ModelViewMatrix * position;

#ifdef STUDIO_HAS_SHADOWS
	var_Position = (u_ModelMatrix * position).xyz; // in world space
#endif
	vec3 L = ( u_LightDir );

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

#if defined( STUDIO_HAS_BUMP ) || defined( STUDIO_HAS_GLOSS )
	// transform lightdir into tangent space
	var_LightDir = vec3( dot( L, T ), dot( L, B ), dot( L, N ));

#ifdef STUDIO_HAS_GLOSS
	vec3 eye = ( u_ViewOrigin - position.xyz );
	// transform viewdir into tangent space
	var_ViewDir = vec3( dot( eye, T ), dot( eye, B ), dot( eye, N ));
#endif// STUDIO_HAS_GLOSS
#endif// STUDIO_HAS_BUMP || STUDIO_HAS_GLOSS

	// helper to kill backward lighting
	var_LightCos = clamp( dot( N, L ), -1.0, 1.0 ); // -1 colinear, 1 opposite
}