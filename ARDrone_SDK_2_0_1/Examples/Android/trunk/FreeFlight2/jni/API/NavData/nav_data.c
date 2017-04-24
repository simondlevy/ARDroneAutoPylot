/*
 * nav_data.c
 *
 *  Created on: May 13, 2011
 *      Author: "Dmytro Baryskyy"
 */

// VP_Os Library
#include <VP_Os/vp_os_thread.h>
#include <VP_Os/vp_os_signal.h>

// ARDroneLib
#include "ARDroneTypes.h"
#include <control_states.h>
#include <ardrone_tool/Navdata/ardrone_navdata_file.h>
#include <ardrone_tool/Navdata/ardrone_navdata_client.h>
#include <ardrone_tool/UI/ardrone_input.h>

#include "common.h"
#include "nav_data.h"

static const char* TAG = "NAV_DATA";
navdata_unpacked_t inst_nav;
vp_os_mutex_t instance_navdata_mutex;

static bool_t bIsInitialized = FALSE;


inline C_RESULT navdata_init( void* data )
{
	LOGD(TAG, "navdata_init");
	vp_os_mutex_init(&instance_navdata_mutex);
	vp_os_mutex_lock( &instance_navdata_mutex);
	navdata_reset(&inst_nav);
	bIsInitialized = TRUE;
	vp_os_mutex_unlock( &instance_navdata_mutex);
	return C_OK;
}


inline C_RESULT navdata_process( const navdata_unpacked_t* const navdata )
{
	if (bIsInitialized == FALSE) {
		LOGW(TAG, "Navdata is not initialized yet");
		return C_OK;
	}

	vp_os_mutex_lock( &instance_navdata_mutex);
	vp_os_memcpy(&inst_nav, navdata, sizeof(navdata_unpacked_t));
	vp_os_mutex_unlock( &instance_navdata_mutex );

	return C_OK;
}


inline C_RESULT navdata_release( void )
{
	LOGI(TAG, "navdata_release");
	vp_os_mutex_destroy(&instance_navdata_mutex);
	bIsInitialized = FALSE;
    return C_OK;
}


C_RESULT navdata_reset(navdata_unpacked_t *nav)
{
	C_RESULT result = C_FAIL;

	if(nav)
	{
		vp_os_memset(nav, 0x0, sizeof(navdata_unpacked_t));
        nav->ardrone_state |= ARDRONE_NAVDATA_BOOTSTRAP;
        result = C_OK;
	}

	return result;
}


C_RESULT navdata_get(navdata_unpacked_t *data)
{
	C_RESULT result = C_FAIL;

	if(data)
	{
		vp_os_mutex_lock( &instance_navdata_mutex );
		vp_os_memcpy(data, &inst_nav, sizeof(navdata_unpacked_t));
		vp_os_mutex_unlock( &instance_navdata_mutex );
		result = C_OK;
	}

	return result;
}



BEGIN_NAVDATA_HANDLER_TABLE
	NAVDATA_HANDLER_TABLE_ENTRY(navdata_init, navdata_process, navdata_release, NULL)
END_NAVDATA_HANDLER_TABLE
