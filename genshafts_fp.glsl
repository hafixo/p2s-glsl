/*
genshafts_fp.glsl - generate sun shafts
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

uniform sampler2D		u_ColorMap;
uniform sampler2D		u_DepthMap;
uniform float		u_zFar;

varying vec2       		var_TexCoord;

float znear = Z_NEAR;	// fixed
float zfar = u_zFar;	// camera clipping end

float linearizeDepth( float depth )
{
	return -zfar * znear / ( depth * ( zfar - znear ) - zfar );
}

void main( void )
{
	float sceneDepth = linearizeDepth( texture2D( u_DepthMap, var_TexCoord ).r );
	vec4 sceneColor = texture2D( u_ColorMap, var_TexCoord );
	float fShaftsMask = RemapVal( sceneDepth, znear, zfar, 0.0, 1.0 );

	// g-cont. use linear depth scale to prevent parazite lighting
	gl_FragColor = vec4( sceneColor.xyz * fShaftsMask, 1.0 - fShaftsMask );
}