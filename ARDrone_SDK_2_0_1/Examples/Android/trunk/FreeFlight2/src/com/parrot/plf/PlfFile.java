/*
 * PlfFile
 *
 *  Created on: Aug 30, 2011
 *      Author: Dmytro Baryskyy
 */

package com.parrot.plf;

import java.io.IOException;
import java.io.InputStream;

import android.content.res.AssetManager;
import android.util.Log;

public class PlfFile 
{
	private static final String TAG = "PlfFile";
	
	private String fileName;
	private AssetManager assetManager;
	
	public PlfFile(AssetManager am, String fileName)
	{
		this.fileName = fileName;
		this.assetManager = am;
	}
	
	/**
	 * Returns version of the PLF file
	 * @return version in 1.7.4 format or null if error occurred.
	 */
	public String getVersion()
	{
		return getVersionNative();
	}
	
	
	/*
	 * This method is called from native code.
	 */
	private byte[] getHeader(int size) 
	{
		byte[] result = new byte[size];
		InputStream is = null;
		
		try {
			is = assetManager.open(fileName);
		
			if (is.read(result, 0, result.length) == -1) {
				Log.w(TAG, "End of " + fileName + " is reached.");
			}
			
			return result;
		} catch (IOException e) {
			e.printStackTrace();
		} finally {
			if (is != null) {
				try {
					is.close();
				} catch (IOException e) {
					e.printStackTrace();
				}
			}
		}
		
		return null;
	}
	
	// Implementation can be found in /jni/Stubs/plf_file_stub.c
	private native String getVersionNative();	
}
