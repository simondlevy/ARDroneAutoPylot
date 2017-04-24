/**
 *  \brief    File stage declaration
 *  \author   D'HAEYER Frédéric <frederic.dhaeyer@parrot.com>
 *  \date     14/06/2011
 */
#ifndef _VIDEO_STAGE_IO_FILE_H_
#define _VIDEO_STAGE_IO_FILE_H_

#include <VP_Api/vp_api.h>
#include <stdio.h>

typedef struct _video_stage_io_file_config_t_
{
	// Public
	char *filename;

	// Private
	FILE *f;
    int8_t **buffers;
    int32_t max_size;
} video_stage_io_file_config_t;

///////////////////////////////////////////////
// FUNCTIONS
/**
 * @fn      Open the input file stage
 * @param   video_stage_io_file_config_t *cfg
 * @return  VP_SUCCESS
 */
C_RESULT
video_stage_io_file_stage_open(video_stage_io_file_config_t *cfg);

/**
 * @fn      Transform the input file stage
 * @param   video_stage_io_file_config_t *cfg
 * @param   vp_api_io_data_t *in
 * @param   vp_api_io_data_t *out
 * @return  VP_SUCCESS
 */
C_RESULT
video_stage_io_file_stage_transform(video_stage_io_file_config_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out);

/**
 * @fn      Close the input file stage
 * @param   video_stage_io_file_config_t *cfg
 * @return  VP_SUCCESS
 */
C_RESULT
video_stage_io_file_stage_close(video_stage_io_file_config_t *cfg);

extern const vp_api_stage_funcs_t video_stage_io_file_funcs;

#endif // ! _VIDEO_STAGE_IO_FILE_H_
