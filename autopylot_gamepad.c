/*
autopylot_gamepad.c - ardrone_tool custom code for AR.Drone autopilot agent.

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

History:

  04-JUN-2007: version 1.0 Created by Sylvain Gaeremynck <sylvain.gaeremynck@parrot.fr>.
 
  24-OCT-2010 Simon D. Levy: Removed non-gamepad (non-Logitech) code.
                             Incorporated gamepad.h.
   
  26-OCT-2010 Simon D. Levy: Replaced deprecated ardrone_tool_set_ui_pad_* navigation calls 
                             with ardrone_at_set_progress_cmd.
 
  24-NOV-2010 Simon D. Levy: Added auto-pilot toggling.

  03-AUG-2011 Simon D. Levy: Fixed missing return value in update_gamepad.
  
  05-JUN-2013 Simon D. Levy: Works with AR.Drone 2.0
*/

// Gamepad type is defined in Makefile.

#ifdef GAMEPAD_PS3_ID

#define GAMEPAD_ID GAMEPAD_PS3_ID

typedef enum {
  AXIS_PHI = 0,
  AXIS_THETA,
  AXIS_YAW,
  AXIS_GAZ,
  AXIS_IGNORE3,
  AXIS_IGNORE4,
} PAD_AXIS;

typedef enum {
  BUTTON_SELECT = 8,
  BUTTON_START = 9,
  BUTTON_ZAP = 0,
  BUTTON_AUTO = 1
} PAD_BUTTONS;

#else // default to Logitech gamepad

#define GAMEPAD_ID GAMEPAD_LOGITECH_ID

typedef enum {
  AXIS_PHI = 0,
  AXIS_THETA,
  AXIS_YAW,
  AXIS_IGNORE3,
  AXIS_IGNORE4,
  AXIS_GAZ
} PAD_AXIS;

typedef enum {
  BUTTON_START = 0,
  BUTTON_SELECT,
  BUTTON_ZAP,
  BUTTON_AUTO
} PAD_BUTTONS;

#endif

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <limits.h>

#include <linux/joystick.h>

#include <ardrone_api.h>
#include <VP_Os/vp_os_print.h>

#include <VP_Os/vp_os_types.h>
#include <ardrone_tool/UI/ardrone_input.h>

#include "ardrone_autopylot.h"
#include "autopylot_agent.h"


typedef struct {
	int32_t bus;
	int32_t vendor;
	int32_t product;
	int32_t version;
	char    name[MAX_NAME_LENGTH];
	char    handlers[MAX_NAME_LENGTH];
} device_t;

static C_RESULT parse_proc_input_devices(FILE* f, const int32_t id);

input_device_t gamepad;

static int32_t joy_dev;

C_RESULT open_gamepad(void) {

	C_RESULT res = C_FAIL;

	FILE* f = fopen("/proc/bus/input/devices", "r");

	if( f != NULL ) {

		res = parse_proc_input_devices( f, GAMEPAD_ID);

		fclose( f );

		if( SUCCEED( res ) && strcmp(gamepad.name, "Gamepad")!=0) {

			char dev_path[20]="/dev/input/";
			strcat(dev_path, gamepad.name);
			joy_dev = open(dev_path, O_NONBLOCK | O_RDONLY);
		}
		else {

			return C_FAIL;
		}
	}

	return res;
}

C_RESULT update_gamepad(void) {

	static int32_t start;
    static float phi, theta, gaz, yaw;

	struct js_event js_e_buffer[64];
	ssize_t res = read(joy_dev, js_e_buffer, sizeof(struct js_event) * 64);

	if( !res || (res < 0 && errno == EAGAIN) )
		return C_OK;

	if( res < 0 )
		return C_FAIL;

	if (res < (int) sizeof(struct js_event))// If non-complete bloc: ignored
		return C_OK;

	// Buffer decomposition in blocs (if the last is incomplete, it's ignored)
	bool_t refresh_values = FALSE;
	int32_t idx = 0;
	for (idx = 0; idx < res / sizeof(struct js_event); idx++) {

		unsigned char type = js_e_buffer[idx].type;
		unsigned char number = js_e_buffer[idx].number;
		short value = js_e_buffer[idx].value;

		if (type & JS_EVENT_INIT ) {

			break;
		}
		else if (!value) {

			break;
		}
		else if (type & JS_EVENT_BUTTON ) {

			switch(number ) {

				case BUTTON_START :
					start ^= 1;
					ardrone_tool_set_ui_pad_start( start );
					g_autopilot = FALSE;
					break;
				case BUTTON_SELECT :
					ardrone_tool_set_ui_pad_select(js_e_buffer[idx].value);
					return C_OK;
				case BUTTON_ZAP:
					zap();
					break;
				case BUTTON_AUTO:
					if (g_autopilot) {
						refresh_values = TRUE;
					}
					else {
						g_autopilot = TRUE;
					}
					break;
			}

		}
		else if (type & JS_EVENT_AXIS ) {
		    
			if (number != AXIS_IGNORE3 && number != AXIS_IGNORE4) {
				refresh_values = TRUE;
				float angle = value / (float)SHRT_MAX;
				switch (number) {
					case AXIS_PHI:
						phi = angle;
						break;
					case AXIS_THETA:
						theta = angle;
						break;
					case AXIS_GAZ:
						gaz = angle;
						break;
					case AXIS_YAW:
						yaw = angle;
						break;
				}
			}
		}

	} // loop over events


	if (refresh_values) {

		g_autopilot = FALSE;
		
		set(phi, theta, gaz, yaw);		
	}

	return C_OK;
}



