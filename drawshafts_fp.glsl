/*
drawshafts_fp.glsl - render sun shafts
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
uniform vec3		u_LightDir;
uniform vec3		u_LightOrigin;
uniform vec3		u_LightDiffuse;

varying vec2       		var_TexCoord;

void main( void )
{
	vec2 sunPosProj = u_LightOrigin.xy;
	vec2 sunVec = sunPosProj.xy - ( var_TexCoord - vec2( 0.5, 0.5 ));
	float sunDist = saturate( 1.0 - saturate( length( sunVec ) * 2.0 ));

	sunVec *= 0.1;

	vec4 accum = vec4( 0.0 );
	vec2 tc = var_TexCoord;

	tc += sunVec;
	accum += texture2D( u_DepthMap, tc ) * 1.0;
	tc += sunVec;
	accum += texture2D( u_DepthMap, tc ) * 0.875;
	tc += sunVec;
	accum += texture2D( u_DepthMap, tc ) * 0.75;
	tc += sunVec;
	accum += texture2D( u_DepthMap, tc ) * 0.625;
	tc += sunVec;
	accum += texture2D( u_DepthMap, tc ) * 0.5;
	tc += sunVec;
	accum += texture2D( u_DepthMap, tc ) * 0.375;
	tc += sunVec;
	accum += texture2D( u_DepthMap, tc ) * 0.25;
	tc += sunVec;
	accum += texture2D( u_DepthMap, tc ) * 0.125;

	accum *= 0.2 * vec4( sunDist, sunDist, sunDist, 1.0 );
	
 	vec4 cScreen = texture2D( u_ColorMap, var_TexCoord );      
      
	float fBlend = accum.w * 1.2;

	vec4 sunColor = vec4( u_LightDiffuse, 1.0 );

	gl_FragColor = cScreen + accum.xyzz * fBlend * sunColor * ( 1.0 - cScreen );
}