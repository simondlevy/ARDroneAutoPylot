/*
 * transcoding_service_stub.c
 *
 *  Created on: Apr 6, 2012
 *      Author: "Dmytro Baryskyy"
 */

#include <common.h>
#include "transcoding_service_stub.h"
#include "video_stage_io_file.h"
#include <libswscale/swscale.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>

#include <utils/ardrone_video_atoms.h>

#define NB_STAGES   5
#define ENCODER_PRIORITY  (15)

#define STREAM_DURATION   5.0
#define STREAM_FRAME_RATE 20 /* 20 images/s */
#define STREAM_NB_FRAMES  ((int)(STREAM_DURATION * STREAM_FRAME_RATE))

static const char* TAG = "TranscodingServiceNative";

static bool_t encoder_stage_in_pause = FALSE;
static bool_t encoder_sgate_stop_requested = FALSE;
static vp_os_cond_t encoder_stage_condition;
static vp_os_mutex_t  encoder_stage_mutex;

static THREAD_HANDLE encoder_thread;

/*- LibAVFormat variables */
const char *filename;
static AVFrame *picture = NULL, *tmp_picture = NULL;
static AVOutputFormat *fmt = NULL;
static AVFormatContext *oc = NULL;
static AVStream *video_st = NULL;
double video_pts;

#define STREAM_BIT_RATE_KBITS 1600
static const int sws_flags = SWS_BICUBIC;

uint8_t *video_outbuf=NULL;
int frame_count=0, video_outbuf_size=0;


const vp_api_stage_funcs_t encoder_stage_funcs =
{
    (vp_api_stage_handle_msg_t) encoder_handle,
    (vp_api_stage_open_t) encoder_stage_open,
    (vp_api_stage_transform_t) encoder_stage_transform,
    (vp_api_stage_close_t) encoder_stage_close
};

struct
{
	int width,height;
	char* buffer;
	int frame_number;
} previous_frame;


void encoderThreadResume()
{
	vp_os_mutex_lock(&encoder_stage_mutex);
	vp_os_cond_signal(&encoder_stage_condition);
	encoder_stage_in_pause = FALSE;
	LOGV(TAG, "Encoder stage resumed");
	vp_os_mutex_unlock(&encoder_stage_mutex);
}


void encoderThreadStop()
{
	vp_os_mutex_lock(&encoder_stage_mutex);
	encoder_sgate_stop_requested = TRUE;
	LOGV(TAG, "Encoder stage stop requested");
	vp_os_mutex_unlock(&encoder_stage_mutex);


	if (encoder_stage_in_pause) {
		encoderThreadResume();
	}
}


JNIEXPORT void JNICALL
Java_com_parrot_freeflight_transcodeservice_TranscodingService_encoderThreadStart(JNIEnv *env, jobject obj)
{
	LOGD(TAG, "Initializing encoder");
	encoder_stage_in_pause = FALSE;
	encoder_sgate_stop_requested = FALSE;

	vp_os_mutex_init(&encoder_stage_mutex);
	vp_os_cond_init(&encoder_stage_condition, &encoder_stage_mutex);

	jobject serviceHandle = (*env)->NewGlobalRef(env, obj);

	LOGD(TAG, "Starting encoder thread...");
	vp_os_thread_create (thread_encoder, serviceHandle, &encoder_thread);
}


