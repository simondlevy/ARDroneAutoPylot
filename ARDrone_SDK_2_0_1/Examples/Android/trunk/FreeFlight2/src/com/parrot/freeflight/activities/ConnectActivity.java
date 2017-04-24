
package com.parrot.freeflight.activities;

import java.util.Random;

import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.os.Bundle;
import android.os.IBinder;
import android.preference.PreferenceManager;
import android.support.v4.content.LocalBroadcastManager;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.CheckBox;
import android.widget.CompoundButton;
import android.widget.CompoundButton.OnCheckedChangeListener;

import com.parrot.freeflight.R;
import com.parrot.freeflight.activities.base.ParrotActivity;
import com.parrot.freeflight.receivers.DroneConnectionChangeReceiverDelegate;
import com.parrot.freeflight.receivers.DroneConnectionChangedReceiver;
import com.parrot.freeflight.receivers.DroneReadyReceiver;
import com.parrot.freeflight.receivers.DroneReadyReceiverDelegate;
import com.parrot.freeflight.service.DroneControlService;
import com.parrot.freeflight.utils.SystemUtils;

public class ConnectActivity
        extends ParrotActivity
        implements ServiceConnection, DroneReadyReceiverDelegate, DroneConnectionChangeReceiverDelegate
{

    private static final int[] TIPS = {
            R.layout.hint_screen_joypad_mode, R.layout.hint_screen_absolute_control, R.layout.hint_screen_record,
            R.layout.hint_screen_usb, R.layout.hint_screen_switch,
            R.layout.hint_screen_landing, R.layout.hint_screen_take_off, R.layout.hint_screen_emergency,
            R.layout.hint_screen_altitude, R.layout.hint_screen_hovering,
            // R.layout.hint_screen_geolocation,
            R.layout.hint_screen_share, R.layout.hint_screen_flip
    };

    private static final String TAG = ConnectActivity.class.getSimpleName();

    private DroneControlService mService;
    private String AUTO_SKIPP_KEY = "auto_skip";

    private BroadcastReceiver droneReadyReceiver;
    private BroadcastReceiver droneConnectionChangeReceiver;


    @Override
    protected void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);

        Random random = new Random(System.currentTimeMillis());
        int tipNumber = random.nextInt(TIPS.length);
     
        if (!SystemUtils.isGoogleTV(this)) {
            setContentView(TIPS[tipNumber]);
        } else {
            setContentView(R.layout.remote_instructions);
            prepareGoogleTVControls();
        }

        droneReadyReceiver = new DroneReadyReceiver(this);
        droneConnectionChangeReceiver = new DroneConnectionChangedReceiver(this);

        bindService(new Intent(this, DroneControlService.class), this, Context.BIND_AUTO_CREATE);

    }


    private void prepareGoogleTVControls()
    {
        this.findViewById(R.id.loading_view).setVisibility(View.VISIBLE);
        final View skipButton = this.findViewById(R.id.skip_button);
        skipButton.setVisibility(View.GONE);
        this.findViewById(R.id.skip_button).setOnClickListener(new OnClickListener()
        {
            @Override
            public void onClick(View v)
            {
                onOpenHudScreen();
            }
        });

        final CheckBox autoSkipCheck = (CheckBox) this.findViewById(R.id.auto_skip);
        autoSkipCheck.setChecked(getAutoSkip());
        autoSkipCheck.setOnCheckedChangeListener(new OnCheckedChangeListener()
        {
            @Override
            public void onCheckedChanged(CompoundButton buttonView, boolean isChecked)
            {
                ConnectActivity.this.setAutoSkip(isChecked);
            }
        });
    }


    @Override
    protected void onDestroy()
    {
        super.onDestroy();

        unbindService(this);
        Log.d(TAG, "Connect activity destroyed");
    }


    @Override
    protected void onPause()
    {
        super.onPause();

        if (mService != null) {
            mService.pause();
        }

        LocalBroadcastManager manager = LocalBroadcastManager.getInstance(getApplicationContext());
        manager.unregisterReceiver(droneReadyReceiver);
        manager.unregisterReceiver(droneConnectionChangeReceiver);
    }


    @Override
    protected void onResume()
    {
        super.onResume();

        if (mService != null)
            mService.resume();

        LocalBroadcastManager manager = LocalBroadcastManager.getInstance(getApplicationContext());
        manager.registerReceiver(droneReadyReceiver, new IntentFilter(DroneControlService.DRONE_STATE_READY_ACTION));
        manager.registerReceiver(droneConnectionChangeReceiver, new IntentFilter(
                DroneControlService.DRONE_CONNECTION_CHANGED_ACTION));
    }


    public void onServiceConnected(ComponentName name, IBinder service)
    {
        mService = ((DroneControlService.LocalBinder) service).getService();

        mService.resume();
        mService.requestDroneStatus();
    }


    private void onOpenHudScreen()
    {
        Intent droneControlActivity = new Intent(ConnectActivity.this, ControlDroneActivity.class);
        droneControlActivity.putExtra("USE_SOFTWARE_RENDERING", false);
        droneControlActivity.putExtra("FORCE_COMBINED_CONTROL_MODE", false);
        startActivity(droneControlActivity);
    }


    public void onDroneConnected()
    {
        // We still waiting for onDroneReady event
        mService.requestConfigUpdate();
    }


    public void onDroneReady()
    {
        if (!SystemUtils.isGoogleTV(this)) {
            onOpenHudScreen();
        } else {
            final CheckBox autoSkip = (CheckBox) this.findViewById(R.id.auto_skip);
            
            if (autoSkip.isChecked()) {
                onOpenHudScreen();
            }
            
            this.findViewById(R.id.loading_view).setVisibility(View.GONE);
            this.findViewById(R.id.skip_button).setVisibility(View.VISIBLE);
        }
    }


    public void onDroneDisconnected()
    {
        // Left unimplemented
    }


    public void onServiceDisconnected(ComponentName name)
    {
        // Left unimplemented
    }


    protected void setAutoSkip(boolean theSkip)
    {
        PreferenceManager.getDefaultSharedPreferences(this).edit()
                .putBoolean(AUTO_SKIPP_KEY, theSkip)
                .commit();
    }


    protected boolean getAutoSkip()
    {
        return PreferenceManager.getDefaultSharedPreferences(this).getBoolean(AUTO_SKIPP_KEY, false);
    }
}
