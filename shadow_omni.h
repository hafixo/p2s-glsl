/*
shadow_omni.h - shadow for omnidirectional dlights and PCF filtering
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

#ifndef SHADOW_OMNI_H
#define SHADOW_OMNI_H

#extension GL_EXT_gpu_shader4 : require

#define NUM_SAMPLES		4.0

uniform samplerCubeShadow	u_ShadowMap;

float depthCube( vec3 coord, mat4 lightProjection )
{
	vec3 abs_coord = abs( coord );
	float fs_z = -max( abs_coord.x, max( abs_coord.y, abs_coord.z ));
	vec4 clip = lightProjection * vec4( 0.0, 0.0, fs_z, 1.05 );	// z-bias
	float depth = ( clip.z / clip.w ) * 0.5 + 0.5;

	return shadowCube( u_ShadowMap, vec4( -coord.z, -coord.x, coord.y, depth )).r;
}

float ShadowOmni( mat4 lightProjection, vec3 I, vec2 texel )
{
#if defined( SHADOW_PCF2X2 ) || defined( SHADOW_PCF3X3 )
	vec3 forward, right, up;

	forward = normalize( I );
	MakeNormalVectors( forward, right, up );

#if defined( SHADOW_PCF2X2 )
	float filterWidth = texel.x * length( I ) * 2.0;	// PCF2X2
#elif defined( SHADOW_PCF3X3 )
	float filterWidth = texel.x * length( I ) * 3.0;	// PCF3X3
#else
	float filterWidth = texel.x * length( I );	 // Hardware PCF1X1
#endif
	// compute step size for iterating through the kernel
	float stepSize = 4.0 * filterWidth / NUM_SAMPLES;

	float shadow = 0.0;

	for( float i = -filterWidth; i < filterWidth; i += stepSize )
	{
		for( float j = -filterWidth; j < filterWidth; j += stepSize )
		{
			shadow += depthCube( I + right * i + up * j, lightProjection );
		}
	}

	// return average of the samples
	shadow *= ( 4.0 / ( NUM_SAMPLES * NUM_SAMPLES ));

	return shadow;
#else
	return depthCube( I, lightProjection ); // fast path
#endif
}

#endif//SHADOW_OMNI_H