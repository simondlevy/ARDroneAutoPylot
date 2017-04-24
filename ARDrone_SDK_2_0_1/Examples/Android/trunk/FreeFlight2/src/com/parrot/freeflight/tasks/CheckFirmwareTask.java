package com.parrot.freeflight.tasks;

import java.io.IOException;

import org.xmlpull.v1.XmlPullParserException;

import android.content.Context;
import android.os.AsyncTask;
import android.util.Log;

import com.parrot.freeflight.drone.DroneConfig;
import com.parrot.freeflight.updater.utils.FirmwareConfig;
import com.parrot.freeflight.utils.FTPUtils;
import com.parrot.freeflight.utils.Version;

public class CheckFirmwareTask extends AsyncTask<Object, Integer, Boolean> 
{
	private static final String TAG = CheckFirmwareTask.class.getSimpleName();
	private Context context;
	
	public CheckFirmwareTask(Context context)
	{
		this.context = context;
	}
	
	@Override
	protected Boolean doInBackground(Object... params) 
	{
		try {
			FirmwareConfig config = new FirmwareConfig(context, "firmware");
	
			String droneVersionStr = FTPUtils.downloadFile(context, DroneConfig.getHost(), DroneConfig.getFtpPort(), "version.txt");
			if (droneVersionStr == null) {
				Log.w(TAG, "Can't determine drone version");
				return Boolean.FALSE;
			}
			
			Version droneVersion = new Version(droneVersionStr.trim());
			Version firmwareVersion = null;
			
			if (droneVersionStr.startsWith("1")) {
				firmwareVersion = new Version(config.getFirmwareVersion());
			} else if (droneVersionStr.startsWith("2")) {
				firmwareVersion = new Version(config.getFirmwareVersionV2());
			} else {
				Log.w(TAG, "Can't determine drone version");
				return Boolean.FALSE;
			}
			
			if (firmwareVersion.isGreater(droneVersion)) {
				return Boolean.TRUE;
			} else {
				return Boolean.FALSE;
			}
			
		} catch (IOException e) {
			e.printStackTrace();
		} catch (XmlPullParserException e) {
			e.printStackTrace();
		}	
		
		return Boolean.FALSE;
	}
}
