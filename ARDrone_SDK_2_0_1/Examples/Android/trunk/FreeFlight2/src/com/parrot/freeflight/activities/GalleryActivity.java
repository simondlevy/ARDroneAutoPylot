package com.parrot.freeflight.activities;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutionException;
import java.util.logging.Level;
import java.util.logging.Logger;

import android.content.Intent;
import android.media.MediaPlayer;
import android.media.MediaPlayer.OnErrorListener;
import android.os.AsyncTask.Status;
import android.os.Bundle;
import android.support.v4.view.ViewPager;
import android.support.v4.view.ViewPager.OnPageChangeListener;
import android.util.Log;
import android.view.GestureDetector;
import android.view.GestureDetector.OnGestureListener;
import android.view.MotionEvent;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.View.OnTouchListener;
import android.view.ViewGroup;
import android.view.ViewStub;
import android.widget.VideoView;

import com.parrot.freeflight.R;
import com.parrot.freeflight.activities.base.ParrotActivity;
import com.parrot.freeflight.drone.DroneProxy.EVideoRecorderCapability;
import com.parrot.freeflight.tasks.GetMediaObjectsListTask;
import com.parrot.freeflight.tasks.GetMediaObjectsListTask.MediaFilter;
import com.parrot.freeflight.ui.ActionBar;
import com.parrot.freeflight.ui.VideoController;
import com.parrot.freeflight.ui.adapters.GalleryAdapter;
import com.parrot.freeflight.ui.adapters.GalleryAdapterDelegate;
import com.parrot.freeflight.utils.DeviceCapabilitiesUtils;
import com.parrot.freeflight.utils.NookUtils;
import com.parrot.freeflight.utils.ShareUtils;
import com.parrot.freeflight.vo.MediaVO;

/**
 * GalleryActivity allows the user to browse media files one by one with ability
 * to slide to next and previous media file with simple gesture. Also it allows
 * to view video files when user pressed on play button.
 */
public class GalleryActivity extends ParrotActivity
        implements
        OnTouchListener,
        OnClickListener,
        OnPageChangeListener,
        GalleryAdapterDelegate,
        OnGestureListener
        
