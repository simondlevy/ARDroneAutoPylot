/*
 * AnalogueJoystick
 *
 *  Created on: May 26, 2011
 *      Author: Dmytro Baryskyy
 */

package com.parrot.freeflight.ui.hud;

import android.content.Context;

import com.parrot.freeflight.R;

public class AnalogueJoystick 
	extends JoystickBase
{

	public AnalogueJoystick(Context context, Align align, boolean absolute) 
	{
		super(context, align, absolute);
	}
 
	@Override
	protected int getBackgroundDrawableId() 
	{
		return R.drawable.joystick_halo;
	}

	
	@Override
	protected int getTumbDrawableId() 
	{
		return R.drawable.joystick_manuel;
	}
}
