#ifndef _IHM_VISION_H
#define _IHM_VISION_H

#include <gtk-2.0/gtk/gtk.h>
#include <ardrone_tool/Navdata/ardrone_navdata_client.h>

extern char label_vision_state_value[32];
extern GtkLabel *label_vision_values;

void ihm_ImageWinDestroy( GtkWidget *widget, gpointer data );
void create_image_window( void );

C_RESULT navdata_hdvideo_init( void* param );
C_RESULT navdata_hdvideo_process( const navdata_unpacked_t* const navdata );
C_RESULT navdata_hdvideo_release( void );


#endif // _IHM_VISION_H
