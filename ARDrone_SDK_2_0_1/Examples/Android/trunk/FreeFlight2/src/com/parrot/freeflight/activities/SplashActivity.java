/*
 * SplashActivity
 *
 *  Created on: May 5, 2011
 *      Author: Dmytro Baryskyy
 */

package com.parrot.freeflight.activities;

import android.annotation.SuppressLint;
import android.content.Intent;
import android.media.CamcorderProfile;
import android.media.MediaCodecInfo;
import android.media.MediaCodecList;
import android.media.MediaPlayer;
import android.media.MediaPlayer.OnCompletionListener;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.util.Log;
import android.view.MotionEvent;
import android.view.View;
import android.view.View.OnTouchListener;
import android.view.Window;
import android.view.WindowManager;
import android.widget.LinearLayout;
import android.widget.VideoView;

import com.parrot.freeflight.R;
import com.parrot.freeflight.activities.base.ParrotActivity;
import com.parrot.freeflight.utils.DeviceCapabilitiesUtils;

public class SplashActivity
        extends ParrotActivity
        implements Runnable
{
    public static final int SPLASH_TIME = 4000;
    public final static String VIDEO_FILE_NAME = "arfreeflight";
    
    private static final String TAG = SplashActivity.class.getSimpleName();

    protected boolean playIntro = false;

    private Thread thread;
    private boolean isActive;
    private int timeElapsed = 0;
    private LinearLayout splashBackgroundView;
    private View videoContainer;
    private VideoView videoView;


    @Override
    protected void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        
        if (isFinishing()) {
            return;
        }

        // Requesting full screen without title
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().setFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN, WindowManager.LayoutParams.FLAG_FULLSCREEN);

        setContentView(R.layout.splash_screen);
        
        videoContainer = (View) findViewById(R.id.videoContainer);
        videoView = (VideoView) findViewById(R.id.videoView);
        if (videoView != null) {
            if (rawResourceExists(VIDEO_FILE_NAME)) {
                playIntro = true;
                Uri video = Uri.parse("android.resource://" + getPackageName() + "/raw/" + VIDEO_FILE_NAME);
                videoView.setVideoURI(video);
            } else {
                playIntro = false;
            }
        }
        splashBackgroundView = (LinearLayout) findViewById(R.id.splash);

        isActive = true;
        thread = new Thread(this);
        thread.start();
        
        DeviceCapabilitiesUtils.dumpScreenSizeInDips(this);
    }
    
    @SuppressLint("NewApi")
    private void dumpVideoCapabilitiesInfo()
    {
        // Here we try to use different methods to determine the maximum video frame size
        // that device supports
        
        Log.i(TAG, "=== DEVICE VIDEO SUPPORT ====>>>>>>>>>");
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN) {
            Log.i(TAG, "Codecs available to the system: ");
            for (int i=0; i<MediaCodecList.getCodecCount(); ++i) {
                MediaCodecInfo info = MediaCodecList.getCodecInfoAt(i);

                String[] supportedTypes = info.getSupportedTypes();
                StringBuilder supportedTypesBuilder = new StringBuilder();
                
                for (int j=0; j<supportedTypes.length; ++j) {
                    supportedTypesBuilder.append(supportedTypes[j]);
                    if (j<(supportedTypes.length - 1)) {
                        supportedTypesBuilder.append(", ");
                    }
                }
                
                Log.i(TAG, info.getName() + " , supported types: " + supportedTypesBuilder.toString());;
            }
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB) {
            if (CamcorderProfile.hasProfile(CamcorderProfile.QUALITY_720P)) { 
                Log.i(TAG, "Device supports HD video [720p]");
            } else if (CamcorderProfile.hasProfile(CamcorderProfile.QUALITY_480P)){
                Log.i(TAG, "Device supports regular video [480p]");
            } else if (CamcorderProfile.hasProfile(CamcorderProfile.QUALITY_QVGA)) {
                Log.i(TAG, "Device supports low quality video [240p]");
            } else {
                Log.w(TAG, "Can't determine video support of this device.");
            }
        }
        
        CamcorderProfile prof = CamcorderProfile.get(CamcorderProfile.QUALITY_HIGH);
        if (prof != null) {
            Log.i(TAG, "Highest video frame size for this device is [" + prof.videoFrameWidth + ", " + prof.videoFrameHeight + "]");
        } else {
            Log.w(TAG, "Unable to determine highest possible video frame size.");
        }
        
        Log.i(TAG, "<<<<<<<<<=== DEVICE VIDEO SUPPORT ===");
    }

    
    @Override
    public boolean onTouchEvent(MotionEvent event)
    {
        if (event.getAction() == MotionEvent.ACTION_UP) {
            isActive = false;
            return true;
        }

        return super.onTouchEvent(event);
    }

    @Override
    protected void onDestroy()
    {
        stopThreadAndJoin();

        super.onDestroy();
    }

    @Override
    protected void onPause()
    {
        super.onPause();
        stopThreadAndJoin();
    }
    
    
    @Override
    protected void onResume()
    {
        super.onResume();
        dumpVideoCapabilitiesInfo();
    }

    public void run()
    {
        try {
            while (isActive && (timeElapsed < SPLASH_TIME)) {
                Thread.sleep(100);

                if (isActive) {
                    timeElapsed += 100;
                }
            }
        } catch (InterruptedException e) {
            // do nothing
        } finally {
            if (playIntro) {
                playIntro();
            } else {
                proceedToNextActivity();
            }
        }
    }

    private void stopThreadAndJoin()
    {
        isActive = false;

        try {
            if (thread != null) {
                thread.join();
            }

        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }

    private void playIntro()
    {
        runOnUiThread(new Runnable()
        {
            public void run()
            {
                splashBackgroundView.setVisibility(View.GONE);
                videoContainer.setVisibility(View.VISIBLE);

                videoView.setOnTouchListener(new OnTouchListener()
                {

                    public boolean onTouch(View v, MotionEvent event)
                    {
                        videoView.stopPlayback();
                        videoView.setEnabled(false);
                        videoContainer.setVisibility(View.GONE);

                        startActivity(new Intent(SplashActivity.this, ConnectActivity.class));
                        finish();

                        return true;
                    }
                });

                videoView.setOnCompletionListener(new OnCompletionListener()
                {

                    public void onCompletion(MediaPlayer mp)
                    {
                        proceedToNextActivity();
                    }

                });

                videoView.start();
            }
        });
    }

    private void proceedToNextActivity()
    {
        if (videoContainer != null) {
            videoContainer.setVisibility(View.GONE);
        }

        Intent dashboard = new Intent(SplashActivity.this, DashboardActivity.class);
        startActivity(dashboard);
    }
    private boolean rawResourceExists(String theName)
    {
        int resId = this.getResources().getIdentifier("arfreeflight", "raw", this.getPackageName());
        return resId != 0;
    }
}
