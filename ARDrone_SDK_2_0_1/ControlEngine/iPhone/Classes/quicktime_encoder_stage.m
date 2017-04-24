//
//  quicktile_encoder_stage.m
//  ARDroneEngine
//
//  Created by Frédéric D'Haeyer on 8/17/11.
//  Copyright 2011 Parrot SA. All rights reserved.
//
#import "ConstantsAndMacros.h"
#import "ARDroneMediaManager.h"
#import "quicktime_encoder_stage.h"
#import "utils/ardrone_video_atoms.h"

#define NB_STAGES   5
#define QUICKTIME_ENCODER_PRIORITY  (15)

static bool_t quicktime_encoder_stage_in_pause = FALSE;
static vp_os_cond_t quicktime_encoder_stage_condition;
static vp_os_mutex_t quicktime_encoder_stage_mutex;
static THREAD_HANDLE quicktime_encoder_thread;

NSString *const QuicktimeEncoderStageDidSuspend = @"QuicktimeEncoderStageDidSuspend";
NSString *const QuicktimeEncoderStageDidResume = @"QuicktimeEncoderStageDidResume";
NSString *const QuicktimeEncoderStageDidFinishEncoding = @"QuicktimeEncoderStageDidFinishEncoding";

const vp_api_stage_funcs_t quicktime_encoder_stage_funcs =
{
    (vp_api_stage_handle_msg_t) NULL,
    (vp_api_stage_open_t) quicktime_encoder_stage_open,
    (vp_api_stage_transform_t) quicktime_encoder_stage_transform,
    (vp_api_stage_close_t) quicktime_encoder_stage_close
};

static int quicktime_encoder_expand_buffer_x2_yuv420p(/*Input*/uint8_t*in_buf,
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

NSString *quicktime_encoder_stage_get_next_file(NSString *extension)
{
    NSString *result = nil;
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES) objectAtIndex:0];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:documentsDirectory];
    
    NSString* video = nil;
    
    while (!result && ((video = [enumerator nextObject]) != nil))
    {
        if([[video pathExtension] isEqualToString:extension])
            result = [documentsDirectory stringByAppendingPathComponent:video];
    }

    return result;
}

void quicktime_encoder_stage_init(void)
{
    NSString *video_path = nil;
    quicktime_encoder_stage_in_pause = FALSE;
	vp_os_mutex_init(&quicktime_encoder_stage_mutex);
	vp_os_cond_init(&quicktime_encoder_stage_condition, &quicktime_encoder_stage_mutex);
    
    while((video_path = quicktime_encoder_stage_get_next_file(@"bak")) != nil)
        [[NSFileManager defaultManager] removeItemAtPath:video_path error:nil];
    
    while((video_path = quicktime_encoder_stage_get_next_file(@"MISC")) != nil)
    {
        [[NSFileManager defaultManager] removeItemAtPath:video_path error:nil];
    }
    
    vp_os_thread_create (thread_quicktime_encoder, NULL, &quicktime_encoder_thread);
}

void quicktime_encoder_stage_suspend(void)
{
	vp_os_mutex_lock(&quicktime_encoder_stage_mutex);
	quicktime_encoder_stage_in_pause = TRUE;
    printf ("Quick time encoder stage paused\n");
	vp_os_mutex_unlock(&quicktime_encoder_stage_mutex);	
}

void quicktime_encoder_stage_resume(void)
{
	vp_os_mutex_lock(&quicktime_encoder_stage_mutex);
	vp_os_cond_signal(&quicktime_encoder_stage_condition);
	quicktime_encoder_stage_in_pause = FALSE;
    printf ("Quick time encoder stage resumed\n");
	vp_os_mutex_unlock(&quicktime_encoder_stage_mutex);	
}