static int encoder_expand_buffer_x2_yuv420p(/*Input*/uint8_t*in_buf,
                                               /*output*/uint8_t*out_buf,
                                               int width,
                                               int height,
                                               int rowstride)
{
	int row,col;
	uint32_t *src,*dst1,*dst2;
	uint32_t r,w1,w2;

//	src =(uint32_t*) ( in ); //+ 1*row*width   );
	/* Expand the buffer */
    for (row=0;row<height;row++)
    {
        src = (uint32_t*) (in_buf + (rowstride * row));
        dst1=(uint32_t*) ( out_buf + (2*row+0)*2*width );
        dst2=(uint32_t*) ( out_buf + (2*row+1)*2*width );

        /* Takes 4 points 'abcd' and writes 'aabb' 'ccdd'
         *                                  'aabb' 'ccdd'
         */
        for (col=0;col<width/4;col++)
        {
            r=*(src++);
            w1= ( (r&0x000000FF)      ) | ( (r&0x000000FF)<<8 ) | ((r&0x0000FF00)<<8  ) | ( (r&0x0000FF00)<<16 );
            w2= ( (r&0x00FF0000) >> 16) | ( (r&0x00FF0000)>>8 ) | ((r&0xFF000000)>>8 )  | ( (r&0xFF000000) );

            *(dst1++)=w1; *(dst1++)=w2;
            *(dst2++)=w1; *(dst2++)=w2;
        }
    }

    return 0;
}



static C_RESULT create_video_file(const char*filename, int width, int height, int frame_rate, enum PixelFormat pix_fmt)
{
	/* auto detect the output format from the name. default is mpeg. */
    avformat_alloc_output_context2(&oc, NULL, "mp4", filename);

    if (!oc) {
        LOGW(TAG, "Could not deduce output format from file extension: using MPEG.");
        avformat_alloc_output_context2(&oc, NULL, "mpeg", filename);
    }

    if (!oc) {
    	LOGW(TAG, "Memory error");
        return C_FAIL;
    }

    LOGD(TAG, "Output Context Created [OK]");
    /* add the audio and video streams using the default format codecs
       and initialize the codecs */
    video_st = NULL;
    fmt = oc->oformat;

    if (fmt->video_codec != CODEC_ID_MPEG4) {
    	if (fmt->video_codec == CODEC_ID_H263) {
    		LOGD(TAG, "Guessed codec is CODEC_ID_H263");
    	} else {
    		LOGW(TAG, "Guessed codec is not MPEG4. It is %d", fmt->video_codec);
    	}
    }

    LOGD(TAG, "Using codec: %s ", fmt->long_name);
    LOGD(TAG, "Codec ID: %s", fmt->video_codec == CODEC_ID_MPEG4?"CODEC_ID_MPEG4":"UNKNOWN");

    if (fmt->video_codec != CODEC_ID_NONE) {
    	LOGD(TAG, "Adding video stream. Width: %d Height: %d Frame rate: %d", width, height, frame_rate);
        video_st = add_video_stream(oc, fmt->video_codec, width, height, frame_rate, pix_fmt);

        if (video_st == NULL) {
        	LOGW(TAG, "Could not add video stream.");
        	return C_FAIL;
        }
    }

   // av_dump_format(oc, 0, filename, 1);
   // LOGV(TAG, "av_dump_format [OK]");

    /* now that all the parameters are set, we can open the audio and
       video codecs and allocate the necessary encode buffers */
    if (video_st) {
        if (VP_FAILED(open_video(oc, video_st))) {
        	LOGW(TAG, "Can't open video");
        	return C_FAIL;
        }
    } else {
    	LOGW(TAG, "Video_st is null");
    }

    int res = avio_check(filename, AVIO_FLAG_WRITE);
	LOGW(TAG, "avio_check == %d", res);


    /* open the output file, if needed */
    if (!(fmt->flags & AVFMT_NOFILE)) {
    	int result = avio_open(&oc->pb, filename, AVIO_FLAG_WRITE);
        if (result < 0) {
        	char error[256] = {0};
        	av_strerror(result, error, 256);
        	LOGW(TAG, "Could not open '%s', error: %d %s", filename, result, error);
            return C_FAIL;

        } else {
        	LOGV(TAG, "avio_open [OK]");
        }
    }

    /* write the stream header, if any */
    av_write_header(oc);

    LOGD(TAG, "Create video file [OK]");

    return C_OK;
 }


