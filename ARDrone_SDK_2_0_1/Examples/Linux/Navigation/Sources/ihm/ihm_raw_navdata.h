#ifndef __NAVIGATION_IHM_RAW_NAVDATA__
#define __NAVIGATION_IHM_RAW_NAVDATA__

enum
{
  COL_FIELD = 0,
  COL_VALUE,
  COL_COMMENT,
  NUM_COLS
};

int navdata_ihm_raw_navdata_create_window ();
int navdata_ihm_raw_navdata_update( const navdata_unpacked_t* const navdata );
int navdata_ihm_raw_navdata_init ( void*v );
int navdata_ihm_raw_navdata_release ();

#endif
