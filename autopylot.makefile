#
#    Copyright (C) 2013 Simon D. Levy
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Lesser General Public License as 
#    published by the Free Software Foundation, either version 3 of the 
#    License, or (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License 
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# You should also have received a copy of the Parrot Parrot AR.Drone 
# Development License and Parrot AR.Drone copyright notice and disclaimer 
# and If not, see 
#   <https://projects.ardrone.org/attachments/277/ParrotLicense.txt> 
# and
#   <https://projects.ardrone.org/attachments/278/ParrotCopyrightAndDisclaimer.txt>.

# We currently support LOGITCH and PS3 gamepads
GAMEPAD = GAMEPAD_LOGITECH_ID=0x046dc215
#GAMEPAD = GAMEPAD_PS3_ID=0x0e8f0003

# Python version: you may need to run apt-get install python-dev as root
PYVER = 2.7

# If you use Python, make sure that PYTHONPATH shell variable contains . 
# (dot; current directory). In ~/.bashrc:
# export PYTHONPATH=$PYTHONPATH:.
LANGUAGE = python
LANGUAGE_LIB = -L/usr/lib/python$(PYVER)/config -lpython$(PYVER) -lm
LANGUAGE_PATH = /usr/include/python$(PYVER)	

# If you use Matlab, make sure to put the following in ~/.bashrc:
# export MATLAB=/usr/local/MATLAB/R2013b # or whatever your version is
# export PATH=$PATH:$MATLAB/bin
# export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$MATLAB/bin/glnxa64
# Also make sure that you can run csh (if not: sudo apt-get install csh).
#LANGUAGE = matlab
#LANGUAGE_LIB = -L $(MATLAB)/bin/glnxa64 -lm -leng -lmx -lmwMATLAB_res
#LANGUAGE_PATH=$(MATLAB)/extern/include/

# If you use C, this is all you need
#LANGUAGE = c
#LANGUAGE_LIB = -lm
