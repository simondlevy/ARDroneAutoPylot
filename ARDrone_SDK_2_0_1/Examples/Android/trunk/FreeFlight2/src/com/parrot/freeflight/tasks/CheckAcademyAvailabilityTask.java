
package com.parrot.freeflight.tasks;

import java.io.IOException;

import org.apache.http.client.ClientProtocolException;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.impl.client.DefaultHttpClient;

import android.content.Context;
import android.os.AsyncTask;
import android.util.Log;

import com.parrot.freeflight.R;

public class CheckAcademyAvailabilityTask extends AsyncTask<Context, Integer, Boolean>
{
    private static final String TAG = CheckAcademyAvailabilityTask.class.getSimpleName();
    private HttpGet requestForTest;
    

    @Override
    protected Boolean doInBackground(Context... params)
    {
        if (params.length == 0) { throw new IllegalStateException(
                "Context should be passed to CheckAcademyAvailability task"); }

        String url = params[0].getString(R.string.url_aa_register);

        boolean result = false;

        requestForTest = new HttpGet(url);

        try {
            DefaultHttpClient client = new DefaultHttpClient();
            client.execute(requestForTest);
            result = true;
        } catch (ClientProtocolException e) {
            Log.w(TAG, e.toString());
        } catch (IOException e) {
            Log.w(TAG, e.toString());
        } finally {
            requestForTest = null;
        }

        if (isCancelled()) {
            Log.d(TAG, "Check for academy availability has been canceled.");
        }
        
        return isCancelled()?false:result;
    }
   
    
    public void cancel()
    {      
        cancel(true);
        
        if (requestForTest != null) {
            requestForTest.abort();
        }
    }
}
