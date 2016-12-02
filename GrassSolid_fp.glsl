/*
GrassSolid_fp.glsl - fragment uber shader for grass meshes
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

uniform sampler2D		u_ColorMap;

varying vec2		var_TexDiffuse;
varying vec4		var_FrontLight;
varying vec4		var_BackLight;

void main( void )
{
	vec4 diffuse = texture2D( u_ColorMap, var_TexDiffuse );

#if !defined( GRASS_FULLBRIGHT ) && ( defined( GRASS_LIGHTMAP_DEBUG ) || defined( GRASS_DELUXEMAP_DEBUG ))
	diffuse.rgb = vec3( 1.0 );
#endif

#ifndef GRASS_FULLBRIGHT
#ifdef GRASS_SKYBOX
	if( bool( gl_FrontFacing ))
		diffuse *= var_FrontLight;
	else diffuse *= var_BackLight;
#else
	diffuse *= var_FrontLight;
#endif
#endif

#ifdef GRASS_FOG_EXP
	float fogFactor = saturate( exp2( -gl_Fog.density * ( gl_FragCoord.z / gl_FragCoord.w )));
	diffuse.rgb = mix( gl_Fog.color.rgb, diffuse.rgb, fogFactor );
#endif
	gl_FragColor = diffuse;
}