#pragma once

#include <string>
#include <iostream>
#include <stdio.h>

#include <GLFW/glfw3.h>
#include <GLFW/glfw3native.h>

#include "png.h"

struct image_t
{
	std::string path;

	int width;
	int height;
	int depth;
	size_t size;

	GLubyte* data;
	GLuint tex_id;
};

// It's about to get very Jack Kolb in here
bool load_png(std::string path, image_t& image)
{
	FILE* file = fopen(path.c_str(), "rb");
	if(file == NULL)
	{
		std::cerr << "error: failed to open " << path << std::endl;
		return false;
	}

	png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
	if(png == NULL)
	{
		std::cerr << "error: failed to create png_structp for " << path << std::endl;
		fclose(file);
		return false;
	}
	
	png_infop info = png_create_info_struct(png);
	if(info == NULL)
	{
		std::cerr << "error: failed to create png_infop for " << path << std::endl;
		png_destroy_read_struct(&png, NULL, NULL);
		fclose(file);
		return false;
	}

	if(setjmp(png_jmpbuf(png)))
	{
		std::cerr << "error: png_jmpbuf triggered for " << path << std::endl;
		png_destroy_read_struct(&png, &info, NULL);
		fclose(file);
		return false;
	}

	png_init_io(png, file);
	png_set_sig_bytes(png, 0);
	png_read_png(png, info, PNG_TRANSFORM_STRIP_16 | PNG_TRANSFORM_PACKING | PNG_TRANSFORM_EXPAND, NULL);

	png_uint_32 width;
	png_uint_32 height;
	int depth;
	int colour_type;
	int interlace_type;
	png_get_IHDR(png, info, &width, &height, &depth, &colour_type, &interlace_type, NULL, NULL);
	bool alpha = colour_type == PNG_COLOR_TYPE_RGBA || colour_type == PNG_COLOR_TYPE_GA;
	int row_size = png_get_rowbytes(png, info);
	int size = sizeof(GLubyte) * row_size * height;

	GLubyte* data = (GLubyte*) malloc(size);
	png_bytepp rows = png_get_rows(png, info);
	for(int i = 0; i < height; i++)
	{ memcpy(data + row_size * i, rows[i], row_size); }

	GLuint tex_id;
	glGenTextures(1, &tex_id);
	glBindTexture(GL_TEXTURE_2D, tex_id);
	glTexParameteri(tex_id, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(tex_id, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(tex_id, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(tex_id, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexImage2D(GL_TEXTURE_2D, 0, alpha ? GL_RGBA : GL_RGB, width, height, 0, alpha ? GL_RGBA : GL_RGB, GL_UNSIGNED_BYTE, data);
	glGenerateMipmap(GL_TEXTURE_2D);

	image.path = path;
	image.width = width;
	image.height = height;
	image.depth = depth;
	image.size = size;
	image.data = data;
	image.tex_id = tex_id;

	png_destroy_read_struct(&png, &info, NULL);
	fclose(file);
	return true;
}