static void close_video_file()
{
/* write the trailer, if any.  the trailer must be written
     * before you close the CodecContexts open when you wrote the
     * header; otherwise write_trailer may try to use memory that
     * was freed on av_codec_close() */
    av_write_trailer(oc);

    /* close each codec */
    if (video_st)
        close_video(oc, video_st);

    int i=0;
    /* free the streams */
    for(i = 0; i < oc->nb_streams; i++) {
        av_freep(&oc->streams[i]->codec);
        av_freep(&oc->streams[i]);
    }

    if (!(fmt->flags & AVFMT_NOFILE)) {
        /* close the output file */
        avio_close(oc->pb);
    }

    /* free the stream */
    av_free(oc);
}



static C_RESULT open_video(AVFormatContext *oc, AVStream *st)
{
	if (oc == NULL || st == NULL) {
		LOGW(TAG, "Wrong parameters");
		return C_FAIL;
	}

   AVCodec *codec;
   AVCodecContext *c;

   c = st->codec;

   /* find the video encoder */
   codec = avcodec_find_encoder(c->codec_id);
   if (!codec) {
       LOGW(TAG, "Codec not found");
       return C_FAIL;
   }

   LOGD(TAG, "Find encoder [OK]");
   /* open the codec */
   if (avcodec_open(c, codec) < 0) {
	   LOGW(TAG, "Could not open codec");
       return C_FAIL;
   }

   LOGD(TAG, "Open codec [OK]");
   video_outbuf = NULL;
   if (!(oc->oformat->flags & AVFMT_RAWPICTURE)) {
       /* allocate output buffer */
       /* XXX: API change will be done */
       /* buffers passed into lav* can be allocated any way you prefer,
          as long as they're aligned enough for the architecture, and
          they're freed appropriately (such as using av_free for buffers
          allocated with av_malloc) */
       video_outbuf_size = 200000;
       video_outbuf = av_malloc(video_outbuf_size);
   }

   LOGD(TAG, "Allocate video outbuff [OK]");

   picture = alloc_picture(c->pix_fmt, c->width, c->height);

   LOGD(TAG, "Allocate picture [OK]");
   if (!picture) {
	   LOGW(TAG, "Could not allocate picture");
	   return C_FAIL;
   }

   /* if the output format is not YUV420P, then a temporary YUV420P
      picture is needed too. It is then converted to the required
      output format */
   tmp_picture = NULL;
   if (c->pix_fmt != PIX_FMT_YUV420P) {
       tmp_picture = alloc_picture(PIX_FMT_YUV420P, c->width, c->height);
       if (!tmp_picture) {
    	   LOGW(TAG, "Could not allocate temporary picture");
           return C_FAIL;
       }
   }

   return C_OK;
}


static AVFrame *alloc_picture(enum PixelFormat pix_fmt, int width, int height)
{
    AVFrame *picture;
    uint8_t *picture_buf;
    int size;

    picture = avcodec_alloc_frame();
    if (!picture)
        return NULL;
    size = avpicture_get_size(pix_fmt, width, height);
    picture_buf = av_malloc(size);
    if (!picture_buf) {
        av_free(picture);
        return NULL;
    }
    avpicture_fill((AVPicture *)picture, picture_buf,
                   pix_fmt, width, height);
    return picture;
}

