/*
 * CheckBootloaderState
 *
 *  Created on: May 5, 2011
 *      Author: Dmytro Baryskyy
 */

package com.parrot.freeflight.updater.commands;

import android.content.Context;

import com.parrot.freeflight.R;
import com.parrot.freeflight.service.listeners.DroneUpdaterListener.ArDroneToolError;
import com.parrot.freeflight.ui.ConnectScreenViewController.IndicatorState;
import com.parrot.freeflight.updater.UpdateManager;
import com.parrot.freeflight.utils.Version;

public class UpdaterCheckBootloaderCommand extends UpdaterCommandBase 
{
	
	private UpdaterCommandId nextCommand = UpdaterCommandId.UPLOAD_FIRMWARE;
	
	public UpdaterCheckBootloaderCommand(UpdateManager context) 
	{
		super(context);
	}
	
	public void execute(Context service) 
	{
        delegate.setCheckingRepairingState(IndicatorState.ACTIVE, 0, "");
		
		// Download version.txt from ftp://192.168.1.1:5551/version.txt
		String firmwareVersion = context.getDroneFirmwareVersion();
		String repairVersion = context.getFirmwareConfig().getRepairVersion();
		
		if (firmwareVersion != null && repairVersion != null) {
			Version verRemoteVersion = new Version(firmwareVersion.trim());
			Version verRepairVersion = new Version(repairVersion.trim());
			
			// If drone firmware version is older than repair version
			if (verRemoteVersion.isLower(verRepairVersion)) {
				// Do repair
				nextCommand = UpdaterCommandId.REPAIR_BOOTLOADER;
			} else {
				nextCommand = UpdaterCommandId.UPLOAD_FIRMWARE;
			}
			
			onSuccess();
		} else {
			setError(ArDroneToolError.E_UPDATE_BOOTLOADER_FAILED);
			onFailure(service.getString(R.string.ardrone_firmware) + 
					"\nCheck for boot loader has failed.");
		}
	}

	
	public void onSuccess()
	{
	    if (nextCommand != UpdaterCommandId.REPAIR_BOOTLOADER) {
            delegate.setCheckingRepairingState(IndicatorState.PASSED, 100, "");
        } 
	}
	
	
	public void onFailure(String message)
	{
		error = ArDroneToolError.E_UPDATE_BOOTLOADER_FAILED;
	    delegate.setCheckingRepairingState(IndicatorState.FAILED, 100, message);
		
		nextCommand = null;
	}

	
	public UpdaterCommandId getNextCommandId() 
	{
		return nextCommand;
	}


	public UpdaterCommandId getId()
	{
		return UpdaterCommandId.CHECK_BOOT_LOADER;
	}
}
