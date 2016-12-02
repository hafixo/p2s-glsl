/*
mathlib.h - math subroutines for GLSL
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

#ifndef MATHLIB_H
#define MATHLIB_H

float saturate( float val ) { return clamp( val, 0.0, 1.0 ); }
vec2 saturate( vec2 val ) { return clamp( val, 0.0, 1.0 ); }
vec3 saturate( vec3 val ) { return clamp( val, 0.0, 1.0 ); }
vec4 saturate( vec4 val ) { return clamp( val, 0.0, 1.0 ); }

// remap a value in the range [A,B] to [C,D].
float RemapVal( float val, const in vec4 bounds )
{
	return bounds.z + (bounds.w - bounds.z) * (val - bounds.x) / (bounds.y - bounds.x);
}

// remap a value in the range [A,B] to [C,D].
float RemapVal( float val, float A, float B, float C, float D )
{
	return C + (D - C) * (val - A) / (B - A);
}

void MakeNormalVectors( const vec3 forward, inout vec3 right, inout vec3 up )
{
	// this rotate and negate guarantees a vector not colinear with the original
	right = vec3( forward.z, -forward.x, forward.y );
	right -= forward * dot( right, forward );
	up = cross( normalize( right ), forward );
}

// get support for classical and DXT5NM style normalmaps
vec3 normalmap2D( sampler2D tex, const vec2 uv )
{
	vec4 normalmap = texture2D( tex, uv );
	vec3 N;

#ifdef NORMALMAP_DXT5NM
	N.xy = ( 2.0 * ( normalmap.ag - 0.5 ));
	N.z = sqrt( clamp( 1.0 - dot( normalmap.xy, normalmap.xy ), 0.1, 1.0 ));
#else
	N = ( 2.0 * ( normalmap.xyz - 0.5 ));
#endif
	N = normalize( N );
	N.y = -N.y;
	return N;
}

float w0( float a ) { return (1.0 / 6.0) * (a * (a * (-a + 3.0) - 3.0) + 1.0); }
float w1( float a ) { return (1.0 / 6.0) * (a * a * (3.0 * a - 6.0) + 4.0); }
float w2( float a ) { return (1.0 / 6.0) * (a * (a * (-3.0 * a + 3.0) + 3.0) + 1.0); }
float w3( float a ) { return (1.0 / 6.0) * (a * a * a); }
float g0( float a ) { return w0( a ) + w1( a ); }
float g1( float a ) { return w2( a ) + w3( a ); }
float h0( float a ) { return -1.0 + w1( a ) / ( w0( a ) + w1( a )) + 0.5; }
float h1( float a ) { return 1.0 + w3( a ) / (w2( a ) + w3( a )) + 0.5; }

// bicubic interpolation
vec4 lightmap2D( sampler2D tex, vec2 uv )
{
	float res = 1024.0;
	
	float x = uv.x * res;
	float y = uv.y * res;
   
	x -= 0.5;
	y -= 0.5;  
	
	float px = floor( x );
	float py = floor( y );
	float fx = x - px;
	float fy = y - py;

	// note: we could store these functions in a lookup table texture, but maths is cheap
	float g0x = g0( fx );
	float g1x = g1( fx );
	float h0x = h0( fx );
	float h1x = h1( fx );
	float h0y = h0( fy );
	float h1y = h1( fy );

	return g0( fy ) * ( g0x * texture2D( tex, vec2( px + h0x, py + h0y ) * 1.0 / res )
	     + g1x * texture2D( tex, vec2( px + h1x, py + h0y ) * 1.0 / res ))
	     + g1( fy ) * ( g0x * texture2D( tex, vec2( px + h0x, py + h1y ) * 1.0 / res )
	     + g1x * texture2D( tex, vec2( px + h1x, py + h1y ) * 1.0 / res ));
}

float fresnel( const vec3 v, const vec3 n, float fresnelExp, float scale )
{
	return 0.001 + pow( 1.0 - max( dot( n, v ), 0.0 ), fresnelExp ) * scale;
}

// Box Projected Cube Environment Mapping by Bartosz Czuba
vec3 bpcem( in vec3 v, vec3 Emax, vec3 Emin, vec3 Epos, vec3 vertex )
{	
	vec3 nrdir = normalize( v );
	vec3 rbmax = (Emax - vertex) / nrdir;
	vec3 rbmin = (Emin - vertex) / nrdir;
	
	vec3 rbminmax;
	rbminmax.x = (nrdir.x > 0.0) ? rbmax.x : rbmin.x;
	rbminmax.y = (nrdir.y > 0.0) ? rbmax.y : rbmin.y;
	rbminmax.z = (nrdir.z > 0.0) ? rbmax.z : rbmin.z;		
	float fa = min( min( rbminmax.x, rbminmax.y ), rbminmax.z );
	vec3 posonbox = vertex + nrdir * fa;

	return posonbox - Epos;
}

vec3 ColorNormalize( const in vec3 color, float threshold )
{
	float	max, scale;
	vec3	ncolor;

	max = color.r;
	if( color.g > max )
		max = color.g;
	if( color.b > max )
		max = color.b;

	if( max == 0.0 )
		return color;

	scale = threshold / max;
	return color * scale;
}

float ColorHDRL( in vec3 color )
{
	vec2 lum = vec2( 0.65, 0.75 );	// fxied constant instead of adapation curve

	float Lp = ( 1.2 / lum.x ) * max( color.x, max( color.y, color.z ));
	float LmSqr = ( lum.y + 1.0 * lum.y ) * ( lum.y + 1.0 * lum.y );
	return ( Lp * ( 1.0 + ( Lp / ( LmSqr )))) / ( 1.0 + Lp );
}

vec3 ApplyGamma( in vec3 color, float gamma, float contrast )
{
	color.r = pow( color.r, gamma ) * contrast;
	color.g = pow( color.g, gamma ) * contrast;
	color.b = pow( color.b, gamma ) * contrast;

	return color;
}

float get_shadow_offset( in float lightCos )
{
	float bias = 0.0005 * tan( acos( saturate( lightCos )));
	return clamp( bias, 0.0, 0.005 );
}

vec2 GetTexCoordsForVertex( int vertexNum )
{
	if( vertexNum == 0 || vertexNum == 4 || vertexNum == 8 || vertexNum == 12 )
		return vec2( 0.0, 1.0 );
	else if( vertexNum == 1 || vertexNum == 5 || vertexNum == 9 || vertexNum == 13 )
		return vec2( 0.0, 0.0 );
	else if( vertexNum == 2 || vertexNum == 6 || vertexNum == 10 || vertexNum == 14 )
		return vec2( 1.0, 0.0 );
	return vec2( 1.0, 1.0 );
}

vec3 GetNormalForVertex( int vertexNum )
{
	if( vertexNum == 0 || vertexNum == 1 || vertexNum == 2 || vertexNum == 3 )
		return vec3( 0.0, 1.0, 0.0 );
	else if( vertexNum == 4 || vertexNum == 5 || vertexNum == 6 || vertexNum == 7 )
		return vec3( -1.0, 0.0, 0.0 );
	else if( vertexNum == 8 || vertexNum == 9 || vertexNum == 10 || vertexNum == 11 )
		return vec3( -0.707107, 0.707107, 0.0 );
	return vec3( 0.707107, 0.707107, 0.0 );
}

#endif//MATHLIB_H