/**************************************************************/
/* video output */
/* add a video output stream */
static AVStream *add_video_stream(AVFormatContext *oc, enum CodecID codec_id, int width, int height,int frame_rate, enum PixelFormat pix_fmt)
{
    AVCodecContext *c;
    AVStream *st;

    st = av_new_stream(oc, 0);
    if (!st) {
    	LOGW(TAG, "Could not alloc stream");
        return NULL;
    }

    c = st->codec;
    c->codec_id = codec_id;
    c->codec_type = AVMEDIA_TYPE_VIDEO;

    /* put sample parameters */
    c->bit_rate = (STREAM_BIT_RATE_KBITS)*1000;
    /* resolution must be a multiple of two */
    c->width = width;
    c->height = height;
    /* time base: this is the fundamental unit of time (in seconds) in terms
       of which frame timestamps are represented. for fixed-fps content,
       timebase should be 1/framerate and timestamp increments should be
       identically 1. */
    c->time_base.den = frame_rate;
    c->time_base.num = 1;
    c->gop_size = 12; /* emit one intra frame every twelve frames at most */
    c->pix_fmt = pix_fmt;
    if (c->codec_id == CODEC_ID_MPEG2VIDEO) {
        /* just for testing, we also add B frames */
        c->max_b_frames = 2;
    }
    if (c->codec_id == CODEC_ID_MPEG1VIDEO){
        /* Needed to avoid using macroblocks in which some coeffs overflow.
           This does not happen with normal video, it just happens here as
           the motion of the chroma plane does not match the luma plane. */
        c->mb_decision=2;
    }
    // some formats want stream headers to be separate
    if(oc->oformat->flags & AVFMT_GLOBALHEADER)
        c->flags |= CODEC_FLAG_GLOBAL_HEADER;

    return st;
}


static C_RESULT write_video_frame(AVFormatContext *oc, AVStream *st)
{
   int out_size, ret;
   AVCodecContext *c;
   static struct SwsContext *img_convert_ctx;

   //printf("Here0 \n");

   c = st->codec;

   if (frame_count >= STREAM_NB_FRAMES) {
       /* no more frame to compress. The codec has a latency of a few
          frames if using B frames, so we get the last frames by
          passing the same picture again */
   } else {
       if (c->pix_fmt != PIX_FMT_YUV420P) {
           /* as we only generate a YUV420P picture, we must convert it
              to the codec pixel format if needed */
           if (img_convert_ctx == NULL) {

		#if (LIBSWSCALE_VERSION_INT<AV_VERSION_INT(0,12,0))
           	img_convert_ctx = sws_getContext(c->width, c->height,
                                                PIX_FMT_YUV420P,
                                                c->width, c->height,
                                                c->pix_fmt,
                                                sws_flags, NULL, NULL, NULL);
		#else
           	img_convert_ctx = sws_alloc_context();

               if (img_convert_ctx == NULL) {
            	   LOGW(TAG, "Cannot initialize the conversion context");
                   return C_FAIL;
               }

               /* see http://permalink.gmane.org/gmane.comp.video.ffmpeg.devel/118362 */
               /* see http://ffmpeg-users.933282.n4.nabble.com/Documentation-for-sws-init-context-td2956723.html */

               av_set_int(img_convert_ctx, "srcw", c->width);
               av_set_int(img_convert_ctx, "srch", c->height);

               av_set_int(img_convert_ctx, "dstw", c->width);
               av_set_int(img_convert_ctx, "dsth", c->height);

               av_set_int(img_convert_ctx, "src_format", PIX_FMT_YUV420P);
               av_set_int(img_convert_ctx, "dst_format", c->pix_fmt);

               av_set_int(img_convert_ctx, "param0", 0);
               av_set_int(img_convert_ctx, "param1", 0);

               av_set_int(img_convert_ctx, "flags", sws_flags);

               sws_init_context(img_convert_ctx,NULL,NULL);
		#endif

           }
           sws_scale(img_convert_ctx, (const uint8_t* const *)tmp_picture->data,
           		  tmp_picture->linesize,
                     0, c->height, picture->data, picture->linesize);
       } else {

       }
   }


   if (oc->oformat->flags & AVFMT_RAWPICTURE) {
       /* raw video case. The API will change slightly in the near
          futur for that */
       AVPacket pkt;
       av_init_packet(&pkt);

       pkt.flags |= AV_PKT_FLAG_KEY;
       pkt.stream_index= st->index;
       pkt.data= (uint8_t *)picture;
       pkt.size= sizeof(AVPicture);

       ret = av_interleaved_write_frame(oc, &pkt);
   } else {
       /* encode the image */
       out_size = avcodec_encode_video(c, video_outbuf, video_outbuf_size, picture);
       /* if zero size, it means the image was buffered */
       if (out_size > 0) {
           AVPacket pkt;
           av_init_packet(&pkt);

           if (c->coded_frame->pts != AV_NOPTS_VALUE)
               pkt.pts= av_rescale_q(c->coded_frame->pts, c->time_base, st->time_base);
           if(c->coded_frame->key_frame)
               pkt.flags |= AV_PKT_FLAG_KEY;
           pkt.stream_index= st->index;
           pkt.data= video_outbuf;
           pkt.size= out_size;

           /* write the compressed frame in the media file */
           ret = av_interleaved_write_frame(oc, &pkt);
       } else {
           ret = 0;
       }
   }
   if (ret != 0) {
	   LOGW(TAG, "Error while writing video frame");
       return C_FAIL;
   }

   frame_count++;

   return C_OK;
}


