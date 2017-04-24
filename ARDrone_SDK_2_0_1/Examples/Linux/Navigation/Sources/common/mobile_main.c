/**
 * @file mobile_main.c
 * @author aurelien.morelle@parrot.com & sylvain.gaeremynck@parrot.com
 * @date 2006/05/01
 */

#include <ATcodec/ATcodec_api.h>

#include <ardrone_tool/ardrone_version.h>
#include <ardrone_tool/ardrone_tool.h>
#include <ardrone_tool/ardrone_tool_configuration.h>
#include <ardrone_tool/Control/ardrone_control.h>
#include <ardrone_tool/Navdata/ardrone_navdata_client.h>
#include <ardrone_tool/Com/config_com.h>

#include <common/mobile_config.h>
#include <ihm/ihm.h>
#include <ihm/ihm_stages_o_gtk.h>
#include <navdata_client/navdata_client.h>
#include <ardrone_tool/Video/video_stage.h>
#include <ardrone_tool/Video/video_recorder_pipeline.h>

#ifdef RECORD_RAW_VIDEO
#include <ardrone_tool/Video/video_stage_recorder.h>
video_stage_recorder_config_t           vrc;
#endif

#if defined(FFMPEG_SUPPORT) && defined(RECORD_FFMPEG_VIDEO)
#include <ardrone_tool/Video/video_stage_ffmpeg_recorder.h>
video_stage_ffmpeg_recorder_config_t    ffmpeg_vrc;
#endif

vp_stages_latency_estimation_config_t vlat;
vp_stages_gtk_config_t gtkconf;
extern video_decoder_config_t vec;
extern vp_stages_draw_trackers_config_t draw_trackers_cfg;

#ifdef USE_ARDRONE_VICON
#include <libViconDataStreamSDK/vicon.h>
#endif // USE_ARDRONE_VICON

#ifdef PC_USE_POLARIS
#include <libPolaris/polaris.h>
#endif // PC_USE_POLARIS

#ifdef USE_TABLE_PILOTAGE
#include "libTestBenchs/novadem.h"
#endif // USE_TABLE_PILOTAGE

#ifdef RAW_CAPTURE
PROTO_THREAD_ROUTINE(raw_capture, params);
#endif
PROTO_THREAD_ROUTINE(remote_console, params);

static mobile_config_t cfg;

static int32_t exit_ihm_program = 1;

extern Controller_info *default_control;
extern GList *devices;

#define CONTROL_C_HANDLER_USES_ARDRONE_TOOL_EXIT (1)

C_RESULT signal_exit() {
    exit_ihm_program = 0;

    ihm_destroyCurves();

    return C_OK;
}

void controlCHandler (int signal)
{
	static int callCounter=0;

	callCounter++;

	/* In case GTK in unresponsive, force killing the application */
	if(callCounter>3){
		printf("Ctrl-C pressed several times. Killing the application ...\n");
		exit(-1);
	}

#if CONTROL_C_HANDLER_USES_ARDRONE_TOOL_EXIT
    gtk_main_quit ();
    signal_exit ();
#else
    // Flush all streams before terminating
    fflush (NULL);
    usleep (200000); // Wait 200 msec to be sure that flush occured
    printf ("\nAll files were flushed\n");
    exit (0);
#endif
}

int main(int argc, char** argv)
{
	printf("AR.Drone Navigation - build %s %s\n\n",__DATE__,__TIME__);
	gtk_init(&argc, &argv);
    signal (SIGABRT, &controlCHandler);
    signal (SIGTERM, &controlCHandler);
    signal (SIGINT, &controlCHandler);
	return ardrone_tool_main(argc, argv);
}

