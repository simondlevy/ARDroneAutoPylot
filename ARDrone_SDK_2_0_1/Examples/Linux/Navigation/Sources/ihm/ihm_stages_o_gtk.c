/*
 * @ihm_stages_o_gtk.c
 * @author marc-olivier.dzeukou@parrot.com
 * @date 2007/07/27
 *
 * ihm vision thread implementation
 *
 */
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <termios.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>

#include <gtk/gtk.h>
#include <gtk/gtkcontainer.h>
#include <sys/time.h>
#include <time.h>

#include <VP_Api/vp_api.h>
#include <VP_Api/vp_api_error.h>
#include <VP_Api/vp_api_stage.h>
#include <VP_Api/vp_api_picture.h>
#include <VP_Stages/vp_stages_io_file.h>
#ifdef USE_ELINUX
#include <VP_Stages/vp_stages_V4L2_i_camif.h>
#else
#include <VP_Stages/vp_stages_i_camif.h>
#endif

#include <VP_Os/vp_os_print.h>
#include <VP_Os/vp_os_malloc.h>
#include <VP_Os/vp_os_delay.h>
#include <VP_Stages/vp_stages_yuv2rgb.h>
#include <VP_Stages/vp_stages_buffer_to_picture.h>

#include <ardrone_tool/Video/video_stage.h>

#ifdef PC_USE_VISION
#include <Vision/vision_draw.h>
#include <Vision/vision_stage.h>
#endif

#include <config.h>


#include <ardrone_tool/ardrone_tool.h>
#include <ardrone_tool/Com/config_com.h>

#include "ihm/ihm.h"
#include "ihm/ihm_vision.h"
#include "ihm/ihm_stages_o_gtk.h"
#include "common/mobile_config.h"

#include <video_encapsulation.h>

extern GtkWidget *ihm_ImageWin, *ihm_ImageEntry[9], *ihm_ImageDA, *ihm_VideoStream_VBox;
/* For fullscreen video display */
extern GtkWindow *fullscreen_window;
extern GtkImage *fullscreen_image;
extern GdkScreen *fullscreen;

extern int tab_vision_config_params[10];
extern int vision_config_options;
extern int image_vision_window_view, image_vision_window_status;
extern char video_to_play[16];

static GtkImage *image = NULL;
static GdkPixbuf *pixbuf = NULL;
static GdkPixbuf *pixbuf2 = NULL;

static int32_t pixbuf_width = 0;
static int32_t pixbuf_height = 0;
static int32_t pixbuf_rowstride = 0;
static uint8_t* pixbuf_data = NULL;

int videoPauseStatus = 0;

float DEBUG_fps = 0.0;

const vp_api_stage_funcs_t vp_stages_output_gtk_funcs = {
    NULL,
    (vp_api_stage_open_t) output_gtk_stage_open,
    (vp_api_stage_transform_t) output_gtk_stage_transform,
    (vp_api_stage_close_t) output_gtk_stage_close
};

/* Widgets defined in other files */
extern GtkWidget * ihm_fullScreenFixedContainer;
extern GtkWidget * ihm_fullScreenHBox;
extern GtkWidget * video_information;

/* Information about the video pipeline stages */
extern video_com_multisocket_config_t icc;

extern parrot_video_encapsulation_codecs_t video_stage_decoder_lastDetectedCodec;

extern float DEBUG_nbSlices;
extern float DEBUG_totalSlices;
extern int DEBUG_missed;
extern float DEBUG_fps; // --> a calculer dans le ihm_stages_o_gtk.c
extern float DEBUG_bitrate;
extern float DEBUG_latency;
extern int DEBUG_isTcp;


C_RESULT output_gtk_stage_open(vp_stages_gtk_config_t *cfg)//, vp_api_io_data_t *in, vp_api_io_data_t *out)
{
    return (SUCCESS);
}

void destroy_image_callback(GtkWidget *widget, gpointer data) {
    image = NULL;
}

char video_information_buffer[1024];
int video_information_buffer_index = 0;

