/*
autopylot_video.h - video-display data structure for AR.Drone autopilot agent.

    Copyright (C) 2013 Simon D. Levy

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as 
    published by the Free Software Foundation, either version 3 of the 
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

 You should have received a copy of the GNU Lesser General Public License 
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 You should also have received a copy of the Parrot Parrot AR.Drone 
 Development License and Parrot AR.Drone copyright notice and disclaimer 
 and If not, see 
   <https://projects.ardrone.org/attachments/277/ParrotLicense.txt> 
 and
   <https://projects.ardrone.org/attachments/278/ParrotCopyrightAndDisclaimer.txt>.
*/

#include <ardrone_tool/Video/video_stage.h>
#include <inttypes.h>

typedef struct _video_cfg_ {

    uint8_t *frameBuffer;
    uint32_t fbSize;
    
    int width;
    int height;

} video_cfg_t;

C_RESULT video_open (video_cfg_t *cfg);
C_RESULT video_transform (video_cfg_t *cfg, vp_api_io_data_t *in, vp_api_io_data_t *out);
C_RESULT video_close (video_cfg_t *cfg);

extern const vp_api_stage_funcs_t video_funcs;
