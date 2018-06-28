/*
autopylot_python_agent.c - C/Python communication code for AR.Drone Autopylot 
                           agent.

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
*/

#include <Python.h>

#undef _GNU_SOURCE

#include <navdata_common.h>

#include <stdio.h>
#include <stdlib.h>

#include "autopylot_agent.h"

#define AGENT_MODULE_NAME "autopylot_agent"
#define AGENT_FUNCTION_NAME "action"

static PyObject *pModule, *pFunc, *pArgs, *pResult;

static void error(const char * msg, const char * name)
{
	
	fprintf(stderr, msg, name);
	exit(1);
}

static void fun_error(const char * msg, const char * name)
{
	PyErr_Print();
	Py_DECREF(pArgs);
	Py_DECREF(pResult);
	Py_DECREF(pModule);
	Py_DECREF(pFunc);
	error(msg, name);
}

void agent_init()
{
		
	Py_Initialize();

    // Make sure we can access Python modules in the current directory
    PyRun_SimpleString("import sys");
    PyRun_SimpleString("sys.path.append(\".\")");

    PyObject * pName = PyString_FromString(AGENT_MODULE_NAME);

    pModule = PyImport_Import(pName);

    Py_DECREF(pName);
	
	if (pModule == NULL)
{
		PyErr_Print();
		error("Failed to load %s", AGENT_MODULE_NAME);
	}
	
	pFunc = PyObject_GetAttrString(pModule, AGENT_FUNCTION_NAME);
	
	if (!(pFunc && PyCallable_Check(pFunc)))
{
		if (PyErr_Occurred())
{
			PyErr_Print();
		}
		error("Cannot find function %s", AGENT_FUNCTION_NAME);
	}
	
	pArgs = PyTuple_New(12);
	
	pResult = PyTuple_New(5);
}

static void set_arg(PyObject * pValue, int pos)
{
	
	if (!pValue)
{
		fun_error("Cannot convert argument", "");
	}
	
	PyTuple_SetItem(pArgs, pos, pValue);
}


static void set_int_arg(int val, int pos)
{
	
	set_arg(PyInt_FromLong((long)val), pos);
}

static void set_float_arg(float val, int pos)
{
	
	set_arg(PyFloat_FromDouble((double)val), pos);
}

static int get_int_result(PyObject *pResult, int pos)
{
	
	return (int)PyInt_AsLong(PyTuple_GetItem(pResult, pos));
}

static float get_float_result(PyObject *pResult, int pos)
{
	
	return (float)PyFloat_AsDouble(PyTuple_GetItem(pResult, pos));
}

void agent_act(unsigned char * img_bytes, int img_width, int img_height, bool_t img_is_belly,
	navdata_unpacked_t * navdata, commands_t * commands)
{    
	int k = 0;

	PyObject *pImageBytes = PyByteArray_FromStringAndSize((const char *)img_bytes, img_width*img_height*3);
	
	set_arg(pImageBytes,                         k++);
	set_int_arg(img_width, 	                     k++);
	set_int_arg(img_height,	                     k++);
	
	set_int_arg(img_is_belly?1:0, 	             k++);

    navdata_demo_t demo = navdata->navdata_demo;
	
	set_int_arg(demo.ctrl_state, 	         k++);
	set_int_arg(demo.vbat_flying_percentage, k++);
	set_float_arg(demo.theta,                k++);
	set_float_arg(demo.phi,                  k++);
	set_float_arg(demo.psi,                  k++);

	set_int_arg(navdata->navdata_altitude.altitude_raw, k++);

    navdata_vision_raw_t vision_raw = navdata->navdata_vision_raw;

	set_float_arg(vision_raw.vision_tx_raw, k++);
	set_float_arg(vision_raw.vision_ty_raw, k++);
	
	PyObject * pResult = PyObject_CallObject(pFunc, pArgs);
	
	if (!pResult)
{
		fun_error("Call failed\n", "");
	}
	
	k = 0;
	commands->zap     = get_int_result(pResult,   k++);
	commands->phi     = get_float_result(pResult, k++);
	commands->theta   = get_float_result(pResult, k++);
	commands->gaz     = get_float_result(pResult, k++);
	commands->yaw     = get_float_result(pResult, k++);
}

void agent_close()
{
	
	Py_XDECREF(pFunc);
	Py_DECREF(pModule);
	Py_DECREF(pArgs);
	Py_DECREF(pResult);
	
	Py_Finalize();
}
