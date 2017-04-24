package com.parrot.freeflight.receivers;

import java.io.File;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

import com.parrot.freeflight.service.DroneControlService;
import com.parrot.freeflight.transcodeservice.TranscodingService;

public class MediaReadyReceiver extends BroadcastReceiver
{
    private MediaReadyDelegate delegate;

    public MediaReadyReceiver(MediaReadyDelegate delegate)
    {
        this.delegate = delegate;
    }
    
    @Override
    public void onReceive(Context context, Intent intent)
    {
        String action = intent.getAction();
        
        if (action.equals(DroneControlService.NEW_MEDIA_IS_AVAILABLE_ACTION) ||
                action.equals(TranscodingService.NEW_MEDIA_IS_AVAILABLE_ACTION)) {
            String path = intent.getStringExtra(DroneControlService.EXTRA_MEDIA_PATH);
            
            if (path == null) {
                path = intent.getStringExtra(TranscodingService.EXTRA_MEDIA_PATH);
            }
            
            if (delegate != null && path != null) {
                delegate.onMediaReady(new File(path));
            } 
        }
    }

}
