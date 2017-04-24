/*
 * FirmwareConfig
 *
 *  Created on: Sep 1, 2011
 *      Author: Dmytro Baryskyy
 */


package com.parrot.freeflight.updater.utils;

import java.io.IOException;
import java.io.InputStream;

import org.xmlpull.v1.XmlPullParser;
import org.xmlpull.v1.XmlPullParserException;
import org.xmlpull.v1.XmlPullParserFactory;

import android.content.Context;

import com.parrot.plf.PlfFile;

public class FirmwareConfig 
{
	private static final String FIRMWARE_TAG            = "firmware";
	
	private static final String FIRMWARE_FILE_NAME_ATTR = "fileName";
	private static final String FIRMWARE_V2_FILE_NAME_ATTR  = "fileName2";
	private static final String REPAIR_FILE_NAME_ATTR   = "repairFileName";
	private static final String BOOTLDR_FILE_NAME_ATTR  = "bootldrFileName";
	private static final String REPAIR_VERSION_ATTR     = "repairVersion";
	
	private String fileName;
	private String fileNameV2;
	private String repairFileName;
	private String bootldrFileName;
	private String firmwareVersion;
	private String firmwareVersionV2;
	private String repairVersion;
	
	public FirmwareConfig(Context context, String rootFolder) throws IOException, XmlPullParserException
	{
		XmlPullParser parser = XmlPullParserFactory.newInstance().newPullParser();
		InputStream is = context.getAssets().open( rootFolder + "/firmware.xml");
		parser.setInput(is, "UTF-8");
		
		init(parser);
		
		is.close();
		
		PlfFile plfFile = new PlfFile(context.getAssets(), rootFolder + "/" + fileName);
		firmwareVersion = plfFile.getVersion();
		
		PlfFile plfFile2 = new PlfFile(context.getAssets(), rootFolder + "/" + fileNameV2);
		firmwareVersionV2 = plfFile2.getVersion();
	}

	
	public String getFileName() 
	{
		return fileName;
	}
	
	
	public String getFileNameV2()
	{
		return fileNameV2;
	}

	
	public String getRepairFileName() 
	{
		return repairFileName;
	}


	public String getBootldrFileName() 
	{
		return bootldrFileName;
	}


	public String getFirmwareVersion() 
	{
		return firmwareVersion;
	}
	
	
	public String getFirmwareVersionV2()
	{
		return firmwareVersionV2;
	}

	
	public String getRepairVersion() 
	{
		return repairVersion;
	}


	private void init(XmlPullParser parser) throws XmlPullParserException, IOException
	{
		parser.next();
		int eventType = parser.getEventType();
		
		 while (eventType != XmlPullParser.END_DOCUMENT) {
			 if(eventType == XmlPullParser.START_TAG) {
				 if (parser.getName().equals(FIRMWARE_TAG)) {
					 this.fileName = parser.getAttributeValue(null, FIRMWARE_FILE_NAME_ATTR);
					 this.fileNameV2 = parser.getAttributeValue(null, FIRMWARE_V2_FILE_NAME_ATTR);
					 this.bootldrFileName = parser.getAttributeValue(null, BOOTLDR_FILE_NAME_ATTR);
					 this.repairVersion = parser.getAttributeValue(null, REPAIR_VERSION_ATTR);
					 this.repairFileName = parser.getAttributeValue(null, REPAIR_FILE_NAME_ATTR);
				 }
			 }
			 
			 eventType = parser.next();
		 }
	}
}