C_RESULT output_gtk_stage_transform(vp_stages_gtk_config_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out) {
    

    if (!ihm_is_initialized) return SUCCESS;
    if (ihm_ImageWin == NULL) return SUCCESS;
    if (image_vision_window_view != WINDOW_VISIBLE) return SUCCESS;


    gdk_threads_enter(); //http://library.gnome.org/devel/gdk/stable/gdk-Threads.html
    static struct timeval tvPrev = {0, 0}, tvNow = {0, 0};
    static int nbFramesForCalc = 1;
#define CALCULATE_EVERY_X_FRAMES 10
    if (0 == --nbFramesForCalc)
      {
        nbFramesForCalc = CALCULATE_EVERY_X_FRAMES;
        tvPrev.tv_sec = tvNow.tv_sec;
        tvPrev.tv_usec = tvNow.tv_usec;
        gettimeofday(&tvNow, NULL);
        if (0 != tvPrev.tv_sec) // Avoid first time calculation
          {
            float timeDiffMillis = ((tvNow.tv_sec - tvPrev.tv_sec) * 1000.0) + ((tvNow.tv_usec - tvPrev.tv_usec) / 1000.0);
            DEBUG_fps = (0.8 * DEBUG_fps) + (0.2 * ((1000.0 * CALCULATE_EVERY_X_FRAMES) / timeDiffMillis));
          }
      }

    video_decoder_config_t * dec_config;
    dec_config = (video_decoder_config_t *) cfg->last_decoded_frame_info;
    pixbuf_width = dec_config->src_picture->width;
    pixbuf_height = dec_config->src_picture->height;
    pixbuf_rowstride = dec_config->rowstride;
    pixbuf_data = (uint8_t*) in->buffers[in->indexBuffer];

    if (pixbuf != NULL) {
        g_object_unref(pixbuf);
        pixbuf = NULL;
    }

    pixbuf = gdk_pixbuf_new_from_data(pixbuf_data,
        GDK_COLORSPACE_RGB,
        FALSE,
        8,
        pixbuf_width,
        pixbuf_height,
        pixbuf_rowstride,
        NULL,
        NULL);

    if (fullscreen != NULL && fullscreen_window != NULL) {
        if (pixbuf2 != NULL) {
            g_object_unref(pixbuf2);
            pixbuf2 = NULL;
        }

        pixbuf2 = gdk_pixbuf_scale_simple(pixbuf,
            gdk_screen_get_width(fullscreen),
            gdk_screen_get_height(fullscreen),
            /*GDK_INTERP_HYPER*/
            cfg->gdk_interpolation_mode);
        /*if (fullscreen_image == NULL)
          {
          fullscreen_image  = (GtkImage*) gtk_image_new_from_pixbuf( pixbuf );
          //if (fullscreen_image == NULL) { printf("Probleme.\n"); }
          //gtk_container_add( GTK_CONTAINER( fullscreen_window ), GTK_WIDGET(fullscreen_image) );
          gtk_fixed_put(ihm_fullScreenFixedContainer,fullscreen_image,0,0);
          }*/
        if (fullscreen_image != NULL) {
            gtk_image_set_from_pixbuf(fullscreen_image, pixbuf2);
            //gtk_widget_show_all (GTK_WIDGET(fullscreen_window));
            gtk_widget_show(GTK_WIDGET(fullscreen_image));
            //gtk_widget_show(ihm_fullScreenHBox);
        }
    } else {

        if (cfg->desired_display_height != 0 && cfg->desired_display_width != 0) /* 0 and 0 means auto mode */ {
            if (pixbuf2 != NULL) {
                g_object_unref(pixbuf2);
                pixbuf2 = NULL;
            }

            pixbuf2 = gdk_pixbuf_scale_simple(pixbuf,
                cfg->desired_display_width,
                cfg->desired_display_height,
                cfg->gdk_interpolation_mode);
        } else {
            /* A copy of pixbuf is always made into pixbuf 2.
              If pixbuf is used directly, GTK renders the video from the buffer allocated by the FFMPEG decoding stage,
              which becomes invalid when the decoder is resetted (when a codec change occurs for example).
              This makes GTK crash.
              TODO : find a reliable way of rendering from the FFMPEG output buffer to avoid the data copy from pixbuf to pixbuf2
             */

            if (pixbuf2 != NULL) {
                g_object_unref(pixbuf2);
                pixbuf2 = NULL;
            }

            pixbuf2 = gdk_pixbuf_copy(pixbuf);
        }

        if (image == NULL && (pixbuf != NULL || pixbuf2 != NULL)) {
            image = (GtkImage*) gtk_image_new_from_pixbuf((pixbuf2) ? (pixbuf2) : (pixbuf));
            gtk_signal_connect(GTK_OBJECT(image), "destroy", G_CALLBACK(destroy_image_callback), NULL);
            if (GTK_IS_WIDGET(ihm_ImageWin))
                if (GTK_IS_WIDGET(ihm_VideoStream_VBox))
                    gtk_container_add(GTK_CONTAINER(ihm_VideoStream_VBox), (GtkWidget*) image);
        }
        if (image != NULL && (pixbuf != NULL || pixbuf2 != NULL)) {
            if (!videoPauseStatus) gtk_image_set_from_pixbuf(image, (pixbuf2) ? (pixbuf2) : (pixbuf));
        }
    }

    /*---- Display statistics ----*/


    float DEBUG_percentMiss = DEBUG_nbSlices * 100.0 /  DEBUG_totalSlices;


    video_information_buffer_index =
    			snprintf(video_information_buffer,
					sizeof(video_information_buffer),
					"%s - %s %dx%d\n",
					(icc.configs[icc.last_active_socket]->protocol == VP_COM_TCP)?"TCP":(icc.configs[icc.last_active_socket]->protocol == VP_COM_UDP)?"UDP":"?",
					/*codec*/
							(video_stage_decoder_lastDetectedCodec == CODEC_MPEG4_AVC )?"H.264":
							(video_stage_decoder_lastDetectedCodec == CODEC_MPEG4_VISUAL) ? "MP4":
							(video_stage_decoder_lastDetectedCodec == CODEC_VLIB) ? "VLIB":
							(video_stage_decoder_lastDetectedCodec == CODEC_P264) ? "P.264": "?",
							pixbuf_width,pixbuf_height
					);

    if (video_stage_decoder_lastDetectedCodec == CODEC_MPEG4_AVC )
    {
    	video_information_buffer_index+=
    			snprintf(video_information_buffer+video_information_buffer_index,
						sizeof(video_information_buffer)-video_information_buffer_index,
						"Mean missed slices :%6.3f/%2.0f (%5.1f%%)\nMissed frames : %10d\nFPS : %4.1f | Bitrate : %6.2f Kbps\nLatency : %5.1f ms | Protocol : %s",\
							DEBUG_nbSlices,
							DEBUG_totalSlices,
							DEBUG_percentMiss,
							DEBUG_missed,
							DEBUG_fps,
							DEBUG_bitrate,
							DEBUG_latency,
							(1 == DEBUG_isTcp) ? "TCP" : "UDP");

    }
    else
    {
    	video_information_buffer_index+=
    	    			snprintf(video_information_buffer+video_information_buffer_index,
    							sizeof(video_information_buffer)-video_information_buffer_index,
    							"Missed frames : %10d\nFPS : %4.1f | Bitrate : %6.2f Kbps\nLatency : %5.1f ms | Protocol : %s",\
    								DEBUG_missed,
    								DEBUG_fps,
    								DEBUG_bitrate,
    								DEBUG_latency,
    								(1 == DEBUG_isTcp) ? "TCP" : "UDP");

    }

    if (video_information){
		gtk_label_set_text((GtkLabel *)video_information,(const gchar*)video_information_buffer);
		gtk_label_set_justify((GtkLabel *)video_information,GTK_JUSTIFY_LEFT);
    }

    gtk_widget_show_all(ihm_ImageWin);
    gdk_threads_leave();


    return (SUCCESS);
}

