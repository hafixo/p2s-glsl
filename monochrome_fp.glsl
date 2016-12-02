/*
monochrome_fp.glsl - monochrome effect
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

uniform sampler2D	u_ColorMap;
uniform float	u_BlurFactor;

varying vec2	var_TexCoord;

void main(void)
{
	vec3 diffuse = texture2D( u_ColorMap, var_TexCoord ).xyz;

	float lum = dot( vec3( 0.27, 0.67, 0.06 ), diffuse ); // convert to luminance

	diffuse = mix( diffuse, vec3( lum ), clamp( u_BlurFactor, 0.0, 1.0 ));

	gl_FragColor = vec4( diffuse, 1.0 );
}