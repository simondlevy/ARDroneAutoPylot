package com.parrot.freeflight.remotecontrollers;

import android.R.color;
import android.app.Activity;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.view.KeyEvent;
import android.view.MotionEvent;

import com.sony.rdis.receiver.utility.RdisUtility;
import com.sony.rdis.receiver.utility.RdisUtilityConnectionListener;
import com.sony.rdis.receiver.utility.RdisUtilityEventListener;
import com.sony.rdis.receiver.utility.RdisUtilityGamePad;

public class RemoteManager       
        implements RdisUtilityConnectionListener
{
    private RdisUtility mRdisUtility = null;
    private RdisUtilityEventListener remoteEventListener;
    private SensorEventListener sensorListener;

    public RemoteManager(Activity theActivity)
    {
        initRemoteListener();
        mRdisUtility = new RdisUtility(theActivity, this, null);        
    }
   
    private void initRemoteListener()
    {
        remoteEventListener = new RdisUtilityEventListener()
        {

            @Override
            public boolean onTouchEvent(MotionEvent arg0)
            {
                return false;
            }

            @Override
            public void onSensorChanged(SensorEvent arg0)
            {
                applySensorChanged(arg0);
            }

            @Override
            public boolean onKeyUp(int arg0, KeyEvent arg1)
            {
                return false;
            }

            @Override
            public boolean onKeyDown(int arg0, KeyEvent arg1)
            {
                return false;
            }

            @Override
            public void onAccuracyChanged(Sensor arg0, int arg1)
            {
                applySensorAccuracyChanged(arg0, arg1);
            }
        };
    }
  
    protected void applySensorChanged(SensorEvent arg0)
    {      
        if (this.sensorListener != null) {
            this.sensorListener.onSensorChanged(arg0);
        }
    }

    protected void applySensorAccuracyChanged(Sensor arg0, int arg1)
    {
        if (this.sensorListener != null) {
            this.sensorListener.onAccuracyChanged(arg0, arg1);
        }
    }

    @Override
    public void onConnected(RdisUtilityGamePad gamePad)
    {       
        if (gamePad.isDefaultGamePad() == true) {
            registerGamePad(gamePad, 0);
        }
    }

    @Override
    public void onDisconnected(RdisUtilityGamePad gamePad)
    {      
        if (gamePad.isDefaultGamePad() == true) {
            mRdisUtility.unregisterGamePad(gamePad);
        }
    }

    private void registerGamePad(RdisUtilityGamePad gamePad, int id)
    {
        boolean sensorExist = false;
        int[] sensorArray = gamePad.getSensorType();
        for (int j = 0; j < sensorArray.length; j++) {
            if (sensorArray[j] == Sensor.TYPE_ACCELEROMETER)
                sensorExist = true;
        }
        if (sensorExist == true) {
            int[] acceleSensor = new int[1];
            acceleSensor[0] = Sensor.TYPE_ACCELEROMETER;
            mRdisUtility.registerGamePad(gamePad, this.remoteEventListener, acceleSensor, color.white);
        }
    }

    public void onDestroy()
    {
        mRdisUtility.destroy();        
    }

    public void onPause()
    {
        mRdisUtility.pause();       
    }

    public void onResume()
    {
        mRdisUtility.resume();        
    }

    public void setSensorEventListener(final SensorEventListener theListener)
    {
        this.sensorListener = theListener;
    }
}
