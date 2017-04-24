/*
 *  opengl_stage.c
 *  Test
 *
 *  Created by Karl Leplat on 22/02/10.
 *  Copyright 2010 Parrot SA. All rights reserved.
 *
 */
#include "opengl_stage.h"
#include "time.h"

float DEBUG_fps = 0.0;

extern opengl_video_stage_config_t ovsc;

const vp_api_stage_funcs_t opengl_video_stage_funcs = {
	(vp_api_stage_handle_msg_t) NULL,
	(vp_api_stage_open_t) opengl_video_stage_open,
	(vp_api_stage_transform_t) opengl_video_stage_transform,
	(vp_api_stage_close_t) opengl_video_stage_close
};

C_RESULT opengl_video_stage_open(opengl_video_stage_config_t *cfg)
{
	vp_os_mutex_init(&cfg->mutex);
	return C_OK;
}

C_RESULT opengl_video_stage_transform(opengl_video_stage_config_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out)
{
    static struct timeval tvPrev = {0, 0}, tvNow = {0, 0};
    static int nbFramesForCalc = 1;
#define CALCULATE_EVERY_X_FRAMES 10
    if (0 == --nbFramesForCalc)
    {
        nbFramesForCalc = CALCULATE_EVERY_X_FRAMES;
        tvPrev.tv_sec = tvNow.tv_sec;
        tvPrev.tv_usec = tvNow.tv_usec;
        gettimeofday(&tvNow, NULL);
        if (0 != tvPrev.tv_sec) // Avoid first time calculation
        {
            float timeDiffMillis = ((tvNow.tv_sec - tvPrev.tv_sec) * 1000.0) + ((tvNow.tv_usec - tvPrev.tv_usec) / 1000.0);
            DEBUG_fps = (0.9 * DEBUG_fps) + (0.1 * ((1000.0 * CALCULATE_EVERY_X_FRAMES) / timeDiffMillis));
        }
    }
    
	vp_os_mutex_lock( &out->lock );
	if(out->status == VP_API_STATUS_INIT)
	{
		out->status = VP_API_STATUS_PROCESSING;
	}
		
	if(out->status == VP_API_STATUS_PROCESSING )
	{
		vp_os_mutex_lock( &cfg->mutex );

		if(cfg->video_decoder->num_picture_decoded > cfg->num_picture_decoded)
		{
            cfg->widthImage          = cfg->video_decoder->src_picture->width;
            cfg->heightImage         = cfg->video_decoder->src_picture->height;		
            cfg->widthTexture        = cfg->video_decoder->dst_picture->width;
            cfg->heightTexture       = cfg->video_decoder->dst_picture->height;
			switch(cfg->video_decoder->dst_picture->format)
			{
				case PIX_FMT_RGB565:
					cfg->bytesPerPixel		= 2;
					cfg->format = GL_RGB;
					cfg->type = GL_UNSIGNED_SHORT_5_6_5;
					break;
				
				case PIX_FMT_RGB24:
					cfg->bytesPerPixel		= 3;
					cfg->format = GL_RGB;
					cfg->type = GL_UNSIGNED_BYTE;
					break;
					
				default:
					cfg->bytesPerPixel		= 4;
					cfg->format = GL_RGBA;
					cfg->type = GL_UNSIGNED_BYTE;
					break;
			}
			
            if(cfg->data != in->buffers[in->indexBuffer])
               cfg->data = in->buffers[in->indexBuffer]; 
 
            cfg->num_picture_decoded = cfg->video_decoder->num_picture_decoded;

			out->numBuffers  = in->numBuffers;
			out->indexBuffer = in->indexBuffer;
			out->buffers	 = in->buffers;
			out->size        = in->size;
		}

		vp_os_mutex_unlock( &cfg->mutex );
	}
	
	vp_os_mutex_unlock( &out->lock );

	return C_OK;
}

C_RESULT opengl_video_stage_close(opengl_video_stage_config_t *cfg)
{
	vp_os_mutex_destroy(&cfg->mutex);
	return C_OK;
}

opengl_video_stage_config_t* opengl_video_stage_get(void)
{
	return &ovsc;
}