C_RESULT output_gtk_stage_close(vp_stages_gtk_config_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out) {
    return (SUCCESS);
}

static vp_os_mutex_t draw_trackers_update;
/*static*/ vp_stages_draw_trackers_config_t draw_trackers_cfg = {0};

/*
void set_draw_trackers_config(vp_stages_draw_trackers_config_t* cfg) {
    void*v;
    vp_os_mutex_lock(&draw_trackers_update);
    v = draw_trackers_cfg.last_decoded_frame_info;
    vp_os_memcpy(&draw_trackers_cfg, cfg, sizeof (draw_trackers_cfg));
    draw_trackers_cfg.last_decoded_frame_info = v;
    vp_os_mutex_unlock(&draw_trackers_update);
}
*/

C_RESULT draw_trackers_stage_open(vp_stages_draw_trackers_config_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out) {
    vp_os_mutex_lock(&draw_trackers_update);

    int32_t i;
    for (i = 0; i < NUM_MAX_SCREEN_POINTS; i++) {
        cfg->locked[i] = C_OK;
    }

    PRINT("Draw trackers inited with %d trackers\n", cfg->num_points);

    vp_os_mutex_unlock(&draw_trackers_update);

    return (SUCCESS);
}

C_RESULT draw_trackers_stage_transform(vp_stages_draw_trackers_config_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out)
{
    int32_t i;
    video_decoder_config_t * dec_config;
    vp_api_picture_t * picture;
    int pixbuf_width;
    int pixbuf_height;

    dec_config = (video_decoder_config_t *) cfg->last_decoded_frame_info;
    pixbuf_width = dec_config->src_picture->width;
    pixbuf_height = dec_config->src_picture->height;

    vp_os_mutex_lock(&draw_trackers_update);

    picture = dec_config->dst_picture;
    picture->raw = in->buffers[in->indexBuffer];

    if (in->size > 0) {
#if defined DEBUG && 0
        for (i = 0; i < cfg->num_points; i++) {
            int32_t dist;
            uint8_t color;
            screen_point_t point;

            point = cfg->points[i];
            //       point.x += ACQ_WIDTH / 2;
            //       point.y += ACQ_HEIGHT / 2;

            if (point.x >= STREAM_WIDTH || point.x < 0 || point.y >= STREAM_HEIGHT || point.y < 0) {
                PRINT("Bad point (%d,%d) received at index %d on %d points\n", point.x, point.y, i, cfg->num_points);
                continue;
            }

            if (SUCCEED(cfg->locked[i])) {
                dist = 3;
                color = 0;
            } else {
                dist = 1;
                color = 0xFF;
            }

            vision_trace_cross(&point, dist, color, picture);
        }
#endif

        for (i = 0; i < cfg->detected; i++) {
            //uint32_t centerX,centerY;
            uint32_t width, height;
            screen_point_t center;
            if (cfg->last_decoded_frame_info != NULL) {

                center.x = cfg->patch_center[i].x * pixbuf_width / 1000;
                center.y = cfg->patch_center[i].y * pixbuf_height / 1000;
                width = cfg->width[i] * pixbuf_width / 1000;
                height = cfg->height[i] * pixbuf_height / 1000;

                width = min(2 * center.x, width);
                width = min(2 * (pixbuf_width - center.x), width) - 1;
                height = min(2 * center.y, height);
                width = min(2 * (pixbuf_height - center.y), height) - 1;


                trace_reverse_rgb_rectangle(dec_config->dst_picture,center, width, height);

            } else {
                printf("Problem drawing rectangle.\n");
            }
        }
    }

    vp_os_mutex_unlock(&draw_trackers_update);

    out->size = in->size;
    out->indexBuffer = in->indexBuffer;
    out->buffers = in->buffers;

    out->status = VP_API_STATUS_PROCESSING;

    return (SUCCESS);
}