static void close_video(AVFormatContext *oc, AVStream *st)
{
   avcodec_close(st->codec);
   av_free(picture);
   picture = NULL;
   if (tmp_picture) {
       av_free(tmp_picture->data[0]);
       av_free(tmp_picture);
       tmp_picture=NULL;
   }
   av_free(video_outbuf);
}


static jstring encoder_stage_get_next_file(JNIEnv* env, jobject obj, const char* extention)
{
	jclass cls = (*env)->GetObjectClass(env, obj);
	jmethodID mid = (*env)->GetMethodID(env, cls, "getNextFile", "()Ljava/lang/String;");

	if (mid == 0) {
		LOGW(TAG, "Method not found");
		return NULL;
	}

	jstring result = (*env)->CallObjectMethod(env, obj, mid);

	// Removing reference to the class instance
	(*env)->DeleteLocalRef(env, cls);

    return result;
}


static void notify_media_ready(JNIEnv* env, jobject obj, encoder_stage_config_t* cfg)
{
	LOGD(TAG, "Notifying about new media available");
	parrot_java_callbacks_call_void_method_string(env, obj, "onMediaReady", cfg->file_dest);
}

C_RESULT
encoder_handle (encoder_stage_config_t * cfg, PIPELINE_MSG msg_id, void *callback, void *param)
{
	LOGV(TAG, "FFMPEG recorder message handler.");
	switch (msg_id)
	{
		case PIPELINE_MSG_START:
			if(cfg->startRec==VIDEO_RECORD_STOP)
				cfg->startRec=VIDEO_RECORD_HOLD;
			else
				cfg->startRec=VIDEO_RECORD_STOP;
			break;

		default:
			break;
	}

	return (VP_SUCCESS);
}


C_RESULT encoder_stage_open(encoder_stage_config_t *cfg)
{
	LOGV(TAG, "Encoder Stage Open called");
	avcodec_init();
	av_register_all();

	cfg->file_dest = strncpy(cfg->file_dest, cfg->file_src, strlen(cfg->file_src));
	cfg->file_dest[strlen(cfg->file_src)-3] = '\0';
	cfg->file_dest = strncat(cfg->file_dest, "bak", 3);
	cfg->video_file_open = 0;
	LOGD(TAG, "Destination file name: %s", cfg->file_dest);

	if (VP_FAILED(create_video_file(cfg->file_dest, 320, 240, STREAM_FRAME_RATE, PIX_FMT_YUV420P))) {
		return C_FAIL;
	}

	cfg->video_file_open = 1;
    LOGD(TAG, "File opened [OK]");

	return C_OK;
}