C_RESULT quicktime_encoder_stage_open(quicktime_encoder_stage_config_t *cfg)
{
    C_RESULT result = C_FAIL;

    if(cfg->filename && cfg->vlib_stage_decoding_config)
    {
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
#if TARGET_OS_IPHONE == 1
                                    [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange], kCVPixelBufferPixelFormatTypeKey, 
#else
                                    [NSNumber numberWithInt:kCVPixelFormatType_24RGB], kCVPixelBufferPixelFormatTypeKey, 
#endif
                                    nil];
        
        NSString *str_filename = [NSString stringWithCString:cfg->filename encoding:NSUTF8StringEncoding];
        str_filename = [str_filename stringByDeletingPathExtension];
        str_filename = [str_filename stringByAppendingPathExtension:@"bak"];
        NSLog(@"Trancoding to %@", str_filename);
        
        NSError *error = nil;
        if([[NSFileManager defaultManager] fileExistsAtPath:str_filename])
        {
            NSLog(@"File %@ exists, removing it", str_filename);
            [[NSFileManager defaultManager] removeItemAtPath:str_filename error:&error];
            if(error != nil)
                NSLog(@"error : %@", [error localizedDescription]);
        }
        
        error = nil;
        
        cfg->videoWriter = [[AVAssetWriter alloc] initWithURL:
                            [NSURL fileURLWithPath:str_filename] fileType:AVFileTypeQuickTimeMovie error:&error];
        
        if(cfg->videoWriter != nil)
        {
            NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                           AVVideoCodecH264, AVVideoCodecKey,
                                           [NSNumber numberWithInt:cfg->vlib_stage_decoding_config->picture->width], AVVideoWidthKey,
                                           [NSNumber numberWithInt:cfg->vlib_stage_decoding_config->picture->height], AVVideoHeightKey,
                                           nil];
            
            cfg->videoWriterInput = [[AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                                        outputSettings:videoSettings] retain];
            ((AVAssetWriterInput*)cfg->videoWriterInput).expectsMediaDataInRealTime = NO;
            
            cfg->videoAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:(AVAssetWriterInput*)cfg->videoWriterInput sourcePixelBufferAttributes:attributes];
            
            if((cfg->videoAdaptor != nil) && (cfg->videoWriterInput != nil) &&
               ([(AVAssetWriter *)cfg->videoWriter canApplyOutputSettings:videoSettings forMediaType:AVMediaTypeVideo]) &&
               ([(AVAssetWriter *)cfg->videoWriter canAddInput:(AVAssetWriterInput *)cfg->videoWriterInput]))
            {
                [(AVAssetWriter *)cfg->videoWriter addInput:(AVAssetWriterInput *)cfg->videoWriterInput];
                
                cfg->previous_num_picture_decoded = 0;
                cfg->starting_num_frames = 0;
                cfg->previous_num_frames = UINT32_MAX;
                cfg->success = TRUE;
                cfg->first_frame_ok = FALSE;
 
                result = C_OK;
            }
        }
    }
    
    return result;
}

