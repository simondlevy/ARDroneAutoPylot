/*
 * @ihm_vision.c
 * @author marc-olivier.dzeukou@parrot.com
 * @date 2007/07/27
 *
 * @author stephane.piskorski@parrot.com
 * @date 2010/10/18
 * ihm vision source file
 *
 */

#include   <pthread.h>
#include   <gtk/gtk.h>

#include <ardrone_api.h>
#ifdef PC_USE_VISION
#    include <Vision/vision_tracker_engine.h>
#endif
#include "ihm/ihm_vision.h"
#include "ihm/ihm.h"
#include "common/mobile_config.h"
#include "ihm/ihm_stages_o_gtk.h"

#include <ardrone_tool/ardrone_tool_configuration.h>
#include <ardrone_tool/ardrone_version.h>

#include <VP_Os/vp_os_print.h>
#include <VP_Os/vp_os_malloc.h>
#include <VP_Os/vp_os_delay.h>
#include <VP_Api/vp_api_supervisor.h>
#include <VLIB/video_codec.h>

#include <ardrone_tool/Academy/academy_stage_recorder.h>
#include <ardrone_tool/Navdata/ardrone_academy_navdata.h>

#ifdef RECORD_RAW_VIDEO
#include <ardrone_tool/Video/video_stage_recorder.h>
extern video_stage_recorder_config_t vrc;
#endif

#if defined(FFMPEG_SUPPORT) && defined(RECORD_FFMPEG_VIDEO)
#include <ardrone_tool/Video/video_stage_ffmpeg_recorder.h>
extern video_stage_ffmpeg_recorder_config_t ffmpeg_vrc;
#endif

#if defined (RECORD_ENCODED_VIDEO)
#include <ardrone_tool/Video/video_stage_encoded_recorder.h>
#endif

#include <ardrone_tool/Video/video_stage_latency_estimation.h>
#include <ardrone_tool/Video/video_stage.h>
#include <ardrone_tool/Video/video_recorder_pipeline.h>

enum {
  VIDEO_DISPLAYSIZE_FRAME=0,
  STATE_FRAME,
  TRACKING_PARAMETERS_FRAME,
  TRACKING_OPTION_FRAME,
  COMPUTING_OPTION_FRAME,
  VIDEO_STREAM_FRAME,
  VIDEO_BITRATE_FRAME,
  VIDEO_DISPLAY_FRAME,
  VIDEO_INFO_FRAME,
  VIDEO_NAVDATA_FRAME,
  NB_IMAGES_FRAMES
};

enum {
  TRACKING_PARAM_HBOX1=0,
  TRACKING_PARAM_HBOX2,
  TRACKING_PARAMS_HBOX,
  TRACKING_OPTION_HBOX,
  COMPUTING_OPTION_HBOX,
  VIDEO_DISPLAYSIZE_HBOX,
  VIDEO_STREAM_HBOX,
  VIDEO_BITRATE_HBOX,
  VIDEO_DISPLAY_HBOX,
  NB_IMAGES_H_BOXES
};

enum {
  CS_ENTRY=0,
  NB_P_ENTRY,
  LOSS_ENTRY,
  NB_TLG_ENTRY,
  NB_TH_ENTRY,
  SCALE_ENTRY,
  DIST_MAX_ENTRY,
  MAX_DIST_ENTRY,
  NOISE_ENTRY,
  FAKE_ENTRY,
  NB_IMAGES_ENTRIES
};

enum {
  UPDATE_VISION_PARAMS_BUTTON = 0,
  TZ_KNOWN_BUTTON,
  NO_SE_BUTTON,
  SE2_BUTTON,
  SE3_BUTTON,
  PROJ_OVERSCENE_BUTTON,
  LS_BUTTON,
  FRONTAL_SCENE_BUTTON,
  FLAT_GROUND_BUTTON,
  PICTURE_BUTTON,
  RECORD_BUTTON,
  RAW_CAPTURE_BUTTON,
  ZAPPER_BUTTON,
  FULLSCREEN_BUTTON,
  PAUSE_BUTTON,
  LATENCY_ESTIMATOR_BUTTON,
  CUSTOM_BUTTON,
  NB_IMAGES_BUTTONS,
};

enum {
  RAW_CAPT_FSBUTTON = 0,
  RECORD_LOCAL_FSBUTTON,
  CHANGE_CAM_FSBUTTON,
  FULLSCREEN_FSBUTTON,
  NB_FULL_SCREEN_BUTTON,
};

enum {
  VIDEO_SIZE_LIST=0,
  NB_VIDEO_SIZE_WIDGET
};

enum {
  CODEC_TYPE_LIST=0,
  BITRATE_MODE_LIST,
  MANUAL_BITRATE_ENTRY,
  WIFI_BITRATE_MODE_LIST,
  CODEC_FPS_LIST,
  USB_RECORD_CHECKBOX,
  NB_VIDEO_STREAM_WIDGET
};

char  ihm_ImageTitle[128] = "VISION : Image" ;
char *ihm_ImageFrameCaption[NB_IMAGES_FRAMES]  = {"Video display size",
												  "Vision states",
												  "Tracking parameters",
												  "Tracking options",
												  "Computing options",
												  "Video Stream",
												  "Video Bitrate",
												  "Live Display",
												  "Last decoded picture",
												  "Video stream navdata"};

char *ihm_ImageEntryCaption[NB_IMAGES_ENTRIES]  = {  "      CS ",
                                     "           NB_P ",
                                     "       Loss% ",
                                     "     NB_TLg ",
                                     "   NB_TH ",
                                     " Scale ",
                                     "    Dist_Max ",
                                     "   Max_Dist ",
                                     "        Noise ",
                                     ""};
char *ihm_ImageButtonCaption[NB_IMAGES_BUTTONS] = { "Update\nvision\nparams",
                                                    " TZ_Known  ",
                                                    "   No_SE    ",
                                                    "   SE2      ",
                                                    "     SE3     ",
                                                    "Proj_OverScene",
                                                    "    LS   ",
                                                    " Frontal_Scene  ",
                                                    " Flat_ground ",
                                                    "Take Picture",
                                                    "Record Video\non local disk",
                                                    "Raw capture",
                                                    " Change camera",
                                                    " GTK Full Screen ",
                                                    " Pause ",
                                                    " Latency Estimator ",
                                                    " Custom "
};

enum{
  VIDEO_DISPLAYSIZE_CAPTION_FRAMETITLE=0,
  VIDEO_DISPLAYSIZE_CAPTION_SIZES,
  VIDEO_DISPLAYSIZE_CAPTION_INTERP_MODES,
  NB_VIDEO_DISPLAYSIZE_CAPTION
};

char *ihm_ImageVideoSizeCaption[NB_VIDEO_DISPLAYSIZE_CAPTION] = {" Viewport size ","Display size","Interpolation"};

enum {
  VIDEO_SIZE_AUTO=0,
  VIDEO_SIZE_IPHONE3GS,
  VIDEO_SIZE_IPHONE4,
  VIDEO_SIZE_IPAD,
  VIDEO_SIZE_720p,
  NB_DISPLAY_SIZES
};

struct {
  const char * name;
  int w;
  int h;
}video_displaySizesArray[NB_DISPLAY_SIZES] = { { "auto",0,0 } , { "iPhone3GS (480x320)",480,320 } , { "iPhone4/4S (960x640)",960,640 }, { "iPad1/2 (1024x768)",1024,768 } , { "720p (1280x720)",1280,720 } };


char *ihm_ImageVideoStreamCaption[NB_VIDEO_STREAM_WIDGET] = {" Codec type "," Bitrate control mode ", " Manual target bitrate ","WiFi bitrate","FPS"};


