/*
 * frame_rate.c
 *
 *  Created on: May 20, 2011
 *      Author: "Dmytro Baryskyy"
 */

#include <time.h>

#include "common.h"
#include "frame_rate.h"


//FPS will be calculated by measuring time that 30 frames took to render.
static const int FRAMES_COUNT = 240;

//Used to calculate frames count
static int renderedFramesCount = 0;

//Used to calculate render time
static time_t start = 0;

static float fps;

void parrot_frame_rate_init()
{
	renderedFramesCount = 0;
	start = time(NULL);
}


void parrot_frame_rate_on_draw_completed()
{
	renderedFramesCount += 1;

	if (renderedFramesCount > FRAMES_COUNT) {
		fps = (float)renderedFramesCount / ((float)(time(NULL) - start));
		LOGI("FRAME_RATE", "FPS: %.2f", fps);

		renderedFramesCount = 0;
		start = time(NULL);
	}
}
