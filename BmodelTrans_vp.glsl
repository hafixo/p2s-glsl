/*
BmodelTrans_vp.glsl - vertex uber shader for all trans bmodel surfaces
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
attribute vec4		attr_TexCoord1;	// lightmap 0-1
attribute vec4		attr_TexCoord2;	// lightmap 2-3
attribute vec3		attr_Normal;
attribute vec3		attr_Tangent;
attribute vec3		attr_Binormal;
attribute vec4		attr_LightStyles;

uniform mat4		u_ModelViewMatrix;
uniform mat4		u_ModelViewProjectionMatrix;
uniform vec3		u_ViewOrigin;	// already in modelspace
uniform vec2		u_DetailScale;
uniform int		u_ClipPlane;
uniform vec2		u_TexOffset;	// conveyor stuff

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

#if defined( BMODEL_HAS_GLOSSMAP ) || defined( BMODEL_CUBEMAP_BPCEM ) || defined( BMODEL_CUBEMAP_SIMPLE ) || defined( BMODEL_WATER )
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
	vec4 position = vec4( attr_Position, 1.0 ); // in object space

	gl_Position = u_ModelViewProjectionMatrix * position;

	if( bool( u_ClipPlane ))
		gl_ClipVertex = u_ModelViewMatrix * position;

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

#if !defined( BMODEL_NOLIGHTMAP ) && ( defined (BMODEL_ALPHA_GLASS) || defined( BMODEL_HAS_GLOSSMAP ))
	// setup lightcoords
	var_TexLight[0] = attr_TexCoord1.xy;
	var_TexLight[1] = attr_TexCoord1.zw;
	var_TexLight[2] = attr_TexCoord2.xy;
	var_TexLight[3] = attr_TexCoord2.zw;

	// setup lightstyles and clamp it
#if defined( allow_gpu_shader4 )
	var_LightStyles[0] = clamp( int( attr_LightStyles.x ), 0, 255 );
	var_LightStyles[1] = clamp( int( attr_LightStyles.y ), 0, 255 );
	var_LightStyles[2] = clamp( int( attr_LightStyles.z ), 0, 255 );
	var_LightStyles[3] = clamp( int( attr_LightStyles.w ), 0, 255 );
#else
	var_LightStyles[0] = clamp( attr_LightStyles.x, 0.0, 255.0 );
	var_LightStyles[1] = clamp( attr_LightStyles.y, 0.0, 255.0 );
	var_LightStyles[2] = clamp( attr_LightStyles.z, 0.0, 255.0 );
	var_LightStyles[3] = clamp( attr_LightStyles.w, 0.0, 255.0 );
#endif

#endif

#if defined( BMODEL_HAS_GLOSSMAP ) || defined( BMODEL_CUBEMAP_BPCEM ) || defined( BMODEL_CUBEMAP_SIMPLE ) || defined( BMODEL_WATER )
	// compute object-space view direction
	vec3 eye = ( u_ViewOrigin - attr_Position );

#if defined( BMODEL_HAS_GLOSSMAP ) || defined( BMODEL_WATER )
	// transform viewdir into tangent space
	var_ViewDir = vec3( dot( eye, attr_Tangent ), dot( eye, attr_Binormal ), dot( eye, attr_Normal ));
#endif

#if defined( BMODEL_CUBEMAP_BPCEM ) || defined( BMODEL_CUBEMAP_SIMPLE )
	var_EyeDir = normalize( eye );
#endif
#endif

#ifdef BMODEL_WATER
	vec4 texCoord;

	// compute texcoords for projection texture
	texCoord.s = dot( position, vec4( 1.0, 0.0, 0.0, 0.0 ));
	texCoord.t = dot( position, vec4( 0.0, 1.0, 0.0, 0.0 ));
	texCoord.p = dot( position, vec4( 0.0, 0.0, 1.0, 0.0 ));
	texCoord.q = dot( position, vec4( 0.0, 0.0, 0.0, 1.0 ));

	var_TexMirror = gl_TextureMatrix[1] * texCoord;
#endif

#if defined( BMODEL_CUBEMAP_BPCEM ) || defined( BMODEL_CUBEMAP_SIMPLE )
	var_Position = attr_Position;
	var_Normal = attr_Normal;
#endif
}