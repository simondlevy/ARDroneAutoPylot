
package com.parrot.freeflight.ui;

import java.util.Formatter;
import java.util.Locale;

import android.annotation.SuppressLint;
import android.media.MediaPlayer;
import android.media.MediaPlayer.OnCompletionListener;
import android.os.Handler;
import android.os.Message;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.ImageButton;
import android.widget.SeekBar;
import android.widget.SeekBar.OnSeekBarChangeListener;
import android.widget.TextView;
import android.widget.VideoView;

import com.parrot.freeflight.R;
import com.parrot.freeflight.utils.AnimationUtils;

public class VideoController implements OnClickListener, OnCompletionListener, OnSeekBarChangeListener
{
    protected static final int MSG_UPDATE_PROGRESS = 1;
 
    private static final int UPDATE_TIME = 1000;

    private final Formatter mFormatter;
    private final StringBuilder mFormatBuilder;

    private VideoView video;
    private View view;
    private TextView textCurrentTime;
    private TextView textTotalTime;

    private SeekBar seekBar;
    private ImageButton cboxPlayPause;

    private int lastMsec;
    private boolean seeking;
    private boolean showing;

    @SuppressLint("HandlerLeak")
    private final Handler handler = new Handler() {
        @Override
        public void handleMessage(Message msg)
        {
            int progress = 0;
            switch (msg.what) {
            case MSG_UPDATE_PROGRESS:
                progress = updateProgress();
                boolean videoIsPlaying = false;
                
                try {
                    videoIsPlaying = (video != null && video.isPlaying());
                } catch (IllegalStateException e) {
                    // Assume that it is not playing
                    e.printStackTrace();
                }
               
                if (video != null && !seeking && videoIsPlaying) {
                    msg = obtainMessage(MSG_UPDATE_PROGRESS);
                    sendMessageDelayed(msg, UPDATE_TIME - (progress % UPDATE_TIME));
                }

                break;
            }
        }
    };
    

    public VideoController(final View view)
    {
        mFormatBuilder = new StringBuilder();
        mFormatter = new Formatter(mFormatBuilder, Locale.getDefault());
        this.view = view;
        view.setVisibility(View.INVISIBLE);

        initView();
    }


    public void attachVideo(final VideoView video)
    {
        this.video = video;
        
        if (video != null) {
            this.video.setOnCompletionListener(this);
        }
        
        this.lastMsec = 0;
    }


    public void show()
    {
        if (!showing && video != null) {
            updateProgress();
            updatePauseResume();
            AnimationUtils.makeVisibleAnimated(view);

            showing = true;
        }

        handler.sendEmptyMessageDelayed(MSG_UPDATE_PROGRESS, 500);
    }


    public void hide()
    {
        if (video == null) { return; }

        if (showing) {
            handler.removeMessages(MSG_UPDATE_PROGRESS);
            AnimationUtils.makeInvisibleAnimated(view);
            showing = false;
        }
    }


    public View getView()
    {
        return view;
    }


    public void onCompletion(final MediaPlayer mp)
    {
        updateProgress();
        updatePauseResume();
    }


    public void onProgressChanged(final SeekBar seekBar, final int progress, final boolean fromUser)
    {
        if (fromUser && video != null)
        {
            video.seekTo(progress);
        }
    }


    public void onStartTrackingTouch(final SeekBar seekBar)
    {
        seeking = true;

        handler.removeMessages(MSG_UPDATE_PROGRESS);
    }


    public void onStopTrackingTouch(final SeekBar seekBar)
    {
        seeking = false;
        updateProgress();
        updatePauseResume();
        show();

        handler.sendEmptyMessage(MSG_UPDATE_PROGRESS);
    }


    protected void updatePauseResume()
    {
        if (video != null) {
            if (video.isPlaying()) {
                cboxPlayPause.setImageResource(R.drawable.btn_pause);
            } else {
                cboxPlayPause.setImageResource(R.drawable.btn_play);
            }
        }
    }


    protected void doPlayPause()
    {
        if (video != null) {
            if (video.isPlaying()) {
                video.pause();
            } else {
                video.start();
                handler.sendEmptyMessage(MSG_UPDATE_PROGRESS);
            }

            updatePauseResume();
        }
    }


    public boolean isPaused()
    {
        if (video != null) { return !video.isPlaying(); }

        return false;
    }


    public void stop()
    {
        if (video != null)
        {
            if (video.isPlaying()) {
                video.stopPlayback();
            }

            updatePauseResume();
        }

        updateProgress();
    }


    private void initView()
    {
        cboxPlayPause = (ImageButton) view.findViewById(R.id.cboxPlayPause);
        cboxPlayPause.setOnClickListener(this);
        seekBar = (SeekBar) view.findViewById(R.id.barProgress);
        textCurrentTime = (TextView) view.findViewById(R.id.textCurrentTime);
        textTotalTime = (TextView) view.findViewById(R.id.textTotalTime);

        seekBar.setOnSeekBarChangeListener(this);
    }


    private String stringForTime(final int timeMs)
    {
        final int totalSeconds = timeMs / 1000;

        final int seconds = totalSeconds % 60;
        final int minutes = (totalSeconds / 60) % 60;
        final int hours = totalSeconds / 3600;

        mFormatBuilder.setLength(0);
        if (hours > 0)
        {
            return mFormatter.format("%d:%02d:%02d", hours, minutes, seconds).toString();
        } else
        {
            return mFormatter.format("%02d:%02d", minutes, seconds).toString();
        }
    }


    private int updateProgress()
    {
        if (video != null) {
            final int currentPositionMilis = video.getCurrentPosition();
            final int duration = video.getDuration();
            seekBar.setMax(duration);
            seekBar.setProgress(currentPositionMilis);
            textCurrentTime.setText(stringForTime(currentPositionMilis));
            textTotalTime.setText(stringForTime(duration));

            lastMsec = currentPositionMilis;

            return currentPositionMilis;
        }

        return 0;
    }


    public void resume()
    {
        if (video != null) {
            video.seekTo(lastMsec);

            if (!video.isPlaying()) {
                doPlayPause();
            }
        }
    }


    public void pause()
    {
        if (isPaused())
            return;

        if (video != null) {
            video.pause();
            updatePauseResume();
        }
    }


    @Override
    public void onClick(View view)
    {
        switch (view.getId()) {
        case R.id.cboxPlayPause:
            doPlayPause();
            break;
        }
    }
}