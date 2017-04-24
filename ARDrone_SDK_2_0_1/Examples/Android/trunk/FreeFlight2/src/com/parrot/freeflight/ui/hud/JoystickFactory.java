/*
 * JoystickFactory
 *
 *  Created on: May 26, 2011
 *      Author: Dmytro Baryskyy
 */

package com.parrot.freeflight.ui.hud;


import android.content.Context;

import com.parrot.freeflight.ui.hud.Sprite.Align;

public class JoystickFactory 
{
	public static JoystickBase createAnalogueJoystick(Context context, boolean absolute,
															JoystickListener analogueListener)
	{
		AnalogueJoystick joy = new AnalogueJoystick(context, Align.NO_ALIGN, absolute);
		joy.setOnAnalogueChangedListener(analogueListener);
		
		return joy;
	}
	
	
	public static JoystickBase createAcceleroJoystick(Context context, 
															boolean absolute,
															JoystickListener acceleroListener)
	{
		AcceleroJoystick joy = new AcceleroJoystick(context, Align.NO_ALIGN, absolute);
		joy.setOnAnalogueChangedListener(acceleroListener);
		
		return joy;
	}
	
	
	public static JoystickBase createCombinedJoystick(Context context, 
															boolean absolute,
															JoystickListener analogueListener,
															JoystickListener acceleroListener)
	{
		JoystickBase joy = new AnalogueJoystick(context, Align.NO_ALIGN, absolute);
		joy.setOnAnalogueChangedListener(analogueListener);
		
		return joy;
	}
}