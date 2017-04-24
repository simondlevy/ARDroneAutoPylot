
package com.parrot.freeflight.transcodeservice;

import java.io.File;
import java.util.concurrent.ExecutionException;

import android.app.Service;
import android.content.Intent;
import android.os.AsyncTask.Status;
import android.os.Binder;
import android.os.IBinder;
import android.support.v4.content.LocalBroadcastManager;
import android.util.Log;

import com.parrot.freeflight.tasks.MoveFileTask;
import com.parrot.freeflight.transcodeservice.tasks.CleanupCacheFolderTask;
import com.parrot.freeflight.utils.ARDroneMediaGallery;
import com.parrot.freeflight.utils.FileUtils;

public class TranscodingService extends Service
{
    public static final String NEW_MEDIA_IS_AVAILABLE_ACTION = "transcoding.media.available";
    public static final String EXTRA_MEDIA_PATH = "extra.video.path";

    private static final String TAG = TranscodingService.class.getSimpleName();

    private IBinder binder = new LocalBinder();
    private File videoPath;

    private CleanupCacheFolderTask removeBak;
    private ARDroneMediaGallery mediaGallery;
    private boolean running;
    
    private int refcounter;


    @Override
    public void onCreate()
    {
        super.onCreate();
        
        mediaGallery = new ARDroneMediaGallery(this);
    }


    @Override
    public void onDestroy()
    {
        super.onDestroy();
        
        mediaGallery.onDestroy();
    }
    

    public IBinder onBind(Intent intent)
    {
        return binder;
    }


    @Override
    public int onStartCommand(Intent intent, int flags, int startId)
    {   
        if (intent == null) {
          
            stopSelf(startId);
        } else {
            String videoPathStr = intent.getStringExtra(EXTRA_MEDIA_PATH);
    
            if (running) {
                
                if (running) {
                    Log.w(TAG, "Transcoding already running. Ignoring request.");
                }
                
                return START_STICKY;
            }
            
            if (videoPathStr != null) {
                videoPath = new File(videoPathStr);
                removeTempFiles();
            } else {
                stopSelf(startId);
            }
        }
        return START_STICKY;
    }


    private void removeTempFiles()
    {
        if (removeBak == null || removeBak.getStatus() == Status.FINISHED) {
            removeBak = new CleanupCacheFolderTask() {
                protected void onPostExecute(Boolean result)
                {
                    onTemporaryFilesCleared();
                }
            };

            removeBak.execute(videoPath);
        } else {
            onTemporaryFilesCleared();
        }
    }



    // WARNING: Do not rename this method. It is called from native code.
    protected String getNextFile()
    {
        if (videoPath != null) {
            return FileUtils.getNextFile(videoPath, "enc");
        } else
            return null;
    }

    
    // WARNING: Do not rename this method. It is called from native code.
    public void onMediaReady(String filename)
    {
        File src = new File(filename);
        File dest = null;

        String name = src.getName();
        int lastIndexOf =  name.lastIndexOf(".");
        
        if (lastIndexOf == -1) {
            Log.w(TAG, "OnMediaReady() received but filename looks like broken. Filename: " + filename);
            return;
        }
        
        name = name.substring(0, lastIndexOf);

        String newName = name + ".mp4";

        dest = new File(src.getParentFile().getAbsolutePath(), newName);
       
        if (dest.exists()) {
            Log.w(TAG, "Can't rename file to " + dest.getAbsolutePath() + ". Already exists!");
        } else {
            if (!src.renameTo(dest)) {
                Log.w(TAG, "Can't rename file " + filename + " due to error");
            }
        }
        
        MoveFileTask moveFile = new MoveFileTask() {
            @Override
            protected void onPostExecute(Boolean result)
            {
                if (result.equals(Boolean.TRUE)) {
                    File resultFile = getResultFile();
                    if (resultFile != null) {
                        Log.d(TAG, "Going to add file " + resultFile.getAbsolutePath() + " to media gallery");
                        mediaGallery.insertMedia(resultFile);
                        notifyNewMediaAvailable(resultFile);
                    } else {
                        Log.w(TAG, "File transcoded successfully but getResultFile() returned null. Looks like a bug.");
                    }
                }
            }
        };
        
        File mediaFolder = FileUtils.getMediaFolder(this);
        
        if (mediaFolder != null) {
            try {   
                // Moving file synchronously
                moveFile.execute(dest, new File(mediaFolder, dest.getName())).get();
            } catch (InterruptedException e) {
                e.printStackTrace();
            } catch (ExecutionException e) {
                e.printStackTrace();
            }
        }
    }


    protected void notifyNewMediaAvailable(File dest)
    {
        if (dest != null) {
            Intent mediaAvailableIntent = new Intent(NEW_MEDIA_IS_AVAILABLE_ACTION);
            mediaAvailableIntent.putExtra(EXTRA_MEDIA_PATH, dest.getAbsolutePath());
            LocalBroadcastManager.getInstance(getApplicationContext()).sendBroadcast(mediaAvailableIntent);
        }
    }


    protected void onTemporaryFilesCleared()
    {
        if (!running) {
            Log.d(TAG, "Transcoding started...");
            running = true;
            encoderThreadStart();
        }
    };


    // WARNING: Do not rename this method. It is called from native code.
    protected void onTranscodingFinished()
    {
        Log.d(TAG, "Transcoding stopped.");
        running = false;
        
        stopSelf();
    }

    
    public class LocalBinder extends Binder
    {
        public TranscodingService getService()
        {
            return TranscodingService.this;
        }
    }


    private native void encoderThreadStart();
}
