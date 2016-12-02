/*
StudioDepth_vp.glsl - studio shadow pass
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

attribute vec3		attr_Position;
attribute vec2		attr_TexCoord0;
attribute float		attr_BoneIndexes;

uniform mat4		u_ModelViewMatrix;
uniform mat4		u_ModelViewProjectionMatrix;
uniform mat4		u_BoneMatrix[MAXSTUDIOBONES];
uniform int		u_ClipPlane;

varying vec2		var_TexCoord;	// for alpha-testing

void main( void )
{
	vec4 position = vec4( 0.0, 0.0, 0.0, 1.0 );

	// compute hardware skinning
	mat4 boneMatrix = u_BoneMatrix[int(min(float(attr_BoneIndexes), float(MAXSTUDIOBONES - 1)))];
	position.xyz = ( boneMatrix * vec4( attr_Position, 1.0 )).xyz;

	// transform vertex position into homogenous clip-space
	gl_Position = u_ModelViewProjectionMatrix * position;

	if( bool( u_ClipPlane ))
		gl_ClipVertex = u_ModelViewMatrix * position;

	var_TexCoord = attr_TexCoord0;
}