GtkWidget *ihm_ImageVBox, *ihm_ImageVBoxPT, *ihm_ImageHBox[NB_IMAGES_H_BOXES], *displayvbox, *ihm_ImageButton[NB_IMAGES_BUTTONS], *ihm_ImageLabel[NB_IMAGES_ENTRIES],  *ihm_ImageFrames[NB_IMAGES_FRAMES], *ihm_VideoStreamLabel[NB_VIDEO_STREAM_WIDGET],*ihm_ImageVideoSizeLabel[NB_VIDEO_DISPLAYSIZE_CAPTION];

extern GtkWidget *button_show_image,*button_show_image2;
extern mobile_config_t *pcfg;
extern PIPELINE_HANDLE video_pipeline_handle;
/* Vision image var */
GtkLabel *label_vision_values=NULL;
GtkWidget *ihm_ImageWin=NULL, *ihm_ImageEntry[NB_IMAGES_ENTRIES], *ihm_VideoStream_VBox=NULL;

/* For fullscreen video display */
GtkWidget *fullscreen_window = NULL;
GtkWidget *fullscreen_eventbox = NULL;
GtkImage *fullscreen_image = NULL;
GdkScreen *fullscreen = NULL;
GtkWidget *ihm_fullScreenButton[5], *ihm_fullScreenHBox;
GtkWidget *ihm_fullScreenFixedContainer;
GtkWidget *align;
int flag_timer_is_active = 0;
int timer_counter = 0;

GtkWidget* video_bitrateEntry;
GtkWidget*  video_bitrateModeList;
GtkWidget*  wifi_bitrateModeList;
GtkWidget*  codecFPSList;
GtkWidget*  codecSlicesList;
GtkWidget*  codecSocketList;
GtkWidget*  decodeLatencyList;
GtkWidget*  usbRecordCheckBox;
//GtkObject * codecFPSList_adj;
GtkWidget * video_sizeList;
GtkWidget * video_interpolationModesList;
GtkWidget * video_codecList;
GtkWidget *video_bitrateButton;
int tab_vision_config_params[10];
int vision_config_options;
int image_vision_window_status, image_vision_window_view;
char label_vision_state_value[32];
extern GtkImage *image;

GtkWidget * video_information = NULL;
GtkWidget * video_information_hbox = NULL;

GtkWidget * video_navdata = NULL;
GtkWidget * video_navdata_hbox = NULL;


static void ihm_sendVisionConfigParams(GtkWidget *widget, gpointer data) {
  api_vision_tracker_params_t params;

  params.coarse_scale       = tab_vision_config_params[0]; // scale of current picture with respect to original picture
  params.nb_pair            = tab_vision_config_params[1]; // number of searched pairs in each direction
  params.loss_per           = tab_vision_config_params[2]; // authorized lost pairs percentage for tracking
  params.nb_tracker_width   = tab_vision_config_params[3]; // number of trackers in width of current picture
  params.nb_tracker_height  = tab_vision_config_params[4]; // number of trackers in height of current picture
  params.scale              = tab_vision_config_params[5]; // distance between two pixels in a pair
  params.trans_max          = tab_vision_config_params[6]; // largest value of trackers translation between two adjacent pictures
  params.max_pair_dist      = tab_vision_config_params[7]; // largest distance of pairs research from tracker location
  params.noise              = tab_vision_config_params[8]; // threshold of significative contrast

  ardrone_at_set_vision_track_params( &params );

  DEBUG_PRINT_SDK("CS %04d NB_P %04d Lossp %04d NB_Tlg %04d NB_TH %04d Scale %04d Dist_Max %04d Max_Dist %04d Noise %04d\n",
          tab_vision_config_params[0],
          tab_vision_config_params[1],
          tab_vision_config_params[2],
          tab_vision_config_params[3],
          tab_vision_config_params[4],
          tab_vision_config_params[5],
          tab_vision_config_params[6],
          tab_vision_config_params[7],
          tab_vision_config_params[8] );
}

#ifdef RECORD_RAW_VIDEO
void ihm_video_recording_callback(video_stage_recorder_config_t *cfg) {
  printf("%s recording %s\n", (cfg->startRec != VIDEO_RECORD_STOP) ? "Started" : "Stopped", cfg->video_filename);
}
#endif

#ifdef RECORD_FFMPEG_VIDEO
void ihm_ffmpeg_video_recording_callback(video_stage_ffmpeg_recorder_config_t *cfg) {
  printf("%s recording %s\n", (cfg->startRec != VIDEO_RECORD_STOP) ? "Started" : "Stopped", cfg->video_filename);
}
#endif

#ifdef RECORD_ENCODED_VIDEO
void ihm_video_encoded_recording_callback(video_stage_encoded_recorder_config_t *cfg) {
  // nothing for now ...
  printf ("callback status %d\n", cfg->startRec);
}
#endif

static void ihm_RecordVideo(GtkWidget *widget, gpointer data) {
  static int is_recording = 0;

  DEBUG_PRINT_SDK("Record video\n");
#ifdef RECORD_RAW_VIDEO
  DEST_HANDLE dest;
  dest.pipeline = video_pipeline_handle;
#endif

  is_recording ^= 1;

  ardrone_academy_navdata_record();

  /*
   * Tells the Raw capture stage to start dumping YUV frames from
   *  the pipeline to a disk file.
   */

#ifdef RECORD_RAW_VIDEO
  dest.stage = vrc.stage;
  vp_api_post_message(dest, PIPELINE_MSG_START, ihm_video_recording_callback, NULL);
#endif

#if defined(FFMPEG_SUPPORT) && defined(RECORD_FFMPEG_VIDEO)
  /* Tells the FFMPEG recorder stage to start dumping the video in a
   * MPEG4 video file.
   */
  dest.stage = ffmpeg_vrc.stage;
  vp_api_post_message(dest, PIPELINE_MSG_START, NULL, NULL);
#endif

  if (is_recording) {
    gtk_button_set_label((GtkButton*) ihm_ImageButton[RECORD_BUTTON], (const gchar*) "Recording...\n(click again to stop)");
    gtk_button_set_label((GtkButton*) ihm_fullScreenButton[1], (const gchar*) "Recording...\n(click again to stop)");
  }
  else {
    video_stage_encoded_recorder_enable (0, 0);
    gtk_button_set_label((GtkButton*) ihm_ImageButton[RECORD_BUTTON], (const gchar*) "Recording stopped.\nClick again to start a new video");
    gtk_button_set_label((GtkButton*) ihm_fullScreenButton[1], (const gchar*) "Recording stopped.\nClick again to start a new video");
  }

}

static void ihm_TakePicture(GtkWidget *widget, gpointer data) {
  ardrone_at_raw_picture();
}

extern int videoPauseStatus;
static void ihm_PauseVideo(GtkWidget *widget, gpointer data) {
	videoPauseStatus = videoPauseStatus ^ 1;
}

extern vp_stages_latency_estimation_config_t vlat;
static void ihm_LatencyEstimator(GtkWidget *widget, gpointer data) {
	if (vlat.state==LE_DISABLED)
	{
		vlat.state=LE_WAITING;
	}
	else
	{
		vlat.state=LE_DISABLED;
	}
}


static void ihm_customVideoButton(GtkWidget *widget, gpointer data)
{
	static int video_codec = 0x81;

	switch(video_codec)
	{
	case 0x81:	video_codec = 0x83; break;
	case 0x83:	video_codec = 0x81; break;
	default: break;
	}

	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(video_codec, &video_codec, NULL);
}




static void ihm_RAWCapture(GtkWidget *widget, gpointer data) {
  static int is_recording = 0;

  DEBUG_PRINT_SDK("   RAW video capture\n");

  is_recording ^= 1;

  // Sending AT command to drone.
  ardrone_at_raw_capture( is_recording );

 if (is_recording) {
    gtk_button_set_label((GtkButton*) ihm_ImageButton[RAW_CAPTURE_BUTTON], (const gchar*) "Raw capture started...\n(click again to stop)");
    gtk_button_set_label((GtkButton*) ihm_fullScreenButton[0], (const gchar*) "Raw capture started...\n(click again to stop)");
  }
  else {
    gtk_button_set_label((GtkButton*) ihm_ImageButton[RAW_CAPTURE_BUTTON], (const gchar*) "Raw capture stopped.\nClick again to start a new raw capture");
    gtk_button_set_label((GtkButton*) ihm_fullScreenButton[0], (const gchar*) "Raw capture stopped.\nClick again to start a new raw capture");
  }
}

