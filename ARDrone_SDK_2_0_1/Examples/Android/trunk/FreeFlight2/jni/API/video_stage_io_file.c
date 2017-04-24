/**
 *  \brief    File stage declaration
 *  \author   D'HAEYER Frédéric <frederic.dhaeyer@parrot.com>
 *  \date     14/06/2011
 */
///////////////////////////////////////////////
// INCLUDES
#include <VP_Api/vp_api_error.h>
#include <VP_Os/vp_os_assert.h>
#include <VP_Os/vp_os_print.h>
#include <VP_Os/vp_os_delay.h>
#include <VP_Os/vp_os_malloc.h>
#include <video_stage_io_file.h>

const vp_api_stage_funcs_t video_stage_io_file_funcs =
{
  (vp_api_stage_handle_msg_t) NULL,
  (vp_api_stage_open_t) video_stage_io_file_stage_open,
  (vp_api_stage_transform_t) video_stage_io_file_stage_transform,
  (vp_api_stage_close_t) video_stage_io_file_stage_close
};

C_RESULT
video_stage_io_file_stage_open(video_stage_io_file_config_t *cfg)
{
	C_RESULT result = C_OK;
    cfg->max_size = 0;
	cfg->f = fopen(cfg->filename, "rb");

	if(cfg->f == NULL)
	{
		PRINT("Missing input file\n");
		result = C_FAIL;
	}
	return result;
}

C_RESULT
video_stage_io_file_stage_transform(video_stage_io_file_config_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out)
{
  vp_os_mutex_lock(&out->lock);

  if( out->status == VP_API_STATUS_INIT )
  {
    out->numBuffers =  1;
    out->indexBuffer = 0;
    out->buffers = (uint8_t **) vp_os_malloc (sizeof(uint8_t *));
    out->buffers[out->indexBuffer] = (uint8_t *)NULL;
    out->status = VP_API_STATUS_PROCESSING;
    cfg->buffers = (int8_t **)out->buffers;
  }

  if(out->status == VP_API_STATUS_PROCESSING)
  {
	  out->size = 0;
	  if(!feof(cfg->f))
	  {
 		  if((fread(&out->size, sizeof(int32_t), 1, cfg->f) > 0) && (out->size > 0))
		  {
			  if(out->size > cfg->max_size)
			  {
				  cfg->max_size = out->size;
				  out->buffers[out->indexBuffer] = (uint8_t *)vp_os_realloc(out->buffers[out->indexBuffer], sizeof(uint8_t) * cfg->max_size);
			  }
	
			  if(!fread(out->buffers[out->indexBuffer], sizeof(uint8_t), out->size, cfg->f) == out->size)
                  out->status = VP_API_STATUS_ENDED;
		  }
          else
          {
              out->size = 1;
              out->status = VP_API_STATUS_ENDED;
          }
	  }
      else
      {
          out->size = 1;
          out->status = VP_API_STATUS_ENDED;
      }
  }
    
  vp_os_mutex_unlock(&out->lock);
  return C_OK;
}

C_RESULT
video_stage_io_file_stage_close(video_stage_io_file_config_t *cfg)
{
  fclose(cfg->f);
  cfg->f = NULL;
  
  if(cfg->buffers[0] != NULL)
  {
      vp_os_free(cfg->buffers[0]);
      cfg->buffers[0] = NULL;
  }

  vp_os_free(cfg->buffers);
  cfg->buffers = NULL;
  
  return C_OK;
}