C_RESULT draw_trackers_stage_close(vp_stages_draw_trackers_config_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out) {
    return (SUCCESS);
}

const vp_api_stage_funcs_t draw_trackers_funcs = {
    NULL,
    (vp_api_stage_open_t) draw_trackers_stage_open,
    (vp_api_stage_transform_t) draw_trackers_stage_transform,
    (vp_api_stage_close_t) draw_trackers_stage_close
};

static inline void reverse(uint8_t * x){
	uint8_t r=*(x);
	uint8_t g=*(x+1);
	uint8_t b=*(x+2);
	*(x)   = r+128;
	*(x+1) = g+128;
	*(x+2) = b+128;
}

void trace_reverse_rgb_h_segment(vp_api_picture_t * picture,int line,int start,int stop)
{
	int i;
	uint8_t *linepointer;
	if (line<0 || line>picture->height-1) return;
	linepointer = &picture->raw[3*picture->width*line];
	for ( i=max(start,0);  i<(picture->width-1) && i<stop ; i++ ) {
          reverse(&linepointer[3*i]);
	};
}

void trace_reverse_rgb_v_segment(vp_api_picture_t * picture,int column,int start,int stop)
{
	int i;
	uint8_t *columnpointer;
	if (column<0 || column>picture->width-1) return;
	columnpointer = &picture->raw[3*(picture->width*start+column)];
	for ( i=max(start,0);  i<(picture->height-1) && i<stop ; i++ ) {
		reverse(&columnpointer[0]);
		columnpointer+=3*picture->width;
	};
}

void trace_reverse_rgb_rectangle( vp_api_picture_t * picture,screen_point_t center, int width, int height)
{

	if (!picture) { return; }
	if (!picture->raw) { printf("NULL pointer\n");return; }
	/*if (PIX_FMT_RGB24!=picture->format) {
		printf("%s:%d - Invalid format : %d/%d\n",__FUNCTION__,__LINE__,PIX_FMT_BGR8,picture->format); return;
	};*/
	trace_reverse_rgb_h_segment(picture,center.y-height/2,center.x-width/2,center.x+width/2);
	trace_reverse_rgb_h_segment(picture,center.y+height/2,center.x-width/2,center.x+width/2);
	trace_reverse_rgb_v_segment(picture,center.x-width/2 ,center.y-height/2,center.y+height/2);
	trace_reverse_rgb_v_segment(picture,center.x+width/2 ,center.y-height/2,center.y+height/2);

	trace_reverse_rgb_h_segment(picture,center.y,center.x-width/4 ,center.x+width/4);
	trace_reverse_rgb_v_segment(picture,center.x,center.y-height/4,center.y+height/4);

}


