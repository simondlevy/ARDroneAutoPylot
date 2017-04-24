package com.parrot.freeflight.activities;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.os.Bundle;
import android.os.IBinder;
import android.support.v4.content.LocalBroadcastManager;
import android.view.View;

import com.parrot.freeflight.R;
import com.parrot.freeflight.activities.base.ParrotActivity;
import com.parrot.freeflight.service.DroneControlService;
import com.parrot.freeflight.ui.ConnectScreenViewController;
import com.parrot.freeflight.ui.ConnectScreenViewController.IndicatorState;
import com.parrot.freeflight.ui.StatusBar;
import com.parrot.freeflight.updater.FirmwareUpdateService;
import com.parrot.freeflight.updater.FirmwareUpdateService.ECommand;
import com.parrot.freeflight.updater.FirmwareUpdateService.ECommandResult;
import com.parrot.freeflight.updater.receivers.FirmwareUpdateServiceReceiver;
import com.parrot.freeflight.updater.receivers.FirmwareUpdateServiceReceiverDelegate;

public class UpdateFirmwareActivity extends ParrotActivity 
implements ServiceConnection,
            FirmwareUpdateServiceReceiverDelegate
{
	private StatusBar header = null;
//	private UpdateManager updateManager;
	
	private ConnectScreenViewController view;
    private FirmwareUpdateServiceReceiver firmwareUpdateServiceReceiver;
	
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		
		setContentView(R.layout.firmware_update_screen);
		firmwareUpdateServiceReceiver = new FirmwareUpdateServiceReceiver(this);
		
		bindService(new Intent(this, DroneControlService.class), this, Context.BIND_AUTO_CREATE);
		
	    view = new ConnectScreenViewController(this);
	    view.setProgressMaxValue(100);
	      
		View headerView = findViewById(R.id.header_preferences);
		header = new StatusBar(this, headerView);	
	}

	
	@Override
	protected void onDestroy()
	{
		super.onDestroy();
		
		unbindService(this);
	}


	@Override
    protected void onStart()
    {
        super.onStart();
        
        registerReceivers();
        
        startService(new Intent(this, FirmwareUpdateService.class));
    }


    @Override
    protected void onStop()
    {
        super.onStop();
        unregisterReceivers();
    }


    @Override
	protected void onPause() 
	{
		super.onPause();
		
		if (header != null) {
			header.stopUpdating();
		}

		finish();
	}

	
	@Override
	protected void onResume() 
	{	
		super.onResume();
		
		if (header != null) {
			header.startUpdating();
		}

	}
	
	
	private void registerReceivers()
	{
	    LocalBroadcastManager mgr = LocalBroadcastManager.getInstance(getApplicationContext());
	    mgr.registerReceiver(firmwareUpdateServiceReceiver, new IntentFilter(FirmwareUpdateService.UPDATE_SERVICE_STATE_CHANGED_ACTION));
	}
	
	
	private void unregisterReceivers()
	{
	    LocalBroadcastManager mgr = LocalBroadcastManager.getInstance(getApplicationContext());
        mgr.unregisterReceiver(firmwareUpdateServiceReceiver);
	}


    public void onCommandStateChanged(ECommand command, ECommandResult result, int progress, String message)
    {
        switch (command) {
        case COMMAND_CHECK_REPAIR:
            onCheckRepairChanged(result, progress, message);
            break;
        case COMMAND_SEND_FILE:
            onSendFileChanged(result, progress, message);
            break;
        case COMMAND_INSTALL:
            onInstallChanged(result, progress, message);
            break;
        case COMMAND_RESTART_DRONE:
            onRestartChanged(result, progress, message);
            break;
        }
        
        if (message != null) {
            view.setMessage(message);
        }
    }
    

    public void onCheckRepairChanged(ECommandResult result, int progress, String message)
    {
        view.setSendingFileState(IndicatorState.EMPTY);
        view.setRestartingDroneState(IndicatorState.EMPTY);
        view.setInstallingState(IndicatorState.EMPTY);
        
        view.setStatus(getString(R.string.checking_repairing));
        
        if (progress == 0) {
            view.setCheckingRepairingState(IndicatorState.ACTIVE);
        }
        
        switch (result) {
        case SUCCESS:
            view.setCheckingRepairingState(IndicatorState.PASSED);
            break;
        case FAILURE:
            view.setCheckingRepairingState(IndicatorState.FAILED);
            break;
        default:
            view.setCheckingRepairingState(IndicatorState.ACTIVE);
            break;
        }
    }
    

    private void onSendFileChanged(ECommandResult result, int progress, String message)
    {
        view.setCheckingRepairingState(IndicatorState.PASSED);
        view.setRestartingDroneState(IndicatorState.EMPTY);
        view.setInstallingState(IndicatorState.EMPTY);
        
        view.setStatus(getString(R.string.sending_file));
     
        if (progress > 0 && progress < 100) {
            view.setProgressVisible(true);
            view.setProgressValue(progress);
        } else {
            view.setProgressVisible(false);
        }
        
        switch (result) {
        case SUCCESS:
            view.setSendingFileState(IndicatorState.PASSED);
            break;
        case FAILURE:
            view.setSendingFileState(IndicatorState.FAILED);
            break;
        default:
            view.setSendingFileState(IndicatorState.ACTIVE);
            break;
        }
    }

    
    private void onRestartChanged(ECommandResult result, int progress, String message)
    {
        view.setCheckingRepairingState(IndicatorState.PASSED);
        view.setSendingFileState(IndicatorState.PASSED);
        view.setInstallingState(IndicatorState.EMPTY);

        view.setProgressVisible(false);
        
        view.setStatus(getString(R.string.restarting_ardrone));
      
        switch (result) {
        case SUCCESS:
            view.setRestartingDroneState(IndicatorState.PASSED);
            break;
        case FAILURE:
            view.setRestartingDroneState(IndicatorState.FAILED);
            break;
        default:
            view.setRestartingDroneState(IndicatorState.ACTIVE);
            break;
        }
    }
    
    
    private void onInstallChanged(ECommandResult result, int progress, String message)
    {
        view.setCheckingRepairingState(IndicatorState.PASSED);
        view.setSendingFileState(IndicatorState.PASSED);
        view.setRestartingDroneState(IndicatorState.PASSED);
        
        view.setProgressVisible(false);
        
        view.setStatus(getString(R.string.installing));
      
        switch (result) {
        case SUCCESS:
            view.setInstallingState(IndicatorState.PASSED);
            break;
        case FAILURE:
            view.setInstallingState(IndicatorState.FAILED);
            break;
        default:
            view.setInstallingState(IndicatorState.ACTIVE);
            break;
        }
    }


    public void onServiceConnected(ComponentName arg0, IBinder arg1)
    {
        // TODO Auto-generated method stub
        
    }


    public void onServiceDisconnected(ComponentName arg0)
    {
        // TODO Auto-generated method stub
        
    }

}
