/*
 *  video_stage.c
 *  Test
 *
 *  Created by Frédéric D'HAEYER on 22/02/10.
 *  Copyright 2010 Parrot SA. All rights reserved.
 *
 */
#include <VP_Api/vp_api.h>
#include <VP_Api/vp_api_error.h>
#include <VP_Api/vp_api_stage.h>
#include <VP_Api/vp_api_picture.h>
#include <VP_Api/vp_api_thread_helper.h>

#include <VLIB/Stages/vlib_stage_decode.h>

#include <VP_Os/vp_os_print.h>
#include <VP_Os/vp_os_malloc.h>
#include <VP_Os/vp_os_delay.h>

#include <config.h>

#include <transcoder_stage_io_file.h>

#ifdef RECORD_RAW_VIDEO
#include <ardrone_tool/Video/video_stage_recorder.h>
video_stage_recorder_config_t           vrc;
#endif

#if defined(FFMPEG_SUPPORT) && defined(RECORD_FFMPEG_VIDEO)
#include <ardrone_tool/Video/video_stage_ffmpeg_recorder.h>
video_stage_ffmpeg_recorder_config_t    ffmpeg_vrc;
#endif

#define VIDEO_FILE_DEFAULT_PATH root_dir
extern char root_dir[];

#define NB_STAGES 5

PIPELINE_HANDLE transcoder_pipeline_handle;

bool_t ardrone_tool_exit()
{
	return TRUE;
}

int main(int argc, char** argv)
{
	C_RESULT res;
	vp_api_io_pipeline_t    pipeline;
	vp_api_io_data_t        out;
	vp_api_io_stage_t       stages[NB_STAGES];
	
	vp_api_picture_t picture;
	vlib_stage_decoding_config_t    vec;
	transcoder_stage_io_file_config_t ifc;

	if(argc != 2)
	{
		printf("Usage : %s <encoded file>", argv[0]);
	}
	else
	{
		vp_os_memset(&vec,          0, sizeof( vec ));
		vp_os_memset(&picture,      0, sizeof( picture ));

		/// Picture configuration
		picture.format        = PIX_FMT_YUV420P;
		picture.width         = STREAM_WIDTH;
		picture.height        = STREAM_HEIGHT;
		picture.framerate     = 20;

		picture.y_buf   = vp_os_malloc( STREAM_WIDTH * STREAM_HEIGHT     );
		picture.cr_buf  = vp_os_malloc( STREAM_WIDTH * STREAM_HEIGHT / 4 );
		picture.cb_buf  = vp_os_malloc( STREAM_WIDTH * STREAM_HEIGHT / 4 );

		picture.y_line_size   = STREAM_WIDTH;
		picture.cb_line_size  = STREAM_WIDTH / 2;
		picture.cr_line_size  = STREAM_WIDTH / 2;

		vp_os_memset(&ifc,          0, sizeof( ifc ));
		vp_os_memset(&vec,          0, sizeof( vec ));

		ifc.filename = argv[1];

		vec.width               = STREAM_WIDTH;
		vec.height              = STREAM_HEIGHT;
		vec.picture             = &picture;
#ifdef USE_VIDEO_YUV
		vec.luma_only           = FALSE;
#else
		vec.luma_only           = TRUE;
#endif // USE_VIDEO_YUV
		vec.block_mode_enable   = TRUE;

		vec.luma_only           = FALSE;

#ifdef RECORD_RAW_VIDEO
		vp_os_memset(&vrc,			0, sizeof( vrc ));
#endif

#if defined(FFMPEG_SUPPORT) && defined(RECORD_FFMPEG_VIDEO)
		vp_os_memset(&ffmpeg_vrc, 0, sizeof( ffmpeg_vrc ));
		strcpy(ffmpeg_vrc.video_filename, root_dir);
		strcat(ffmpeg_vrc.video_filename, "/");
		strcpy(ffmpeg_vrc.video_filename, argv[1]);
		strcat(ffmpeg_vrc.video_filename, ".mp4");
		ffmpeg_vrc.numframes = &vec.controller.num_frames;
#endif

		pipeline.nb_stages = 0;

		stages[pipeline.nb_stages].type    = VP_API_INPUT_FILE;
		stages[pipeline.nb_stages].cfg     = (void *)&ifc;
		stages[pipeline.nb_stages++].funcs = transcoder_stage_io_file_funcs;
	
		stages[pipeline.nb_stages].type    = VP_API_FILTER_DECODER;
		stages[pipeline.nb_stages].cfg     = (void*)&vec;
		stages[pipeline.nb_stages++].funcs = vlib_decoding_funcs;

#ifdef RECORD_RAW_VIDEO
		vrc.dest.pipeline = transcoder_pipeline_handle;
		vrc.dest.stage = pipeline.nb_stages;
		stages[pipeline.nb_stages].type    = VP_API_FILTER_DECODER;
		stages[pipeline.nb_stages].cfg     = (void*)&vrc;
		stages[pipeline.nb_stages++].funcs   = video_recorder_funcs;
#endif

#if defined(FFMPEG_SUPPORT) && defined(RECORD_FFMPEG_VIDEO)
		ffmpeg_vrc.dest.pipeline = transcoder_pipeline_handle;
		ffmpeg_vrc.dest.stage = pipeline.nb_stages;
		stages[pipeline.nb_stages].type    = VP_API_FILTER_DECODER;
		stages[pipeline.nb_stages].cfg     = (void*)&ffmpeg_vrc;
		stages[pipeline.nb_stages++].funcs   = video_ffmpeg_recorder_funcs;
#endif

		pipeline.stages = &stages[0];

		res = vp_api_open(&pipeline, &transcoder_pipeline_handle);

		if( SUCCEED(res) )
		{
			int loop = SUCCESS;
			out.status = VP_API_STATUS_PROCESSING;
#ifdef RECORD_RAW_VIDEO
			vp_api_post_message( vrc.dest, PIPELINE_MSG_START, NULL, (void*)NULL);
#endif			

#if defined(FFMPEG_SUPPORT) && defined(RECORD_FFMPEG_VIDEO)
			vp_api_post_message( ffmpeg_vrc.dest, PIPELINE_MSG_START, NULL, (void*)NULL);
#endif
			while( loop == SUCCESS )
			{
				if( SUCCEED(vp_api_run(&pipeline, &out)) ) {
					if( (out.status == VP_API_STATUS_PROCESSING || out.status == VP_API_STATUS_STILL_RUNNING) ) {
						loop = SUCCESS;
					}
				}
				else loop = -1; // Finish this thread
			}

			vp_api_close(&pipeline, &transcoder_pipeline_handle);
		}
	}
	
	return 0;
}

DEFINE_THREAD_ROUTINE(not_used, data)
{
	return (THREAD_RET)0;
}

/* Implementing thread table in which you add routines of your application and those provided by the SDK */
BEGIN_THREAD_TABLE
THREAD_TABLE_ENTRY(not_used, 20)
END_THREAD_TABLE

