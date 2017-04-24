/**
 * Post decoding stage that dump the raw decoded video
 */

#ifndef _POST_STAGE_H_
#define _POST_STAGE_H_ (1)

#include <stdio.h>
#include <VP_Api/vp_api_stage.h>
#include <VP_Api/vp_api.h>

typedef struct _post_stage_cfg_ {
    // PARAM
    char outputName[256];
    // INTERNAL
    FILE *outputFile;
} post_stage_cfg_t;

C_RESULT post_stage_open (post_stage_cfg_t *cfg);
C_RESULT post_stage_transform (post_stage_cfg_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out);
C_RESULT post_stage_close (post_stage_cfg_t *cfg);

extern const vp_api_stage_funcs_t post_stage_funcs;

#endif // _POST_STAGE_H_
