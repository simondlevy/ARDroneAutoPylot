package com.parrot.freeflight.activities;

import java.io.File;

import android.annotation.SuppressLint;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.net.NetworkInfo;
import android.net.wifi.WifiManager;
import android.os.AsyncTask;
import android.os.AsyncTask.Status;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.os.IBinder;
import android.support.v4.content.LocalBroadcastManager;
import android.util.Log;

import com.parrot.freeflight.R;
import com.parrot.freeflight.activities.base.DashboardActivityBase;
import com.parrot.freeflight.receivers.DroneAvailabilityDelegate;
import com.parrot.freeflight.receivers.DroneAvailabilityReceiver;
import com.parrot.freeflight.receivers.DroneConnectionChangeReceiverDelegate;
import com.parrot.freeflight.receivers.DroneConnectionChangedReceiver;
import com.parrot.freeflight.receivers.DroneFirmwareCheckReceiver;
import com.parrot.freeflight.receivers.DroneFirmwareCheckReceiverDelegate;
import com.parrot.freeflight.receivers.MediaReadyDelegate;
import com.parrot.freeflight.receivers.MediaReadyReceiver;
import com.parrot.freeflight.receivers.NetworkChangeReceiver;
import com.parrot.freeflight.receivers.NetworkChangeReceiverDelegate;
import com.parrot.freeflight.service.DroneControlService;
import com.parrot.freeflight.service.intents.DroneStateManager;
import com.parrot.freeflight.tasks.CheckAcademyAvailabilityTask;
import com.parrot.freeflight.tasks.CheckDroneNetworkAvailabilityTask;
import com.parrot.freeflight.tasks.CheckFirmwareTask;
import com.parrot.freeflight.tasks.CheckMediaAvailabilityTask;
import com.parrot.freeflight.transcodeservice.TranscodingService;
import com.parrot.freeflight.updater.FirmwareUpdateService;
import com.parrot.freeflight.utils.GPSHelper;

