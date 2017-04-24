/*
 * UpdaterConnectCommand
 *
 *  Created on: May 5, 2011
 *      Author: Dmytro Baryskyy
 */

package com.parrot.freeflight.updater.commands;

import android.content.Context;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;
import android.os.Build;
import android.util.Log;

import com.parrot.freeflight.R;
import com.parrot.freeflight.drone.DroneConfig;
import com.parrot.freeflight.service.listeners.DroneUpdaterListener.ArDroneToolError;
import com.parrot.freeflight.ui.ConnectScreenViewController.IndicatorState;
import com.parrot.freeflight.updater.UpdateManager;
import com.parrot.freeflight.utils.FtpDelegate;

public class UpdaterConnectCommand
	extends UpdaterCommandBase
	implements FtpDelegate
{

	private UpdaterCommandId nextCommand = UpdaterCommandId.CHECK_BOOT_LOADER;

	private String firmwareVersion;

	private boolean requestSent;
	
	
	public UpdaterConnectCommand(UpdateManager context) 
	{
		super(context);
	}

	
	public synchronized void execute(Context service) 
	{
		firmwareVersion = null;
		
		retrieveFirmwareVersion(service);

		// Will be used to connect to this hot spot when drone is rebooted.
		saveCurrentWifiSsid();
		
		if (firmwareVersion == null) {
			onFailure(service);
		} else {
			saveFirmwareVersion(firmwareVersion);
			onSuccess();
		}
	}


	public UpdaterCommandId getNextCommandId() 
	{
		return nextCommand;
	}

	
	public UpdaterCommandId getId() 
	{
		return UpdaterCommandId.CONNECT;
	}
	
	
	private void saveFirmwareVersion(String firmwareVersion)
	{
		context.setDroneFirmwareVersion(firmwareVersion);
	}


	private void saveCurrentWifiSsid() 
	{
		WifiManager wifi = (WifiManager) context.getContext().getSystemService(Context.WIFI_SERVICE);
		WifiInfo wifiInfo = wifi.getConnectionInfo();
		context.setDroneNetworkSSID(wifiInfo.getSSID());
	}

	
	private void onSuccess()
	{	
	}
	

	private void onFailure(Context service) 
	{
		error = ArDroneToolError.E_WIFI_NOT_AVAILABLE;
		nextCommand = null;
		
		String wifiNotAvailable = service.getString(R.string.wifi_not_available_please_connect_device_to_drone);
		wifiNotAvailable = wifiNotAvailable.replace("%@", Build.MANUFACTURER.toUpperCase());

	    delegate.setCheckingRepairingState(IndicatorState.FAILED, 100, wifiNotAvailable);
	}


	private void retrieveFirmwareVersion(Context service) 
	{
		requestSent = false;
	
		// Waiting for ftp download in a loop in order to exit
		// if user will cancel the operation.
		while (firmwareVersion == null && !context.isShuttingDown()) {
			
			if (!requestSent) {
				// Getting the firmware version.
				// firmwareVersion will be updated in the delegate.
				context.downloadFileAsync(service, DroneConfig.getHost(), 
										DroneConfig.getFtpPort(),
										"version.txt",
										this);
				requestSent = true;
			}
				
			
			if (firmwareVersion == null) {
				try {
					// version.txt was not yet downloaded. Waiting...
					wait(200);
				} catch (InterruptedException e) {
					e.printStackTrace();
				}
			}
			
			// if requestSent is false it means that ftp operation was completed,
			// exiting this method.
			if (requestSent == false) {
				return;
			}
		}
	}


	public void ftpOperationSuccess(String contents) 
	{
		firmwareVersion = contents;
		requestSent = false;
	}


	public void ftpOperationFailure() 
	{
		Log.w(getCommandName(), "Can't get file from the drone due to error.");
		requestSent = false;
	}
}
