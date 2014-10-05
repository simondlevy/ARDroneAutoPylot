'''
Python green-ball-tracking agent for AR.Drone Autopylot program.  

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
'''

# PID parameters
Kpx = 0.25
Kpy = 0.25
Kdx = 0.25
Kdy = 0.25
Kix = 0
Kiy = 0

import cv
import greenball_tracker

# Routine called by C program.
def action(img_bytes, img_width, img_height, is_belly, ctrl_state, vbat_flying_percentage, theta, phi, psi, altitude, vx, vy):

    # Set up command defaults
    zap = 0
    phi = 0     
    theta = 0 
    gaz = 0
    yaw = 0

    # Set up state variables first time around
    if not hasattr(action, 'count'):
        action.count = 0
        action.errx_1 = 0
        action.erry_1 = 0
        action.phi_1 = 0
        action.gaz_1 = 0
                
    # Create full-color image from bytes
    image = cv.CreateImageHeader((img_width,img_height), cv.IPL_DEPTH_8U, 3)      
    cv.SetData(image, img_bytes, img_width*3)
                
    # Grab centroid of green ball
    ctr = greenball_tracker.track(image)

    # Use centroid if it exists
    if ctr:

        # Compute proportional distance (error) of centroid from image center
        errx =  _dst(ctr, 0, img_width)
        erry = -_dst(ctr, 1, img_height)

        # Compute vertical, horizontal velocity commands based on PID control after first iteration
        if action.count > 0:
            phi = _pid(action.phi_1, errx, action.errx_1, Kpx, Kix, Kdx)
            gaz = _pid(action.gaz_1, erry, action.erry_1, Kpy, Kiy, Kdy)

        # Remember PID variables for next iteration
        action.errx_1 = errx
        action.erry_1 = erry
        action.phi_1 = phi
        action.gaz_1 = gaz
        action.count += 1

    # Send control parameters back to drone
    return (zap, phi, theta, gaz, yaw)
    
# Simple PID controller from http://www.control.com/thread/1026159301
def _pid(out_1, err, err_1, Kp, Ki, Kd):
    return Kp*err + Ki*(err+err_1) + Kd*(err-err_1) 

# Returns proportional distance to image center along specified dimension.
# Above center = -; Below = +
# Right of center = +; Left = 1
def _dst(ctr, dim, siz):
    siz = siz/2
    return (ctr[dim] - siz) / float(siz)    