public class DashboardActivity extends DashboardActivityBase 
implements 
	ServiceConnection,
	DroneAvailabilityDelegate,
	NetworkChangeReceiverDelegate,
	DroneFirmwareCheckReceiverDelegate,
	DroneConnectionChangeReceiverDelegate,
	MediaReadyDelegate
{
	private DroneControlService mService;
	
	private BroadcastReceiver droneStateReceiver;
	private BroadcastReceiver networkChangeReceiver;
	private BroadcastReceiver droneFirmwareCheckReceiver;
	private BroadcastReceiver mediaReadyReceiver;
    private BroadcastReceiver droneConnectionChangeReceiver;
    
	private CheckAcademyAvailabilityTask checkAcademyAvailabilityTask;
	private CheckMediaAvailabilityTask checkMediaTask;
    private CheckFirmwareTask checkFirmwareTask;
    private CheckDroneNetworkAvailabilityTask checkDroneConnectionTask;
    
	private boolean droneOnNetwork;
	private boolean firmwareUpdateAvailable;
	private EPhotoVideoState mediaState;
	private boolean academyAvailable;
	
    @Override
    protected void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);

        if (isFinishing()) {
            return;
        }
        
        mediaState = EPhotoVideoState.UNKNOWN;
        initBroadcastReceivers();
        
        bindService(new Intent(this, DroneControlService.class), this, Context.BIND_AUTO_CREATE);

          if (GPSHelper.deviceSupportGPS(this) && !GPSHelper.isGpsOn(this)) {
              onNotifyAboutGPSDisabled();
        }
    }
   

    protected void initBroadcastReceivers()
    {
        droneStateReceiver = new DroneAvailabilityReceiver(this);
        networkChangeReceiver = new NetworkChangeReceiver(this);
        droneFirmwareCheckReceiver = new DroneFirmwareCheckReceiver(this);
        mediaReadyReceiver = new MediaReadyReceiver(this);
        droneConnectionChangeReceiver = new DroneConnectionChangedReceiver(this);
    }
    
    
    private void registerBroadcastReceivers()
    {
        LocalBroadcastManager broadcastManager = LocalBroadcastManager.getInstance(getApplicationContext());
        broadcastManager.registerReceiver(droneStateReceiver, new IntentFilter(
                DroneStateManager.ACTION_DRONE_STATE_CHANGED));
        broadcastManager.registerReceiver(droneFirmwareCheckReceiver, new IntentFilter(
                DroneControlService.DRONE_FIRMWARE_CHECK_ACTION));
        
        IntentFilter mediaReadyFilter = new IntentFilter();
        mediaReadyFilter.addAction(DroneControlService.NEW_MEDIA_IS_AVAILABLE_ACTION);
        mediaReadyFilter.addAction(TranscodingService.NEW_MEDIA_IS_AVAILABLE_ACTION);
        broadcastManager.registerReceiver(mediaReadyReceiver, mediaReadyFilter);
        broadcastManager.registerReceiver(droneConnectionChangeReceiver, new IntentFilter(DroneControlService.DRONE_CONNECTION_CHANGED_ACTION));
        
        registerReceiver(networkChangeReceiver, new IntentFilter(WifiManager.NETWORK_STATE_CHANGED_ACTION));
    }
    
    
    private void unregisterReceivers()
    {
        LocalBroadcastManager broadcastManager = LocalBroadcastManager.getInstance(getApplicationContext());
        broadcastManager.unregisterReceiver(droneStateReceiver);
        broadcastManager.unregisterReceiver(droneFirmwareCheckReceiver);
        broadcastManager.unregisterReceiver(mediaReadyReceiver);
        broadcastManager.unregisterReceiver(droneConnectionChangeReceiver);
        unregisterReceiver(networkChangeReceiver);
    }
    
    
    @Override
    protected void onDestroy()
    {
        unbindService(this);
        super.onDestroy();
    }
    
    
    @Override
    protected void onPause()
    {
        super.onPause();
        
        unregisterReceivers();
        stopTasks();
    }

    
    @Override
    protected void onResume()
    {
        super.onResume();

        registerBroadcastReceivers();
        
        disableAllButtons();

        if (mService != null) {
            checkMedia();
        }
        checkAcademyAvailability();
        checkDroneConnectivity();
    }
    
    
    private void disableAllButtons()
    {
        droneOnNetwork = false;
        firmwareUpdateAvailable = false;
        mediaState = EPhotoVideoState.NO_SDCARD;
        academyAvailable = false;
        
        requestUpdateButtonsState();
    }


    @Override
    protected boolean onStartFreeflight()
    {
        if (!droneOnNetwork)
        {
            return false;
        }

        Intent connectActivity = new Intent(this, ConnectActivity.class);
        startActivity(connectActivity);

        return true;
    }
    
    
    @Override
    protected boolean onStartFirmwareUpdate() 
    {
        if (firmwareUpdateAvailable) {
            if (mService != null && mService.isUSBInserted() && !FirmwareUpdateService.isRunning()) {
                onNotifyAboutUSBStickRemove();
            } else {              
                Intent updatefirmwareActivity = new Intent(this, UpdateFirmwareActivity.class);
                startActivity(updatefirmwareActivity);
            }
        }
        
        return firmwareUpdateAvailable;
    }
    
    
    protected void onUSBStickRemoveDialogDismissed()
    {
        Intent updatefirmwareActivity = new Intent(this, UpdateFirmwareActivity.class);
        startActivity(updatefirmwareActivity);
    }

    
    @Override
    protected boolean onStartGuestSpace() 
    {
        Intent intent = new Intent(this, GuestSpaceActivity.class);
        startActivity(intent);
        
        return true;
    }
    
    
    @Override
    protected boolean onStartAcademy()
    {
        Intent intent = new Intent(this, BrowserActivity.class);
        intent.putExtra(BrowserActivity.URL, getString(R.string.url_aa_register));
        startActivity(intent);
        
        return true;
    }
    
    
    @Override
    protected boolean onStartPhotosVideos()
    {
        Intent intent = new Intent(this, MediaActivity.class);
        startActivity(intent);
    
        return true;
    }

    
    public void onFirmwareChecked(boolean updateRequired) 
    {   
        firmwareUpdateAvailable = updateRequired;
    
        requestUpdateButtonsState();
    }
    

    public void onMediaReady(File mediaFile)
    {
        // Triggering check for new media if photo/video button is disabled
        // If new media is found this will result in enabling the button.
        if (!getPhotoVideoState().equals(EPhotoVideoState.READY)) {
            checkMedia();
        }
    }
    
    public void onNetworkChanged(NetworkInfo info)
    {
        Log.d(TAG, "Network state has changed. State is: " + (info.isConnected()?"CONNECTED":"DISCONNECTED"));

        if (mService != null && info.isConnected()) {
            checkDroneConnectivity();
            checkAcademyAvailability();
        } else {         
            firmwareUpdateAvailable = false;
            droneOnNetwork = false;
            requestUpdateButtonsState();
        }
    }
    

    public void onDroneConnected()
    {
        if (mService != null) {
            mService.pause();
        }
    }


    public void onDroneDisconnected()
    {
        // Left unimplemented
    }
    

    public void onDroneAvailabilityChanged(boolean droneOnNetwork)
    {
        if (droneOnNetwork) {
            Log.d(TAG, "AR.Drone connection [CONNECTED]");
            this.droneOnNetwork = droneOnNetwork;
            
            if (droneOnNetwork) {
                // If we connected to the drone we are 100% sure that there is no internet connection
                this.academyAvailable = false;
            }
            
            requestUpdateButtonsState();
            checkFirmware();
        } else {
            Log.d(TAG, "AR.Drone connection [DISCONNECTED]");
        }
    }


    private void checkFirmware()
    {
        if (checkFirmwareTask != null && checkFirmwareTask.getStatus() != Status.FINISHED) {
            checkFirmwareTask.cancel(true);
        }
        
        checkFirmwareTask = new CheckFirmwareTask(this) {                 
                @Override
                protected void onPostExecute(Boolean result) {
                   onFirmwareChecked(result);
                }
            };
            
        checkFirmwareTask.execute();    
    }
    
    
    @SuppressLint("NewApi")
    private void checkDroneConnectivity()
    {
        if (checkDroneConnectionTask != null && checkDroneConnectionTask.getStatus() != Status.FINISHED) {
            checkDroneConnectionTask.cancel(true);
        }
        
        checkDroneConnectionTask = new CheckDroneNetworkAvailabilityTask() {
            
                @Override
                protected void onPostExecute(Boolean result) {
                   onDroneAvailabilityChanged(result);
                } 
                    
            };
            
            if (Build.VERSION.SDK_INT >= 11) {
                checkDroneConnectionTask.executeOnExecutor(CheckDroneNetworkAvailabilityTask.THREAD_POOL_EXECUTOR, this);
            } else {
                checkDroneConnectionTask.execute(this);
            }
    }
    
       
    @Override
    public void onMediaStorageMounted()
    {
         checkMedia();
    }


    @Override
    public void onMediaStorageUnmounted()
    {
        checkMedia();
    }


    public void onServiceConnected(ComponentName name, IBinder service)
    {
        mService = ((DroneControlService.LocalBinder) service).getService();
        
        File mediaDir = mService.getMediaDir();
        if (mediaDir == null) {
            mediaState = EPhotoVideoState.NO_SDCARD;
            requestUpdateButtonsState();
        }     
        
        checkMedia();
    }  
    
    
    public void onServiceDisconnected(ComponentName name)
    {
        // Left unimplemented
    }

	
    private void checkMedia()
    {    
        if (mService != null) {
            String mediaStorageState = Environment.getExternalStorageState();
            
            if (!mediaStorageState.equals(Environment.MEDIA_MOUNTED) &&
                !mediaStorageState.equals(Environment.MEDIA_MOUNTED_READ_ONLY)) {
                mediaState = EPhotoVideoState.NO_SDCARD;
                requestUpdateButtonsState();
                return;
            } else {
                mediaState = EPhotoVideoState.NO_MEDIA;
            }
        } else {
            mediaState = EPhotoVideoState.NO_SDCARD;
            requestUpdateButtonsState();
            return;
        }
        
        
        if (!taskRunning(checkMediaTask))
        {
            checkMediaTask = new CheckMediaAvailabilityTask(this) { 
                @Override
                protected void onPostExecute(Boolean available)
                {
                    if (available) {
                        mediaState = EPhotoVideoState.READY;
                    } else {
                        mediaState = EPhotoVideoState.NO_MEDIA;
                    }
                    requestUpdateButtonsState();
                }
    
            };
            
            checkMediaTask.execute();
        }
    }
    

    @SuppressLint("NewApi")
    private void checkAcademyAvailability()
    {
        if (!taskRunning(checkAcademyAvailabilityTask)) {
            checkAcademyAvailabilityTask = new CheckAcademyAvailabilityTask()
            {
                @Override
                protected void onPostExecute(Boolean result)
                {
                    academyAvailable = result;
                    requestUpdateButtonsState();
                }
            };

            if (Build.VERSION.SDK_INT >= 11) {
                checkAcademyAvailabilityTask.executeOnExecutor(CheckAcademyAvailabilityTask.THREAD_POOL_EXECUTOR, this);
            } else {
                checkAcademyAvailabilityTask.execute(this);
            }
        }
    }
    
    
    private boolean taskRunning(AsyncTask<?,?,?> checkMediaTask2)
    {
        if (checkMediaTask2 == null)
            return false;
        
        if (checkMediaTask2.getStatus() == Status.FINISHED) 
            return false;
        
        return true;
    }


	private void stopTasks()
    {
        if (taskRunning(checkMediaTask)) {
            checkMediaTask.cancel(true);
        }
        
        if (taskRunning(checkAcademyAvailabilityTask)) {
            checkAcademyAvailabilityTask.cancel(true);
        }  
        
        if (taskRunning(checkFirmwareTask)) {
            checkFirmwareTask.cancel(true);
        }
        
        if (taskRunning(checkDroneConnectionTask)) {
            checkDroneConnectionTask.cancelAnyFtpOperation();
        }
            
    }

	@Override
	protected boolean isGuestSpaceEnabled() 
	{
		return true;
	}

	
	@Override
	protected boolean isAcademyEnabled()
	{
		return academyAvailable;
	}

	@Override
	protected boolean isFreeFlightEnabled()
	{
		return droneOnNetwork;
	}

	@Override
	protected EPhotoVideoState getPhotoVideoState()
	{
		return mediaState;
	}
	
	@Override
	protected boolean isFirmwareUpdateEnabled() 
	{
		return firmwareUpdateAvailable;
	}
	
    private void onNotifyAboutGPSDisabled()
    {
        showAlertDialog(getString(R.string.Location_services_alert), getString(R.string.If_you_want_to_store_your_location_anc_access_your_media_enable_it),
          null);
    }
    
    private void onNotifyAboutUSBStickRemove()
    {
        Runnable actionOnDismiss = new Runnable() {
            @Override
             public void run()
             {
                onUSBStickRemoveDialogDismissed();
             } 
         };
         
        showAlertDialog(getString(R.string.Update_Warning), getString(R.string.Please_unplug_your_USB_key_from_the_ARDrone_now), actionOnDismiss);
    }

}
