package com.parrot.freeflight.transcodeservice.tasks;

import java.io.File;
import java.io.FileFilter;
import java.util.ArrayList;
import java.util.List;

import android.os.AsyncTask;
import android.util.Log;

import com.parrot.freeflight.utils.FileUtils;

public class CleanupCacheFolderTask extends AsyncTask<File, Integer, Boolean>
{

	private static final String TAG = CleanupCacheFolderTask.class.getSimpleName();
	
	private FileFilter bakFileFilter;
	private String[] extentionsToRemove = {"bak", "tmp"};
	
	public CleanupCacheFolderTask()
	{
		bakFileFilter = new FileFilter() 
		{	
			public boolean accept(File pathname) {
				return pathname.isDirectory() || (pathname.isFile() && endsWith(pathname.getName(), extentionsToRemove));
			}
			
			private boolean endsWith(String name, String[] extentions) 
			{
			  for (int i=0; i<extentions.length; ++i) {
			      if (name.endsWith(extentions[i]))
			          return true;
			  }
			  
			  return false;
			}
		};
	}

	@Override
	protected Boolean doInBackground(File... params) 
	{	
		Log.d(TAG, "Removing temporary files...");
		File folder = params[0];
		
		List<File> files = new ArrayList<File>();
    	if (folder.isDirectory()) {
    		FileUtils.getFileList(files, folder, bakFileFilter);
    	}
    	
    	if (files.size() > 0) {
    		int filesSize = files.size();
    
    		for (int i=0; i<filesSize; ++i) {
    			File file = files.get(i);
    			
    			if (file.exists()) {
    				file.delete();
    				
//    				File parent = file.getParentFile();
//    				
//    				if (parent.isDirectory()) {
//    				    // Trying to delete empty dir
//    				    parent.delete();
//    				}
    			}
    			
    			publishProgress(i);
    			
    			if (isCancelled()) {
    				break;
    			}
    		}
    	}
    	
		return Boolean.TRUE;
	}
	
	

}
