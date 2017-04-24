/**
 * Pre decoding stage that dump the raw encoded Drone 2 video
 * Don't do anything on AR.Drone 1
 */

#ifndef _PRE_STAGE_H_
#define _PRE_STAGE_H_ (1)

#include <stdio.h>
#include <VP_Api/vp_api_stage.h>
#include <VP_Api/vp_api.h>

typedef struct _pre_stage_cfg_ {
    // PARAM
    char outputName[256];
    // INTERNAL
    FILE *outputFile;
} pre_stage_cfg_t;

C_RESULT pre_stage_open (pre_stage_cfg_t *cfg);
C_RESULT pre_stage_transform (pre_stage_cfg_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out);
C_RESULT pre_stage_close (pre_stage_cfg_t *cfg);

extern const vp_api_stage_funcs_t pre_stage_funcs;

#endif // _PRE_STAGE_H_
