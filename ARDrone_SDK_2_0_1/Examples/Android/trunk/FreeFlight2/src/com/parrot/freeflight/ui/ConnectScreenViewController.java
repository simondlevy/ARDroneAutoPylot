/*
 * ConnectScreenViewController
 *
 *  Created on: May 5, 2011
 *      Author: Dmytro Baryskyy
 */

package com.parrot.freeflight.ui;

import java.util.Hashtable;

import android.app.Activity;
import android.content.res.Resources;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.util.Log;
import android.view.View;
import android.widget.ProgressBar;
import android.widget.TextView;

import com.parrot.freeflight.R;

public class ConnectScreenViewController 
{	
	public enum IndicatorState {
		EMPTY,
		ACTIVE,
		PASSED,
		FAILED,
	}
	
	private final static String TAG = "ConnectScreenViewController";
	
	private TextView txtCurrStep;
	private TextView txtStatusMsg; 
	private TextView txtCheckingBootloader;
	private TextView txtSendingFile;
	private TextView txtRestartingDrone;
	private TextView txtInstalling;
	
	private String message;
	private String status;
	
	private ProgressBar progressUpload;
	
	private Hashtable<IndicatorState, BitmapDrawable> stateDrawables;
	private Activity context;
	
	public ConnectScreenViewController(Activity context)
	{
		this.context = context;

		txtStatusMsg          = (TextView) context.findViewById(R.id.txtMessage);
		txtCurrStep			  = (TextView) context.findViewById(R.id.txtCurrStepTitle);
		progressUpload        = (ProgressBar) context.findViewById(R.id.progressBar);
		
		txtCheckingBootloader = (TextView) context.findViewById(R.id.txtCheckingRepairing);
		txtSendingFile        = (TextView) context.findViewById(R.id.txtSendingFile);
		txtRestartingDrone    = (TextView) context.findViewById(R.id.txtRestarting);
		txtInstalling         = (TextView) context.findViewById(R.id.txtInstalling);
		
		stateDrawables = new Hashtable<ConnectScreenViewController.IndicatorState, BitmapDrawable>();
		
		Resources resources = context.getResources();
		stateDrawables.put(IndicatorState.EMPTY, (BitmapDrawable)resources.getDrawable(R.drawable.ff2_updater_empty));
		stateDrawables.put(IndicatorState.ACTIVE, (BitmapDrawable)resources.getDrawable(R.drawable.ff2_updater_in_progress));
		stateDrawables.put(IndicatorState.PASSED, (BitmapDrawable)resources.getDrawable(R.drawable.ff2_updater_ok));
		stateDrawables.put(IndicatorState.FAILED, (BitmapDrawable)resources.getDrawable(R.drawable.ff2_updater_ko));
		
		initActionBar();
	}
	
    
    private void initActionBar()
    {
        final View actionBarView = context.findViewById(R.id.actionBar);

        ActionBar actionBar = new ActionBar(context, actionBarView);
        actionBar.initTitle(context.getString(R.string.AR_DRONE_UPDATE));
        actionBar.initHomeButton();
    }


	public void setMessage(final String message)
	{	
		this.message = message;
		
		updateStatusMessage();
	}
	
	
	private void updateStatusMessage()
	{
		Runnable runnable = new Runnable() {
			public void run() {
				String statusMessage = "";

				if (status != null) {
					statusMessage += status + "\n";
				}

				if (message != null) {
					statusMessage += message;
				}
				
				if (txtStatusMsg != null) {
					txtStatusMsg.setText(statusMessage);
					
					if (message.length() > 0) {
	                    txtStatusMsg.setVisibility(View.VISIBLE);
	                } else {
	                    txtStatusMsg.setVisibility(View.INVISIBLE);
	                }
				} else {
					Log.e(TAG, "Can't set status message. Field is null");
				}
			}
		};
		
		context.runOnUiThread(runnable);
	}
		
	
	public void setCheckingRepairingState(final IndicatorState state)
	{
		setStateOnUiThread(txtCheckingBootloader, state);
	}

	
	public void setSendingFileState(final IndicatorState state)
	{
		setStateOnUiThread(txtSendingFile, state);
	}
	
	
	public void setRestartingDroneState(final IndicatorState state) 
	{
		setStateOnUiThread(txtRestartingDrone, state);
	}
	
	
	public void setInstallingState(final IndicatorState state) 
	{
		setStateOnUiThread(txtInstalling, state);
	}
	

	private void setStateOnUiThread(final TextView textView, final IndicatorState state)
	{
		disableAllStepLabels();
		
		//Drawable drawable = new BitmapDrawable(stateDrawables.get(state).getBitmap());
		Drawable drawable = stateDrawables.get(state);
		if (drawable != null) {
			drawable.setBounds(0,0,drawable.getIntrinsicWidth(),drawable.getIntrinsicHeight());
			textView.setCompoundDrawables(drawable, null, null, null);
		}
		
		textView.setEnabled(true);
	}

	
	public void setProgressVisible(boolean visible)
	{
		setControlVisibleOnUiThread(progressUpload, visible?View.VISIBLE:View.INVISIBLE);
	}
	
	
	public void setProgressMaxValue(int max)
	{
		progressUpload.setMax(max);
	}
	
	
	public void setProgressValue(final int value)
	{
	    progressUpload.setProgress(value);
	}
	
	
	private void setControlVisibleOnUiThread(final View control, final int visibility)
	{
        if (control.getVisibility() != visibility)
			control.setVisibility(visibility);
	}
	

	public void setStatus(final String string) 
	{
		txtCurrStep.setText(string);	
	}
	
	
	private void disableAllStepLabels()
	{
		txtCheckingBootloader.setEnabled(false);
		txtInstalling.setEnabled(false);
		txtRestartingDrone.setEnabled(false);
		txtSendingFile.setEnabled(false);
	}
}
