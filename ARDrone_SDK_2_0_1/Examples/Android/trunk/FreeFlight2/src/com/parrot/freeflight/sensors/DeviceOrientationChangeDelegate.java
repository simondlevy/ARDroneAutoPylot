package com.parrot.freeflight.sensors;

public interface DeviceOrientationChangeDelegate
{
    public void onDeviceOrientationChanged(float[] orientation, float magneticHeading, int magnetoAccuracy);
}
