#ifndef _NAVDATA_H_
#define _NAVDATA_H_

#include "ConstantsAndMacros.h"
#include "ARDroneTypes.h"

C_RESULT navdata_reset(navdata_unpacked_t *nav);
C_RESULT navdata_get(navdata_unpacked_t *data);
C_RESULT navdata_write_to_file(bool_t enable);

#endif // _NAVDATA_H_