{
    private static final String TAG = GalleryActivity.class.getSimpleName();
    public static String SELECTED_ELEMENT = "SELECTED_ELEMENT";
    public static String MEDIA_FILTER = "MEDIA_FILTER";

    private ActionBar bar;
    private VideoController vc;
    private ViewGroup viewCurrItem;

    private final List<MediaVO> mediaList = new ArrayList<MediaVO>();

    private int currentItem;
    private boolean shouldResumeVideo = false;
    
    private GalleryAdapter adapter;
    private GetMediaObjectsListTask initMediaTask;
    
    private GestureDetector gestureDetector;


    private void initHeader()
    {
        final View headerView = findViewById(R.id.navigation_bar);

        bar = new ActionBar(this, headerView);
        bar.initBackButton();
        bar.changeBackground(ActionBar.Background.ACCENT_HALF_TRANSP);
        bar.hide(false);

        if (!NookUtils.isNook()) {
            bar.initShareButton(this);
        }
        
        gestureDetector = new GestureDetector(this, this);
    }


    private void initMediaTask(MediaFilter filter, final int selectedElement)
    {
        if (initMediaTask == null || (initMediaTask != null && initMediaTask.getStatus() != Status.RUNNING)) {
            initMediaTask = new GetMediaObjectsListTask(this, filter)
            {
                @Override
                protected void onPostExecute(final List<MediaVO> result)
                {
                    onMediaScanCompleted(selectedElement, result);
                }
            };

            try {
                initMediaTask.execute().get();
            } catch (InterruptedException e) {
                e.printStackTrace();
            } catch (ExecutionException e) {
                e.printStackTrace();
            }
        }
    }


    private void initView(final int selectedElement)
    {
        vc = new VideoController(findViewById(R.id.media_controller));
        setTitle((selectedElement + 1) + " " + getString(R.string.of) + " " + mediaList.size());

        final ViewPager gallery = (ViewPager) findViewById(R.id.gallery);
        adapter = new GalleryAdapter(mediaList, this, this);

        gallery.setAdapter(adapter);
        gallery.setCurrentItem(selectedElement, false);
        gallery.setOnPageChangeListener(this);
        gallery.setOnTouchListener(this);

        vc.hide();
    }


    public void onClick(final View v)
    {
        if (v.getId() == R.id.btnShare) {
            onShareClicked();
        }
    }


    @Override
    protected void onCreate(final Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
      
        setContentView(R.layout.gallery_screen);

        initHeader();
        final Intent intent = getIntent();
        
        if (savedInstanceState != null) {
            currentItem = savedInstanceState.getInt(SELECTED_ELEMENT, 0);
        } else {
            if (currentItem == 0) {
                currentItem = intent.getIntExtra(SELECTED_ELEMENT, 0);
            }
        }

        MediaFilter mediaFilter = MediaFilter.values()[intent.getIntExtra(MEDIA_FILTER, MediaFilter.ALL.ordinal())];
        initMediaTask(mediaFilter, currentItem);
    }


    @Override
    protected void onDestroy()
    {
        super.onDestroy();
        
        if (initMediaTask != null && initMediaTask.getStatus() == Status.RUNNING) {
            initMediaTask.cancel(false);
        }
    }
    

    protected void onMediaScanCompleted(final int selectedElement, final List<MediaVO> result)
    {
        mediaList.clear();
        mediaList.addAll(result);

        initView(selectedElement);

        initMediaTask = null;
    }


    public void onPageScrolled(final int arg0, final float arg1, final int arg2)
    {
        // Left unimplemented
    }


    public void onPageScrollStateChanged(final int state)
    {
        switch (state) {
        case ViewPager.SCROLL_STATE_DRAGGING:
            Log.d(TAG, "onPageScrollStateChanged: DRAGGING");
            
            if (!bar.isVisible()) {
                bar.show(true);
            }
            
            vc.hide();
            
            if (viewCurrItem != null) {
                VideoView video = (VideoView) viewCurrItem.findViewById(R.id.video_view);
                if (video != null) {
                    video.stopPlayback();
                    setMediaViewVisible(false);
                    vc.attachVideo(null);
                }

                viewCurrItem = null;
            }
            
            break;
        case ViewPager.SCROLL_STATE_SETTLING:
            Log.d(TAG, "onPageScrollStateChanged: SETTLING");
            break;
        case ViewPager.SCROLL_STATE_IDLE:
            Log.d(TAG, "onPageScrollStateChanged: IDLE");
            break;
        }

    }


    public void onPageSelected(int position)
    {
        currentItem = position;

        setTitle(++position + " " + getString(R.string.of) + " " + mediaList.size());
    }


    @Override
    protected void onPause()
    {
        super.onPause();
        
        if (vc != null) {
	        shouldResumeVideo = !vc.isPaused();
	        vc.pause();
	        
	        bar.hide(true);
	        vc.hide();
        }
    }


    @Override
    public void onPlayButtonClicked(ViewGroup parent)
    {  
    	if (DeviceCapabilitiesUtils.getMaxSupportedVideoRes() == EVideoRecorderCapability.NOT_SUPPORTED) {
    		playVideoInExternalPlayer();
    		return;
    	}
    	
        VideoView videoView = null;
        
        /*
         * There should be only one video view in view hierarchy in order for
         * video to work. That is why we use video stub that is transformed
         * into video view when user press play button.
         */
        ViewStub videoStub = (ViewStub)parent.findViewById(R.id.video_view_stub);
     
        if (videoStub != null) {
        	videoView = (VideoView) videoStub.inflate();
        } else {
        	// Looks like VideoView has been already inflated. Looking for it.
        	videoView = (VideoView) parent.findViewById(R.id.video_view);
        	
        	if (videoView == null) {
        		// Nope, something went wrong here. Calling error handler.
        		playVideoInExternalPlayer();
        		return;
        	}
        }
        
        videoView.setOnErrorListener(new OnErrorListener() {
            @Override
            public boolean onError(final MediaPlayer mp, final int what, final int extra)
            {
                return onVideoPlayFailed(mp, what, extra);
            }
        });

      
        final MediaVO media = mediaList.get(currentItem);
    
        if (media.isVideo()) {
            viewCurrItem = parent;
            setMediaViewVisible(true);
            vc.attachVideo(videoView);
            
            final VideoView videoViewControl = videoView;
            
            videoView.postDelayed(new Runnable() {
                @Override
                public void run()
                {
                    videoViewControl.setVideoURI(media.getUri());
                    videoViewControl.start();       
                    bar.hide(true);
                }
            }, 100);
        }
    }


    @Override
    protected void onResume()
    {
        super.onResume();
        
        if (vc != null) {
            if (shouldResumeVideo) {
                vc.resume();
            } else {
                vc.resume();
                vc.pause();
            }
        }
    }


    @Override
    protected void onSaveInstanceState(Bundle outState)
    {
        super.onSaveInstanceState(outState);

        final ViewPager gallery = (ViewPager) findViewById(R.id.gallery);
        outState.putInt(SELECTED_ELEMENT, gallery.getCurrentItem());
    }


    protected void onShareClicked()
    {
        final MediaVO media = mediaList.get(currentItem);

        if (media.isVideo()) {
            ShareUtils.shareVideo(this, media.getPath());
        } else {
            ShareUtils.sharePhoto(this, media.getPath());
        }
    }


	public boolean onTouch(final View v, final MotionEvent event) 
	{
	    gestureDetector.onTouchEvent(event);
		return false;
	}
	

    protected boolean onVideoPlayFailed(MediaPlayer mp, int what, int extra)
    {
		if (mp != null) {
    		mp.stop();
    	}
    	
    	playVideoInExternalPlayer();
        
        setMediaViewVisible(false);

        return true;
    }


	private void playVideoInExternalPlayer() 
	{
        vc.hide();
        
        Log.d(TAG, "Error occured while trying to play video via embedded player. Trying to play video in external player");
        Intent intent = new Intent(Intent.ACTION_VIEW);

        overridePendingTransition(R.anim.nothing, R.anim.nothing);
        
        MediaVO media = (MediaVO) mediaList.get(currentItem);
        intent.setDataAndType(media.getUri(), "video/mp4");
        startActivity(intent);
	}

	
	private void setMediaViewVisible(boolean visible) 
	{
		if (viewCurrItem == null) {
			return;
		}

		VideoView videoView = (VideoView) viewCurrItem
				.findViewById(R.id.video_view);
		View btnPlay = viewCurrItem.findViewById(R.id.btn_play);
		View thumb = viewCurrItem.findViewById(R.id.image);

		if (visible) {
			if (videoView != null) {
				videoView.setVisibility(View.VISIBLE);
			} else {
				Log.w(TAG,
						"Can't make video view visible. It has not been found in view hierarchy.");
			}
			thumb.setVisibility(View.INVISIBLE);
			btnPlay.setVisibility(View.INVISIBLE);
		} else {
			thumb.setVisibility(View.VISIBLE);
			btnPlay.setVisibility(View.VISIBLE);

			if (videoView != null) {
				videoView.setVisibility(View.GONE);
			} else {
				Log.w(TAG,
						"Unable to make video view invisible. It has not been found in view hierarchy.");
			}
		}
	}


    private void setTitle(final String value)
    {
        if (bar != null) {
            bar.initTitle(value);
        }
    }


    @Override
    public boolean onSingleTapUp(MotionEvent e)
    {
        final MediaVO imageDetailVO = mediaList.get(currentItem);

         if (bar.isVisible()) {
             bar.hide(true);
    
             if (imageDetailVO.isVideo() && viewCurrItem != null) {
                 vc.hide();
             }
         } else {
             bar.show(true);
    
             if (imageDetailVO.isVideo() && viewCurrItem != null) {
                 if (viewCurrItem.findViewById(R.id.video_view)
                         .getVisibility() == View.VISIBLE) {
                     vc.show();
                 }
             }
         }
        return true;
    }

    
    @Override
    public boolean onDown(MotionEvent e)
    {
       // Left unimplemented
        return false;
    }


    @Override
    public void onShowPress(MotionEvent e)
    {
       // Left unimplemented
    }

    @Override
    public boolean onScroll(MotionEvent e1, MotionEvent e2, float distanceX, float distanceY)
    {
        // Left unimplemented
        return false;
    }


    @Override
    public void onLongPress(MotionEvent e)
    {
        // Left unimplemented
    }


    @Override
    public boolean onFling(MotionEvent e1, MotionEvent e2, float velocityX, float velocityY)
    {
        // Left unimplemented
        return false;
    }

}
