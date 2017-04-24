/*
 * UpdateManager
 *
 *  Created on: May 5, 2011
 *      Author: Dmytro Baryskyy
 */

package com.parrot.freeflight.updater;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.Map;
import java.util.Queue;

import org.xmlpull.v1.XmlPullParserException;

import android.content.Context;
import android.util.Log;

import com.parrot.freeflight.service.listeners.DroneUpdaterListener;
import com.parrot.freeflight.updater.UpdaterCommand.UpdaterCommandId;
import com.parrot.freeflight.updater.commands.UpdaterCheckBootloaderCommand;
import com.parrot.freeflight.updater.commands.UpdaterConnectCommand;
import com.parrot.freeflight.updater.commands.UpdaterInstallCommand;
import com.parrot.freeflight.updater.commands.UpdaterRepairBootloaderCommand;
import com.parrot.freeflight.updater.commands.UpdaterRestartDroneCommand;
import com.parrot.freeflight.updater.commands.UpdaterUploadFirmwareCommand;
import com.parrot.freeflight.updater.utils.FirmwareConfig;
import com.parrot.freeflight.utils.CacheUtils;
import com.parrot.freeflight.utils.FtpDelegate;
import com.parrot.ftp.FTPClient;

public final class UpdateManager implements Runnable
{
	private static final String TAG = "UpdateManager";

	private ArrayList<DroneUpdaterListener> listeners;
	private Map<UpdaterCommandId, UpdaterCommand> commands;
	
	private Queue<UpdaterCommand> cmdQueue;
	private Thread workerThread;
	private Thread downloadFileThread;
	private boolean stopThreads;
	private FirmwareConfig firmwareConfig;
	private String fimrmwareVersion;
	private String droneSsid;
	
	private FTPClient ftpClient;

	private Context context;
	private UpdaterDelegate delegate;

	
	public UpdateManager(Context context, UpdaterDelegate delegate)
	{
	    this.context = context;
        this.delegate = delegate;
        
        try {
            firmwareConfig = new FirmwareConfig(context, "firmware");
        } catch (IOException e) {
            e.printStackTrace();
        } catch (XmlPullParserException e) {
            e.printStackTrace();
        }
        
        listeners = new ArrayList<DroneUpdaterListener>();
        cmdQueue = new LinkedList<UpdaterCommand>();
        
        int commandsCount = UpdaterCommandId.values().length;
        commands = new HashMap<UpdaterCommand.UpdaterCommandId, UpdaterCommand>(commandsCount);
        commands.put(UpdaterCommandId.CONNECT,             new UpdaterConnectCommand          (this));
        commands.put(UpdaterCommandId.CHECK_BOOT_LOADER,   new UpdaterCheckBootloaderCommand  (this));
        commands.put(UpdaterCommandId.REPAIR_BOOTLOADER,   new UpdaterRepairBootloaderCommand (this));
        commands.put(UpdaterCommandId.UPLOAD_FIRMWARE,     new UpdaterUploadFirmwareCommand   (this));
        commands.put(UpdaterCommandId.RESTART_DRONE,       new UpdaterRestartDroneCommand     (this) );
        commands.put(UpdaterCommandId.INSTALL,             new UpdaterInstallCommand          (this));
        
        ftpClient = null;
	}
	
	
	public void start()
	{
	    if (!isInProgress()) {
	        workerThread = new Thread(this, "Updater Worker Thread");
	        workerThread.start();
	        UpdaterCommand cmd = commands.get(UpdaterCommandId.CONNECT);
	        startCommand(cmd);
	    } else {
	        Log.w(TAG, "Updater already in progress. Start skipped");
	    }
	}
	
	
	public void stop()
	{
		stopThreads = true;

		try {
			synchronized (cmdQueue) {
				cmdQueue.notify();
			}
		
			cancelAnyFtpOperation();
			
			if (workerThread != null) {
			    workerThread.join();
			}
		} catch (InterruptedException e) {
			e.printStackTrace();
		}
	}
	
	
	public void onPreExecuteCommand(UpdaterCommand command)
	{
		Log.d(TAG, "State " + command.getCommandName());
		
		notifyOnPreExecuteListeners(command);
	}
	
	
	public void onPostExecuteCommand(UpdaterCommand command)
	{
		Log.d(TAG, "State " + command.getCommandName() + " has finished.");
		
		notifyOnPostExecuteListeners(command, listeners);
		
		UpdaterCommandId nextCmdId = command.getNextCommandId();
	
		if (nextCmdId != null) {
			UpdaterCommand cmd = commands.get(nextCmdId);
			startCommand(cmd);
		} else {
			stopThreads = true;
		}
	}
	
	
	public void onUpdate(UpdaterCommand command)
	{
		notifyOnUpdateListeners(command);
	}
	

