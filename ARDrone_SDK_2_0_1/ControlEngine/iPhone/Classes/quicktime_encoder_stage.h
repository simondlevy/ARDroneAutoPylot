//
//  quicktile_encoder_stage.h
//  ARDroneEngine
//
//  Created by Frédéric D'Haeyer on 8/17/11.
//  Copyright 2011 Parrot SA. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define QUICKTIME_ENCODER_STATE_TIMEOUT_IN_MS 2000

extern NSString *const QuicktimeEncoderStageDidSuspend;
extern NSString *const QuicktimeEncoderStageDidResume;
extern NSString *const QuicktimeEncoderStageDidFinishEncoding; // Return path of encoded file.

typedef struct _quicktime_encoder_stage_config_t_
{
	// Public
    char *filename;
    vlib_stage_decoding_config_t *vlib_stage_decoding_config;
    
    // Private
    id videoWriter;
    id videoWriterInput;
    id videoAdaptor;
    int starting_num_frames;
    uint32_t previous_num_frames;
    int previous_num_picture_decoded;
    bool_t success;
    bool_t first_frame_ok;
} quicktime_encoder_stage_config_t;

PROTO_THREAD_ROUTINE(quicktime_encoder, data);

///////////////////////////////////////////////
// FUNCTIONS
/**
 * @fn      Intialize Quicktime encoder
 */
void quicktime_encoder_stage_init(void);

///////////////////////////////////////////////
// FUNCTIONS
/**
 * @fn      Suspend Quicktime encoder
 */
void quicktime_encoder_stage_suspend(void);

///////////////////////////////////////////////
// FUNCTIONS
/**
 * @fn      Resume Quicktime encoder
 */
void quicktime_encoder_stage_resume(void);

///////////////////////////////////////////////
// FUNCTIONS
/**
 * @fn      Open the quicktime encoder stage
 * @param   quicktime_encoder_stage_config_t *cfg
 * @return  VP_SUCCESS
 */
C_RESULT
quicktime_encoder_stage_open(quicktime_encoder_stage_config_t *cfg);

/**
 * @fn      Transform the quicktime encoder stage
 * @param   quicktime_encoder_stage_config_t *cfg
 * @param   vp_api_io_data_t *in
 * @param   vp_api_io_data_t *out
 * @return  VP_SUCCESS
 */
C_RESULT
quicktime_encoder_stage_transform(quicktime_encoder_stage_config_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out);

/**
 * @fn      Close the quicktime encoder stage
 * @param   quicktime_encoder_stage_config_t *cfg
 * @return  VP_SUCCESS
 */
C_RESULT
quicktime_encoder_stage_close(quicktime_encoder_stage_config_t *cfg);

extern const vp_api_stage_funcs_t quicktime_encoder_stage_funcs;