static void ihm_Zapper(GtkWidget *widget, gpointer data) {
  int32_t channel = ZAP_CHANNEL_NEXT;
  printf("   Zap\n");
  ARDRONE_TOOL_CONFIGURATION_ADDEVENT(video_channel, &channel, NULL);
}

static void ihm_VideoFullScreenStop(GtkWidget *widget, gpointer data) {
  printf("Quitting fullscreen.\n");
  fullscreen = NULL;
  fullscreen_image = NULL;
  fullscreen_window = NULL;
}

gboolean hide_fullscreen_buttons(gpointer pData) {
  timer_counter--;
  if (timer_counter <= 0) {
    if (GTK_IS_WIDGET(ihm_fullScreenHBox))
      gtk_widget_hide(ihm_fullScreenHBox);
    timer_counter = 0;
  }
  return TRUE;
}

void ihm_VideoFullScreenMouseMove(GtkWidget *widget, gpointer data) {
  timer_counter = 2;
  if (GTK_IS_WIDGET(ihm_fullScreenHBox)) {
    gtk_widget_show(ihm_fullScreenHBox);
  }
}

static void ihm_QuitFullscreenRequest(GtkWidget *widget, gpointer data) {
  gtk_widget_destroy(fullscreen_window);
}

static void ihm_VideoFullScreen(GtkWidget *widget, gpointer data) {
  int w, h;

  if (fullscreen != NULL) {
    printf("   Already fullscreen\n");
    return;
  }
  printf("   Go Fullscreen\n");

  /* Builds the image */
  fullscreen_image = (GtkImage*) gtk_image_new();
  fullscreen_eventbox = gtk_event_box_new();
  //align = gtk_alignment_new(0.5f,0.5f,0.0f,0.0f);


  /* Add three buttons on the fullscreen window */
  ihm_fullScreenHBox = gtk_hbox_new(FALSE, 0);

  ihm_fullScreenButton[0] = gtk_button_new_with_label(ihm_ImageButtonCaption[RAW_CAPTURE_BUTTON]);
  g_signal_connect(G_OBJECT(ihm_fullScreenButton[0]), "clicked", (GCallback) ihm_RAWCapture, NULL);
  gtk_container_add(GTK_CONTAINER(ihm_fullScreenHBox), ihm_fullScreenButton[0]);


  ihm_fullScreenButton[1] = gtk_button_new_with_label(ihm_ImageButtonCaption[RECORD_BUTTON]);
  g_signal_connect(G_OBJECT(ihm_fullScreenButton[1]), "clicked", (GCallback) ihm_RecordVideo, NULL);
  gtk_container_add(GTK_CONTAINER(ihm_fullScreenHBox), ihm_fullScreenButton[1]);

  ihm_fullScreenButton[2] = gtk_button_new_with_label(ihm_ImageButtonCaption[ZAPPER_BUTTON]);
  g_signal_connect(G_OBJECT(ihm_fullScreenButton[2]), "clicked", (GCallback) ihm_Zapper, NULL);
  gtk_container_add(GTK_CONTAINER(ihm_fullScreenHBox), ihm_fullScreenButton[2]);

  ihm_fullScreenButton[3] = gtk_button_new_with_label("Quit Fullscreen");
  g_signal_connect(G_OBJECT(ihm_fullScreenButton[3]), "clicked", (GCallback) ihm_QuitFullscreenRequest, NULL);
  gtk_container_add(GTK_CONTAINER(ihm_fullScreenHBox), ihm_fullScreenButton[3]);

  //ihm_fullScreenButton[3] = gtk_button_new(); // Fake button

  //gtk_container_add(GTK_CONTAINER (align),ihm_fullScreenHBox);

  /* Create window (full screen) */
  fullscreen_window = gtk_window_new(GTK_WINDOW_TOPLEVEL);

  /* the screen */
  fullscreen = gtk_window_get_screen(GTK_WINDOW(fullscreen_window));
  w = gdk_screen_get_width(fullscreen);
  h = gdk_screen_get_height(fullscreen);
  gtk_widget_set_size_request(GTK_WIDGET(fullscreen_window), w, h);

  /* The fixed container */
  ihm_fullScreenFixedContainer = gtk_fixed_new();
  gtk_fixed_put((GtkFixed*) (ihm_fullScreenFixedContainer), GTK_WIDGET(fullscreen_image), 0, 0);
  gtk_fixed_put((GtkFixed*) (ihm_fullScreenFixedContainer), GTK_WIDGET(ihm_fullScreenHBox), 0, 0);

  /* Build the fullscreen window with the fixed container */
  gtk_container_add(GTK_CONTAINER(fullscreen_eventbox), ihm_fullScreenFixedContainer);
  gtk_container_add(GTK_CONTAINER(fullscreen_window), fullscreen_eventbox);

  gtk_window_set_decorated(GTK_WINDOW(fullscreen_window), FALSE);
  gtk_window_set_resizable(GTK_WINDOW(fullscreen_window), FALSE);

  printf("Fullscreen size : %ix%i\n", w, h);

  g_signal_connect(G_OBJECT(fullscreen_window), "destroy", (GCallback) ihm_VideoFullScreenStop, NULL);
  g_signal_connect(fullscreen_eventbox, "motion_notify_event", (GCallback) ihm_VideoFullScreenMouseMove, NULL);
  gtk_widget_add_events(fullscreen_eventbox, GDK_POINTER_MOTION_MASK);

  gtk_window_fullscreen(GTK_WINDOW(fullscreen_window));
  gtk_widget_show_all(GTK_WIDGET(fullscreen_window));
  gtk_widget_hide(ihm_fullScreenHBox);
  //gtk_widget_get_size_request(ihm_fullScreenHBox,&w2,&h2);
  //printf("Fullscreen size2 : %ix%i    %ix%i\n",w,h,w2,h2);

  //gtk_fixed_put(ihm_fullScreenFixedContainer,ihm_fullScreenHBox,0,h-30);

  if (!flag_timer_is_active) {
    g_timeout_add(1000, (GtkFunction) hide_fullscreen_buttons, NULL);
    flag_timer_is_active = 1;
  }

}


static void ihm_ImageButtonCB(GtkWidget *widget, gpointer data) {
  int button = (int) data;

  printf("   Button clicked No: %d\n", button);

  ardrone_at_set_vision_update_options(button);
}

// void ihm_ImageWinDestroy ( void )
void ihm_ImageWinDestroy(GtkWidget *widget, gpointer data) {
  image_vision_window_status = WINDOW_CLOSED;
  printf("Destroying the Video window.\n");
  if (fullscreen != NULL) {
    ihm_VideoFullScreenStop(NULL, NULL);
  }
  ihm_VideoStream_VBox = NULL; /* this var. is tested by stage Gtk */
  ihm_ImageWin = NULL;
  video_stage_suspend_thread();
  if (2 <= ARDRONE_VERSION ())
    {
      video_recorder_suspend_thread ();
    }
}

gint ihm_ImageWinDelete(GtkWidget *widget, GdkEvent *event, gpointer data) {
  image_vision_window_status = WINDOW_CLOSED;
  printf("Deleting the Video window.\n");
  gtk_toggle_button_set_active(GTK_TOGGLE_BUTTON(button_show_image), FALSE);
  return FALSE;
}

static void ihm_showImage(gpointer pData) {
  //GtkWidget* widget = (GtkWidget*) pData;

  //if (gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(widget))) 
  {
    if (!GTK_IS_WIDGET(ihm_ImageWin)) {
      create_image_window(); // Recreate window if it has been killed
    }
    gtk_widget_show_all(ihm_ImageWin);
    image_vision_window_view = WINDOW_VISIBLE;
    
    vp_os_delay(500);
    video_stage_resume_thread();
    if (2 <= ARDRONE_VERSION ())
      {
        video_recorder_resume_thread ();
      }
  }
  /*else {
    if (GTK_IS_WIDGET(ihm_ImageWin)) {
      gtk_widget_hide_all(ihm_ImageWin);
      image_vision_window_view = WINDOW_HIDE;
    }
  }*/
}

