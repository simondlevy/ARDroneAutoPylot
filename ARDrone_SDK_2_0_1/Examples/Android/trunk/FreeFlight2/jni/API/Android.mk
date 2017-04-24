LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE    := sdk 
LOCAL_SRC_FILES := libsdk.a

include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE    := pc_ardrone 
LOCAL_SRC_FILES := libpc_ardrone.a

include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE    := vlib 
LOCAL_SRC_FILES := libvlib.a

include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)  

LOCAL_CFLAGS += -I$(SDK_PATH)
LOCAL_CFLAGS += -I$(SDK_PATH)/Soft/Common
LOCAL_CFLAGS += -I$(SDK_PATH)/Soft/Lib
LOCAL_CFLAGS += -I$(SDK_PATH)/VLIB
LOCAL_CFLAGS += -I$(SDK_PATH)/VLIB/Platform/arm9
LOCAL_CFLAGS += -I$(SDK_PATH)/VP_SDK
LOCAL_CFLAGS += -I$(SDK_PATH)/VP_SDK/VP_Com/linux
LOCAL_CFLAGS += -I$(SDK_PATH)/VP_SDK/VP_Com
LOCAL_CFLAGS += -I$(SDK_PATH)/VP_SDK/VP_Os
LOCAL_CFLAGS += -I$(SDK_PATH)/VP_SDK/VP_Os/linux
LOCAL_CFLAGS += -I$(SDK_PATH)/VP_SDK/VP_Com/linux

LOCAL_C_INCLUDES:=	$(LOCAL_PATH)/../ITTIAM/avc_decoder/includes \
					$(LOCAL_PATH)/../ITTIAM/m4v_decoder/includes \
					$(LOCAL_PATH)/../FFMPEG/Includes
#LIB_PATH=$(LOCAL_PATH)/../../libs/armeabi

LOCAL_LDLIBS := -llog -lGLESv2 -ljnigraphics

LOCAL_MODULE    := adfreeflight  

LOCAL_SRC_FILES := app.c \
				video_stage_io_file.c \
				hardware_capabilites.c \
				Controller/ardrone_controller.c \
				ControlData.c \
				Callbacks/drone_proxy_callbacks.c \
				Callbacks/java_callbacks.c \
				Plf/plf.c \
				Stubs/drone_stub.c \
				Stubs/drone_config_stub.c \
				Stubs/ftp_client_stub.c \
				Stubs/plf_file_stub.c \
				Stubs/transcoding_service_stub.c \
				Stubs/gl_bg_video_sprite_stub.c \
				NavData/nav_data.c \
				Video/video_stage_renderer.c \
				Video/frame_rate.c \
				Controller/virtual_gamepad.c \
				Video/opengl_stage.c \
				Video/opengl_shader.c 

LOCAL_STATIC_LIBRARIES := pc_ardrone vlib sdk ittiam_avc_decoder ittiam_m4v_decoder ittiam_decoder_utils
LOCAL_SHARED_LIBRARIES := AVUTIL-prebuilt AVCODEC-prebuilt SWSCALE-prebuilt AVFILTER-prebuilt AVFORMAT-prebuilt AVDEVICE-prebuilt

LOCAL_CFLAGS += -D__USE_GNU -D__linux__ -DNO_ARDRONE_MAINLOOP -DUSE_ANDROID -DTARGET_CPU_ARM=1 -DTARGET_CPU_X86=0 -DUSE_WIFI -DFFMPEG_SUPPORT -fstack-protector
LOCAL_CFLAGS += -DANDROID_NDK
#LOCAL_LDFLAGS := -Wl,-Map,app.map

include $(BUILD_SHARED_LIBRARY)

