/**
 * Post decoding stage that display the decoded video in a GTK display
 * using Cairo
 */

#ifndef _DISPLAY_STAGE_H_
#define _DISPLAY_STAGE_H_ (1)

#include <ardrone_tool/Video/video_stage.h>
#include <inttypes.h>
#include <gtk/gtk.h>

typedef struct _display_stage_cfg_ {
    // PARAM
    float bpp;
    vp_api_picture_t *decoder_info;

    // INTERNAL
    uint8_t *frameBuffer;
    uint32_t fbSize;
    bool_t paramsOK;

    GtkWidget *widget;
} display_stage_cfg_t;

C_RESULT display_stage_open (display_stage_cfg_t *cfg);
C_RESULT display_stage_transform (display_stage_cfg_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out);
C_RESULT display_stage_close (display_stage_cfg_t *cfg);

extern const vp_api_stage_funcs_t display_stage_funcs;

#endif //_DISPLAY_STAGE_H_
