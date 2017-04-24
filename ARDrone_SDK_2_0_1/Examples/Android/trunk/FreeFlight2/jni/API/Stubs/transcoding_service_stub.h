/*
 * transcoding_service_stub.h
 *
 *  Created on: Apr 6, 2012
 *      Author: "Dmytro Baryskyy"
 */

#ifndef TRANSCODING_SERVICE_STUB_H_
#define TRANSCODING_SERVICE_STUB_H_


typedef enum
{
	VIDEO_RECORD_HOLD, // Video recording is on hold, waiting for the start command. This is the default state.
	VIDEO_RECORD_START, // Video recording has started.
	VIDEO_PICTURE_START,
	VIDEO_PICTURE_HOLD,
	VIDEO_RECORD_STOP		// Video recording has been stopped. Stage will end and restart.
} video_record_state;


typedef struct _encoder_stage_config_t_
{
	// Public
    char *file_src;
    char *file_dest;
    video_record_state startRec;
    vlib_stage_decoding_config_t *vlib_stage_decoding_config;

    AVCodec *codec;
    AVFormatContext *oc;
    AVOutputFormat *fmt;
    AVStream *video_s;
    AVCodecContext *c;
    int i, out_size, size, x, y, outbuf_size;
    FILE *f;

    // Private
    uint32_t *numframes;
    int starting_num_frames;
    int previous_num_picture_decoded;
    bool_t success;
    bool_t first_frame_ok;
    bool_t video_file_open;
} encoder_stage_config_t;


static C_RESULT create_video_file(const char*filename,int width,int height,int frame_rate, enum PixelFormat pix_fmt);
static void close_video_file();
static AVStream *add_video_stream(AVFormatContext *oc, enum CodecID codec_id,int width, int height, int frame_rate, enum PixelFormat pix_fmt);
static AVFrame *alloc_picture(enum PixelFormat pix_fmt, int width, int height);
static C_RESULT open_video(AVFormatContext *oc, AVStream *st);
static C_RESULT write_video_frame(AVFormatContext *oc, AVStream *st);
static void close_video(AVFormatContext *oc, AVStream *st);


PROTO_THREAD_ROUTINE(encoder, data);

///////////////////////////////////////////////
// FUNCTIONS

C_RESULT
encoder_handle (encoder_stage_config_t * cfg, PIPELINE_MSG msg_id, void *callback, void *param);

/**
 * @fn      Open the quicktime encoder stage
 * @param   quicktime_encoder_stage_config_t *cfg
 * @return  VP_SUCCESS
 */
C_RESULT
encoder_stage_open(encoder_stage_config_t *cfg);

/**
 * @fn      Transform the quicktime encoder stage
 * @param   quicktime_encoder_stage_config_t *cfg
 * @param   vp_api_io_data_t *in
 * @param   vp_api_io_data_t *out
 * @return  VP_SUCCESS
 */
C_RESULT
encoder_stage_transform(encoder_stage_config_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out);

/**
 * @fn      Close the quicktime encoder stage
 * @param   quicktime_encoder_stage_config_t *cfg
 * @return  VP_SUCCESS
 */
C_RESULT
encoder_stage_close(encoder_stage_config_t *cfg);


extern const vp_api_stage_funcs_t encoder_stage_funcs;


#endif /* TRANSCODING_SERVICE_STUB_H_ */
