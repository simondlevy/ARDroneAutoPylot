#ifndef _IHM_STAGES_O_GTK_H
#define _IHM_STAGES_O_GTK_H

#include <config.h>
#include <VP_Api/vp_api_thread_helper.h>
#include <VP_Api/vp_api.h>

//#ifdef PC_USE_VISION
//#include <Vision/vision_tracker_engine.h>
//#include <Vision/vision_patch_detect.h>
//#include <VLIB/video_controller.h>
//#include <ardrone_tool/Video/vlib_stage_decode.h>
#include <ardrone_tool/Video/video_stage_decoder.h>
//#endif

#define NUM_MAX_SCREEN_POINTS (DEFAULT_NB_TRACKERS_WIDTH * DEFAULT_NB_TRACKERS_HEIGHT)



typedef struct _vp_stages_draw_trackers_config_t
{
    int32_t num_points;
    uint32_t locked[NUM_MAX_SCREEN_POINTS];
    screen_point_t points[NUM_MAX_SCREEN_POINTS];

    uint32_t detected;
    //patch_ogb_type_t type[4];
    screen_point_t patch_center[4];
    uint32_t width[4];
    uint32_t height[4];

    video_decoder_config_t * last_decoded_frame_info;

} vp_stages_draw_trackers_config_t;

void set_draw_trackers_config(vp_stages_draw_trackers_config_t* cfg);

typedef struct _vp_stages_gtk_config_ {
    //  int max_width;
    //  int max_height;
    int rowstride;
    void * last_decoded_frame_info;
    int desired_display_width;
    int desired_display_height;
    int gdk_interpolation_mode;
} vp_stages_gtk_config_t;

C_RESULT output_gtk_stage_open(vp_stages_gtk_config_t *cfg);
C_RESULT output_gtk_stage_transform(vp_stages_gtk_config_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out);
C_RESULT output_gtk_stage_close(vp_stages_gtk_config_t *cfg , vp_api_io_data_t *in, vp_api_io_data_t *out);

C_RESULT draw_trackers_stage_open(vp_stages_draw_trackers_config_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out);
C_RESULT draw_trackers_stage_transform(vp_stages_draw_trackers_config_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out);
C_RESULT draw_trackers_stage_close(vp_stages_draw_trackers_config_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out);

extern const vp_api_stage_funcs_t vp_stages_output_gtk_funcs;
extern const vp_api_stage_funcs_t draw_trackers_funcs;

void destroy_image_callback(GtkWidget *widget, gpointer data);
void update_vision(void);


/* Functions to trace a rectangle around detected tags in the video window */
void trace_reverse_rgb_h_segment(vp_api_picture_t * picture,int line,int start,int stop);
void trace_reverse_rgb_v_segment(vp_api_picture_t * picture,int column,int start,int stop);
void trace_reverse_rgb_rectangle( vp_api_picture_t * picture,screen_point_t center, int width, int height);

#endif // _IHM_STAGES_O_GTK_H
