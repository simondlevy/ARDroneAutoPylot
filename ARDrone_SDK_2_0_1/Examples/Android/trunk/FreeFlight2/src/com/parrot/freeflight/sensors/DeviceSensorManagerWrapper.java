package com.parrot.freeflight.sensors;

import java.util.List;

import android.content.Context;
import android.hardware.Sensor;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.Build;
import android.os.Handler;
import android.util.Log;

public class DeviceSensorManagerWrapper
        extends SensorManagerWrapper
{
    private static final String TAG = DeviceSensorManagerWrapper.class.getSimpleName();
    private SensorManager sensorManager;

    public DeviceSensorManagerWrapper(final Context theContext)
    {
        sensorManager = (SensorManager) theContext.getSystemService(Context.SENSOR_SERVICE);
        checkSensors(sensorManager);
    }

    private void checkSensors(SensorManager sensorManager)
    {
        List<Sensor> availableSensors = sensorManager.getSensorList(Sensor.TYPE_ALL);

        Log.i(TAG, "Available sensors: " + getAvailableSensorsAsString(availableSensors));

        for (int i = 0; i < availableSensors.size(); ++i) {
            Sensor sensor = availableSensors.get(i);

            if (sensor.getType() == Sensor.TYPE_ACCELEROMETER) {
                setAcceleroAvailable(true);
            } else if (sensor.getType() == Sensor.TYPE_MAGNETIC_FIELD) {

                if (Build.BRAND.equalsIgnoreCase("nook")) {
                    // This is workaround for Nook Tablet.
                    // It is needed because system returns magnetic sensor, but
                    // because Nook Tabled doesn't have hardware magnetometer it
                    // doestn't work
                    setMagnetoAvailable(false);
                } else {
                    setMagnetoAvailable(true);
                }
            } else if (sensor.getType() == Sensor.TYPE_GYROSCOPE && Build.VERSION.SDK_INT > 8) {
                // We use method from the android 9 in the onGyrochanged, so we
                // need to ignore gyroscope for android <= 8
                setGyroAvailable(true);
            }
        }
    }

    @Override
    public boolean registerListener(SensorEventListener theListener, int theType, Handler handler)
    {
        Sensor sensor = sensorManager.getDefaultSensor(theType);
        if (sensor != null) {
            // Do not use SENSOR_DELAY_FASTEST here. This will cause problems on Nexus devices
        	sensorManager.registerListener(theListener, sensor, SensorManager.SENSOR_DELAY_GAME, handler);
            return true;
        }
        return false;
    }

    @Override
    public void unregisterListener(SensorEventListener theListener)
    {
        this.sensorManager.unregisterListener(theListener);
    }

    private String getAvailableSensorsAsString(List<Sensor> availableSensors)
    {
        String sensors = "";

        for (int i = 0; i < availableSensors.size(); ++i) {
            Sensor sensor = availableSensors.get(i);
            sensors += sensor.getName() + "(" + sensor.getVendor() + ", " + sensor.getVersion() + "), ";
        }

        return sensors;
    }

    @Override
    public void onCreate()
    {}
    
    @Override
    public void onDestroy()
    {}

    @Override
    public void onPause()
    {}

    @Override
    public void onResume()
    {}
}
