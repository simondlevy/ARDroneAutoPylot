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
#
# Adapted from code in ARDrone SDK Examples/Linux/sdk_demo


include autopylot.makefile

GENERIC_CFLAGS+=-D$(GAMEPAD)

SDK_DIR:=$(shell pwd)/ARDrone_SDK_2_0_1

SDK_PATH=$(SDK_DIR)/ARDroneLib/

ARDRONE_TARGET_DIR=$(shell pwd)

PC_TARGET=yes
USE_LINUX=yes

TARGET=ardrone_autopylot

GENERIC_INCLUDES+=$(LANGUAGE_PATH)
	
GENERIC_LIBS+=$(LANGUAGE_LIB)

include $(SDK_PATH)/Soft/Build/custom.makefile
include $(SDK_PATH)/Soft/Build/config.makefile

SRC_DIR:=$(shell pwd)

# Define application source files
GENERIC_BINARIES_SOURCE_DIR:=$(SRC_DIR)

GENERIC_BINARIES_COMMON_SOURCE_FILES+=			\
   autopylot_video.c \
   autopylot_gamepad.c \
   autopylot_navdata.c \
   autopylot_commands.c \
   autopylot_$(LANGUAGE)_agent.c

GENERIC_INCLUDES+=					\
	$(SRC_DIR) \
	$(LIB_DIR) \
	$(SDK_PATH)/Soft/Common \
	$(SDK_PATH)/Soft/Lib 

GENERIC_TARGET_BINARIES_DIR=$(ARDRONE_TARGET_DIR)

GENERIC_BINARIES_SOURCE_ENTRYPOINTS+=			\
   ardrone_autopylot.c

GENERIC_INCLUDES:=$(addprefix -I,$(GENERIC_INCLUDES))

GENERIC_LIB_PATHS=-L$(GENERIC_TARGET_BINARIES_DIR) 
GENERIC_LIBS+=-lpc_ardrone -lgtk-x11-2.0 -lrt

SDK_FLAGS+="USE_APP=yes"
SDK_FLAGS+="APP_ID=linux_sdk_demo"

export GENERIC_LIBS
export GENERIC_LIB_PATHS
export GENERIC_INCLUDES
export GENERIC_BINARIES_SOURCE_DIR
export GENERIC_BINARIES_COMMON_SOURCE_FILES
export GENERIC_TARGET_BINARIES_DIR
export GENERIC_BINARIES_SOURCE_ENTRYPOINTS

# Bug fix ...
export GENERIC_LIBRARY_SOURCE_DIR=$(GENERIC_BINARIES_SOURCE_DIR)


.PHONY: $(TARGET) build_libs

all: build_libs $(TARGET)

$(TARGET):
	echo $(GENERIC_CFLAGS)
	echo $(GENERIC_INCLUDES)
	#@$(MAKE) -C $(SDK_PATH)/VP_SDK/Build $(TMP_SDK_FLAGS) $(SDK_FLAGS) $(MAKECMDGOALS) USE_LINUX=yes
	#rm -f sym_$(TARGET)

$(MAKECMDGOALS): build_libs
	@$(MAKE) -C $(SDK_PATH)/VP_SDK/Build $(TMP_SDK_FLAGS) $(SDK_FLAGS) $(MAKECMDGOALS) USE_LINUX=yes

build_libs:
	@$(MAKE) -C $(SDK_PATH)/Soft/Build $(TMP_SDK_FLAGS) $(SDK_FLAGS) $(MAKECMDGOALS) USE_LINUX=yes