static void ihm_send_VideoBitrate(GtkWidget *widget, gpointer data) {
  int32_t bitrateValue = atoi(gtk_entry_get_text(GTK_ENTRY(video_bitrateEntry)));
  ARDRONE_TOOL_CONFIGURATION_ADDEVENT(bitrate, &bitrateValue, NULL);
}

extern vp_stages_gtk_config_t gtkconf;

static void ihm_changeVideoDisplaySize(GtkComboBox *widget, gpointer data) {
  gint pos;
  //int w,h;
  pos = gtk_combo_box_get_active( widget );
  pos = max(0,pos);
  pos = min(pos,NB_DISPLAY_SIZES);
  
  printf("Setting GTK display mode %s size %dx%d\n",
    video_displaySizesArray[pos].name,
    video_displaySizesArray[pos].w,
    video_displaySizesArray[pos].h);
    
   gtkconf.desired_display_width  = video_displaySizesArray[pos].w;
   gtkconf.desired_display_height = video_displaySizesArray[pos].h;
}

static void ihm_changeVideoInterpolation(GtkComboBox *widget, gpointer data) {
  gint pos;
  pos = gtk_combo_box_get_active( widget );
 
  switch(pos)
  {
    case 0:   printf("Setting GTK display interpolation : Nearest neighbour\n"); gtkconf.gdk_interpolation_mode = GDK_INTERP_NEAREST;  break;
    case 1:   printf("Setting GTK display interpolation : Tiles\n");             gtkconf.gdk_interpolation_mode = GDK_INTERP_TILES;    break;
    case 2:   printf("Setting GTK display interpolation : Bilinear\n");          gtkconf.gdk_interpolation_mode = GDK_INTERP_BILINEAR; break;
    case 3:   printf("Setting GTK display interpolation : Hyperbolic\n");        gtkconf.gdk_interpolation_mode = GDK_INTERP_HYPER;    break;
      
    default: /*nada*/ break;
  }
}


static void ihm_send_VideoCodec(GtkComboBox *widget, gpointer data) {
  gint pos;
  int32_t codec;
  pos = gtk_combo_box_get_active( widget );
  switch (pos)
    {
    case 0:
      codec = UVLC_CODEC;
      break;
    case 1:
      codec = P264_CODEC;
      break;
    case 2:
      codec = MP4_360P_CODEC;
      break;
    case 3:
      codec = H264_360P_CODEC;
      break;
    case 4:
      codec = MP4_360P_H264_720P_CODEC;
      break;
    case 5:
      codec = H264_720P_CODEC; /* 720p live */
      break;
    case 6:
      codec = MP4_360P_SLRS_CODEC; /* 360p live+record */
      break;
    case 7:
      codec = H264_360P_SLRS_CODEC;
      break;
    case 8:
      codec = H264_720P_SLRS_CODEC;
      break;
    case 9:
      codec = H264_AUTO_RESIZE_CODEC;
      break;
    default:
      codec = UVLC_CODEC;
      break;
    }
  ardrone_control_config.video_codec = codec;
  ARDRONE_TOOL_CONFIGURATION_ADDEVENT(video_codec, &ardrone_control_config.video_codec, NULL);
}

static void ihm_send_VideoBitrateMode(GtkComboBox *widget, gpointer data) {
  int32_t pos;
  pos = (int32_t)gtk_combo_box_get_active( widget );
  ARDRONE_TOOL_CONFIGURATION_ADDEVENT(bitrate_ctrl_mode, &pos, NULL);
}

static void ihm_send_wifiBitrateMode(GtkComboBox *widget, gpointer data) {
  int32_t pos;
  int32_t rate;
  int k=0;
  
  pos = (int32_t)gtk_combo_box_get_active( widget );
  
  if (pos==(k++)) rate=0;
  if (pos==(k++)) rate=1;
  if (pos==(k++)) rate=2;
  if (pos==(k++)) rate=5;
  if (pos==(k++)) rate=6;
  if (pos==(k++)) rate=9;
  if (pos==(k++)) rate=11;
  if (pos==(k++)) rate=12;
  if (pos==(k++)) rate=18;
  if (pos==(k++)) rate=24;
  if (pos==(k++)) rate=36;
  if (pos==(k++)) rate=48;
  if (pos==(k++)) rate=54;
  if (pos==(k++)) rate=65;
  
  printf("Forcing the WiFi AP rate to %d MBit/s\n",rate);
  
  ARDRONE_TOOL_CONFIGURATION_ADDEVENT(wifi_rate, &rate, NULL);
}


static void ihm_send_codecFPS(GtkComboBox *widget, gpointer data)
{
	int32_t pos;

	 pos = (int32_t)gtk_combo_box_get_active( widget );

	 if (pos<0)  pos =0;
	 if (pos>30) pos =30;

	 pos=30-pos;

	 printf("Forcing the video to %d FPS\n",pos);

	 ARDRONE_TOOL_CONFIGURATION_ADDEVENT(codec_fps, &pos, NULL);
}


static void ihm_send_codecSlices(GtkComboBox *widget, gpointer data)
{
	int32_t pos;
	int32_t slices;

	 pos = (int32_t)gtk_combo_box_get_active( widget );

	 switch(pos)
	 {
	 default:
	 	 case 0: slices = 0; break;
	 	 case 1: slices = 1; break;
	 	 case 2: slices = 2; break;
	 	 case 3: slices = 4; break;
	 	 case 4: slices = 8; break;
	 	 case 5: slices = 12; break;
	 	 case 6: slices = 16; break;
	 	 case 7: slices = 24; break;
	 	 case 8: slices = 32; break;
	 }

	 printf("Forcing the number of H.264 slices to %d\n",slices);

	 ARDRONE_TOOL_CONFIGURATION_ADDEVENT(video_slices, &slices, NULL);
}



static void ihm_send_codecSocket(GtkComboBox *widget, gpointer data)
{
	int32_t pos;
	int32_t socket;

	 pos = (int32_t)gtk_combo_box_get_active( widget );

	 switch(pos)
	 {
	 default:
	 	 case 0: socket = 0; break;
	 	 case 1: socket = 1; break;
	 	 case 2: socket = 2; break;
	 }

	 printf("Forcing the live video socket to %d\n",socket);

	 ARDRONE_TOOL_CONFIGURATION_ADDEVENT(video_live_socket, &socket, NULL);
}

extern int video_stage_decoder_fakeLatency;

static void ihm_change_decodeLatency(GtkComboBox *widget, gpointer data)
{
	int32_t pos;

	 pos = (int32_t)gtk_combo_box_get_active( widget );

	 switch(pos)
	 {
	 default:
	 	 case 0: video_stage_decoder_fakeLatency = 0; break;
	 	 case 1: video_stage_decoder_fakeLatency = 10; break;
	 	 case 2: video_stage_decoder_fakeLatency = 20; break;
	 	 case 3: video_stage_decoder_fakeLatency = 30; break;
	 	 case 4: video_stage_decoder_fakeLatency = 40; break;
	 	 case 5: video_stage_decoder_fakeLatency = 50; break;
	 	 case 6: video_stage_decoder_fakeLatency = 60; break;
	 }
}


static enum { IDLE,SWITCHING,REVERTING } ihm_usbRecordCheckbox_switch_in_progress = IDLE;
/* Called by ARDroneAPI acknowledges the ARDRONE_TOOL_CONFIGURATION_ADDEVENT sent in the next function */
static void ihm_usbRecordCheckbox_ardroneAPI_callback(int success)
{
}

