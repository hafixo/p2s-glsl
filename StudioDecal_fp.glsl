/*
DecalStudio_fp.glsl - fragment uber shader for studio decals
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

uniform sampler2D	u_DecalMap;
uniform sampler2D	u_ColorMap;

uniform float	u_RenderAlpha;

void main( void )
{
	vec4 diffuse = texture2D( u_DecalMap, gl_TexCoord[0].xy );

#ifdef DECAL_ALPHATEST
	if( texture2D( u_ColorMap, gl_TexCoord[0].zw ).a <= STUDIO_ALPHA_THRESHOLD )
	{
		discard;
		return;
	}
#endif

#ifdef STUDIO_ALPHA_GLASS
	vec4 mask = texture2D( u_ColorMap, gl_TexCoord[0].zw );
	float factor;

	if( gl_FrontFacing )
		factor = saturate((1.0 - mask.a) * 2.0 );
	else factor = 1.0;

	diffuse.rgb = mix( vec3( 0.5 ), diffuse.rgb, factor );
#endif
	// decal fading on monster corpses
	diffuse.rgb = mix( vec3( 0.5 ), diffuse.rgb, u_RenderAlpha );

#ifdef DECAL_FOG_EXP
	float fogFactor = clamp( exp2( -gl_Fog.density * ( gl_FragCoord.z / gl_FragCoord.w )), 0.0, 1.0 );
	diffuse.rgb = mix( vec3( 0.5, 0.5, 0.5 ), diffuse.rgb, fogFactor ); // mixing to base
#endif
	gl_FragColor = diffuse;
}