/*
 * UpdaterCommandBase
 *
 *  Created on: May 5, 2011
 *      Author: Dmytro Baryskyy
 */

package com.parrot.freeflight.updater.commands;

import android.content.Context;

import com.parrot.freeflight.service.listeners.DroneUpdaterListener.ArDroneToolError;
import com.parrot.freeflight.updater.UpdateManager;
import com.parrot.freeflight.updater.UpdaterCommand;
import com.parrot.freeflight.updater.UpdaterDelegate;

public abstract class UpdaterCommandBase implements UpdaterCommand 
{
	protected UpdateManager context;
	protected String errorMessage;
	protected String status;
	protected ArDroneToolError error;
	protected UpdaterDelegate delegate;
	
	public UpdaterCommandBase(UpdateManager context)
	{
		this.error = ArDroneToolError.E_NONE;
		this.context = context;
		
	    delegate = context.getDelegate();
	}

	
	public String getCommandName() 
	{
		return getClass().getSimpleName();
	}
	
	
	public void executeInternal(Context service)
	{
		context.onPreExecuteCommand(this);
		execute(service);
		context.onPostExecuteCommand(this);
	}
	
	
	public abstract void execute(Context service);
	
	
	public ArDroneToolError getError()
	{
		return error;
	}
	
	
	protected void setError(ArDroneToolError error)
	{
		this.error = error;
	}
	
	
	protected void onUpdate()
	{
		context.notifyOnUpdateListeners(this);
	}
	
	
	protected void sleep(long time)
	{
		try {
			Thread.sleep(time);
		} catch (InterruptedException e) {
			e.printStackTrace();
		}
	}
}