C_RESULT quicktime_encoder_stage_transform(quicktime_encoder_stage_config_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out)
{
    C_RESULT result = C_FAIL;
    
    vp_os_mutex_lock(&out->lock);
    
    if( out->status == VP_API_STATUS_INIT )
    {
        out->status = VP_API_STATUS_PROCESSING;
    }        
    
    if( in->status == VP_API_STATUS_ENDED ) 
    {
        out->status = in->status;
        result = C_OK;
    }
    
    if(out->status == VP_API_STATUS_PROCESSING)
    {
        // Continue if we have a new frame
        // And if the frame is newer than the last one we got.
        // - Note : first recorded frame is OK regardless of its frame number
        if (cfg->vlib_stage_decoding_config->num_picture_decoded > cfg->previous_num_picture_decoded &&
            ( (!cfg->first_frame_ok) || 
              (cfg->vlib_stage_decoding_config->controller.num_frames > cfg->previous_num_frames)))
        {
            if(!cfg->first_frame_ok)
            {    
                if(cfg->vlib_stage_decoding_config->controller.picture_type == VIDEO_PICTURE_INTRA)
                {
                    cfg->first_frame_ok = TRUE;
                    cfg->starting_num_frames = cfg->vlib_stage_decoding_config->controller.num_frames;

                    //Start a session
                    [(AVAssetWriter*)cfg->videoWriter startWriting];
                    [(AVAssetWriter*)cfg->videoWriter startSessionAtSourceTime:kCMTimeZero];
                }

                result = C_OK;
            }
            
            if(cfg->first_frame_ok)
            {
                // Create a pixel buffer
                CVPixelBufferRef pixelsBuffer = NULL;
                CVReturn retval = CVPixelBufferPoolCreatePixelBuffer(NULL, ((AVAssetWriterInputPixelBufferAdaptor *)cfg->videoAdaptor).pixelBufferPool, &pixelsBuffer);
                if(pixelsBuffer)
                {
                    uint8_t *cb_buf, *cr_buf;
                    // Lock pixel buffer address
                    CVPixelBufferLockBaseAddress(pixelsBuffer, 0);
#if TARGET_OS_IPHONE == 1
                    uint8_t *baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelsBuffer, 0);
                    if(cfg->vlib_stage_decoding_config->controller.width < cfg->vlib_stage_decoding_config->picture->width && 
                       cfg->vlib_stage_decoding_config->controller.height < cfg->vlib_stage_decoding_config->picture->height)
                    {
                        /* Expand the Y buffer */
                        int w_cropping = ((cfg->vlib_stage_decoding_config->controller.width * 2) - cfg->vlib_stage_decoding_config->picture->width) / 2;
                        int h_cropping = ((cfg->vlib_stage_decoding_config->controller.height * 2) - cfg->vlib_stage_decoding_config->picture->height) / 2;

                        quicktime_encoder_expand_buffer_x2_yuv420p ( cfg->vlib_stage_decoding_config->picture->y_buf, baseAddress, cfg->vlib_stage_decoding_config->controller.width - w_cropping, cfg->vlib_stage_decoding_config->controller.height - h_cropping, cfg->vlib_stage_decoding_config->picture->width);
                        
                        cb_buf  = vp_os_malloc( cfg->vlib_stage_decoding_config->picture->width * cfg->vlib_stage_decoding_config->picture->height / 4);
                        cr_buf  = vp_os_malloc( cfg->vlib_stage_decoding_config->picture->width * cfg->vlib_stage_decoding_config->picture->height / 4);
                        
                        /* Expand the U buffer */
                        quicktime_encoder_expand_buffer_x2_yuv420p(cfg->vlib_stage_decoding_config->picture->cb_buf, cb_buf, (cfg->vlib_stage_decoding_config->controller.width - w_cropping) / 2, (cfg->vlib_stage_decoding_config->controller.height - h_cropping) / 2, cfg->vlib_stage_decoding_config->picture->width / 2);
                        
                        /* Expand the V buffer */
                        quicktime_encoder_expand_buffer_x2_yuv420p(cfg->vlib_stage_decoding_config->picture->cr_buf, cr_buf, (cfg->vlib_stage_decoding_config->controller.width - w_cropping) / 2, (cfg->vlib_stage_decoding_config->controller.height - h_cropping) / 2, cfg->vlib_stage_decoding_config->picture->width / 2);
                    }
                    else
                    {
                        vp_os_memcpy(baseAddress, cfg->vlib_stage_decoding_config->picture->y_buf, cfg->vlib_stage_decoding_config->picture->width * cfg->vlib_stage_decoding_config->picture->height);
                        cb_buf = cfg->vlib_stage_decoding_config->picture->cb_buf;
                        cr_buf = cfg->vlib_stage_decoding_config->picture->cr_buf;
                    }
                    
                    baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelsBuffer, 1);
                    
                    for(int i = 0 ; i < cfg->vlib_stage_decoding_config->picture->width * cfg->vlib_stage_decoding_config->picture->height / 4; i++)
                    {
                        baseAddress[i * 2] = cb_buf[i];
                        baseAddress[i * 2 + 1] = cr_buf[i];
                    }
                    
                    if(cfg->vlib_stage_decoding_config->controller.width < cfg->vlib_stage_decoding_config->picture->width && 
                       cfg->vlib_stage_decoding_config->controller.height < cfg->vlib_stage_decoding_config->picture->height)
                    {
                        vp_os_free(cb_buf);
                        vp_os_free(cr_buf);
                    }
#else
                    uint8_t *baseAddress = CVPixelBufferGetBaseAddress(pixelsBuffer);
                    vp_os_memcpy(baseAddress, cfg->vlib_stage_decoding_config->picture->y_buf, cfg->vlib_stage_decoding_config->picture->width * cfg->vlib_stage_decoding_config->picture->height * 3);
#endif
                    // Unlock pixel buffer address
                    CVPixelBufferUnlockBaseAddress(pixelsBuffer, 0);
                    
                    while(!((AVAssetWriterInput*)cfg->videoWriterInput).isReadyForMoreMediaData)
                        vp_os_delay(50);
                    
                    if(![(AVAssetWriterInputPixelBufferAdaptor *)cfg->videoAdaptor appendPixelBuffer:pixelsBuffer withPresentationTime:CMTimeMake(cfg->vlib_stage_decoding_config->controller.num_frames - cfg->starting_num_frames, cfg->vlib_stage_decoding_config->picture->framerate)])
                        NSLog(@"Can't append pixel buffer : %@ : %d", [[(AVAssetWriter *)cfg->videoWriter error] localizedDescription], cfg->vlib_stage_decoding_config->controller.num_frames - cfg->starting_num_frames);

                    // Release pixel buffer
                    CVPixelBufferRelease(pixelsBuffer);
                    result = C_OK;
                }
                else
                {
                    NSLog(@"Error pixel buffer nil : %d", retval);
                }
            }
            
            cfg->previous_num_picture_decoded = cfg->vlib_stage_decoding_config->num_picture_decoded;
            cfg->previous_num_frames = cfg->vlib_stage_decoding_config->controller.num_frames;
        }
        else if (cfg->previous_num_frames >= cfg->vlib_stage_decoding_config->controller.num_frames) {
            // Frame number is not good : skip frame, but still say "ok"
            result = C_OK;
        }
    }
    
    out->numBuffers = in->numBuffers;
    out->indexBuffer = in->indexBuffer;
    out->buffers = in->buffers;
    
    cfg->success = ((result == C_OK) && cfg->first_frame_ok);
    
    vp_os_mutex_unlock(&out->lock);
    
    return result;
}

