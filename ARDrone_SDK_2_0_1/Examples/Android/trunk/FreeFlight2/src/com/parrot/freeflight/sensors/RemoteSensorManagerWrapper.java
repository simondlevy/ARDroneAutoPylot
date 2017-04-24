package com.parrot.freeflight.sensors;

import android.app.Activity;
import android.hardware.Sensor;
import android.hardware.SensorEventListener;
import android.os.Handler;

import com.parrot.freeflight.remotecontrollers.RemoteManager;

public class RemoteSensorManagerWrapper
        extends SensorManagerWrapper
{

    private RemoteManager sensorManager;
    
    public RemoteSensorManagerWrapper(final Activity theContext)
    {
        sensorManager = new RemoteManager(theContext);
        setAcceleroAvailable(true);
        setMagnetoAvailable(false);
        setGyroAvailable(false);
    }

    @Override
    public boolean registerListener(SensorEventListener theListener, int theType, Handler handler)
    {
       if(theType == Sensor.TYPE_ACCELEROMETER)
       {         
          sensorManager.setSensorEventListener(theListener);  
          return true;            
       }
       return false;
    }

    @Override
    public void unregisterListener(SensorEventListener theListener)
    {
       //No need to unregister listener
    }
    
    @Override
    public void onResume()
    {
        sensorManager.onResume();
    }
    @Override
    public void onPause()
    {
        sensorManager.onPause();
    }
    
    public void onCreate()
    {
        // Left unimplemented
    }
    
    @Override
    public void onDestroy()
    {
        sensorManager.onDestroy();
    }
}
