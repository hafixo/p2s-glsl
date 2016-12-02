/*
const.h - GLSL constants
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

#ifndef CONST_H
#define CONST_H

#define Z_NEAR			4.0

#define LUM_THRESHOLD		0.8
#define SHADOW_BIAS			0.001
#define DETAIL_SCALE		2.0
#define BUMP_SCALE			2.0
#define GLASS_SCALE			2.0
#define GRASS_SCALE			2.0
#define DLIGHT_SCALE		1.5
#define DECAL_SCALE			4.0
#define GLOSS_SCALE			2.0
#define SUN_SCALE			3.0

#define STUDIO_ALPHA_THRESHOLD	0.3
#define BMODEL_ALPHA_THRESHOLD	0.25

#define LIGHTMAP_SHIFT		(1.0 / 128.0)	// same as >> 7 in Quake
#define GLOSSMAP_SHIFT		(1.0 / 128.0)

#endif//CONST_H