/* Called by GTK when the user clicks on the checkbox */
static void ihm_usbRecordCheckbox_callback(GtkComboBox *widget, gpointer data)
{
	bool_t videoOnUSB_config_key;

	/* Check if the checked button was just checked or unchecked */
	videoOnUSB_config_key = ((GTK_TOGGLE_BUTTON (widget)->active))? TRUE : FALSE;
	printf("Switching USB record to %d\n",videoOnUSB_config_key);

	/* Asks ARDroneAPI to send the new configuration to the drone */
	ARDRONE_TOOL_CONFIGURATION_ADDEVENT(video_on_usb, &videoOnUSB_config_key, ihm_usbRecordCheckbox_ardroneAPI_callback);

	/* ARDroneAPI will trigger the callback again once the configuration key is acknowledged by the drone */
}

void update_vision( void )
{
  if (ihm_ImageWin != NULL && GTK_IS_WIDGET(ihm_ImageWin)) {
    if (image_vision_window_view == WINDOW_VISIBLE) {

      // Vision state refresh
      if (label_vision_values != NULL && GTK_IS_LABEL(label_vision_values))
        gtk_label_set_label(label_vision_values, label_vision_state_value);
      if (ihm_ImageWin != NULL && GTK_IS_WIDGET(ihm_ImageWin))
        gtk_widget_show_all(ihm_ImageWin);
    }
  }
}

