/*
BrushProjLight_fp.glsl - fragment uber shader for sun light for grass meshes
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

uniform sampler2DShadow	u_ShadowMap0;
uniform sampler2DShadow	u_ShadowMap1;
uniform sampler2DShadow	u_ShadowMap2;
uniform sampler2DShadow	u_ShadowMap3;
uniform sampler2D		u_ColorMap;

uniform vec3		u_LightDiffuse;
uniform float		u_RefractScale;
uniform float		u_AmbientFactor;
uniform float		u_TexelSize;	// shadowmap resolution
uniform mat4		u_ViewMatrix;
uniform mat4		u_ShadowMatrix[MAX_SHADOWMAPS];
uniform vec4		u_ShadowSplitDist;

varying vec2		var_TexDiffuse;
varying vec3		var_LightDir;
varying vec3		var_Normal;

#ifdef GRASS_HAS_SHADOWS
varying vec3		var_Position;
#endif

#ifdef GRASS_HAS_SHADOWS
#include "shadow_sun.h"
#endif

void main( void )
{
	// compute the diffuse term
	vec4 diffuse = texture2D( u_ColorMap, var_TexDiffuse );

	vec3 light = u_LightDiffuse;

	vec3 N = (gl_FrontFacing) ? var_Normal : -var_Normal;

	float lightCos = dot( normalize( var_LightDir ), normalize( N ));

	light *= RemapVal( lightCos, -1.0, 1.0, 0.0, 1.0 ); // fast ugly approximation of subsurface scattering

#ifdef GRASS_HAS_SHADOWS
	float shadow = ComputeShadowParallel( var_Position, lightCos );
	light *= mix( shadow, 0.0, u_RefractScale );
#endif
	diffuse.rgb = ((diffuse.rgb * u_AmbientFactor) + (diffuse.rgb * light) * SUN_SCALE);

	// compute final color
	gl_FragColor = diffuse;
}