C_RESULT ardrone_tool_init_custom(void) {
    ardrone_application_default_config.navdata_options = NAVDATA_OPTION_FULL_MASK /*&
        ~(NAVDATA_OPTION_MASK(NAVDATA_TRACKERS_SEND_TAG)
        | NAVDATA_OPTION_MASK(NAVDATA_VISION_OF_TAG)
        | NAVDATA_OPTION_MASK(NAVDATA_VISION_PERF_TAG)
        | NAVDATA_OPTION_MASK(NAVDATA_VISION_TAG))*/;

    if (IS_ARDRONE2)
    {
        ardrone_application_default_config.video_codec = H264_360P_CODEC;
    }
    else
    {
        ardrone_application_default_config.video_codec = UVLC_CODEC;
    }
    ardrone_application_default_config.bitrate_ctrl_mode = 1;

    /// Init specific code for application
    ardrone_navdata_handler_table[NAVDATA_IHM_PROCESS_INDEX].data = &cfg;

    // Add inputs
    //ardrone_tool_input_add( &gamepad );
    /*ardrone_tool_input_add( &radioGP );
    ardrone_tool_input_add( &ps3pad );
    ardrone_tool_input_add( &joystick );
    ardrone_tool_input_add( &wiimote_device );*/


    load_ini();
    printf("Default control : %s (0x%08x, %s)\n", default_control->name, default_control->serial, default_control->filename);
    ardrone_tool_input_add(&control_device);
    cfg.default_control = default_control;
    cfg.devices = devices;

#ifdef USE_ARDRONE_VICON
    START_THREAD(vicon, &cfg);
#endif // USE_ARDRONE_VICON

    START_THREAD(ihm, &cfg);
#ifdef RAW_CAPTURE
    START_THREAD(raw_capture, &cfg);
#endif
    START_THREAD(remote_console, &cfg);

    /************************ VIDEO STAGE CONFIG ******************************/
    #define NB_NAVIGATION_POST_STAGES   10
    uint8_t post_stages_index = 0;

    //Alloc structs
    specific_parameters_t * params             = (specific_parameters_t *)vp_os_calloc(1,sizeof(specific_parameters_t));
    specific_stages_t * navigation_pre_stages  = (specific_stages_t*)vp_os_calloc(1, sizeof(specific_stages_t));
    specific_stages_t * navigation_post_stages = (specific_stages_t*)vp_os_calloc(1, sizeof(specific_stages_t));
    vp_api_picture_t  * in_picture             = (vp_api_picture_t*) vp_os_calloc(1, sizeof(vp_api_picture_t));
    vp_api_picture_t  * out_picture            = (vp_api_picture_t*) vp_os_calloc(1, sizeof(vp_api_picture_t));

    in_picture->width          = STREAM_WIDTH;
    in_picture->height         = STREAM_HEIGHT;

    out_picture->framerate     = 20;
    out_picture->format        = PIX_FMT_RGB24;
    out_picture->width         = STREAM_WIDTH;
    out_picture->height        = STREAM_HEIGHT;

    out_picture->y_buf         = vp_os_malloc( STREAM_WIDTH * STREAM_HEIGHT * 3 );
    out_picture->cr_buf        = NULL;
    out_picture->cb_buf        = NULL;

    out_picture->y_line_size   = STREAM_WIDTH * 3;
    out_picture->cb_line_size  = 0;
    out_picture->cr_line_size  = 0;

    //Alloc the lists
    navigation_pre_stages->stages_list  = NULL;
    navigation_post_stages->stages_list = (vp_api_io_stage_t*)vp_os_calloc(NB_NAVIGATION_POST_STAGES,sizeof(vp_api_io_stage_t));

    //Fill the POST-stages------------------------------------------------------
    vp_os_memset(&vlat,         0, sizeof( vlat ));
    vlat.state = 0;
    vlat.last_decoded_frame_info = (void*)&vec;
    navigation_post_stages->stages_list[post_stages_index].name    = "(latency estimator)";
    navigation_post_stages->stages_list[post_stages_index].type    = VP_API_FILTER_DECODER;
    navigation_post_stages->stages_list[post_stages_index].cfg     = (void*)&vlat;
    navigation_post_stages->stages_list[post_stages_index++].funcs = vp_stages_latency_estimation_funcs;

    #ifdef RECORD_RAW_VIDEO
    vp_os_memset(&vrc,         0, sizeof( vrc ));
    #warning Recording RAW video option enabled in Navigation.
    vrc.stage = 3;
    #warning We have to get the stage number an other way
    vp_os_memset(&vrc, 0, sizeof(vrc));
    navigation_post_stages->stages_list[post_stages_index].name    = "(raw video recorder)";
    navigation_post_stages->stages_list[post_stages_index].type    = VP_API_FILTER_DECODER;
    navigation_post_stages->stages_list[post_stages_index].cfg     = (void*)&vrc;
    navigation_post_stages->stages_list[post_stages_index++].funcs   = video_recorder_funcs;
    #endif // RECORD_RAW_VIDEO


    #if defined(FFMPEG_SUPPORT) && defined(RECORD_FFMPEG_VIDEO)
    #warning Recording FFMPEG (reencoding)video option enabled in Navigation.
    vp_os_memset(&ffmpeg_vrc, 0, sizeof(ffmpeg_vrc));
    ffmpeg_vrc.numframes = &vec.controller.num_frames;
    ffmpeg_vrc.stage = pipeline.nb_stages;
    navigation_post_stages->stages_list[post_stages_index].name    = "(ffmpeg recorder)";
    navigation_post_stages->stages_list[post_stages_index].type    = VP_API_FILTER_DECODER;
    navigation_post_stages->stages_list[post_stages_index].cfg     = (void*)&ffmpeg_vrc;
    navigation_post_stages->stages_list[post_stages_index++].funcs   = video_ffmpeg_recorder_funcs;
    #endif


    vp_os_memset(&draw_trackers_cfg,         0, sizeof( draw_trackers_funcs ));
    draw_trackers_cfg.last_decoded_frame_info = (void*)&vec;
    navigation_post_stages->stages_list[post_stages_index].type    = VP_API_FILTER_DECODER;
    navigation_post_stages->stages_list[post_stages_index].cfg     = (void*)&draw_trackers_cfg;
    navigation_post_stages->stages_list[post_stages_index++].funcs   = draw_trackers_funcs;


    vp_os_memset(&gtkconf,         0, sizeof( gtkconf ));
    gtkconf.rowstride               = out_picture->width * 3;
    gtkconf.last_decoded_frame_info = (void*)&vec;
    gtkconf.desired_display_width   = 0;  /* auto */
    gtkconf.desired_display_height  = 0;  /* auto */
    gtkconf.gdk_interpolation_mode  = 0;  /* fastest */
    navigation_post_stages->stages_list[post_stages_index].name    = "(Gtk display)";
    navigation_post_stages->stages_list[post_stages_index].type    = VP_API_OUTPUT_SDL;
    navigation_post_stages->stages_list[post_stages_index].cfg     = (void*)&gtkconf;
    navigation_post_stages->stages_list[post_stages_index++].funcs   = vp_stages_output_gtk_funcs;

    //Define the list of stages size
    navigation_pre_stages->length  = 0;
    navigation_post_stages->length = post_stages_index;

    params->in_pic = in_picture;
    params->out_pic = out_picture;
    params->pre_processing_stages_list  = navigation_pre_stages;
    params->post_processing_stages_list = navigation_post_stages;
    params->needSetPriority = 0;
    params->priority = 0;

    START_THREAD(video_stage, params);
    video_stage_init();
    if (2 <= ARDRONE_VERSION ())
      {
        START_THREAD (video_recorder, NULL);
        video_recorder_init ();
      }
    else
      {
        printf ("Don't start ... version is %d\n", ARDRONE_VERSION ());
      }

    /************************ END OF VIDEO STAGE CONFIG ***********************/

#ifdef PC_USE_POLARIS
    START_THREAD(polaris, &cfg);
#endif // PC_USE_POLARIS
#ifdef USE_TABLE_PILOTAGE
    START_THREAD(novadem, (void*) ("/dev/ttyUSB0"));
#endif // USE_TABLE_PILOTAGE

    return C_OK;
}