void create_image_window( void )
{
  /* Image display main window */
  /* ------------------------- */
  int i,k;

  printf("Creating the Video window.\n");

  // Image main window
  ihm_ImageWin = gtk_window_new( GTK_WINDOW_TOPLEVEL);
  gtk_container_set_border_width(GTK_CONTAINER(ihm_ImageWin), 10);
  gtk_window_set_title(GTK_WINDOW(ihm_ImageWin), ihm_ImageTitle);
  gtk_signal_connect(GTK_OBJECT(ihm_ImageWin), "destroy", G_CALLBACK(ihm_ImageWinDestroy), NULL );

  // Boxes
  ihm_ImageVBox = gtk_vbox_new(FALSE, 0);
  ihm_VideoStream_VBox = gtk_vbox_new(FALSE, 0);
  ihm_ImageVBoxPT = gtk_vbox_new(FALSE, 0);

  //hBox_vision_state = gtk_hbox_new(FALSE, 0);
  for (k=0; k<NB_IMAGES_H_BOXES; k++)  ihm_ImageHBox[k] = gtk_hbox_new(FALSE, 0);
  // Frames
  for (k=0; k<NB_IMAGES_FRAMES; k++)  {
    ihm_ImageFrames[k] = gtk_expander_new( ihm_ImageFrameCaption[k]);  //gtk_frame_new( ihm_ImageFrameCaption[k] );
  }

 
  ihm_ImageFrames[VIDEO_DISPLAYSIZE_FRAME]   = gtk_frame_new( ihm_ImageFrameCaption[VIDEO_DISPLAYSIZE_FRAME]);
  ihm_ImageFrames[STATE_FRAME]               = gtk_expander_new( ihm_ImageFrameCaption[STATE_FRAME]);
  ihm_ImageFrames[TRACKING_PARAMETERS_FRAME] = gtk_expander_new( ihm_ImageFrameCaption[TRACKING_PARAMETERS_FRAME]);
  ihm_ImageFrames[TRACKING_OPTION_FRAME]     = gtk_expander_new( ihm_ImageFrameCaption[TRACKING_OPTION_FRAME]);
  ihm_ImageFrames[COMPUTING_OPTION_FRAME]    = gtk_expander_new( ihm_ImageFrameCaption[COMPUTING_OPTION_FRAME]);
  ihm_ImageFrames[VIDEO_STREAM_FRAME]        = gtk_frame_new( ihm_ImageFrameCaption[VIDEO_STREAM_FRAME]);
  ihm_ImageFrames[VIDEO_BITRATE_FRAME]       = gtk_frame_new( ihm_ImageFrameCaption[VIDEO_BITRATE_FRAME]);
  ihm_ImageFrames[VIDEO_DISPLAY_FRAME]       = gtk_frame_new( ihm_ImageFrameCaption[VIDEO_DISPLAY_FRAME]);
  ihm_ImageFrames[VIDEO_INFO_FRAME]          = gtk_frame_new( ihm_ImageFrameCaption[VIDEO_INFO_FRAME]);
  ihm_ImageFrames[VIDEO_NAVDATA_FRAME]       = gtk_frame_new( ihm_ImageFrameCaption[VIDEO_NAVDATA_FRAME]);


  
  // Entries
  for (k=0; k<NB_IMAGES_ENTRIES; k++) {
    ihm_ImageEntry[k] = gtk_entry_new();
    gtk_widget_set_size_request(ihm_ImageEntry[k], 80, 20);
  }
  
  /* List of display sizes */
  video_sizeList = gtk_combo_box_new_text();
  for (i=0;i<NB_DISPLAY_SIZES;i++)
  {
    gtk_combo_box_insert_text( (GtkComboBox*)video_sizeList, i, (const gchar*)video_displaySizesArray[i].name );
  }

  g_signal_connect(G_OBJECT(video_sizeList), "changed", G_CALLBACK(ihm_changeVideoDisplaySize), 0 );

  video_interpolationModesList = gtk_combo_box_new_text();
  gtk_combo_box_insert_text( (GtkComboBox*)video_interpolationModesList, 0,(const gchar*) "Nearest neighbour" );
  gtk_combo_box_insert_text( (GtkComboBox*)video_interpolationModesList, 1,(const gchar*) "Tiles" );
  gtk_combo_box_insert_text( (GtkComboBox*)video_interpolationModesList, 2,(const gchar*) "Bilinear" );
  gtk_combo_box_insert_text( (GtkComboBox*)video_interpolationModesList, 3,(const gchar*) "Hyperbolic" );
	
  g_signal_connect(G_OBJECT(video_interpolationModesList), "changed", G_CALLBACK(ihm_changeVideoInterpolation), 0 );
    
  // Video Stream

  for (k=0; k<NB_VIDEO_STREAM_WIDGET; k++)  ihm_VideoStreamLabel[k] = gtk_label_new( ihm_ImageVideoStreamCaption[k] );

  video_bitrateEntry =   gtk_entry_new();
  gtk_widget_set_size_request(video_bitrateEntry, 150, 20);

  video_codecList = gtk_combo_box_new_text();
  gtk_combo_box_insert_text( (GtkComboBox*)video_codecList, 0, (const gchar*)"UVLC");
  gtk_combo_box_insert_text( (GtkComboBox*)video_codecList, 1, (const gchar*)"P264");
  gtk_combo_box_insert_text( (GtkComboBox*)video_codecList, 2, (const gchar*)"360p live MPeg4.2");
  gtk_combo_box_insert_text( (GtkComboBox*)video_codecList, 3, (const gchar*)"360p live H.264");
  gtk_combo_box_insert_text( (GtkComboBox*)video_codecList, 4, (const gchar*)"360p live MPeg4.2 - 720p storage H.264");
  gtk_combo_box_insert_text( (GtkComboBox*)video_codecList, 5, (const gchar*)"720p live H.264");
  gtk_combo_box_insert_text( (GtkComboBox*)video_codecList, 6, (const gchar*)"360p SLRS+ MP4");
  gtk_combo_box_insert_text( (GtkComboBox*)video_codecList, 7, (const gchar*)"360p SLRS+ H.264");
  gtk_combo_box_insert_text( (GtkComboBox*)video_codecList, 8, (const gchar*)"720p SLRS+ H.264");
  gtk_combo_box_insert_text( (GtkComboBox*)video_codecList, 9, (const gchar*)"720p live Auto Resize");
  gtk_widget_set_size_request(video_codecList, 150, 20);

  video_bitrateModeList = gtk_combo_box_new_text();
  gtk_combo_box_insert_text( (GtkComboBox*)video_bitrateModeList, 0, (const gchar*)"None");
  gtk_combo_box_insert_text( (GtkComboBox*)video_bitrateModeList, 1, (const gchar*)"Adaptative");
  gtk_combo_box_insert_text( (GtkComboBox*)video_bitrateModeList, 2, (const gchar*)"Manual");

  wifi_bitrateModeList = gtk_combo_box_new_text();
  k=0;
  gtk_combo_box_insert_text( (GtkComboBox*)wifi_bitrateModeList, k++, (const gchar*)"auto");
  gtk_combo_box_insert_text( (GtkComboBox*)wifi_bitrateModeList, k++, (const gchar*)"1 MBit/s");
  gtk_combo_box_insert_text( (GtkComboBox*)wifi_bitrateModeList, k++, (const gchar*)"2 MBit/s");
  gtk_combo_box_insert_text( (GtkComboBox*)wifi_bitrateModeList, k++, (const gchar*)"5.5 MBit/s");
  gtk_combo_box_insert_text( (GtkComboBox*)wifi_bitrateModeList, k++, (const gchar*)"6 MBit/s");
  gtk_combo_box_insert_text( (GtkComboBox*)wifi_bitrateModeList, k++, (const gchar*)"9 MBit/s");
  gtk_combo_box_insert_text( (GtkComboBox*)wifi_bitrateModeList, k++, (const gchar*)"11 MBit/s");
  gtk_combo_box_insert_text( (GtkComboBox*)wifi_bitrateModeList, k++, (const gchar*)"12 MBit/s");
  gtk_combo_box_insert_text( (GtkComboBox*)wifi_bitrateModeList, k++, (const gchar*)"18 MBit/s");
  gtk_combo_box_insert_text( (GtkComboBox*)wifi_bitrateModeList, k++, (const gchar*)"24 MBit/s");
  gtk_combo_box_insert_text( (GtkComboBox*)wifi_bitrateModeList, k++, (const gchar*)"36 MBit/s");
  gtk_combo_box_insert_text( (GtkComboBox*)wifi_bitrateModeList, k++, (const gchar*)"48 MBit/s");
  gtk_combo_box_insert_text( (GtkComboBox*)wifi_bitrateModeList, k++, (const gchar*)"54 MBit/s");
  gtk_combo_box_insert_text( (GtkComboBox*)wifi_bitrateModeList, k++, (const gchar*)"65 MBit/s");


  /* Todo : do something less ugly */
  codecFPSList = gtk_combo_box_new_text();
  k=0;
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"30 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"29 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"28 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"27 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"26 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"25 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"24 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"23 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"22 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"21 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"20 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"19 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"18 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"17 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"16 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"15 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"14 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"13 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"12 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"11 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"10 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"9 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"8 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"7 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"6 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"5 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"4 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"3 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"2 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"1 FPS");
  gtk_combo_box_insert_text( (GtkComboBox*)codecFPSList, k++, (const gchar*)"0 FPS");

  codecSlicesList = gtk_combo_box_new_text();
  k=0;
  gtk_combo_box_insert_text( (GtkComboBox*)codecSlicesList, k++, (const gchar*)"No slicing");
  gtk_combo_box_insert_text( (GtkComboBox*)codecSlicesList, k++, (const gchar*)"1 slice");
  gtk_combo_box_insert_text( (GtkComboBox*)codecSlicesList, k++, (const gchar*)"2 slices");
  gtk_combo_box_insert_text( (GtkComboBox*)codecSlicesList, k++, (const gchar*)"4 slices");
  gtk_combo_box_insert_text( (GtkComboBox*)codecSlicesList, k++, (const gchar*)"8 slices");
  gtk_combo_box_insert_text( (GtkComboBox*)codecSlicesList, k++, (const gchar*)"12 slices");
  gtk_combo_box_insert_text( (GtkComboBox*)codecSlicesList, k++, (const gchar*)"16 slices");
  gtk_combo_box_insert_text( (GtkComboBox*)codecSlicesList, k++, (const gchar*)"24 slices");
  gtk_combo_box_insert_text( (GtkComboBox*)codecSlicesList, k++, (const gchar*)"32 slices");

  codecSocketList = gtk_combo_box_new_text();
    k=0;
    gtk_combo_box_insert_text( (GtkComboBox*)codecSocketList, k++, (const gchar*)"Default");
    gtk_combo_box_insert_text( (GtkComboBox*)codecSocketList, k++, (const gchar*)"UDP");
    gtk_combo_box_insert_text( (GtkComboBox*)codecSocketList, k++, (const gchar*)"TCP");

    decodeLatencyList = gtk_combo_box_new_text();
      k=0;
      gtk_combo_box_insert_text( (GtkComboBox*)decodeLatencyList, k++, (const gchar*)"No latency");
      gtk_combo_box_insert_text( (GtkComboBox*)decodeLatencyList, k++, (const gchar*)"10ms");
      gtk_combo_box_insert_text( (GtkComboBox*)decodeLatencyList, k++, (const gchar*)"20ms");
      gtk_combo_box_insert_text( (GtkComboBox*)decodeLatencyList, k++, (const gchar*)"30ms");
      gtk_combo_box_insert_text( (GtkComboBox*)decodeLatencyList, k++, (const gchar*)"40ms");
      gtk_combo_box_insert_text( (GtkComboBox*)decodeLatencyList, k++, (const gchar*)"50ms");
      gtk_combo_box_insert_text( (GtkComboBox*)decodeLatencyList, k++, (const gchar*)"60ms");

      usbRecordCheckBox = gtk_check_button_new_with_label((const gchar *)"USB record");
      g_signal_connect( G_OBJECT(usbRecordCheckBox), "toggled", G_CALLBACK(ihm_usbRecordCheckbox_callback), NULL );

  for (k=0; k<NB_IMAGES_ENTRIES; k++)  ihm_ImageLabel[k] = gtk_label_new( ihm_ImageEntryCaption[k] );

  for (k=0; k<NB_VIDEO_DISPLAYSIZE_CAPTION;k++) ihm_ImageVideoSizeLabel[k] = gtk_label_new( ihm_ImageVideoSizeCaption[k] );

  /* Creates buttons and links them to callbacks */
  for (k=0; k<NB_IMAGES_BUTTONS; k++)
  {
    ihm_ImageButton[k] = gtk_button_new();// ihm_ImageButtonCaption[k] );
    gtk_button_set_label((GtkButton*)ihm_ImageButton[k] ,ihm_ImageButtonCaption[k]);

    switch (k)
    {
      case UPDATE_VISION_PARAMS_BUTTON:
        g_signal_connect( G_OBJECT(ihm_ImageButton[k]), "clicked", G_CALLBACK(ihm_sendVisionConfigParams), (gpointer)k );
        break;
      case RAW_CAPTURE_BUTTON:
        g_signal_connect( G_OBJECT(ihm_ImageButton[k]), "clicked", G_CALLBACK(ihm_RAWCapture), (gpointer)k );
        break;
      case RECORD_BUTTON:
        g_signal_connect( G_OBJECT(ihm_ImageButton[k]), "clicked", G_CALLBACK(ihm_RecordVideo), (gpointer)k );
        break;
      case ZAPPER_BUTTON:
        g_signal_connect( G_OBJECT(ihm_ImageButton[k]), "clicked", G_CALLBACK(ihm_Zapper), (gpointer)k );
        break;
      case FULLSCREEN_BUTTON:
        g_signal_connect( G_OBJECT(ihm_ImageButton[k]), "clicked", G_CALLBACK(ihm_VideoFullScreen), (gpointer)k );
        break;
      case PICTURE_BUTTON:
        g_signal_connect( G_OBJECT(ihm_ImageButton[k]), "clicked", G_CALLBACK(ihm_TakePicture), (gpointer)k );
        break;
      case PAUSE_BUTTON:
     	 g_signal_connect( G_OBJECT(ihm_ImageButton[k]), "clicked", G_CALLBACK(ihm_PauseVideo), (gpointer)k );
     	break;
      case LATENCY_ESTIMATOR_BUTTON:
     	 g_signal_connect( G_OBJECT(ihm_ImageButton[k]), "clicked", G_CALLBACK(ihm_LatencyEstimator), (gpointer)k );
     	break;
      case CUSTOM_BUTTON:
     	 g_signal_connect( G_OBJECT(ihm_ImageButton[k]), "clicked", G_CALLBACK(ihm_customVideoButton), (gpointer)k );
     	break;
      default:
        g_signal_connect( G_OBJECT(ihm_ImageButton[k]), "clicked", G_CALLBACK(ihm_ImageButtonCB), (gpointer)k );
      }
  }





  GdkColor color;
  gdk_color_parse ("red", &color);
  gtk_widget_modify_text ( ihm_ImageButton[RAW_CAPTURE_BUTTON], GTK_STATE_NORMAL, &color);

  video_bitrateButton = gtk_button_new_with_label( "Send" );
  g_signal_connect(G_OBJECT(video_bitrateButton), "clicked", G_CALLBACK(ihm_send_VideoBitrate), 0 );
  g_signal_connect(G_OBJECT(video_codecList), "changed", G_CALLBACK(ihm_send_VideoCodec), 0 );
  g_signal_connect(G_OBJECT(video_bitrateModeList), "changed", G_CALLBACK(ihm_send_VideoBitrateMode), 0 );
  g_signal_connect(G_OBJECT(wifi_bitrateModeList), "changed", G_CALLBACK(ihm_send_wifiBitrateMode), 0 );
  g_signal_connect(G_OBJECT(codecFPSList), "changed", G_CALLBACK(ihm_send_codecFPS), 0 );
  g_signal_connect(G_OBJECT(codecSlicesList), "changed", G_CALLBACK(ihm_send_codecSlices), 0 );
  g_signal_connect(G_OBJECT(codecSocketList), "changed", G_CALLBACK(ihm_send_codecSocket), 0 );
  g_signal_connect(G_OBJECT(decodeLatencyList), "changed", G_CALLBACK(ihm_change_decodeLatency), 0 );

  /* Creates input boxes (aka. entries) */
  char label_vision_default_val[NB_IMAGES_ENTRIES] ;
  tab_vision_config_params[0] = DEFAULT_CS;
  tab_vision_config_params[1] = DEFAULT_NB_PAIRS;
  tab_vision_config_params[2] = DEFAULT_LOSS_PER;
  tab_vision_config_params[3] = DEFAULT_NB_TRACKERS_WIDTH;
  tab_vision_config_params[4] = DEFAULT_NB_TRACKERS_HEIGHT;
  tab_vision_config_params[5] = DEFAULT_SCALE;
  tab_vision_config_params[6] = DEFAULT_TRANSLATION_MAX;
  tab_vision_config_params[7] = DEFAULT_MAX_PAIR_DIST;
  tab_vision_config_params[8] = DEFAULT_NOISE;

  for (k=0; k<NB_IMAGES_ENTRIES; k++)  {
    if (k==FAKE_ENTRY) continue;
    sprintf(label_vision_default_val, "%d", tab_vision_config_params[k]);
    gtk_entry_set_text( GTK_ENTRY(ihm_ImageEntry[k]), label_vision_default_val);
  }
  gtk_entry_set_text( GTK_ENTRY(video_bitrateEntry), "frame size (bytes)");

  /* Builds the vision state frame */
  vp_os_memset(label_vision_state_value, 0, sizeof(label_vision_state_value));
  strcat(label_vision_state_value, "Not Connected");
  label_vision_values = (GtkLabel*) gtk_label_new(label_vision_state_value);

  gtk_container_add( GTK_CONTAINER(ihm_ImageFrames[STATE_FRAME]), (GtkWidget*) label_vision_values );

  /* Builds the vision parameters frame */

  /* First line of parameters */
  for (k=CS_ENTRY; k<NB_TH_ENTRY; k++)  {
    gtk_box_pack_start(GTK_BOX(ihm_ImageHBox[TRACKING_PARAM_HBOX1]), ihm_ImageLabel[k], FALSE , FALSE, 0);
    gtk_box_pack_start(GTK_BOX(ihm_ImageHBox[TRACKING_PARAM_HBOX1]), ihm_ImageEntry[k], FALSE , FALSE, 0);
  }
  /* Second line of parameters */
  for (k=NB_TH_ENTRY; k<NB_IMAGES_ENTRIES; k++)  {
    if (k==FAKE_ENTRY) continue;
    gtk_box_pack_start(GTK_BOX(ihm_ImageHBox[TRACKING_PARAM_HBOX2]), ihm_ImageLabel[k], FALSE , FALSE, 0);
    gtk_box_pack_start(GTK_BOX(ihm_ImageHBox[TRACKING_PARAM_HBOX2]), ihm_ImageEntry[k], FALSE , FALSE, 0);
  }

  gtk_box_pack_start(GTK_BOX(ihm_ImageHBox[TRACKING_PARAM_HBOX2]), ihm_ImageLabel[FAKE_ENTRY], FALSE , FALSE, 0); // To fill space
  /* Fuses the two line in a single VBox */
  gtk_box_pack_start(GTK_BOX(ihm_ImageVBoxPT), ihm_ImageHBox[TRACKING_PARAM_HBOX1], FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX(ihm_ImageVBoxPT), ihm_ImageHBox[TRACKING_PARAM_HBOX2], FALSE , FALSE, 0);

  /* Builds the whole parameter block */
  gtk_box_pack_start(GTK_BOX(ihm_ImageHBox[TRACKING_PARAMS_HBOX]), ihm_ImageVBoxPT, FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX(ihm_ImageHBox[TRACKING_PARAMS_HBOX]), ihm_ImageButton[UPDATE_VISION_PARAMS_BUTTON], TRUE  , FALSE, 5);
  gtk_container_add(GTK_CONTAINER(ihm_ImageFrames[TRACKING_PARAMETERS_FRAME]), ihm_ImageHBox[TRACKING_PARAMS_HBOX]);

  for (k=TZ_KNOWN_BUTTON; k<=SE3_BUTTON; k++)
    gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[TRACKING_OPTION_HBOX]), ihm_ImageButton[k], TRUE , FALSE, 0);
  for (k=PROJ_OVERSCENE_BUTTON; k<=FLAT_GROUND_BUTTON; k++)
    gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[COMPUTING_OPTION_HBOX]), ihm_ImageButton[k], TRUE , FALSE, 0);

  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_DISPLAYSIZE_HBOX]), ihm_ImageVideoSizeLabel[VIDEO_DISPLAYSIZE_CAPTION_SIZES],  FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_DISPLAYSIZE_HBOX]), video_sizeList,  FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_DISPLAYSIZE_HBOX]), ihm_ImageVideoSizeLabel[VIDEO_DISPLAYSIZE_CAPTION_INTERP_MODES],  FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_DISPLAYSIZE_HBOX]), video_interpolationModesList, FALSE , FALSE, 0);

  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_STREAM_HBOX]), ihm_VideoStreamLabel[CODEC_TYPE_LIST], FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_STREAM_HBOX]), video_codecList,  FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_BITRATE_HBOX]), ihm_VideoStreamLabel[BITRATE_MODE_LIST], FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_BITRATE_HBOX]), video_bitrateModeList,  FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_BITRATE_HBOX]), ihm_VideoStreamLabel[MANUAL_BITRATE_ENTRY], FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_BITRATE_HBOX]), video_bitrateEntry,  FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_BITRATE_HBOX]), video_bitrateButton,  FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_BITRATE_HBOX]), ihm_VideoStreamLabel[WIFI_BITRATE_MODE_LIST], FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_BITRATE_HBOX]), wifi_bitrateModeList,  FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_STREAM_HBOX]), ihm_VideoStreamLabel[CODEC_FPS_LIST], FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_STREAM_HBOX]), codecFPSList,  FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_STREAM_HBOX]), codecSlicesList,  FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_STREAM_HBOX]), codecSocketList,  FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_STREAM_HBOX]), decodeLatencyList,  FALSE , FALSE, 0);
  gtk_box_pack_start(GTK_BOX( ihm_ImageHBox[VIDEO_STREAM_HBOX]), usbRecordCheckBox,  FALSE , FALSE, 0);



  /* */
  gtk_container_add(GTK_CONTAINER( ihm_ImageFrames[VIDEO_STREAM_FRAME])    , ihm_ImageHBox[VIDEO_STREAM_HBOX] );
  gtk_container_add(GTK_CONTAINER( ihm_ImageFrames[VIDEO_BITRATE_FRAME])    , ihm_ImageHBox[VIDEO_BITRATE_HBOX] );
  gtk_container_add(GTK_CONTAINER( ihm_ImageFrames[VIDEO_DISPLAYSIZE_FRAME]), ihm_ImageHBox[VIDEO_DISPLAYSIZE_HBOX] );
  gtk_container_add(GTK_CONTAINER( ihm_ImageFrames[TRACKING_OPTION_FRAME]) , ihm_ImageHBox[TRACKING_OPTION_HBOX] );
  gtk_container_add(GTK_CONTAINER( ihm_ImageFrames[COMPUTING_OPTION_FRAME]), ihm_ImageHBox[COMPUTING_OPTION_HBOX] );

  /* Video information box */
  video_information = gtk_label_new(" - Decoding information - ");
  video_information_hbox = gtk_hbox_new(FALSE,0);
  gtk_box_pack_start(GTK_BOX(video_information_hbox),video_information,FALSE,FALSE,5);

  /* Video navdata box */
  video_navdata = gtk_label_new(" - Navdata information - ");
  video_navdata_hbox = gtk_hbox_new(FALSE,0);
  gtk_box_pack_start(GTK_BOX(video_navdata_hbox),video_navdata,FALSE,FALSE,5);


  gtk_container_add(GTK_CONTAINER( ihm_ImageFrames[VIDEO_INFO_FRAME])    , video_information_hbox );
  gtk_container_add(GTK_CONTAINER( ihm_ImageFrames[VIDEO_NAVDATA_FRAME])    , video_navdata_hbox );


  /* Frame where to show buttons controlling how the drone video is displayed */
  displayvbox = gtk_vbox_new(FALSE,0);

  gtk_box_pack_start(GTK_BOX(displayvbox), ihm_ImageButton[PICTURE_BUTTON],     FALSE, FALSE, 5);
  gtk_box_pack_start(GTK_BOX(displayvbox), ihm_ImageButton[RAW_CAPTURE_BUTTON], FALSE, FALSE, 5);
  gtk_box_pack_start(GTK_BOX(displayvbox), ihm_ImageButton[RECORD_BUTTON],      FALSE, FALSE, 5);
  gtk_box_pack_start(GTK_BOX(displayvbox), ihm_ImageButton[ZAPPER_BUTTON],      FALSE, FALSE, 5);
  gtk_box_pack_start(GTK_BOX(displayvbox), ihm_ImageButton[FULLSCREEN_BUTTON],  FALSE, FALSE, 5);
  gtk_box_pack_start(GTK_BOX(displayvbox), ihm_ImageButton[PAUSE_BUTTON],       FALSE, FALSE, 5);
  gtk_box_pack_start(GTK_BOX(displayvbox), ihm_ImageButton[LATENCY_ESTIMATOR_BUTTON],       FALSE, FALSE, 5);
  gtk_box_pack_start(GTK_BOX(displayvbox), ihm_ImageButton[CUSTOM_BUTTON],       FALSE, FALSE, 5);

  gtk_box_pack_start(GTK_BOX(ihm_ImageHBox[VIDEO_DISPLAY_HBOX]),ihm_VideoStream_VBox,FALSE,FALSE,5);
  gtk_box_pack_start(GTK_BOX(ihm_ImageHBox[VIDEO_DISPLAY_HBOX]),displayvbox,FALSE,FALSE,5);

  gtk_container_add(GTK_CONTAINER( ihm_ImageFrames[VIDEO_DISPLAY_FRAME])    , ihm_ImageHBox[VIDEO_DISPLAY_HBOX] );

  /* Builds the final window */
  gtk_box_pack_start(GTK_BOX(ihm_ImageVBox), ihm_ImageFrames[VIDEO_DISPLAY_FRAME], FALSE, FALSE, 5);
  gtk_box_pack_start(GTK_BOX(ihm_ImageVBox), ihm_ImageFrames[VIDEO_INFO_FRAME], FALSE, FALSE, 5);
  gtk_box_pack_start(GTK_BOX(ihm_ImageVBox), ihm_ImageFrames[VIDEO_NAVDATA_FRAME], FALSE, FALSE, 5);
  gtk_box_pack_start(GTK_BOX(ihm_ImageVBox), ihm_ImageFrames[VIDEO_STREAM_FRAME], FALSE, FALSE, 5);
  gtk_box_pack_start(GTK_BOX(ihm_ImageVBox), ihm_ImageFrames[VIDEO_BITRATE_FRAME], FALSE, FALSE, 5);
  gtk_box_pack_start(GTK_BOX(ihm_ImageVBox), ihm_ImageFrames[VIDEO_DISPLAYSIZE_FRAME], FALSE, FALSE, 5);
  gtk_box_pack_start(GTK_BOX(ihm_ImageVBox), ihm_ImageFrames[STATE_FRAME], FALSE, FALSE, 5);
  //gtk_box_pack_start(GTK_BOX(ihm_ImageVBox), ihm_ImageHBox[TRACKING_PARAMS_HBOX], FALSE, FALSE, 5);
  gtk_box_pack_start(GTK_BOX(ihm_ImageVBox), ihm_ImageFrames[TRACKING_PARAMETERS_FRAME], FALSE, FALSE, 5);  
  gtk_box_pack_start(GTK_BOX(ihm_ImageVBox), ihm_ImageFrames[TRACKING_OPTION_FRAME], FALSE, FALSE, 5);
  gtk_box_pack_start(GTK_BOX(ihm_ImageVBox), ihm_ImageFrames[COMPUTING_OPTION_FRAME], FALSE, FALSE, 5);

  gtk_container_add(GTK_CONTAINER(ihm_ImageWin), ihm_ImageVBox);
  image_vision_window_view = WINDOW_HIDE;
  image_vision_window_status = WINDOW_OPENED;

  /* Set the callback for the checkbox inside the main application window */
  //g_signal_connect(G_OBJECT(button_show_image), "clicked", G_CALLBACK(ihm_showImage), (gpointer) ihm_ImageWin);
  g_signal_connect(G_OBJECT(button_show_image2), "clicked", G_CALLBACK(ihm_showImage), (gpointer) ihm_ImageWin);
}



C_RESULT navdata_hdvideo_init( void* param )
{
	return C_OK;
}

C_RESULT navdata_hdvideo_process( const navdata_unpacked_t* const navdata )
{
	char buffer[1024];

	snprintf(buffer,sizeof(buffer)-1,"Storage FIFO: %d packets - %d kbytes %s\nUSB key : size %d kbytes - free %d kbytes",
			navdata->navdata_hdvideo_stream.storage_fifo_nb_packets,
			navdata->navdata_hdvideo_stream.storage_fifo_size,
			(navdata->navdata_hdvideo_stream.hdvideo_state&NAVDATA_HDVIDEO_STORAGE_FIFO_IS_FULL)?
					"- FULL":
					"",
			navdata->navdata_hdvideo_stream.usbkey_size,
			navdata->navdata_hdvideo_stream.usbkey_freespace);

	gdk_threads_enter();

	if (video_information){
			gtk_label_set_text((GtkLabel *)video_navdata,(const gchar*)buffer);
			gtk_label_set_justify((GtkLabel *)video_navdata,GTK_JUSTIFY_LEFT);
	    }

	gdk_threads_leave();

	return C_OK;
}

C_RESULT navdata_hdvideo_release( void )
{
	return C_OK;
}