C_RESULT encoder_stage_transform(encoder_stage_config_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out)
{
    C_RESULT result = C_FAIL;
    if (in == NULL || out == NULL || cfg == NULL) {
    	LOGE(TAG, "One of input parameters to encoder_sgate_transform is NULL");
    	return result;
    }

    vp_os_mutex_lock(&out->lock);

    if( out->status == VP_API_STATUS_INIT )
    {
		cfg->previous_num_picture_decoded = 0;
        out->status = VP_API_STATUS_PROCESSING;
    }

    if( in->status == VP_API_STATUS_ENDED )
    {
        out->status = in->status;
        result = C_OK;
    }

    if(out->status == VP_API_STATUS_PROCESSING)
    {
        if(cfg->vlib_stage_decoding_config->num_picture_decoded > cfg->previous_num_picture_decoded)
        {
            if(!cfg->first_frame_ok)
            {
                if(cfg->vlib_stage_decoding_config->controller.picture_type == VIDEO_PICTURE_INTRA)
                {
                    cfg->first_frame_ok = TRUE;
                    cfg->starting_num_frames = cfg->vlib_stage_decoding_config->controller.num_frames;

                    LOGV(TAG, "Starting session");
                }

                result = C_OK;
            }

            if(cfg->first_frame_ok)
            {
            	if (picture != NULL)
				{
            		 uint8_t *y_buf = NULL, *cb_buf = NULL, *cr_buf = NULL;
            		 int frameWidth = cfg->vlib_stage_decoding_config->controller.width;
            		 int frameHeight = cfg->vlib_stage_decoding_config->controller.height;
            		 int outFrameWidth = cfg->vlib_stage_decoding_config->picture->width;
            		 int outFrameHeight = cfg->vlib_stage_decoding_config->picture->height;

            		 if(frameWidth < outFrameWidth &&
            		    frameHeight < outFrameWidth)
					 {
            			 /* Expand the Y buffer */
						int w_cropping = ((frameWidth * 2) - outFrameWidth) / 2;
						int h_cropping = ((frameHeight * 2) - outFrameHeight) / 2;

						y_buf = vp_os_malloc( outFrameWidth * outFrameHeight);

						encoder_expand_buffer_x2_yuv420p ( cfg->vlib_stage_decoding_config->picture->y_buf,
								y_buf,
								frameWidth - w_cropping,
								frameHeight - h_cropping,
								outFrameWidth);

						cb_buf  = vp_os_malloc( outFrameWidth * outFrameHeight / 4);
						cr_buf  = vp_os_malloc( outFrameWidth * outFrameHeight / 4);

						/* Expand the U buffer */
						encoder_expand_buffer_x2_yuv420p(cfg->vlib_stage_decoding_config->picture->cb_buf,
																	cb_buf,
																	(frameWidth - w_cropping) / 2,
																	(frameHeight - h_cropping) / 2,
																	 outFrameWidth / 2);

						/* Expand the V buffer */
						encoder_expand_buffer_x2_yuv420p(cfg->vlib_stage_decoding_config->picture->cr_buf,
								cr_buf,
								(frameWidth - w_cropping) / 2,
								(frameHeight - h_cropping) / 2,
								outFrameWidth / 2);

						picture->data[0] = picture->base[0] = y_buf;
						picture->data[1] = picture->base[1] = cb_buf;
						picture->data[2] = picture->base[2] = cr_buf;

					} else {
						picture->data[0] = picture->base[0] = cfg->vlib_stage_decoding_config->picture->y_buf;
						picture->data[1] = picture->base[1] = cfg->vlib_stage_decoding_config->picture->cb_buf;
						picture->data[2] = picture->base[2] = cfg->vlib_stage_decoding_config->picture->cr_buf;
					}

					picture->linesize[0] = cfg->vlib_stage_decoding_config->picture->y_line_size;
					picture->linesize[1] = cfg->vlib_stage_decoding_config->picture->cb_line_size;
					picture->linesize[2] = cfg->vlib_stage_decoding_config->picture->cr_line_size;

			    	write_video_frame(oc, video_st);

			    	if (y_buf) vp_os_free(y_buf);
			    	if (cb_buf) vp_os_free(cb_buf);
			    	if (cr_buf) vp_os_free(cr_buf);
				}

				result = C_OK;
            }

            cfg->previous_num_picture_decoded = cfg->vlib_stage_decoding_config->num_picture_decoded;
        }
    }

    out->numBuffers = in->numBuffers;
    out->indexBuffer = in->indexBuffer;
    out->buffers = in->buffers;

    cfg->success = ((result == C_OK) && cfg->first_frame_ok);

    vp_os_mutex_unlock(&out->lock);

    return result;
}


