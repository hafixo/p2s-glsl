/*
BmodelDlight_vp.glsl - vertex uber shader for all dlight types for bmodel surfaces
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
uniform vec3		u_LightOrigin;
uniform vec3		u_ViewOrigin;
uniform vec2		u_DetailScale;
uniform mat4		u_ModelViewMatrix;
uniform mat4		u_ModelViewProjectionMatrix;
uniform mat4		u_TextureMatrix;
uniform mat4		u_ShadowMatrix;
uniform int		u_ClipPlane;
uniform float		u_LightRadius;
uniform vec2		u_TexOffset;

varying vec2		var_TexDiffuse;
varying vec3		var_AttnXYZCoord;

#ifdef BMODEL_HAS_DETAIL
varying vec2		var_TexDetail;
#endif

#ifdef DLIGHT_PROJECTION
varying vec4		var_ProjCoord;
#endif

#ifdef BMODEL_HAS_GLOSSMAP
varying vec3		var_ViewDir;
#endif

#if defined( BMODEL_HAS_NORMALMAP ) || defined( BMODEL_HAS_GLOSSMAP )
varying vec3		var_LightDir;
#endif

varying float		var_LightCos;

#ifdef BMODEL_MIRROR
varying vec4		var_TexMirror;	// mirror coords
#endif

#ifdef BMODEL_HAS_SHADOWS
varying vec4		var_ShadowCoord;
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
	vec3 vec_LightDir;
	vec4 texCoord = vec4( 0.0 ); // assume error

#if defined( DLIGHT_PROJECTION ) || defined( BMODEL_MIRROR )
	// compute texcoords for projection texture
	texCoord.s = dot( position, vec4( 1.0, 0.0, 0.0, 0.0 ));
	texCoord.t = dot( position, vec4( 0.0, 1.0, 0.0, 0.0 ));
	texCoord.p = dot( position, vec4( 0.0, 0.0, 1.0, 0.0 ));
	texCoord.q = dot( position, vec4( 0.0, 0.0, 0.0, 1.0 ));
#endif

#ifdef BMODEL_MIRROR
	var_TexMirror = gl_TextureMatrix[0] * texCoord;
#endif

#ifdef DLIGHT_PROJECTION
	var_ProjCoord = u_TextureMatrix * texCoord;

	// compute texcoords for attenuation Z texture
	vec4 planeS;
	planeS.xyz = -( u_LightDir / u_LightRadius );
	planeS.w = -( dot( -u_LightDir, u_LightOrigin ) / u_LightRadius );
	var_AttnXYZCoord = vec3( 0.0, 0.0, dot( position, planeS ));

	vec_LightDir = ( u_LightDir );

#ifdef BMODEL_HAS_SHADOWS
	// compute texcoords for shadowmap
	var_ShadowCoord = u_ShadowMatrix * texCoord;
#endif
#elif defined( DLIGHT_OMNI )
	// compute texcoords for attenuationXYZ
	float r = 1.0 / (u_LightRadius * 2.0);
	var_AttnXYZCoord.x = dot( position, vec4( r, 0.0, 0.0, -u_LightOrigin.x * r + 0.5 ));
	var_AttnXYZCoord.y = dot( position, vec4( 0.0, r, 0.0, -u_LightOrigin.y * r + 0.5 ));
	var_AttnXYZCoord.z = dot( position, vec4( 0.0, 0.0, r, -u_LightOrigin.z * r + 0.5 ));

	vec_LightDir = normalize( u_LightOrigin - position.xyz );

#ifdef BMODEL_HAS_SHADOWS
	// compute texcoords for shadowmap
	var_ShadowCoord = vec4( (u_ModelViewMatrix * position).xyz, 1.0 );
#endif
#endif

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