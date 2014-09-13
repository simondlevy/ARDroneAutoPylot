% autopylot_agent.m - Matlab agent stub for AR.Drone Autopylot program.  Called
%           automatically by autopilot.
%
%     Copyright (C) 2013 Simon D. Levy
%
%     This program is free software: you can redistribute it and/or modify
%     it under the terms of the GNU Lesser General Public License as 
%     published by the Free Software Foundation, either version 3 of the 
%     License, or (at your option) any later version.
%
%     This program is distributed in the hope that it will be useful,
%     but WITHOUT ANY WARRANTY; without even the implied warranty of
%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%     GNU General Public License for more details.
%
%  You should have received a copy of the GNU Lesser General Public License 
%  along with this program.  If not, see <http://www.gnu.org/licenses/>.
%  You should also have received a copy of the Parrot Parrot AR.Drone 
%  Development License and Parrot AR.Drone copyright notice and disclaimer 
%  and If not, see 
%    <https://projects.ardrone.org/attachments/277/ParrotLicense.txt> 
%  and

function commands = autopylot_agent(img, navdata)

% Extract navigation data from input vector (all are doubles, even flags like is_belly)
is_belly    = navdata(1);
ctrl_state  = navdata(2);
battery     = navdata(3);
theta       = navdata(4);
phi         = navdata(5);
psi         = navdata(6);
altitude    = navdata(7);
vx          = navdata(8);
vy          = navdata(9);

% Report navdata
fprintf(2, 'ctrl state=%6d battery=%2d theta=%+f phi=%+f psi=%+f altitude=%+3d vx=%f vy=%f\n', ...
      ctrl_state, battery, theta, phi, psi, altitude, vx, vy)

% Show the camera image
image(img)
drawnow

% Don't do anything except ...
zap = 0;
phi = 0;
theta = 0;
gaz = 0;

% turn clockwise
yaw = 1.0;

% Put commands into output vector
commands = [zap, phi, theta, gaz, yaw];