C_RESULT close_gamepad(void) {

	close( joy_dev );

	return C_OK;
}

input_device_t gamepad = {
	"Gamepad",
	open_gamepad,
	update_gamepad,
	close_gamepad
};

// -------------------------------------------------------------------------------------------------------------------------------------

static int32_t make_id(device_t* device)
{
	return ( (device->vendor << 16) & 0xffff0000) | (device->product & 0xffff);
}

static C_RESULT add_device(device_t* device, const int32_t id_wanted)
{
	int32_t id = make_id(device);
	if( id_wanted == GAMEPAD_ID && id == id_wanted)
	{
		PRINT("Input device %s found\n", device->name);
		strncpy(gamepad.name, device->handlers, MAX_NAME_LENGTH);
		return C_OK;
	}

	return C_FAIL;
}





/** simple /proc/bus/input/devices generic LL(1) parser **/

#define KW_MAX_LEN 64

typedef enum {
	KW_BUS,
	KW_VENDOR,
	KW_PRODUCT,
	KW_VERSION,
	KW_NAME,
	KW_HANDLERS,
	KW_MAX
} keyword_t;

typedef enum {
	INT,
	STRING,
} value_type_t;

typedef struct {
	const char*   name;
	value_type_t  value_type;
	int32_t       value_offset;
} kw_tab_entry_t;

static int current_c;
static int next_c; // look ahead buffer

static device_t current_device;

static const int separators[] = { ' ',  ':', '=', '\"', '\n' };
static const int quote = '\"';
static const int eol = '\n';

static kw_tab_entry_t kw_tab[] = {
	[KW_BUS]      = {  "Bus",      INT,    offsetof(device_t, bus)       },
	[KW_VENDOR]   = {  "Vendor",   INT,    offsetof(device_t, vendor)    },
	[KW_PRODUCT]  = {  "Product",  INT,    offsetof(device_t, product)   },
	[KW_VERSION]  = {  "Version",  INT,    offsetof(device_t, version)   },
	[KW_NAME]     = {  "Name",     STRING, offsetof(device_t, name)      },
	[KW_HANDLERS] = {  "Handlers", STRING, offsetof(device_t, handlers)  }
};

static const char* handler_names[] = {
	"js0",
	"js1",
	"js2",
	"js3",
	0
};

static bool_t is_separator(int c)
{
	int32_t i;
	bool_t found = FALSE;

	for( i = 0; i < sizeof separators && !found; i++ )
	{
		found = ( c == separators[i] );
	}

	return found;
}

static bool_t is_quote(int c)
{
	return c == quote;
}

static bool_t is_eol(int c)
{
	return c == eol;
}

static C_RESULT fetch_char(FILE* f)
{
	C_RESULT res = C_FAIL;

	current_c = next_c;

	if( !feof(f) )
	{
		next_c = fgetc(f);
		res = C_OK;
	}

	// PRINT("current_c = %c, next_c = %c\n", current_c, next_c );

	return res;
}

static C_RESULT parse_string(FILE* f, char* str, int32_t maxlen)
{
	int32_t i = 0;
	bool_t is_quoted = is_quote(current_c);

	if( is_quoted )
	{
		while( SUCCEED(fetch_char(f)) && ! ( is_separator(current_c) && is_quote(current_c) ) )  {
			str[i] = current_c;
			i++;
		}
	}
	else
	{
		while( SUCCEED(fetch_char(f)) && !is_separator(current_c) )  {
			str[i] = current_c;
			i++;
		}
	}

	str[i] = '\0';
	// PRINT("parse_string: %s\n", str);

	return is_eol( current_c ) ? C_FAIL : C_OK;
}

