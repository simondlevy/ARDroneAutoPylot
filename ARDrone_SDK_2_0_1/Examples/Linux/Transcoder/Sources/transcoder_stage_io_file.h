/**
 *  \brief    File stage declaration
 *  \author   D'HAEYER Frédéric <frederic.dhaeyer@parrot.com>
 *  \date     14/06/2011
 */
#ifndef _TRANSCODER_STAGE_IO_FILE_H_
#define _TRANSCODER_STAGE_IO_FILE_H_

#include <VP_Api/vp_api.h>
#include <stdio.h>

typedef struct _transcoder_stage_io_file_config_t_
{
	// Public
	char *filename;

	// Private
	FILE *f;
    int8_t **buffers;
    int32_t max_size;
} transcoder_stage_io_file_config_t;

///////////////////////////////////////////////
// FUNCTIONS
/**
 * @fn      Open the input file stage
 * @param   transcoder_stage_io_file_config_t *cfg
 * @return  VP_SUCCESS
 */
C_RESULT
transcoder_stage_io_file_stage_open(transcoder_stage_io_file_config_t *cfg);

/**
 * @fn      Transform the input file stage
 * @param   transcoder_stage_io_file_config_t *cfg
 * @param   vp_api_io_data_t *in
 * @param   vp_api_io_data_t *out
 * @return  VP_SUCCESS
 */
C_RESULT
transcoder_stage_io_file_stage_transform(transcoder_stage_io_file_config_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out);

/**
 * @fn      Close the input file stage
 * @param   transcoder_stage_io_file_config_t *cfg
 * @return  VP_SUCCESS
 */
C_RESULT
transcoder_stage_io_file_stage_close(transcoder_stage_io_file_config_t *cfg);

extern const vp_api_stage_funcs_t transcoder_stage_io_file_funcs;

#endif // ! _TRANSCODER_STAGE_IO_FILE_H_
