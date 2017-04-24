package com.parrot.freeflight.utils;

import java.io.IOException;

import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.DefaultHttpClient;

import android.content.Context;
import android.os.Looper;
import android.util.Log;

import com.parrot.freeflight.R;

public final class InternetUtils
{
	private static final String TAG = InternetUtils.class.getSimpleName();

	
	public static boolean isOnline(Context context)
	{
		String url = context.getString(R.string.url_aa_register);
		
		return isOnline(context, url);
	}

	
	public static boolean isOnline(Context context, String url)
	{
		if (Looper.myLooper() != null) {
			throw new IllegalThreadStateException("isOnline should not be called from main thread");
		}
		
		boolean result = false;

		HttpGet requestForTest = new HttpGet(url);	
		
		try {
			DefaultHttpClient client = new DefaultHttpClient();
			client.execute(requestForTest);
			result = true;
		} catch (ClientProtocolException e) {
			Log.w(TAG, e.toString());
		} catch (IOException e) {
			Log.w(TAG, e.toString());
		} 
		
		return result;
	}
}
