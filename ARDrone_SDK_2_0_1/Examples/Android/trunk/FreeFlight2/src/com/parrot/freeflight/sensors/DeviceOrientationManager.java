package com.parrot.freeflight.sensors;

import java.util.List;
import java.util.Timer;
import java.util.TimerTask;

import android.annotation.TargetApi;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.Handler;
import android.os.Looper;
import android.util.FloatMath;
import android.util.Log;

public class DeviceOrientationManager
implements Runnable
{
    private static final String TAG = DeviceOrientationManager.class.getSimpleName();
    
    private static final float HPF_COEFFICIENT = 0.98f;
    private static final float EPSILON = 0.000000001f;
    private static final float NS2S = 1.0f / 1000000000.0f;
     
    private DeviceOrientationChangeDelegate delegate;
    
    private SensorManagerWrapper sensorManager; 
    private SensorEventListener acceleroEventListener;
    private SensorEventListener magnetoEventListener;
    private SensorEventListener gyroEventListener;
    
    private Thread workerThread;
    private Handler sensorHandler;
    
    private Timer fuseTimer;
    
    private boolean acceleroAvailable;
    private boolean magnetoAvailable;
    private boolean gyroAvailable;
    private boolean initState = true;
    
    private float[] acceleroValues;
    private float[] gyroValues;
    private float[] magnetoValues;
    
    private float magneticHeading;
    private int magnetoAccuracy;
    private float timestamp;
    
    private float[] accMagRotationMatrix;
    private float[] gyroRotationMatrix;
    
    private float[] gyroOrientation;
    private float[] accMagOrientation;
    private float[] fusedOrientation;

    private boolean paused;


    public DeviceOrientationManager(SensorManagerWrapper theSensorManager, DeviceOrientationChangeDelegate delegate)
    {
        this.delegate = delegate;
        
        accMagRotationMatrix = new float[16];
        
        gyroOrientation = new float[3];
        gyroOrientation[0] = 0.0f;
        gyroOrientation[1] = 0.0f;
        gyroOrientation[2] = 0.0f;

        gyroRotationMatrix = new float[9];

        // initialise gyroMatrix with identity matrix
        gyroRotationMatrix[0] = 1.0f;
        gyroRotationMatrix[1] = 0.0f;
        gyroRotationMatrix[2] = 0.0f;
        gyroRotationMatrix[3] = 0.0f;
        gyroRotationMatrix[4] = 1.0f;
        gyroRotationMatrix[5] = 0.0f;
        gyroRotationMatrix[6] = 0.0f;
        gyroRotationMatrix[7] = 0.0f;
        gyroRotationMatrix[8] = 1.0f;
        
        sensorManager = theSensorManager;
        checkSensors(sensorManager);
    }

    
    public void resume()
    {
        resume(true, true); 
    }
    
    public void onCreate()
    {
        sensorManager.onCreate();    
    }
    
    
    public void resume(boolean useMagneto, boolean useGyro)
    {
        this.sensorManager.onResume();

        if (magnetoAvailable) magnetoAvailable = useMagneto;
        if (gyroAvailable) gyroAvailable = useGyro;
        
        if (workerThread != null) {
            throw new RuntimeException("Sensor thread already started");
        }
        
        workerThread = new Thread(this, "Sensor Data Processing Thread");
        workerThread.start();
        
        paused = false;

        Log.d(TAG, "Device Orientation Manager has been resumed");
    }
    
    
    public void pause()
    {       
        this.sensorManager.onPause();
        paused = true;
        
        if (workerThread != null) {
            try {                
                sensorHandler.getLooper().quit();
                workerThread.join();
            } catch (InterruptedException e) {
                e.printStackTrace();
            } finally {
                workerThread = null;
            }
        }
        
        Log.d(TAG, "Device Orientation Manager has been paused");
    }
    
    public void destroy()
    {
        this.sensorManager.onDestroy();

    }
    
    public boolean isMagnetoAvailable()
    {
        return magnetoAvailable;
    }
    
    
    public boolean isGyroAvailable()
    {
        return gyroAvailable;
    }
    
    
    public boolean isAcceleroAvailable()
    {
        return acceleroAvailable;
    }
    
    
    private void checkSensors(SensorManagerWrapper sensorManager)
    {
        this.acceleroAvailable = sensorManager.isAcceleroAvailable();
        this.gyroAvailable = sensorManager.isGyroAvailable();
        this.magnetoAvailable = sensorManager.isMagnetoAvailable();
    }
    

    private void initSensorListeners()
    {
        acceleroEventListener = new SensorEventListener() {
            
            public void onSensorChanged(SensorEvent event)
            {
                if (event.sensor.getType() == Sensor.TYPE_ACCELEROMETER) {
                    onAcceleroChanged(event);
                }
            }
            
            public void onAccuracyChanged(Sensor sensor, int accuracy)
            {}
        };
        
        magnetoEventListener = new SensorEventListener()
        {
            public void onSensorChanged(SensorEvent event)
            {
                if (event.sensor.getType() == Sensor.TYPE_MAGNETIC_FIELD) {
                    onMagnetoChanged(event);                
                }
            }
            
            public void onAccuracyChanged(Sensor sensor, int accuracy)
            {}            
        };       
        
       gyroEventListener = new SensorEventListener() {
            
            public void onSensorChanged(SensorEvent event)
            {
                if (event.sensor.getType() == Sensor.TYPE_GYROSCOPE) {
                    onGyroChanged(event);    
                }
            }
            
            public void onAccuracyChanged(Sensor sensor, int accuracy)
            {}
        };
    }
    
    
    private void registerSensorListeners()
    {
        initSensorListeners();

        if (sensorManager.isAcceleroAvailable() && 
                sensorManager.registerListener(acceleroEventListener, Sensor.TYPE_ACCELEROMETER, sensorHandler)) {
            Log.d(TAG, "Accelerometer [OK]");
        }

        if (sensorManager.isMagnetoAvailable() && 
                sensorManager.registerListener(magnetoEventListener, Sensor.TYPE_MAGNETIC_FIELD, sensorHandler)) {
            Log.d(TAG, "Magnetometer [OK]");
        }

        if (sensorManager.isGyroAvailable() && 
                sensorManager.registerListener(gyroEventListener, Sensor.TYPE_GYROSCOPE, sensorHandler)) {
            initState = true;

            fuseTimer = new Timer();
            fuseTimer.scheduleAtFixedRate(new CalculateFusedOrientationTask(), 1000, 30);
            Log.d(TAG, "Gyroscope [OK]");
        }
    }
    
    
    private void unregisterSensorListeners()
    {
        sensorManager.unregisterListener(acceleroEventListener);
        sensorManager.unregisterListener(magnetoEventListener);
        sensorManager.unregisterListener(gyroEventListener);
       
        if (fuseTimer != null) {
            fuseTimer.cancel();
        }
    }
    

    protected void onAcceleroChanged(SensorEvent event)
    {
        if (acceleroValues == null) {
            acceleroValues = new float[3];
        }

        System.arraycopy(event.values, 0, acceleroValues, 0, 3);
        
        computeAccMagOrientation();
        
        if (!gyroAvailable && delegate != null && accMagOrientation != null) {
            delegate.onDeviceOrientationChanged(accMagOrientation, magneticHeading, magnetoAccuracy);
        }
    }

    
    protected void onMagnetoChanged(SensorEvent event)
    {
        if (magnetoValues == null) {
            magnetoValues = new float[3];
        }

        System.arraycopy(event.values, 0, magnetoValues, 0, 3);
        magnetoAccuracy = event.accuracy;
    }
    
    private static float[] tempGyroMatrix;
    private static float[] deltaVector = new float[4];
    private static float[] deltaMatrix = new float[9];
    
    @TargetApi(9)
    protected void onGyroChanged(SensorEvent event)
    {
        // don't start until first accelerometer/magnetometer orientation has
        // been acquired
        if (acceleroValues == null || magnetoValues == null)
            return;

        // initialisation of the gyroscope based rotation matrix
        if (initState) {
            float[] initMatrix = null;
            initMatrix = getRotationMatrixFromOrientation(magnetoValues);
            float[] tempGyroMatrix = new float[9];
            gyroRotationMatrix = matrixMultiplication(tempGyroMatrix, gyroRotationMatrix, initMatrix);
            initState = false;
        }

        // copy the new gyro values into the gyro array
        // convert the raw gyro data into a rotation vector
        if (timestamp != 0) {
            if (gyroValues == null) {
                gyroValues = new float[3];
            }
            
            final float dT = (event.timestamp - timestamp) * NS2S;
            System.arraycopy(event.values, 0, gyroValues, 0, 3);
            getRotationVectorFromGyro(gyroValues, deltaVector, dT / 2.0f);
        }

        // measurement done, save current time for next interval
        timestamp = event.timestamp;

        
        // convert rotation vector into rotation matrix
        SensorManager.getRotationMatrixFromVector(deltaMatrix, deltaVector);

        // apply the new rotation interval on the gyroscope based rotation
        // matrix
        if (tempGyroMatrix == null)
            tempGyroMatrix = new float[9];
        
        gyroRotationMatrix = matrixMultiplication(tempGyroMatrix, gyroRotationMatrix, deltaMatrix);

        // get the gyroscope based orientation from the rotation matrix
        SensorManager.getOrientation(gyroRotationMatrix, gyroOrientation);
    }
    
 
    static float[] xM = new float[9];
    static float[] yM = new float[9];
    static float[] zM = new float[9];
    static float[] resultMatrix = new float[9];
    static float[] resultMatrix2 = new float[9];
  
    private float[] getRotationMatrixFromOrientation(float[] o)
    {
        float sinX = FloatMath.sin(o[1]);
        float cosX = FloatMath.cos(o[1]);
        float sinY = FloatMath.sin(o[2]);
        float cosY = FloatMath.cos(o[2]);
        float sinZ = FloatMath.sin(o[0]);
        float cosZ = FloatMath.cos(o[0]);
       
        // rotation about x-axis (pitch)
        xM[0] = 1.0f;
        xM[1] = 0.0f;
        xM[2] = 0.0f;
        xM[3] = 0.0f;
        xM[4] = cosX;
        xM[5] = sinX;
        xM[6] = 0.0f;
        xM[7] = -sinX;
        xM[8] = cosX;

        // rotation about y-axis (roll)
        yM[0] = cosY;
        yM[1] = 0.0f;
        yM[2] = sinY;
        yM[3] = 0.0f;
        yM[4] = 1.0f;
        yM[5] = 0.0f;
        yM[6] = -sinY;
        yM[7] = 0.0f;
        yM[8] = cosY;
         
        // rotation about z-axis (azimuth)
        zM[0] = cosZ;
        zM[1] = sinZ;
        zM[2] = 0.0f;
        zM[3] = -sinZ;
        zM[4] = cosZ;
        zM[5] = 0.0f;
        zM[6] = 0.0f;
        zM[7] = 0.0f;
        zM[8] = 1.0f;
        
        // rotation order is y, x, z (roll, pitch, azimuth)
        matrixMultiplication(resultMatrix2, xM, yM);
        matrixMultiplication(resultMatrix, zM, resultMatrix2);

        return resultMatrix;
    }
     

    private float[] matrixMultiplication(float[] result, float[] A, float[] B)
    {
        result[0] = A[0] * B[0] + A[1] * B[3] + A[2] * B[6];
        result[1] = A[0] * B[1] + A[1] * B[4] + A[2] * B[7];
        result[2] = A[0] * B[2] + A[1] * B[5] + A[2] * B[8];

        result[3] = A[3] * B[0] + A[4] * B[3] + A[5] * B[6];
        result[4] = A[3] * B[1] + A[4] * B[4] + A[5] * B[7];
        result[5] = A[3] * B[2] + A[4] * B[5] + A[5] * B[8];

        result[6] = A[6] * B[0] + A[7] * B[3] + A[8] * B[6];
        result[7] = A[6] * B[1] + A[7] * B[4] + A[8] * B[7];
        result[8] = A[6] * B[2] + A[7] * B[5] + A[8] * B[8];

        return result;
    }


    private static float[] normValues = new float[3];
    private void getRotationVectorFromGyro(float[] gyroValues, float[] deltaRotationVector, float timeFactor)
    {
        // Calculate the angular speed of the sample
        float omegaMagnitude =
                        FloatMath.sqrt(gyroValues[0] * gyroValues[0] +
                        gyroValues[1] * gyroValues[1] +
                        gyroValues[2] * gyroValues[2]);

        // Normalize the rotation vector if it's big enough to get the axis
        if (omegaMagnitude > EPSILON) {
            normValues[0] = gyroValues[0] / omegaMagnitude;
            normValues[1] = gyroValues[1] / omegaMagnitude;
            normValues[2] = gyroValues[2] / omegaMagnitude;
        }

        // Integrate around this axis with the angular speed by the timestep
        // in order to get a delta rotation from this sample over the timestep
        // We will convert this axis-angle representation of the delta rotation
        // into a quaternion before turning it into the rotation matrix.
        float thetaOverTwo = omegaMagnitude * timeFactor;
        float sinThetaOverTwo = FloatMath.sin(thetaOverTwo);
        float cosThetaOverTwo = FloatMath.cos(thetaOverTwo);
        deltaRotationVector[0] = sinThetaOverTwo * normValues[0];
        deltaRotationVector[1] = sinThetaOverTwo * normValues[1];
        deltaRotationVector[2] = sinThetaOverTwo * normValues[2];
        deltaRotationVector[3] = cosThetaOverTwo;
    }
    
       
    public void computeAccMagOrientation()
    {
        if (acceleroValues != null && magnetoValues != null
                && SensorManager.getRotationMatrix(accMagRotationMatrix, null, acceleroValues, magnetoValues)) {
           
            // Using accelerometer and magnetometer
            if (accMagOrientation == null) {
                accMagOrientation = new float[3];
            }
            
            SensorManager.getOrientation(accMagRotationMatrix, accMagOrientation);
            
            magneticHeading = accMagOrientation[0];
            
            if (accMagOrientation[0] < 0) {
               magneticHeading += Math.PI * 2;
            }
        } else if (acceleroValues != null) {
            
            if (accMagOrientation == null) {
                accMagOrientation = new float[3];
            }
            
            accMagOrientation[2] = (float) Math.atan2(acceleroValues[0],
                    FloatMath.sqrt(acceleroValues[1]*acceleroValues[1]+acceleroValues[2]*acceleroValues[2])) * -1.f;
            accMagOrientation[1] = ((float) Math.atan2(acceleroValues[1],
                    FloatMath.sqrt(acceleroValues[0]*acceleroValues[0]+acceleroValues[2]*acceleroValues[2]))) * -1.f;            
        }
    }
    
    
    private String getAvailableSensorsAsString(List<Sensor> availableSensors)
    {
       String sensors = "";
       
       for (int i=0; i<availableSensors.size(); ++i) {
           Sensor sensor = availableSensors.get(i);
           sensors += sensor.getName() + "("+ sensor.getVendor() +", "+ sensor.getVersion()+ "), ";
       }
       
        return sensors;
    }
    
    
    
    public void run()
    {
        Looper.prepare();
        sensorHandler = new Handler();
        
        registerSensorListeners();
        
        Looper.loop();
        
        unregisterSensorListeners();
        
        sensorHandler = null;
    }
    
   
    class CalculateFusedOrientationTask extends TimerTask
    {

        public void run()
        {
            if (fusedOrientation == null) {
                fusedOrientation = new float[3];
            }

            float oneMinusCoeff = 1.0f - HPF_COEFFICIENT;
           
            if (gyroOrientation != null && accMagOrientation != null) {
                fusedOrientation[0] =
                        HPF_COEFFICIENT * gyroOrientation[0]
                                + oneMinusCoeff * accMagOrientation[0];
    
                fusedOrientation[1] =
                        HPF_COEFFICIENT * gyroOrientation[1]
                                + oneMinusCoeff * accMagOrientation[1];
    
                fusedOrientation[2] =
                        HPF_COEFFICIENT * gyroOrientation[2]
                                + oneMinusCoeff * accMagOrientation[2];
    
                // overwrite gyro matrix and orientation with fused orientation
                // to comensate gyro drift
                gyroRotationMatrix = getRotationMatrixFromOrientation(fusedOrientation);
                System.arraycopy(fusedOrientation, 0, gyroOrientation, 0, 3);
                
                if (delegate != null) {
                    delegate.onDeviceOrientationChanged(fusedOrientation, magneticHeading, magnetoAccuracy);
                }
            }
        }
    }

	public boolean isRunning() {
		return workerThread != null && workerThread.isAlive();
	}
}
