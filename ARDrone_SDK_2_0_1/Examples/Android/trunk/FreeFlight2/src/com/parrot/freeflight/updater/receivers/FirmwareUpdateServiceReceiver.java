package com.parrot.freeflight.updater.receivers;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;

import com.parrot.freeflight.updater.FirmwareUpdateService;
import com.parrot.freeflight.updater.FirmwareUpdateService.ECommand;
import com.parrot.freeflight.updater.FirmwareUpdateService.ECommandResult;

public class FirmwareUpdateServiceReceiver extends BroadcastReceiver
{

    private FirmwareUpdateServiceReceiverDelegate delegate;

    public FirmwareUpdateServiceReceiver(FirmwareUpdateServiceReceiverDelegate delegate)
    {
        this.delegate = delegate;
    }

    @Override
    public void onReceive(Context context, Intent intent)
    {
        if (delegate != null) {
            if (intent.getAction().equals(FirmwareUpdateService.UPDATE_SERVICE_STATE_CHANGED_ACTION)) {
                Bundle extras = intent.getExtras(); 
                ECommand command = (ECommand) extras.get(FirmwareUpdateService.EXT_COMMAND);
                ECommandResult result = (ECommandResult) extras.get(FirmwareUpdateService.EXT_COMMAND_RESULT);               
                int progress = extras.getInt(FirmwareUpdateService.EXT_COMMAND_PROGRESS);
                String message = extras.getString(FirmwareUpdateService.EXT_COMMAND_MESSAGE);
                
                delegate.onCommandStateChanged(command, result, progress, message);
            }
        }
    }

}
