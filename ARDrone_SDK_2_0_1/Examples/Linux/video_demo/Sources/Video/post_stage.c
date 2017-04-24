/**
 * @file post_stage.c
 * @author nicolas.brulez@parrot.com
 * @date 2012/09/04
 */

#include "post_stage.h"

#include <ardrone_tool/ardrone_version.h>
#include <string.h>
#include <video_encapsulation.h>

const vp_api_stage_funcs_t post_stage_funcs = {
    NULL,
    (vp_api_stage_open_t) post_stage_open,
    (vp_api_stage_transform_t) post_stage_transform,
    (vp_api_stage_close_t) post_stage_close
};


C_RESULT post_stage_open (post_stage_cfg_t *cfg)
{
    cfg->outputFile = NULL;
    if (NULL != cfg->outputName && 0 < strlen (cfg->outputName))
    {
        cfg->outputFile = fopen (cfg->outputName, "wb");
    }
    return C_OK;
}

C_RESULT post_stage_transform (post_stage_cfg_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out)
{
    // Copy in to out
    out->size = in->size;
    out->status = in->status;
    out->buffers = in->buffers;
    out->indexBuffer = in->indexBuffer;
    //
    if (NULL != cfg->outputFile)
    {
        fwrite (in->buffers[in->indexBuffer], 1, in->size, cfg->outputFile);
    }

    return C_OK;
}

C_RESULT post_stage_close (post_stage_cfg_t *cfg)
{
    if (NULL != cfg->outputFile)
    {
        fclose (cfg->outputFile);
        cfg->outputFile = NULL;
    }
    return C_OK;
}
