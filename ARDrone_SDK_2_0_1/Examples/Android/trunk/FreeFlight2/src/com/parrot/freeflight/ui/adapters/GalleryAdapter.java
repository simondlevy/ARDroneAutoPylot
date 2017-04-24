package com.parrot.freeflight.ui.adapters;

import java.util.List;
import java.util.concurrent.ExecutionException;

import android.content.Context;
import android.os.AsyncTask.Status;
import android.support.v4.view.PagerAdapter;
import android.support.v4.view.ViewPager;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.ImageView.ScaleType;
import android.widget.RelativeLayout;

import com.parrot.freeflight.R;
import com.parrot.freeflight.tasks.LoadMediaThumbTask;
import com.parrot.freeflight.vo.MediaVO;

public class GalleryAdapter
        extends PagerAdapter
{
    private static final String TAG = GalleryAdapter.class.getSimpleName();
 
    private final List<MediaVO> mediaList;
    private final Context context;
    private final LayoutInflater inflater;
    private GalleryAdapterDelegate delegate;

    private LoadMediaThumbTask currentTask;

    private boolean sync;

    public GalleryAdapter(final List<MediaVO> mediaList, final Context theContext, final GalleryAdapterDelegate delegate)
    {
        this(mediaList, theContext, delegate, false);
    }
    
    public GalleryAdapter(final List<MediaVO> mediaList, final Context theContext, final GalleryAdapterDelegate delegate, boolean syncThumbLoad)
    {
        super();
        sync = syncThumbLoad;
        this.mediaList = mediaList;
        this.context = theContext;
        this.delegate = delegate;
        inflater = LayoutInflater.from(context);
    }

    @Override
    public void destroyItem(final View collection, final int position, final Object view)
    {   
        ((ViewPager) collection).removeView((RelativeLayout) view);
    }

    @Override
    public int getCount()
    {
        return mediaList.size();
    }

    @Override
    public Object instantiateItem(final View collection, final int position)
    {
        final MediaVO imgDetail = mediaList.get(position);

        RelativeLayout root;

        if (imgDetail.isVideo()) {
            root = addVideo(imgDetail);
        } else {
            root = addImage(imgDetail);
        }

        ((ViewPager) collection).addView(root, 0);

        return root;
    }

    
    @Override
    public boolean isViewFromObject(final View view, final Object object)
    {
        return view == ((RelativeLayout) object);
    }

    
    private RelativeLayout addImage(final MediaVO imgDetail)
    {
        final RelativeLayout root = (RelativeLayout) inflater.inflate(R.layout.item_video, null);
        root.setPadding(0, 0, 0, 0);
        root.setDrawingCacheEnabled(true);
        root.setWillNotDraw(true);

        final ImageView image = (ImageView) root.findViewById(R.id.image);
        image.setDrawingCacheEnabled(true);
        final ImageView imageIndicatorView = (ImageView) root.findViewById(R.id.btn_play);
        image.setScaleType(ScaleType.CENTER_CROP);

        imageIndicatorView.setVisibility(View.INVISIBLE);

        if (currentTask != null && currentTask.getStatus() == Status.RUNNING) {
            currentTask.cancel(true);
        }
        
        try {
            if (sync) {
                new LoadMediaThumbTask(imgDetail, image).execute().get();
            } else {
                new LoadMediaThumbTask(imgDetail, image).execute();
            }
        } catch (InterruptedException e) {
            e.printStackTrace();
        } catch (ExecutionException e) {
            e.printStackTrace();
        }
        
        return root;
    }

    
    private RelativeLayout addVideo(final MediaVO media)
    {
        final RelativeLayout root = (RelativeLayout) inflater.inflate(R.layout.item_video, null);
        root.setPadding(0, 0, 0, 0);
        root.setDrawingCacheEnabled(true);
        root.setWillNotDraw(true);

        final ImageView image = (ImageView) root.findViewById(R.id.image);
        image.setDrawingCacheEnabled(true);
        final ImageView btnPlay = (ImageView) root.findViewById(R.id.btn_play);
        btnPlay.setDrawingCacheEnabled(true);
        
        root.setTag(media);

        btnPlay.setOnClickListener(new View.OnClickListener()
        {
            public void onClick(final View v)
            {
                onPlayButtonClicked(root);
            }
        });
       
        try {
            if (sync) {
                new LoadMediaThumbTask(media, image).execute().get();
            } else {
                new LoadMediaThumbTask(media, image).execute();
            }
        } catch (InterruptedException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        } catch (ExecutionException e) {
            // TODO Auto-generated catch block
            e.printStackTrace();
        }
        
        return root;
    }
    
    
    protected void onPlayButtonClicked(ViewGroup root)
    {
        if (delegate != null) {
            delegate.onPlayButtonClicked(root);
        } else {
            Log.w(TAG, "Play button clicked but delegate not set");
        }
    }
}
