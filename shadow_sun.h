/*
shadow_sun.h - shadow from directional source
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

#ifndef SHADOW_SUN_H
#define SHADOW_SUN_H

#include "mathlib.h"

#extension GL_EXT_gpu_shader4 : require

vec3 WorldToTexel( vec3 world, int split )
{
	vec4 pos = u_ShadowMatrix[split] * vec4( world, 1.0 );
	vec3 coord = vec3( pos.xyz / ( pos.w + 0.00005 )); // z-bias
	coord.x = float( clamp( float( coord.x ), u_TexelSize, 1.0 - u_TexelSize ));
	coord.y = float( clamp( float( coord.y ), u_TexelSize, 1.0 - u_TexelSize ));
	coord.z = float( clamp( float( coord.z ), 0.0, 1.0 ));

	return coord;
}

float ComputeShadowParallel( vec3 world, float lightCos )
{
	// transform to camera space
	vec4 cam = u_ViewMatrix * vec4( world.xyz, 1.0 );
	float vertexDistanceToCamera = -cam.z;
	vec3 shadowVert;
	float shadow;
	
#if (NUM_SHADOW_SPLITS == 1)
	if( vertexDistanceToCamera < u_ShadowSplitDist.x )
	{
		shadowVert = WorldToTexel( world, 0 );
		shadow = shadow2D( u_ShadowMap0, shadowVert.xyz ).r * 0.25;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( -1, -1)).r * 0.0625;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( -1, 0 )).r * 0.125;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( -1, 1 )).r * 0.0625;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( 0, -1 )).r * 0.125;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( 0, 1 )).r * 0.125;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( 1, -1 )).r * 0.0625;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( 1, 0 )).r * 0.125;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( 1, 1 )).r * 0.0625;
	}
	else
	{
		shadowVert = WorldToTexel( world, 1 );
		shadow = shadow2D( u_ShadowMap1, shadowVert.xyz ).r;
	}
#elif (NUM_SHADOW_SPLITS == 2)
	if( vertexDistanceToCamera < u_ShadowSplitDist.x )
	{
		shadowVert = WorldToTexel( world, 0 );
		shadow = shadow2D( u_ShadowMap0, shadowVert.xyz ).r * 0.25;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( -1, -1)).r * 0.0625;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( -1, 0 )).r * 0.125;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( -1, 1 )).r * 0.0625;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( 0, -1 )).r * 0.125;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( 0, 1 )).r * 0.125;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( 1, -1 )).r * 0.0625;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( 1, 0 )).r * 0.125;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( 1, 1 )).r * 0.0625;
	}
	else if( vertexDistanceToCamera < u_ShadowSplitDist.y )
	{
		shadowVert = WorldToTexel( world, 1 );
		shadow = shadow2D( u_ShadowMap1, shadowVert.xyz ).r;
		
	}
	else
	{
		shadowVert = WorldToTexel( world, 2 );
		shadow = shadow2D( u_ShadowMap2, shadowVert.xyz ).r;
	}
#elif (NUM_SHADOW_SPLITS == 3)
	if( vertexDistanceToCamera < u_ShadowSplitDist.x )
	{
		shadowVert = WorldToTexel( world, 0 );
		shadow = shadow2D( u_ShadowMap0, shadowVert.xyz ).r * 0.25;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( -1, -1)).r * 0.0625;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( -1, 0 )).r * 0.125;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( -1, 1 )).r * 0.0625;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( 0, -1 )).r * 0.125;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( 0, 1 )).r * 0.125;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( 1, -1 )).r * 0.0625;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( 1, 0 )).r * 0.125;
		shadow += shadow2DOffset( u_ShadowMap0, shadowVert.xyz, ivec2( 1, 1 )).r * 0.0625;
	}
	else if( vertexDistanceToCamera < u_ShadowSplitDist.y )
	{
		shadowVert = WorldToTexel( world, 1 );
		shadow = shadow2D( u_ShadowMap1, shadowVert.xyz ).r;
	}
	else if( vertexDistanceToCamera < u_ShadowSplitDist.z )
	{
		shadowVert = WorldToTexel( world, 2 );
		shadow = shadow2D( u_ShadowMap2, shadowVert.xyz ).r;
	}
	else
	{
		shadowVert = WorldToTexel( world, 3 );
		shadow = shadow2D( u_ShadowMap3, shadowVert.xyz ).r;
	}
#else
	{
		shadowVert = WorldToTexel( world, 0 );
		shadow = shadow2D( u_ShadowMap0, shadowVert.xyz ).r;
	}
#endif
	shadow = mix( 0.5, shadow, max( saturate( lightCos ) - 0.1, 0.0 ));


	return shadow;
}

#endif//SHADOW_SUN_H