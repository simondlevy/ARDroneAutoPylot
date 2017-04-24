package com.parrot.freeflight.updater;

import android.app.Service;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.net.wifi.WifiManager;
import android.net.wifi.WifiManager.WifiLock;
import android.os.Binder;
import android.os.IBinder;
import android.support.v4.content.LocalBroadcastManager;

import com.parrot.freeflight.ui.ConnectScreenViewController.IndicatorState;

public class FirmwareUpdateService extends Service
implements UpdaterDelegate
{   
    public static final String UPDATE_SERVICE_STATE_CHANGED_ACTION = "com.parrot.update.service.state.changed.action";
    public static final String EXT_COMMAND = "ext.command";
    public static final String EXT_COMMAND_RESULT = "ext.command.result";
    public static final String EXT_COMMAND_PROGRESS = "ext.command.progress";
    public static final String EXT_COMMAND_MESSAGE = "ext.command.message";
    
    private static boolean running;
    
    public enum ECommand {
        COMMAND_CHECK_REPAIR,
        COMMAND_SEND_FILE,
        COMMAND_RESTART_DRONE,
        COMMAND_INSTALL
    };
    
    public enum ECommandResult {
        UNKNOWN,
        SUCCESS,
        FAILURE
    };
    
    
    private final IBinder binder = new LocalBinder();  
    private UpdateManager updateManager;
    private LocalBroadcastManager broadcastManager;
    private Intent lastIntent;
    private WifiLock wifiLock;
    
    private static final ComponentName COMPONENT_NAME = new ComponentName(FirmwareUpdateService.class.getPackage().getName(), FirmwareUpdateService.class.getName());
    
    public static ComponentName getComponentName()
    {
       return COMPONENT_NAME;
    }
    
    
    public static boolean isRunning()
    {
        return running;
    }
    
    
    @Override
    public void onCreate()
    {   
        super.onCreate();       
        
        broadcastManager = LocalBroadcastManager.getInstance(getApplicationContext());
        
        WifiManager mgr = (WifiManager) getSystemService(Context.WIFI_SERVICE);
        wifiLock = mgr.createWifiLock("Firmware Update Wifi Lock");
        wifiLock.acquire();
    }


    @Override
    public void onDestroy()
    {
        super.onDestroy();
        
        if (wifiLock.isHeld()) {
            wifiLock.release();
        }
    }


    @Override
    public IBinder onBind(Intent intent) {
        
        if (lastIntent != null) {
            broadcastManager.sendBroadcast(lastIntent);
        }
        
        if (!updateManager.isInProgress()) {
            updateManager.start();
        }
        return binder;
    }
    

    @Override
    public int onStartCommand(Intent intent, int flags, int startId)
    {
        if (lastIntent != null) {
            broadcastManager.sendBroadcast(lastIntent);
        }

        if (updateManager == null) {
            updateManager = new UpdateManager(this, this);
            
            updateManager.start();
            running = true;
        } else {
            return START_STICKY;
        }

        return START_STICKY;
    }


    public void setCheckingRepairingState(IndicatorState state, int progress, String message)
    {
        switch (state) {
        case EMPTY:
            // Left unimplemented
            break;
        case ACTIVE:
            notifyCommandStateChanged(ECommand.COMMAND_CHECK_REPAIR, 0,  ECommandResult.UNKNOWN, message);
            break;
        case PASSED:
            notifyCommandStateChanged(ECommand.COMMAND_CHECK_REPAIR, 100, ECommandResult.SUCCESS, message);
            break;
        case FAILED:
            notifyCommandStateChanged(ECommand.COMMAND_CHECK_REPAIR, 100, ECommandResult.FAILURE, message);
            break;
        }
    }
    

    public void setSendingFileState(IndicatorState state, int progress, String message)
    {
        switch (state) {
        case EMPTY:
            // Left unimplemented
            break;
        case ACTIVE:
            notifyCommandStateChanged(ECommand.COMMAND_SEND_FILE, progress, ECommandResult.UNKNOWN, message);
            break;
        case PASSED:
            notifyCommandStateChanged(ECommand.COMMAND_SEND_FILE, 100, ECommandResult.SUCCESS, message);
            break;
        case FAILED:
            notifyCommandStateChanged(ECommand.COMMAND_SEND_FILE, 100, ECommandResult.FAILURE, message);
            break;
        }
    }


    public void setRestartingDroneState(IndicatorState state, int progress, String message)
    {
        switch (state) {
        case EMPTY:
            // Left unimplemented
            break;
        case ACTIVE:
            notifyCommandStateChanged(ECommand.COMMAND_RESTART_DRONE, 0, ECommandResult.UNKNOWN, message);
            break;
        case PASSED:
            notifyCommandStateChanged(ECommand.COMMAND_RESTART_DRONE, 100, ECommandResult.SUCCESS, message);
            break;
        case FAILED:
            notifyCommandStateChanged(ECommand.COMMAND_RESTART_DRONE, 100, ECommandResult.FAILURE, message);
            break;
        }
    }


    public void setInstallingState(IndicatorState state, int progress, String message)
    {
        switch (state) {
        case EMPTY:
            // Left unimplemented
            break;
        case ACTIVE:
            notifyCommandStateChanged(ECommand.COMMAND_INSTALL, 0, ECommandResult.UNKNOWN, message);
            break;
        case PASSED:
            notifyCommandStateChanged(ECommand.COMMAND_INSTALL, 100, ECommandResult.SUCCESS, message);
            break;
        case FAILED:
            notifyCommandStateChanged(ECommand.COMMAND_INSTALL, 100, ECommandResult.FAILURE, message);
            break;
        }
    }

    
    private void notifyCommandStateChanged(ECommand command, int progress, ECommandResult result, String message)
    {
        Intent intent = new Intent(UPDATE_SERVICE_STATE_CHANGED_ACTION);
        intent.putExtra(EXT_COMMAND, command);
        intent.putExtra(EXT_COMMAND_PROGRESS, progress);
        
        if (result != null) {
            intent.putExtra(EXT_COMMAND_RESULT, result);
        }
        
        if (message != null) {
            intent.putExtra(EXT_COMMAND_MESSAGE, message);
        }
        
        this.lastIntent = intent;
        
        broadcastManager.sendBroadcast(intent);
    }
    
    
    public class LocalBinder extends Binder 
    {
        public FirmwareUpdateService getService() {
            return FirmwareUpdateService.this;
        }
    }


    public void onFinished()
    {
        running = false;
        stopSelf();
    }
}