	public FirmwareConfig getFirmwareConfig()
	{
		return firmwareConfig;
	}
	
	
	public void setDroneFirmwareVersion(String firmwareVersion)
	{
		this.fimrmwareVersion = firmwareVersion.trim();
	}
	
	
	public String getDroneFirmwareVersion()
	{
		return this.fimrmwareVersion;
	}
	
	
	public void addListener(final DroneUpdaterListener listener) 
	{
		Runnable runnable = new Runnable() {
			public void run() {
				synchronized (listeners) {
					if (!listeners.contains(listener))
						listeners.add(listener);
				}
			}
		};

		(new Thread(runnable)).start();
	}


	public void removeListener(final DroneUpdaterListener listener) 
	{
		Runnable runnable = new Runnable() {
			public void run() {
				synchronized (listeners) {
					listeners.remove(listener);	
				}
			}
		};
		
		(new Thread(runnable)).start();
	}
	
	
	public void notifyOnPreExecuteListeners(final UpdaterCommand command) 
	{
	 	if (listeners != null) {
			 synchronized (listeners) {
				for (DroneUpdaterListener listener:listeners) {
					if (listener != null) {
						listener.onPreCommandExecute(command);
					}
				}
			}
	 	}
	}
	
	
	public void notifyOnUpdateListeners(UpdaterCommand command) 
	{
	 	if (listeners != null) {
			 synchronized (listeners) {
				for (DroneUpdaterListener listener:listeners) {
					if (listener != null) {
						listener.onUpdateCommand(command);
					}
				}
			}
	 	}
	}
	
	
	public void notifyOnPostExecuteListeners(final UpdaterCommand command, final ArrayList<DroneUpdaterListener> listeners) 
	{
		if (listeners != null) {
			synchronized (listeners) {
				for (DroneUpdaterListener listener:listeners) {
					if (listener != null) {
						listener.onPostCommandExecute(command);
					}
				}
			}
		}
	}


	public void startCommand(UpdaterCommand cmd)
	{
		synchronized (cmdQueue) {
			cmdQueue.add(cmd);
			cmdQueue.notify();
		}
		
	}
	
	public void run() 
	{	
		while (!stopThreads) {

			synchronized (cmdQueue) {
				try {
					if (cmdQueue.isEmpty() && !stopThreads) {
						cmdQueue.wait();
					}
				} catch (InterruptedException e) {
					e.printStackTrace();
				}
			}
			
			if (stopThreads)
				return;
			
			UpdaterCommand cmd = cmdQueue.poll();
			cmd.executeInternal(context);
		}	
		
		if (delegate != null) {
		    delegate.onFinished();
		}
	}

	
	public void setDroneNetworkSSID(String ssid) 
	{
		this.droneSsid = ssid;
	}
	
	
	public String getDroneNetworkSSID()
	{
		return droneSsid;
	}


	public boolean isShuttingDown() 
	{
		return stopThreads;
	}


	public void downloadFileAsync(final Context service, final String host, final int ftpPort,
			final String remote, final FtpDelegate delegate) 
	{
		Runnable runnable = new Runnable() {
			public void run() {
				File tempFile = null;
				String content = null;
				
				try {
					ftpClient = new FTPClient();
					
					if (!ftpClient.connect(host, ftpPort)) {
						Log.w(TAG, "downloadFile failed. Can't connect");
						return;
					}
					
					tempFile = CacheUtils.createTempFile(context);
					
					if (tempFile == null) {
						Log.w(TAG, "downloadFile failed. Can't connect");
						return;
					}
						
					if (!ftpClient.getSync(remote, tempFile.getAbsolutePath())) {
						return;
					}
					
					if (!tempFile.exists()) {
						return;
					}
					
					StringBuffer stringBuffer = CacheUtils.readFromFile(tempFile);
					
					content = stringBuffer!=null?stringBuffer.toString():null;
				} finally {
					if (tempFile != null && tempFile.exists()) {
						if (!tempFile.delete()) {
							Log.w(TAG, "Can't delete temp file " + tempFile.getAbsolutePath());
						}
					}
					
					if (ftpClient != null && ftpClient.isConnected()) {
						ftpClient.disconnect();
						ftpClient = null;
					}
							
					if (content != null)
						delegate.ftpOperationSuccess(content);
					else 
						delegate.ftpOperationFailure();
				}	
			};
		};

		if (downloadFileThread != null) {
			cancelAnyFtpOperation();
			
			try {
				downloadFileThread.join();
			} catch (InterruptedException e) {
				e.printStackTrace();
			}
		}
		
		downloadFileThread = new Thread(runnable);
		downloadFileThread.start();
	}
	
	
	private void cancelAnyFtpOperation()
	{
		if (ftpClient != null) {
			ftpClient.abort();
			
			try {
				Thread.sleep(500);
			} catch (InterruptedException e) {
				e.printStackTrace();
			}
			
			ftpClient.disconnect();
			ftpClient = null;
		}
 	}

	
	public UpdaterDelegate getDelegate()
	{
	    return delegate;
	}
	
	public Context getContext()
	{
		return context;
	}


    public boolean isInProgress()
    {
        return workerThread != null && workerThread.isAlive();
    }
}
