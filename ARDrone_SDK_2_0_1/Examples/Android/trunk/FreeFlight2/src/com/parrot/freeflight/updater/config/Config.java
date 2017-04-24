/*
 * Config
 *
 *  Created on: Sep 1, 2011
 *      Author: Dmytro Baryskyy
 */

package com.parrot.freeflight.updater.config;

import java.io.IOException;

import org.xmlpull.v1.XmlPullParser;
import org.xmlpull.v1.XmlPullParserException;

import android.content.Context;
import android.content.res.XmlResourceParser;
import android.util.Log;

import com.parrot.freeflight.R;

public class Config 
{
	private static final String CONFIG_TAG = "updater";
	private static final String ENABLED_ATTR = "enabled";
	
	private boolean enabled;

	public Config(Context context)
	{
		XmlResourceParser parser = context.getResources().getXml(R.xml.updater_config);
		
		try {
			init(parser);
		} catch (XmlPullParserException e) {
			Log.e("Config", "Exception e: " + e);
			e.printStackTrace();
		} catch (IOException e) {
			Log.e("Config", "Exception e: " + e);
			e.printStackTrace();
		}
	}
	
	
	public boolean isEnabled() 
	{
		return enabled;
	}

	
	public void setEnabled(boolean enabled) 
	{
		this.enabled = enabled;
	}
	
	
	private void init(XmlResourceParser parser) throws XmlPullParserException, IOException
	{
		parser.next();
		int eventType = parser.getEventType();
		
		 while (eventType != XmlPullParser.END_DOCUMENT) {
			 if(eventType == XmlPullParser.START_TAG) {
				 if (parser.getName().equals(CONFIG_TAG)) {
					 enabled = Boolean.valueOf(parser.getAttributeValue(null, ENABLED_ATTR));
				 }
			 }
			 
			 eventType = parser.next();
		 }
	}
}
