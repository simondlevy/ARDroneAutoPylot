#include "navdata.h"
#include "ARDroneTypes.h"
#include <control_states.h>
#include <ardrone_tool/Navdata/ardrone_navdata_file.h>
#include <ardrone_tool/Navdata/ardrone_navdata_client.h>
navdata_unpacked_t inst_nav;
vp_os_mutex_t inst_nav_mutex;
static bool_t writeToFile = FALSE;

static inline C_RESULT navdata_init( void* data )
{
	vp_os_mutex_init( &inst_nav_mutex );
	
	vp_os_mutex_lock( &inst_nav_mutex);
	navdata_reset(&inst_nav);
	vp_os_mutex_unlock( &inst_nav_mutex);
	
	writeToFile = FALSE;
	
	return C_OK;
}

static inline C_RESULT navdata_process( const navdata_unpacked_t* const navdata )
{
	if( writeToFile )
	{
		if( navdata_file == NULL )
		{
			ardrone_navdata_file_data data;
			data.filename = NULL;
            data.print_header = NULL;
            data.print = NULL;
			ardrone_navdata_file_init(NULL);
		}
		ardrone_navdata_file_process( navdata );
	}
	else
	{
		if(navdata_file != NULL)
			ardrone_navdata_file_release();			
	}
	
	vp_os_mutex_lock( &inst_nav_mutex);
	vp_os_memcpy(&inst_nav, navdata, sizeof(navdata_unpacked_t));
	vp_os_mutex_unlock( &inst_nav_mutex );

	return C_OK;
}

static inline C_RESULT navdata_release( void )
{
	ardrone_navdata_file_release();
	return C_OK;
}

C_RESULT navdata_write_to_file(bool_t enable)
{
	writeToFile = enable;
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
		vp_os_mutex_lock( &inst_nav_mutex );
		vp_os_memcpy(data, &inst_nav, sizeof(navdata_unpacked_t));
		vp_os_mutex_unlock( &inst_nav_mutex );
		result = C_OK;
	}
	
	return result;
}

BEGIN_NAVDATA_HANDLER_TABLE
NAVDATA_HANDLER_TABLE_ENTRY(navdata_init, navdata_process, navdata_release, NULL)
END_NAVDATA_HANDLER_TABLE
