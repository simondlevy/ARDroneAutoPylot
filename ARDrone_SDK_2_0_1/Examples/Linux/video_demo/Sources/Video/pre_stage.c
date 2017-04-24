/**
 * @file pre_stage.c
 * @author nicolas.brulez@parrot.com
 * @date 2012/09/04
 */

#include "pre_stage.h"

#include <ardrone_tool/ardrone_version.h>
#include <string.h>
#include <video_encapsulation.h>

const vp_api_stage_funcs_t pre_stage_funcs = {
    NULL,
    (vp_api_stage_open_t) pre_stage_open,
    (vp_api_stage_transform_t) pre_stage_transform,
    (vp_api_stage_close_t) pre_stage_close
};

bool_t hasPaVE (uint8_t *buffer)
{
    bool_t retVal = FALSE;
    parrot_video_encapsulation_t *PaVE = (parrot_video_encapsulation_t *)buffer;
    if (0 == strncmp ("PaVE", (char *)PaVE->signature, 4))
    {
        retVal = TRUE;
    }
    return retVal;
}

C_RESULT pre_stage_open (pre_stage_cfg_t *cfg)
{
    cfg->outputFile = NULL;
    if (NULL != cfg->outputName && 0 < strlen (cfg->outputName))
    {
        cfg->outputFile = fopen (cfg->outputName, "wb");
    }
    return C_OK;
}

C_RESULT pre_stage_transform (pre_stage_cfg_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out)
{
    // Copy in to out
    out->size = in->size;
    out->status = in->status;
    out->buffers = in->buffers;
    out->indexBuffer = in->indexBuffer;
    //
    if (NULL != cfg->outputFile)
    {
        if (hasPaVE (in->buffers[in->indexBuffer])) // AR.Drone 2
        {
            parrot_video_encapsulation_t *PaVE = (parrot_video_encapsulation_t *)in->buffers[in->indexBuffer];
            uint8_t *videoData = &(in->buffers[in->indexBuffer][PaVE->header_size]);
            uint32_t videoSize = PaVE->payload_size;
            fwrite (videoData, 1, videoSize, cfg->outputFile);
        }
        else // AR.Drone 1
        {
            fwrite (in->buffers[in->indexBuffer], 1, in->size, cfg->outputFile);
        }
    }

    return C_OK;
}

C_RESULT pre_stage_close (pre_stage_cfg_t *cfg)
{
    if (NULL != cfg->outputFile)
    {
        fclose (cfg->outputFile);
        cfg->outputFile = NULL;
    }
    return C_OK;
}
