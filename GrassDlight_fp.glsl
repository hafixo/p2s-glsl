/*
BrushOmniLight_fp.glsl - fragment uber shader for all dlight types for grass meshes
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

uniform sampler2D		u_ProjectMap;
#define u_AttnXYMap		u_ProjectMap	// just for consistency
uniform sampler1D		u_AttnZMap;
uniform sampler2D		u_ColorMap;

#ifdef GRASS_HAS_SHADOWS
#ifdef DLIGHT_PROJECTION
#include "shadow_proj.h"
#elif defined( DLIGHT_OMNI )
#include "shadow_omni.h"
#endif
#endif

uniform vec3		u_LightDiffuse;
uniform vec2		u_ScreenSizeInv;
uniform mat4		u_LightModelViewMatrix;
uniform mat4		u_LightProjectionMatrix;

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
	// compute the diffuse term
	vec4 diffuse = texture2D( u_ColorMap, var_TexDiffuse );

#ifdef DLIGHT_PROJECTION
	vec3 light = texture2DProj( u_ProjectMap, var_ProjCoord ).rgb * u_LightDiffuse;

	// linear attenuation texture
	light *= texture1D( u_AttnZMap, var_AttnXYZCoord.z ).r;

#ifdef GRASS_HAS_SHADOWS
	light *= ShadowProj( var_ShadowCoord, u_ScreenSizeInv );
#else
	vec3 N = (gl_FrontFacing) ? var_Normal : -var_Normal;
	light *= RemapVal( dot( normalize( var_LightDir ), normalize( N )), -0.9, 1.0, 0.0, 1.0 );
#endif

#elif defined( DLIGHT_OMNI )
	vec3 light = u_LightDiffuse;

	// attenuation XY (original code using GL_ONE_MINUS_SRC_ALPHA)
	float attnXY = texture2D( u_AttnXYMap, var_AttnXYZCoord.xy ).a;
	// attenuation Z (original code using GL_ONE_MINUS_SRC_ALPHA)
	float attnZ = texture1D( u_AttnZMap, var_AttnXYZCoord.z ).a;
	// apply attenuation
	light *= ( 1.0 - ( attnXY + attnZ ));

#ifdef GRASS_HAS_SHADOWS
	light *= ShadowOmni( u_LightProjectionMatrix, (u_LightModelViewMatrix * var_ShadowCoord).xyz, u_ScreenSizeInv );
#else
	vec3 N = (gl_FrontFacing) ? var_Normal : -var_Normal;
	light *= RemapVal( dot( normalize( var_LightDir ), normalize( N )), -0.9, 1.0, 0.0, 1.0 );
#endif
#endif
	diffuse.rgb *= light.rgb * DLIGHT_SCALE;

	// compute final color
	gl_FragColor = diffuse;
}