package com.parrot.freeflight;

import android.annotation.SuppressLint;
import android.app.Application;
import android.util.Log;

import com.parrot.freeflight.settings.ApplicationSettings;

public class FreeFlightApplication 
	extends Application 
	
{   
	private static final String TAG = "FreeFlightApplication";
    
	private ApplicationSettings settings;
	
	static {
		System.loadLibrary("avutil");
		System.loadLibrary("swscale");
		System.loadLibrary("avcodec");
		System.loadLibrary("avfilter");
		System.loadLibrary("avformat");
		System.loadLibrary("avdevice");
		System.loadLibrary("adfreeflight");
	}
	
	@SuppressLint("NewApi")
    @Override
	public void onCreate() 
	{
		super.onCreate();
		Log.d(TAG, "OnCreate");

		settings = new ApplicationSettings(this);
	}

	
	@Override
	public void onTerminate() 
	{
		Log.d(TAG, "OnTerminate");
		super.onTerminate();
	}

	
	public ApplicationSettings getAppSettings()
	{
		return settings;
	}

}