C_RESULT quicktime_encoder_stage_close(quicktime_encoder_stage_config_t *cfg)
{
    if([(AVAssetWriter *)cfg->videoWriter status] != AVAssetWriterStatusUnknown)
    {
        [(AVAssetWriterInput*)cfg->videoWriterInput markAsFinished];
        [(AVAssetWriter *)cfg->videoWriter finishWriting];
    }

    CVPixelBufferPoolRelease(((AVAssetWriterInputPixelBufferAdaptor *)cfg->videoAdaptor).pixelBufferPool);
    [(AVAssetWriterInput*)cfg->videoWriterInput release];
    [(AVAssetWriter *)cfg->videoWriter release];
    [(AVAssetWriterInputPixelBufferAdaptor *)cfg->videoAdaptor release];
    
    NSString *filename = [NSString stringWithCString:cfg->filename encoding:NSUTF8StringEncoding];
    NSString *bakFilename = [[filename stringByDeletingPathExtension] stringByAppendingPathExtension:@"bak"];
    NSArray *componentArray = [filename componentsSeparatedByString:@"/"];
    NSString *ardtName = [NSString stringWithFormat:@"%@/%@",
                          [componentArray objectAtIndex:([componentArray count] - 2)],
                          [[[componentArray objectAtIndex:([componentArray count] - 1)] stringByDeletingPathExtension] stringByAppendingPathExtension:@"mov"]];

    
    const char *ardtFileName = NULL;
    const char *ardtData     = NULL;
    FILE *ardtFile           = NULL;
    movie_atom_t *ardtAtom   = NULL;
    
    if(cfg->success)
    {
        ardtFileName = [bakFilename cStringUsingEncoding:NSASCIIStringEncoding];
        ardtData     = [ardtName cStringUsingEncoding:NSASCIIStringEncoding];
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

    if(cfg->success)
    {
        NSLog(@"move %@ to %@", [[filename stringByDeletingPathExtension] stringByAppendingPathExtension:@"bak"], [[filename stringByDeletingPathExtension] stringByAppendingPathExtension:@"mov"]);
        [[NSFileManager defaultManager] moveItemAtPath:[[filename stringByDeletingPathExtension] stringByAppendingPathExtension:@"bak"] toPath:[[filename stringByDeletingPathExtension] stringByAppendingPathExtension:@"mov"] error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:filename error:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:QuicktimeEncoderStageDidFinishEncoding object:[[filename stringByDeletingPathExtension] stringByAppendingPathExtension:@"mov"]];
    }
    else
    {
        [[NSFileManager defaultManager] removeItemAtPath:[[filename stringByDeletingPathExtension] stringByAppendingPathExtension:@"bak"] error:nil];
    }

    return C_OK;
}

PROTO_THREAD_ROUTINE(quicktime_encoder, data)
{
    C_RESULT res;
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    PIPELINE_HANDLE encoder_pipeline_handle;
    
	vp_api_io_pipeline_t    pipeline;
	vp_api_io_data_t        out;
	vp_api_io_stage_t       stages[NB_STAGES];
	
	vp_api_picture_t picture;
    
	video_stage_io_file_config_t ifc;
	vlib_stage_decoding_config_t      vec;
    quicktime_encoder_stage_config_t  qec;
    
    vp_os_thread_priority(vp_os_thread_self(), QUICKTIME_ENCODER_PRIORITY);
    
	vp_os_memset(&ifc,          0, sizeof( ifc ));
	vp_os_memset(&vec,          0, sizeof( vec ));
	vp_os_memset(&picture,      0, sizeof( picture ));
    
	/// Picture configuration
#if TARGET_OS_IPHONE == 1
    picture.format        = PIX_FMT_YUV420P;
#else
    picture.format        = PIX_FMT_RGB24;
#endif    
	picture.width         = QVGA_WIDTH;
	picture.height        = QVGA_HEIGHT;
	picture.framerate     = 20;
	
#if TARGET_OS_IPHONE == 1
	picture.y_buf   = vp_os_malloc( picture.width * picture.height );
    picture.cr_buf  = vp_os_malloc( picture.width * picture.height / 4);
	picture.cb_buf  = vp_os_malloc( picture.width * picture.height / 4);
#else
	picture.y_buf   = vp_os_malloc( picture.width * picture.height * 3);
    picture.cr_buf  = NULL;
	picture.cb_buf  = NULL;
#endif	
    
#if TARGET_OS_IPHONE == 1
	picture.y_line_size   = picture.width;
	picture.cb_line_size  = picture.width / 2;
	picture.cr_line_size  = picture.width / 2;
#else
	picture.y_line_size   = picture.width * 3;
	picture.cb_line_size  = 0;
	picture.cr_line_size  = 0;
#endif    
	vec.width               = picture.width;
	vec.height              = picture.height;
	vec.picture             = &picture;
	vec.luma_only           = FALSE;
	vec.block_mode_enable   = TRUE;
	
    qec.vlib_stage_decoding_config = &vec;
    ifc.filename = NULL;
    qec.filename = NULL;

	pipeline.nb_stages = 0;
	
	stages[pipeline.nb_stages].type    = VP_API_INPUT_BUFFER;
	stages[pipeline.nb_stages].cfg     = (void *)&ifc;
	stages[pipeline.nb_stages++].funcs = video_stage_io_file_funcs;
    
	stages[pipeline.nb_stages].type    = VP_API_FILTER_DECODER;
	stages[pipeline.nb_stages].cfg     = (void*)&vec;
	stages[pipeline.nb_stages++].funcs = vlib_decoding_funcs;
    
	stages[pipeline.nb_stages].type    = VP_API_FILTER_ENCODER;
	stages[pipeline.nb_stages].cfg     = (void*)&qec;
	stages[pipeline.nb_stages++].funcs = quicktime_encoder_stage_funcs;
    
	pipeline.stages = &stages[0];
    
    PRINT("\nencoder stage thread initialisation\n\n");
   
	while( !ardrone_tool_exit() )
	{
        if(quicktime_encoder_stage_in_pause)
        {
            vp_os_mutex_lock(&quicktime_encoder_stage_mutex);
            vp_os_cond_wait(&quicktime_encoder_stage_condition);
            vp_os_mutex_unlock(&quicktime_encoder_stage_mutex);
        }

        NSString *filename = quicktime_encoder_stage_get_next_file(@"enc");
        if(filename != nil)
        {
            NSLog(@"Trancoding %@\n", filename);
            ifc.filename = vp_os_malloc([filename lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1);
            
            int len = filename.length;
            strncpy(ifc.filename, [filename cStringUsingEncoding:NSUTF8StringEncoding], len + 1);
            ifc.filename[len] = '\0';
            
            qec.filename = ifc.filename;

            res = vp_api_open(&pipeline, &encoder_pipeline_handle);
            
            if( SUCCEED(res) )
            {
                int __block thread_state = SUCCESS;
                out.status = VP_API_STATUS_PROCESSING;
                
                while( !ardrone_tool_exit() && (thread_state == SUCCESS) )
                {
                    if( SUCCEED(vp_api_run(&pipeline, &out)) ) 
                    {
                        if( (out.status == VP_API_STATUS_PROCESSING || out.status == VP_API_STATUS_STILL_RUNNING) ) 
                            thread_state = SUCCESS;
                        else if(out.status == VP_API_STATUS_ENDED)
                        {
                            NSLog(@"Finished transcoding video %s with success", qec.filename);
                            thread_state = -1;
                        }
                    }
                    else
                    {
                        thread_state = -1; // Finish this thread
                        NSLog(@"Finished transcoding video  %s with error", qec.filename);
                    }
                }
                
                vp_api_close(&pipeline, &encoder_pipeline_handle);
            }
            
            
            vp_os_free(ifc.filename);
            ifc.filename = NULL;
            qec.filename = NULL;
        }
        else
        {
            quicktime_encoder_stage_suspend ();
        }
	}
	
	PRINT("   encoder stage thread ended\n\n");
    
    vp_os_free(picture.y_buf);
#if TARGET_OS_IPHONE == 1
    vp_os_free(picture.cb_buf);
    vp_os_free(picture.cr_buf);
#endif
    
    [pool release];
    
	return (THREAD_RET)0;
}
