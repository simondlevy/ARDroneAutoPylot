'''
autopylot_agent.py - Python agent stub for AR.Drone Autopylot program.

    Copyright (C) 2013 Simon D. Levy

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as 
    published by the Free Software Foundation, either version 3 of the 
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY without even the implied warranty of
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

# Support packages like ROS that expect command-line argv:
# https://github.com/google/oauth2client/issues/642
import sys
if not hasattr(sys, 'argv'):
    sys.argv  = ['']

def action(img_bytes, img_width, img_height, is_belly, \
    ctrl_state, vbat_flying_percentage, theta, phi, psi, altitude, vx, vy):

    # Report navigation data
    print('ctrl state=%6d battery=%2d%% theta=%+f phi=%+f psi=%+f altitude=%+3d vx=%f vy=%+f' % \
                          (ctrl_state, vbat_flying_percentage, theta, phi, psi, altitude, vx, vy))

    # Set up commands for a clockwise turn
    zap = 0
    phi = 0 
    theta = 0 
    gaz = 0 
    yaw = 1

    return (zap, phi, theta, gaz, yaw)