static C_RESULT parse_int(FILE* f, int32_t* i)
{
	C_RESULT res = C_OK;
	int value;

	*i = 0;

	while( !is_separator(next_c) && SUCCEED(fetch_char(f)) && res == C_OK )  {
		value = current_c - '0';

		if (value > 9 || value < 0)
		{
			value = current_c - 'a' + 10;
			res = (value > 0xF || value < 0xa) ? C_FAIL : C_OK;
		}

		*i *= 16;
		*i += value;
	}

	return res;
}

static C_RESULT skip_line(FILE* f)
{
	while( !is_eol(next_c) && SUCCEED(fetch_char(f)) );

	return C_OK;
}

static C_RESULT match_keyword( const char* keyword, keyword_t* kw )
{
	int32_t i;
	C_RESULT res = C_FAIL;

	for( i = 0; i < KW_MAX && res != C_OK; i++ )
	{
		res = ( strcmp( keyword, kw_tab[i].name ) == 0 ) ? C_OK : C_FAIL;
	}

	*kw = i-1;

	return res;
}

static C_RESULT match_handler( void )
{
	int32_t i = 0;
	bool_t found = FALSE;

	while( !found && handler_names[i] != 0 )
	{
		found = strcmp( (char*)((char*)&current_device + kw_tab[KW_HANDLERS].value_offset), handler_names[i] ) == 0;

		i ++;
	}

        if(found)
        {
                strcpy(current_device.handlers, handler_names[i-1]);
        }

  return found ? C_OK : C_FAIL;
}

static C_RESULT parse_keyword( FILE* f, keyword_t kw )
{
  C_RESULT res = C_OK;

  while( is_separator(next_c) && SUCCEED(fetch_char(f)) );

  switch( kw_tab[kw].value_type ) {
    case INT:
      parse_int( f, (int32_t*)((char*)&current_device + kw_tab[kw].value_offset) );
      //PRINT("%s = %x\n", kw_tab[kw].name, *(int32_t*)((char*)&current_device + kw_tab[kw].value_offset) );
      break;

    case STRING:
      parse_string( f, (char*)((char*)&current_device + kw_tab[kw].value_offset), KW_MAX_LEN );
      //PRINT("%s = %s\n", kw_tab[kw].name, (char*)((char*)&current_device + kw_tab[kw].value_offset) );
      break;

    default:
      res = C_FAIL;
      break;
  }

  return res;
}

static C_RESULT parse_I(FILE* f)
{
  char keyword[KW_MAX_LEN];

  while( SUCCEED(fetch_char(f)) && is_separator(next_c) );

  while( !is_eol(next_c) ) {
    keyword_t kw;

    parse_string( f, keyword, KW_MAX_LEN );
    if( SUCCEED( match_keyword( keyword, &kw ) ) )
    {
      parse_keyword( f, kw );
    }
  }

  return C_OK;
}

static C_RESULT parse_N(FILE* f)
{
  char keyword[KW_MAX_LEN];

  while( SUCCEED(fetch_char(f)) && is_separator(next_c) );

  while( !is_eol(next_c) ) {
    keyword_t kw;

    parse_string( f, keyword, KW_MAX_LEN );
    if( SUCCEED( match_keyword( keyword, &kw ) ) )
    {
      parse_keyword( f, kw );
    }
  }


  return C_OK;
}

static C_RESULT parse_H(FILE* f)
{
  C_RESULT res = C_FAIL;
  char keyword[KW_MAX_LEN];

  while( SUCCEED(fetch_char(f)) && is_separator(next_c) );

  while( !is_eol(next_c) ) {
    parse_string( f, keyword, KW_MAX_LEN );
    if( strcmp( keyword, kw_tab[KW_HANDLERS].name ) == 0 )
    {
      while( FAILED(res) && SUCCEED( parse_string(f,
                                                  (char*)((char*)&current_device + kw_tab[KW_HANDLERS].value_offset),
                                                  KW_MAX_LEN ) ) )
      {
        res = match_handler();
      }
    }
  }

  return res;
}

static C_RESULT end_device(const int32_t id)
{
  C_RESULT res = C_FAIL;
  res=add_device(&current_device, id);
  vp_os_memset( &current_device, 0, sizeof(device_t) );

  return res;
}

static C_RESULT parse_proc_input_devices(FILE* f, const int32_t id)
{
  C_RESULT res = C_FAIL;

  next_c = '\0';
  vp_os_memset( &current_device, 0, sizeof(device_t) );

  while( res != C_OK && SUCCEED( fetch_char(f) ) )
  {
    switch( next_c )
    {
      case 'I': parse_I(f); break;
      case 'N': parse_N(f); break;
      case 'H': if( SUCCEED( parse_H(f) ) ) res = end_device(id); break;
      case 'P':
      case 'S':
      case 'B':
      default: skip_line(f); break;
    }
  }

  return res;
}
