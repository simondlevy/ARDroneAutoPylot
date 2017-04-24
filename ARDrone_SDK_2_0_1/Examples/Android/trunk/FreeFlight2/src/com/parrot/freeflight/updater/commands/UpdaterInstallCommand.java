/*
 * UpdaterInstallCommand
 *
 *  Created on: Jul 27, 2011
 *      Author: Dmytro Baryskyy
 */

package com.parrot.freeflight.updater.commands;

import android.content.Context;
import android.net.wifi.SupplicantState;
import android.net.wifi.WifiInfo;
import android.net.wifi.WifiManager;

import com.parrot.freeflight.R;
import com.parrot.freeflight.ui.ConnectScreenViewController.IndicatorState;
import com.parrot.freeflight.updater.UpdateManager;

public class UpdaterInstallCommand 
	extends UpdaterCommandBase
{
	
	public UpdaterInstallCommand(UpdateManager context) 
	{
		super(context);
	}
	
	
	@Override
	public void execute(Context service) 
	{
        delegate.setInstallingState(IndicatorState.ACTIVE, 0, service.getString(R.string.if_ardrone_led_green_reset_wifi_connection));
        
        boolean connected = false;
        WifiManager mgr = (WifiManager) service.getSystemService(Context.WIFI_SERVICE);
        
        while (!connected) {
            WifiInfo info = mgr.getConnectionInfo();
            
            SupplicantState state = info.getSupplicantState();
            
            if (state == SupplicantState.COMPLETED ||
                state == SupplicantState.DORMANT) {
                try {
                    Thread.sleep(1000);
                } catch (InterruptedException e) {
                   break;
                }
                break;
            }
        }
        
        delegate.setInstallingState(IndicatorState.ACTIVE, 0, service.getString(R.string.if_ardrone_led_green_reset_wifi_connection));
	}


	public UpdaterCommandId getId()
	{
		return UpdaterCommandId.INSTALL;
	}


	public UpdaterCommandId getNextCommandId() 
	{
		return null;
	}
}
