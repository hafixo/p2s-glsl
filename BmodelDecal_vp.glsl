/*
BmodelDecal_vp.glsl - vertex uber shader for bmodel decals
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

uniform mat4	u_ModelViewMatrix;
uniform mat4	u_ModelViewProjectionMatrix;
uniform int	u_ClipPlane;

varying vec3	var_ViewDir;

#ifdef DECAL_REFLECTION
varying vec4	var_TexMirror;	// mirror coords
#endif

void main( void )
{
	gl_Position = u_ModelViewProjectionMatrix * gl_Vertex;

	if( bool( u_ClipPlane ))
		gl_ClipVertex = u_ModelViewMatrix * gl_Vertex;

	// decal & surface scissor coords
	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_TexCoord[1] = gl_MultiTexCoord1;

	var_ViewDir = gl_Normal.xyz;

#ifdef DECAL_REFLECTION
	vec4 texCoord;

	// compute texcoords for projection texture
	texCoord.s = dot( gl_Vertex, vec4( 1.0, 0.0, 0.0, 0.0 ));
	texCoord.t = dot( gl_Vertex, vec4( 0.0, 1.0, 0.0, 0.0 ));
	texCoord.p = dot( gl_Vertex, vec4( 0.0, 0.0, 1.0, 0.0 ));
	texCoord.q = dot( gl_Vertex, vec4( 0.0, 0.0, 0.0, 1.0 ));

	var_TexMirror = gl_TextureMatrix[2] * texCoord;
#endif
}