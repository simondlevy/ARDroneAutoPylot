/*
 *  wifi.c
 *  ARDroneEngine
 *
 *  Created by f.dhaeyer on 30/03/11.
 *  Copyright 2011 Parrot SA. All rights reserved.
 *
 */
#include "ConstantsAndMacros.h"

char iphone_mac_address[] = "00:00:00:00:00:00";

void get_iphone_mac_address(const char *itfName)
{
    int                 mib[6];
    size_t              len;
    char                *buf;
    unsigned char       *ptr;
    struct if_msghdr    *ifm;
    struct sockaddr_dl  *sdl;
        
    mib[0] = CTL_NET;
    mib[1] = AF_ROUTE;
    mib[2] = 0;
    mib[3] = AF_LINK;
    mib[4] = NET_RT_IFLIST;
			
    if ((mib[5] = if_nametoindex(itfName)) == 0) 
    {
        printf("Error: if_nametoindex error\n");
        return;
					}
                    
    if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0) 
    {
        printf("Error: sysctl, take 1\n");
        return;
			}
			
    if ((buf = vp_os_malloc(len)) == NULL) 
    {
        printf("Could not allocate memory. error!\n");
        return;
}

    if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
        printf("Error: sysctl, take 2");
        return;
    }
    
    ifm = (struct if_msghdr *)buf;
    sdl = (struct sockaddr_dl *)(ifm + 1);
    ptr = (unsigned char *)LLADDR(sdl);
    sprintf(iphone_mac_address, "%02X:%02X:%02X:%02X:%02X:%02X",*ptr, *(ptr+1), *(ptr+2), *(ptr+3), *(ptr+4), *(ptr+5));
    
    if(buf != NULL)
        vp_os_free(buf);
}

