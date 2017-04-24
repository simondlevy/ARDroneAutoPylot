package com.parrot.freeflight.ui.adapters;

import java.util.HashSet;
import java.util.List;

import android.app.ActivityManager;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.support.v4.util.LruCache;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.ImageView;
import android.widget.LinearLayout;

import com.parrot.freeflight.R;
import com.parrot.freeflight.tasks.MediaThumbnailExecutorManager;
import com.parrot.freeflight.tasks.ThumbnailWorkerTaskDelegate;
import com.parrot.freeflight.vo.MediaVO;

public class MediaAdapter
        extends BaseAdapter
        implements ThumbnailWorkerTaskDelegate
{
    private static final class ViewHolder
    {
        ImageView imageView;
        ImageView videoIndicatorView;
        LinearLayout selectedHolder;
    }

    private static final String TAG = MediaAdapter.class.getSimpleName();

    private List<MediaVO> fileList;
    private final LayoutInflater inflater;
    private MediaThumbnailExecutorManager getThumbnailWorkerTask;
    
    private int cacheSize; 
    private LruCache<String, Drawable> memoryCache;
    private HashSet<String> thumbnailRequested;
    
    public MediaAdapter(final Context context, final List<MediaVO> fileList)
    {
        this.fileList = fileList;
        this.inflater = (LayoutInflater) context.getSystemService(Context.LAYOUT_INFLATER_SERVICE);
        
        thumbnailRequested = new HashSet<String>(40); 
        
        // use all free memory
        int memClass = ((ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE)).getMemoryClass();
        cacheSize = 1024 * 1024 * memClass;
        
        memoryCache = new LruCache<String, Drawable>(cacheSize)
        {
            @Override
            protected int sizeOf(final String key, final Drawable value)
            {
                Bitmap bitmap = ((BitmapDrawable)value).getBitmap();
                return bitmap.getRowBytes() * bitmap.getHeight();
            }
        };
        
        getThumbnailWorkerTask = new MediaThumbnailExecutorManager(context, this);
    }

    
    public int getCount()
    {
        return fileList.size();
    }

    
    public MediaVO getItem(final int thePosition)
    {
        return fileList.get(thePosition);
    }

    
    public long getItemId(final int thePosition)
    {
        return thePosition;
    }
    
    
    public View getView(final int thePosition, final View theConvertView, final ViewGroup theParent)
    {
        MediaVO media = fileList.get(thePosition);
        View resultView = theConvertView;
        ViewHolder holder = null;

        if (resultView == null) {
            holder = new ViewHolder();
            resultView = inflater.inflate(R.layout.item_image, null);

            holder.selectedHolder = (LinearLayout) resultView.findViewById(R.id.selected_holder);
            holder.imageView = (ImageView) resultView.findViewById(R.id.image);
            holder.videoIndicatorView = (ImageView) resultView.findViewById(R.id.image_indicator);
            
            resultView.setTag(holder);
        } else {
            holder = (ViewHolder) resultView.getTag();
        }

        if (media.isVideo()) {
            if (holder.videoIndicatorView.getVisibility() == View.INVISIBLE) {
                holder.videoIndicatorView.setVisibility(View.VISIBLE);
            }
        } else {
            if (holder.videoIndicatorView.getVisibility() == View.VISIBLE) {
                holder.videoIndicatorView.setVisibility(View.INVISIBLE);
            }
        }

        if (media.isSelected()) {
            holder.selectedHolder.setVisibility(View.VISIBLE);
        } else {
            holder.selectedHolder.setVisibility(View.INVISIBLE);
        }

        String mediaKey = media.getKey();
        Drawable bitmap = memoryCache.get(mediaKey);

        if (bitmap != null) {
            if (holder.imageView.getVisibility() != View.VISIBLE) {
                holder.imageView.setVisibility(View.VISIBLE);
            }
            
            holder.imageView.setImageDrawable(bitmap);
        } 
        else {  
            //holder.imageView.setImageDrawable(null);
            holder.imageView.setVisibility(View.INVISIBLE);
            
            if (!thumbnailRequested.contains(mediaKey)) {
                thumbnailRequested.add(mediaKey);
                holder.imageView.setTag(mediaKey);
                getThumbnailWorkerTask.execute(media, holder.imageView);
            }
        }

        return resultView;
    }
    
    
    public void stopThumbnailLoading()
    {
        getThumbnailWorkerTask.stop();
        
        memoryCache.evictAll();
    }
    
    
    public void setFileList(List<MediaVO> fileList)
    {
        this.fileList = fileList;
        notifyDataSetChanged();
    }


    public void onThumbnailReady(ImageView view, String key, BitmapDrawable thumbnail)
    {
        if (thumbnailRequested.contains(key)) {
            thumbnailRequested.remove(key);
            
            if (view.getTag().equals(key)) {
                view.setImageDrawable(thumbnail);
                if (view.getVisibility() != View.VISIBLE) {
                    view.setVisibility(View.VISIBLE);
                }
            }
        }
        
        if (memoryCache.get(key) == null) {
            memoryCache.put(key, thumbnail);
        }
    }


    public void onLowMemory()
    {
        Log.w(TAG, "Low memory warning received");
        memoryCache.evictAll();
    }
}
