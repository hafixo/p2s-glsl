/*
BmodelPlight_vp.glsl - fragment uber shader for sun light for bmodel surfaces
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
attribute vec2		attr_TexCoord0;
attribute vec3		attr_Normal;
attribute vec3		attr_Tangent;
attribute vec3		attr_Binormal;

uniform vec3		u_LightDir;
uniform vec3		u_ViewOrigin;
uniform vec2		u_DetailScale;
uniform mat4		u_ModelMatrix;
uniform mat4		u_ModelViewMatrix;
uniform mat4		u_ModelViewProjectionMatrix;
uniform int		u_ClipPlane;
uniform vec2		u_TexOffset;

varying vec2		var_TexDiffuse;

#ifdef BMODEL_HAS_DETAIL
varying vec2		var_TexDetail;
#endif

#ifdef BMODEL_HAS_GLOSSMAP
varying vec3		var_ViewDir;
#endif

#if defined( BMODEL_HAS_NORMALMAP ) || defined( BMODEL_HAS_GLOSSMAP )
varying vec3		var_LightDir;
#endif

#ifdef BMODEL_HAS_SHADOWS
varying vec3		var_Position;
#endif

varying float		var_LightCos;

void main( void )
{
	vec4 position = vec4( attr_Position, 1.0 ); // in object space

	gl_Position = u_ModelViewProjectionMatrix * position;

	if( bool( u_ClipPlane ))
		gl_ClipVertex = u_ModelViewMatrix * position;

#ifdef BMODEL_HAS_SHADOWS
	var_Position = (u_ModelMatrix * position).xyz; // in world space
#endif
	// used for diffuse, normalmap, specular and height map
#ifdef BMODEL_CONVEYOR
	var_TexDiffuse = ( attr_TexCoord0 + u_TexOffset );
#else
	var_TexDiffuse = attr_TexCoord0;
#endif

#ifdef BMODEL_HAS_DETAIL
#ifdef BMODEL_CONVEYOR
	var_TexDetail = ( attr_TexCoord0 + u_TexOffset ) * u_DetailScale;
#else
	var_TexDetail = attr_TexCoord0 * u_DetailScale;
#endif
#endif

	vec3 vec_LightDir = ( u_LightDir );	// FIXME: should we normalize up?

#if defined( BMODEL_HAS_NORMALMAP ) || defined( BMODEL_HAS_GLOSSMAP )
	// transform lightdir into tangent space
	var_LightDir = vec3( dot( vec_LightDir, attr_Tangent ), dot( vec_LightDir, attr_Binormal ), dot( vec_LightDir, attr_Normal ));

#ifdef BMODEL_HAS_GLOSSMAP
	vec3 eye = ( u_ViewOrigin - attr_Position );
	// transform viewdir into tangent space
	var_ViewDir = vec3( dot( eye, attr_Tangent ), dot( eye, attr_Binormal ), dot( eye, attr_Normal ));
#endif// BMODEL_HAS_GLOSSMAP
#endif// BMODEL_HAS_NORMALMAP || BMODEL_HAS_GLOSSMAP

	// NOTE: lightdir already in modelspace so we don't need to rotate the normal
	var_LightCos = clamp( dot( attr_Normal, vec_LightDir ), -1.0, 1.0 ); // -1 colinear, 1 opposite
}