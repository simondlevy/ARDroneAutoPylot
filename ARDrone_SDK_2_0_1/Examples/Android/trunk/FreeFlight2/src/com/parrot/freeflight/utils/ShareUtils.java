package com.parrot.freeflight.utils;

import java.io.File;

import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.provider.MediaStore.Images;
import android.provider.MediaStore.Video;
import android.util.Log;

import com.parrot.freeflight.R;

public final class ShareUtils
{
	private static final String TAG = ShareUtils.class.getSimpleName();

	private ShareUtils()
	{}

	public static void sharePhoto(Context context, String filePath)
	{
	    ContentResolver contentResolver = context.getContentResolver();
        
        Uri uri = FileUtils.isExtStorgAvailable() ? Images.Media.EXTERNAL_CONTENT_URI
                : Images.Media.INTERNAL_CONTENT_URI;    
        
        File file = new File(filePath);
        String[] args = new String[] { file.getName(), FileUtils.MEDIA_PUBLIC_FOLDER_NAME };
        String where = Images.Media.DISPLAY_NAME + "=? and " + Images.Media.BUCKET_DISPLAY_NAME + "=?";

        Cursor cursor = contentResolver.query(uri, new String[]{Images.Media._ID, Images.Media.MIME_TYPE}, where, args, null);

        long id = 0;
        if (cursor == null) {
            // query failed, handle error.
            Log.w(TAG, "Unknown error");
        } else if (!cursor.moveToFirst()) {
            // no media on the device
            Log.w(TAG, "Error, no such file in media gallery. " + filePath );
        } else {
            int idColumn = cursor.getColumnIndex(android.provider.MediaStore.Images.Media._ID);
            int contentTypeColumn = cursor.getColumnIndex(android.provider.MediaStore.Images.Media.MIME_TYPE);
            do {
                id =  cursor.getLong(idColumn);
                String contentType = cursor.getString(contentTypeColumn);
                
                if (contentType == null) {
                	contentType = "image/jpg";
                }
                
                Log.i("sharePhoto", "Image id: " + id + " type: " + contentType);

                Intent msg = new Intent(Intent.ACTION_SEND);
                msg.setType(contentType);
                msg.putExtra(Intent.EXTRA_STREAM, Uri.withAppendedPath(uri, Long.toString(id)));
                context.startActivity(Intent.createChooser(msg, context.getString(R.string.share)));
                
                break;
            } while (cursor.moveToNext());
        }
        
        cursor.close();
	}

	
	public static void shareVideo(Context context, String filePath)
	{
	    ContentResolver contentResolver = context.getContentResolver();
        Uri uri = android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI;
        
        File file = new File(filePath);
        String[] args = new String[] { file.getName(), FileUtils.MEDIA_PUBLIC_FOLDER_NAME };
        String where = Images.Media.DISPLAY_NAME + "=? and " + Images.Media.BUCKET_DISPLAY_NAME + "=?";

        Cursor cursor = contentResolver.query(uri, new String[]{Video.Media._ID, Video.Media.MIME_TYPE}, where, args, null);

        long id = 0;
        if (cursor == null) {
            // query failed, handle error.
            Log.w(TAG, "Unknown error");
        } else if (!cursor.moveToFirst()) {
            // no media on the device
            Log.w(TAG, "Error, no such file");
        } else {
            int idColumn = cursor.getColumnIndex(android.provider.MediaStore.Video.Media._ID);
            int contentTypeColumn = cursor.getColumnIndex(android.provider.MediaStore.Video.Media.MIME_TYPE);
            do {
                id = cursor.getLong(idColumn);
                String contentType = cursor.getString(contentTypeColumn);
                
                if (contentType == null) {
                	contentType = "video/mp4";
                }

                Log.i("shareVideo", "Video id: " + id + " type: " + contentType);
                
                Intent msg = new Intent(Intent.ACTION_SEND);
                msg.setType(contentType);
                msg.putExtra(Intent.EXTRA_STREAM, Uri.withAppendedPath(uri, Long.toString(id)));
                context.startActivity(Intent.createChooser(msg, context.getString(R.string.share)));
                
                break;
            } while (cursor.moveToNext());
        }
        
        cursor.close();
	}
}