C_RESULT encoder_stage_close(encoder_stage_config_t *cfg)
{
	close_video_file();

    const char *ardtFileName = NULL;
    const char *ardtData     = NULL;
    FILE *ardtFile           = NULL;
    movie_atom_t *ardtAtom   = NULL;


   if(cfg->success)
	{
		ardtFileName = cfg->file_dest;
		ardtData     = "This is just for test";
		if (NULL == ardtFileName || NULL == ardtData)
		{
			cfg->success = FALSE;
		}
	}


   if(cfg->success)
   {
       ardtFile = fopen(ardtFileName, "ab");
       if (NULL == ardtFile)
       {
           cfg->success = FALSE;
       }
   }

   if (cfg->success)
   {
       ardtAtom = ardtAtomFromPathAndDroneVersion(ardtData, 1);
       if (-1 == writeAtomToFile(&ardtAtom, ardtFile))
       {
           cfg->success = FALSE;
       }

       fclose (ardtFile);
   }

   if (cfg->success == TRUE) {
	   LOGD(TAG, "Updated atom info [OK]");
   }

	LOGV(TAG, "Encoder stage close called");
	return C_OK;
}


PROTO_THREAD_ROUTINE(encoder, data)
{
	JNIEnv* env = NULL;
	jobject service = data;

	if (g_vm) {
		(*g_vm)->AttachCurrentThread (g_vm, (JNIEnv **) &env, NULL);
	}

	LOGD(TAG, "Encoder thread started [OK]");

    C_RESULT res = C_FAIL;

    PIPELINE_HANDLE encoder_pipeline_handle;

	vp_api_io_pipeline_t    pipeline;
	vp_api_io_data_t        out;
	vp_api_io_stage_t       stages[NB_STAGES];

	vp_api_picture_t picture;

	video_stage_io_file_config_t ifc;
	vlib_stage_decoding_config_t vec;
    encoder_stage_config_t       qec;

    vp_os_thread_priority(vp_os_thread_self(), ENCODER_PRIORITY);

	vp_os_memset(&ifc,          0, sizeof( ifc ));
	vp_os_memset(&vec,          0, sizeof( vec ));
	vp_os_memset(&picture,      0, sizeof( picture ));

	/// Picture configuration
    picture.format        = PIX_FMT_YUV420P;

	picture.width         = QVGA_WIDTH;
	picture.height        = QVGA_HEIGHT;
	picture.framerate     = 20;

	picture.y_buf   = vp_os_malloc( picture.width * picture.height );
    picture.cr_buf  = vp_os_malloc( picture.width * picture.height / 4);
	picture.cb_buf  = vp_os_malloc( picture.width * picture.height / 4);

	picture.y_line_size   = picture.width;
	picture.cb_line_size  = picture.width / 2;
	picture.cr_line_size  = picture.width / 2;

	vec.width               = picture.width;
	vec.height              = picture.height;
	vec.picture             = &picture;
	vec.luma_only           = FALSE;
	vec.block_mode_enable   = TRUE;

    qec.vlib_stage_decoding_config = &vec;
    ifc.filename = NULL;
    qec.file_src = NULL;

	pipeline.nb_stages = 0;

	stages[pipeline.nb_stages].type    = VP_API_INPUT_BUFFER;
	stages[pipeline.nb_stages].cfg     = (void *)&ifc;
	stages[pipeline.nb_stages++].funcs = video_stage_io_file_funcs;

	stages[pipeline.nb_stages].type    = VP_API_FILTER_DECODER;
	stages[pipeline.nb_stages].cfg     = (void*)&vec;
	stages[pipeline.nb_stages++].funcs = vlib_decoding_funcs;

	stages[pipeline.nb_stages].type    = VP_API_FILTER_ENCODER;
	stages[pipeline.nb_stages].cfg     = (void*)&qec;
	stages[pipeline.nb_stages++].funcs = encoder_stage_funcs;

	pipeline.stages = &stages[0];

    LOGD(TAG, "Encoder thread initialized [OK]");

	while( !ardrone_tool_exit() && encoder_sgate_stop_requested != TRUE )
	{
        if(encoder_stage_in_pause)
        {
        	LOGD(TAG, "Pausing encoder thread.");
            vp_os_mutex_lock(&encoder_stage_mutex);
            vp_os_cond_wait(&encoder_stage_condition);
            vp_os_mutex_unlock(&encoder_stage_mutex);

            LOGD(TAG, "Encoder thread resumed.");
        }

        jstring filenameString = encoder_stage_get_next_file(env, service, "enc");

        if(filenameString)
        {
        	const char* filename = (*env)->GetStringUTFChars(env, filenameString, NULL);
            int len = strlen(filename);
            ifc.filename = vp_os_malloc((len + 1)*sizeof(char));
            strncpy(ifc.filename, filename, len + 1);

            LOGD(TAG, "Source file: %s", ifc.filename);

            (*env)->ReleaseStringUTFChars(env, filenameString, filename);

            ifc.filename[len] = '\0';
            qec.file_src = vp_os_malloc((len + 1) * sizeof(char));
        	qec.file_dest = vp_os_malloc((len + 1) * sizeof(char));

            strncpy(qec.file_src, ifc.filename, len+1);

            res = vp_api_open(&pipeline, &encoder_pipeline_handle);

            if( SUCCEED(res) )
            {
                int thread_state = SUCCESS;
                out.status = VP_API_STATUS_INIT;

                while( !ardrone_tool_exit() && (thread_state == SUCCESS) && encoder_sgate_stop_requested != TRUE )
                {
                    if( SUCCEED(vp_api_run(&pipeline, &out)) )
                    {
                        if( (out.status == VP_API_STATUS_PROCESSING || out.status == VP_API_STATUS_STILL_RUNNING) )
                            thread_state = SUCCESS;
                        else if(out.status == VP_API_STATUS_ENDED)
                        {
                            LOGV(TAG, "Finished transcoding video %s with success", qec.file_src);
                            thread_state = SUCCESS;

                            break;
                        }
                    }
                    else
                    {
                        thread_state = -1; // Finish this thread
                        LOGV(TAG, "Finished transcoding video  %s with error", qec.file_src);
                    }
                }

                vp_api_close(&pipeline, &encoder_pipeline_handle);

                if (thread_state == SUCCESS) {
					if (remove(qec.file_src) == -1) {
						LOGW(TAG, "Can't delete file %s", qec.file_src);
					}

					notify_media_ready(env, service, &qec);
                } else {
                	LOGW(TAG, "Error happened during video transcoding. Removing damaged file %s", qec.file_dest);
                	if (remove(qec.file_dest) == -1) {
                		LOGW(TAG, "Can't delete file %d", qec.file_dest);
                	}

                	encoder_sgate_stop_requested = TRUE;
                }
            }

            if (ifc.filename != NULL) {
            	vp_os_free(ifc.filename);
            	ifc.filename = NULL;
            }

            if (qec.file_src != NULL) {
            	vp_os_free(qec.file_src);
            	qec.file_src = NULL;
            }

            if (qec.file_src != NULL) {
            	vp_os_free(qec.file_dest);
            	qec.file_dest = NULL;
            }
        }
        else
        {
        	encoder_sgate_stop_requested = TRUE;
        }
	}

    vp_os_free(picture.y_buf);
    vp_os_free(picture.cb_buf);
    vp_os_free(picture.cr_buf);

    parrot_java_callbacks_call_void_method(env, service, "onTranscodingFinished");

	LOGV(TAG, "Encoder stage thread stopped.");

	(*env)->DeleteGlobalRef(env, service);

	if (g_vm) {
		(*g_vm)->DetachCurrentThread (g_vm);
	}

    return (THREAD_RET)0;
}