C_RESULT ardrone_tool_shutdown_custom() {
#ifdef USE_TABLE_PILOTAGE
    JOIN_THREAD(novadem);
#endif // USE_TABLE_PILOTAGE
#ifdef PC_USE_POLARIS
    JOIN_THREAD(polaris);
#endif // PC_USE_POLARIS
#ifdef USE_ARDRONE_VICON
    JOIN_THREAD(vicon);
#endif // USE_ARDRONE_VICON
    JOIN_THREAD(ihm);
    video_stage_resume_thread(); //Resume thread to kill it !
    JOIN_THREAD(video_stage);
    if (2 <= ARDRONE_VERSION ())
      {
        video_recorder_resume_thread ();
        JOIN_THREAD (video_recorder);
      }
#ifdef RAW_CAPTURE
    JOIN_THREAD(raw_capture);
#endif
    JOIN_THREAD(remote_console);

    /*ardrone_tool_input_remove( &gamepad );
    ardrone_tool_input_remove( &radioGP );
    ardrone_tool_input_remove( &ps3pad );
    ardrone_tool_input_remove( &wiimote_device );*/
    ardrone_tool_input_remove(&control_device);

    return C_OK;
}


bool_t ardrone_tool_exit() {
    return exit_ihm_program == 0;
}

BEGIN_THREAD_TABLE
THREAD_TABLE_ENTRY(ihm, 20)
#ifdef RAW_CAPTURE
THREAD_TABLE_ENTRY(raw_capture, 20)
#endif
THREAD_TABLE_ENTRY(remote_console, 20)
THREAD_TABLE_ENTRY(video_stage, 20)
THREAD_TABLE_ENTRY(video_recorder, 20)
THREAD_TABLE_ENTRY(navdata_update, 20)
THREAD_TABLE_ENTRY(ATcodec_Commands_Client, 20)
THREAD_TABLE_ENTRY(ardrone_control, 20)
#ifdef PC_USE_POLARIS
THREAD_TABLE_ENTRY(polaris, 20)
#endif // PC_USE_POLARIS
#ifdef USE_ARDRONE_VICON
THREAD_TABLE_ENTRY(vicon, 20)
#endif // USE_ARDRONE_VICON
#ifdef USE_TABLE_PILOTAGE
THREAD_TABLE_ENTRY(novadem, 20)
#endif // USE_TABLE_PILOTAGE
END_THREAD_TABLE

