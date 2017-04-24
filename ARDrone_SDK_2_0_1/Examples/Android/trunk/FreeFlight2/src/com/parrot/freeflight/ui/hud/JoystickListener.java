/*
 * JoystickListener
 *
 *  Created on: May 26, 2011
 *      Author: Dmytro Baryskyy
 */

package com.parrot.freeflight.ui.hud;

public abstract class JoystickListener 
{
	public abstract void onChanged(JoystickBase joystick, float x, float y);
	public abstract void onPressed(JoystickBase joystick);
	public abstract void onReleased(JoystickBase joystick);
}
