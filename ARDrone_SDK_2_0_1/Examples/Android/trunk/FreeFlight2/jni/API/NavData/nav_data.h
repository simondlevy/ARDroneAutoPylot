/*
 * nav_data.h
 *
 *  Created on: May 13, 2011
 *      Author: "Dmytro Baryskyy"
 */

#ifndef NAV_DATA_H_
#define NAV_DATA_H_

//typedef struct _instance_navdata_t {
//	uint32_t battery_level;
//	uint32_t altitude;
//	uint32_t prev_control_state;
//	uint32_t current_control_state;
//	uint32_t ardrone_state;
//	uint32_t alert_state;
//	uint32_t emergency_state;
//	uint32_t num_frames;
//	bool_t wifiReachable;
//	bool_t   flying;
//} instance_navdata_t;
//extern instance_navdata_t instance_navdata;

C_RESULT navdata_reset(navdata_unpacked_t *nav);
C_RESULT navdata_get(navdata_unpacked_t *data);
C_RESULT navdata_write_to_file(bool_t enable);

//extern C_RESULT parrot_ardrone_navdata_get(instance_navdata_t */*data*/);
//extern inline void parrot_ardrone_navdata_checkErrors();

#endif /* NAV_DATA_H_ */
