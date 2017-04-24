/*
 * UpdaterUploadFirmwareCommand
 *
 *  Created on: Jul 27, 2011
 *      Author: Dmytro Baryskyy
 */

package com.parrot.freeflight.updater.commands;

import java.io.File;

import android.content.Context;
import android.content.res.AssetManager;
import android.os.Build;
import android.util.Log;

import com.parrot.freeflight.R;
import com.parrot.freeflight.drone.DroneConfig;
import com.parrot.freeflight.ui.ConnectScreenViewController.IndicatorState;
import com.parrot.freeflight.updater.UpdateManager;
import com.parrot.freeflight.utils.CacheUtils;
import com.parrot.freeflight.utils.TelnetUtils;
import com.parrot.ftp.FTPClient;
import com.parrot.ftp.FTPClientStatus;
import com.parrot.ftp.FTPClientStatus.FTPStatus;
import com.parrot.ftp.FTPOperation;
import com.parrot.ftp.FTPProgressListener;

public class UpdaterUploadFirmwareCommand 
	extends UpdaterCommandBase 
	implements FTPProgressListener 
{
	
	private static final int RETRY_COUNT = 2;
	
	private UpdaterCommandId nextCommand;
	private boolean uploadFinished;
	private final Object lock = new Object();
	
	public UpdaterUploadFirmwareCommand(UpdateManager context) 
	{
		super(context);
	}

	
	@Override
	public synchronized void execute(Context service) 
	{
        delegate.setSendingFileState(IndicatorState.ACTIVE, 0, "");
		
		String droneFirmwareVersion = context.getDroneFirmwareVersion();
		
		String firmwareFileName = null;
		
		if (droneFirmwareVersion.startsWith("1.")) {
			firmwareFileName = context.getFirmwareConfig().getFileName();
		} else if (droneFirmwareVersion.startsWith("2.")) {
			firmwareFileName = context.getFirmwareConfig().getFileNameV2();
		} else {
			onFailure("Unable to get AR.Drone version.");
			return;
		}

		int counter = 0;
		boolean success = false;
		
		while (!success && counter < RETRY_COUNT) {
			 success = uploadFirmwareToDrone(service, firmwareFileName);

			 if (context.isShuttingDown()) {
				 break;
			 }
			 
			 if (!success && !context.isShuttingDown()) {
				counter += 1;
				
				try {
					wait(1000);
				} catch (InterruptedException e) {
					e.printStackTrace();
					break;
				}
			 }
		}

		
		if (success) {
			onSuccess();
		} else {
			onFailure(null);
		}

	}


	private boolean uploadFirmwareToDrone(Context service, String firmwareFileName) 
	{
	    // deleting the firmware files that could be left from previous unsuccessful attempt.
	    // On some drones may cause out of storage error so update in this case will not be possible.
	    TelnetUtils.executeRemotely(DroneConfig.getHost(), DroneConfig.TELNET_PORT, "cd /update && rm *.plf \n");
	    
		String localPath = "firmware/" + firmwareFileName; // in Assets folder
		String host = DroneConfig.getHost();
		int port = DroneConfig.getFtpPort();
		
		Log.d(getCommandName(), "Uploading file " + localPath + " to " + host + ":" + port);
		
		File tempFile = CacheUtils.createTempFile(service);
		FTPClient client = new FTPClient();
		
		try {
			if (tempFile == null) {
				return false;
			}
			
			AssetManager assets = service.getAssets();
			if (!CacheUtils.copyFileFromAssetsToStorage(assets, localPath, tempFile)) {
				Log.e(getCommandName(), "uploadFile() Can't copy file " + localPath + " to " + tempFile.getAbsolutePath());
				return false;
			}
				
			// Send file over ftp	
			if (!client.connect(host, port)) {
				Log.e(getCommandName(), "uploadFile() Can't connect to " + host + ":" + port);
				return false;
			}
			
			client.setProgressListener(this);
				
			uploadFinished = false;
			// Start transfer
			String remotePath = firmwareFileName;
			client.put(tempFile.getAbsolutePath(), remotePath);
			
			// Wait for upload to complete			
			while (!context.isShuttingDown() && !uploadFinished) {
				synchronized (lock) {
					try {
						lock.wait(500);
					} catch (InterruptedException e) {
						e.printStackTrace();
					}
				}
			}
			
			if (context.isShuttingDown()) {
				Log.d(getCommandName(), "uploadFile() Aborting the transfer to  " + host + ":" + port);
				
				client.setProgressListener(null);
				
				if (!client.abort()) {
					Log.d(getCommandName(), "uploadFile() Some problem has occured during ftp abort");
				}
				
				//Give it some time to abort. App will crash without this.
				sleep(1000);
				
				return false;
			}
			
			// Check result
			if (FTPClientStatus.isFailure(client.getReplyStatus())) {
				Log.e(getCommandName(), "uploadFile() Failed to upload file to ftp " + host + ":" + port);
				return false;
			}
	
			return true;	
		} finally {
			// Delete temp file
			if (tempFile != null && tempFile.exists()) {
				if (!tempFile.delete()) {
					Log.w(getCommandName(), "Can't delete file " + tempFile.getAbsolutePath());
				}
			}
			
			// Close FTP connection
			if (client.isConnected()) {
				client.disconnect();
			}
		}
		
	}


	public UpdaterCommandId getId() 
	{
		return UpdaterCommandId.UPLOAD_FIRMWARE;
	}


	public UpdaterCommandId getNextCommandId() 
	{
		return nextCommand;
	}
	
	
	public void onProgress(int progress) 
	{
        delegate.setSendingFileState(IndicatorState.ACTIVE, progress, "");
	}
	
	
	protected void onFailure(String message)
	{   
        String updateFailedMessage = null;

        if (message == null) {
            updateFailedMessage = context.getContext().getString(
                    R.string.wifi_not_available_please_connect_device_to_drone);
            updateFailedMessage = updateFailedMessage.replace("%@", Build.MANUFACTURER.toUpperCase());
        } else {
            updateFailedMessage = message;
        }

        delegate.setSendingFileState(IndicatorState.FAILED, 100, updateFailedMessage);
	}
	
	
	protected void onSuccess()
	{
		nextCommand = UpdaterCommandId.RESTART_DRONE;
		errorMessage = null;
		status = "";

	    delegate.setSendingFileState(IndicatorState.PASSED, 100, "");
	}


	public void onStatusChanged(FTPStatus status, float progress,
			FTPOperation operation) 
	{
		if (status == FTPStatus.FTP_PROGRESS) {
			onProgress(Math.round(progress));
		} else {
			uploadFinished = true;
			synchronized (lock) {
				lock.notify();
			}
		}
	}
}
