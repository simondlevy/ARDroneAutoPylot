
package com.parrot.freeflight.activities;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ExecutionException;

import android.annotation.SuppressLint;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.Bundle;
import android.support.v4.content.LocalBroadcastManager;
import android.util.Log;
import android.view.View;
import android.view.View.OnClickListener;
import android.widget.AdapterView;
import android.widget.AdapterView.OnItemClickListener;
import android.widget.Button;
import android.widget.GridView;
import android.widget.LinearLayout;
import android.widget.RadioGroup;
import android.widget.RadioGroup.OnCheckedChangeListener;

import com.parrot.freeflight.R;
import com.parrot.freeflight.activities.base.ParrotActivity;
import com.parrot.freeflight.receivers.MediaReadyDelegate;
import com.parrot.freeflight.receivers.MediaReadyReceiver;
import com.parrot.freeflight.receivers.MediaStorageReceiver;
import com.parrot.freeflight.receivers.MediaStorageReceiverDelegate;
import com.parrot.freeflight.service.DroneControlService;
import com.parrot.freeflight.tasks.GetMediaObjectsListTask;
import com.parrot.freeflight.tasks.GetMediaObjectsListTask.MediaFilter;
import com.parrot.freeflight.transcodeservice.TranscodingService;
import com.parrot.freeflight.ui.ActionBar;
import com.parrot.freeflight.ui.StatusBar;
import com.parrot.freeflight.ui.adapters.MediaAdapter;
import com.parrot.freeflight.utils.ARDroneMediaGallery;
import com.parrot.freeflight.vo.MediaVO;

public class MediaActivity extends ParrotActivity
        implements
        OnClickListener,
        OnCheckedChangeListener,
        OnItemClickListener,
        MediaReadyDelegate,
        MediaStorageReceiverDelegate
{
    private enum ActionBarState
    {
        BROWSE, EDIT;
    }

    private static final String TAG = MediaActivity.class.getSimpleName();

    private final ArrayList<MediaVO> mediaList = new ArrayList<MediaVO>();
    private final ArrayList<MediaVO> selectedItems = new ArrayList<MediaVO>();

    private MediaFilter currentFilter = MediaFilter.ALL;

    private StatusBar header;
    private GridView gridView;
    private Button btnSelectClear;
    private ARDroneMediaGallery mediaGallery;
    private ActionBarState currentABState = ActionBarState.BROWSE;
    
    private MediaReadyReceiver mediaReadyReceiver;    // Detects when drone created new media file
    private MediaStorageReceiver mediaStorageReceiver; // Detects when SD Card becomes unmounted

    
    @Override
    protected void onCreate(final Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        mediaGallery = new ARDroneMediaGallery(this);
        setContentView(R.layout.media_screen);

        mediaReadyReceiver = new MediaReadyReceiver(this);
        mediaStorageReceiver = new MediaStorageReceiver(this);
        initListeners();
        initHeader();
        initNavigationBar();
        initActionBar(currentABState);
        initGallery();

        onApplyMediaFilter(currentFilter);   
    }
    

    @Override
    protected void onDestroy()
    {
        super.onDestroy();

        MediaAdapter adapter = (MediaAdapter) gridView.getAdapter();
        
        if (adapter != null) {
            adapter.stopThumbnailLoading();
        }
    }


    private void initListeners()
    {
        final RadioGroup filter = (RadioGroup) findViewById(R.id.filter);
        filter.setOnCheckedChangeListener(this);

        final Button btnEdit = (Button) findViewById(R.id.btnEdit);
        btnEdit.setOnClickListener(this);

        final Button btnCancel = (Button) findViewById(R.id.btnCancel);
        btnCancel.setOnClickListener(this);

        final Button btnDelete = (Button) findViewById(R.id.btnDelete);
        btnDelete.setOnClickListener(this);

        btnSelectClear = (Button) findViewById(R.id.btnSelectClear);
        btnSelectClear.setOnClickListener(this);
    }


    private void initHeader()
    {
        final View viewHeader = findViewById(R.id.header_preferences);
        header = new StatusBar(this, viewHeader);
    }


    private void initNavigationBar()
    {
        final View viewOrangeBar = findViewById(R.id.navigation_bar);

        final ActionBar orangeHeader = new ActionBar(this, viewOrangeBar);
        orangeHeader.initTitle(getString(R.string.photos_videos));
        orangeHeader.initHomeButton();
    }


    private void initGallery()
    {
        int columnCount = getResources().getInteger(R.integer.media_gallery_columns_count);
        gridView = (GridView) findViewById(R.id.grid);
        gridView.setNumColumns(columnCount);
        gridView.setOnItemClickListener(this);
    }
    
    
    

    @Override
    protected void onStart()
    {
        super.onStart();

        LocalBroadcastManager broadcastManager = LocalBroadcastManager.getInstance(getApplicationContext());

        IntentFilter mediaReadyFilter = new IntentFilter();
        mediaReadyFilter.addAction(DroneControlService.NEW_MEDIA_IS_AVAILABLE_ACTION);
        mediaReadyFilter.addAction(TranscodingService.NEW_MEDIA_IS_AVAILABLE_ACTION);
        broadcastManager.registerReceiver(mediaReadyReceiver, mediaReadyFilter);
    }


    @Override
    protected void onStop()
    {
        super.onStop();
        
        LocalBroadcastManager broadcastManager = LocalBroadcastManager.getInstance(getApplicationContext());
        broadcastManager.unregisterReceiver(mediaReadyReceiver);
    }


    @Override
    protected void onPause()
    {
        super.onPause();
        header.stopUpdating();
        mediaStorageReceiver.unregisterFromEvents(this);
    }

  
    @Override
    protected void onResume()
    {
        super.onResume();
        header.startUpdating();
        mediaStorageReceiver.registerForEvents(this);
    }


    @SuppressLint("NewApi")
    protected synchronized void onApplyMediaFilter(MediaFilter filter)
    {
        GetMediaObjectsListTask mediaWorkerTask = new GetMediaObjectsListTask(this, filter)
        {
            @Override
            protected void onPostExecute(final List<MediaVO> result)
            {
                mediaList.clear();
                mediaList.addAll(result);

                MediaAdapter adapter = (MediaAdapter) gridView.getAdapter();

                if (adapter == null) {
                    adapter = new MediaAdapter(MediaActivity.this, mediaList);
                    gridView.setAdapter(adapter);
                } else {
                    adapter.setFileList(mediaList);
                }
            }
        };

        try {
            if (Build.VERSION.SDK_INT < 11) {
                mediaWorkerTask.execute().get();
            } else {
                mediaWorkerTask.executeOnExecutor(GetMediaObjectsListTask.THREAD_POOL_EXECUTOR).get(); 
            }
        } catch (InterruptedException e) {
            e.printStackTrace();
        } catch (ExecutionException e) {
            e.printStackTrace();
        }
    }


    protected void onEditClicked()
    {
        currentABState = ActionBarState.EDIT;
    }


    protected void onCancelEditClicked()
    {
        switchEditBarToInitialState();
        currentABState = ActionBarState.BROWSE;
    }


    protected void onSelectAllClicked()
    {
        if (selectedItems.size() > 0) {
            btnSelectClear.setText(getString(R.string.select_all));
            switchAllItemState(false);
        } else {
            btnSelectClear.setText(getString(R.string.clear_all));
            switchAllItemState(true);
        }

        final MediaAdapter adapter = (MediaAdapter) gridView.getAdapter();
        adapter.notifyDataSetChanged();
    }


    protected void onDeleteMediaClicked()
    {
        if (selectedItems.size() > 0) {
            AlertDialog.Builder alert = new AlertDialog.Builder(this);
            alert.setTitle("");
            alert.setMessage(R.string.delete_popup);

            alert.setPositiveButton(getString(R.string.delete_media), new DialogInterface.OnClickListener()
            {
                public void onClick(final DialogInterface dialog, final int whichButton)
                {
                    onDeleteSelectedMediaItems();
                }
            });
            alert.setNegativeButton(getString(android.R.string.cancel), new DialogInterface.OnClickListener()
            {
                public void onClick(final DialogInterface dialog, final int whichButton)
                {
                    dialog.cancel();
                }
            });

            alert.show();
        }
    }


    private void onDeleteSelectedMediaItems()
    {
        int size = selectedItems.size();

        List<MediaVO> photosToDelete = new ArrayList<MediaVO>();
        List<MediaVO> videosToDelete = new ArrayList<MediaVO>();

        for (int i = 0; i < size; ++i) {
            MediaVO media = selectedItems.get(i);

            if (media.isSelected()) {

                if (media.isVideo()) {
                    videosToDelete.add(media);
                } else {
                    photosToDelete.add(media);
                }
            }
        }

        // Deleting photos
        int countOfPhotos = photosToDelete.size();
        if (countOfPhotos > 0) {
            int[] idsToDelete = new int[countOfPhotos];

            for (int i = 0; i < countOfPhotos; ++i) {
                idsToDelete[i] = photosToDelete.get(i).getId();
            }

            mediaGallery.deleteImages(idsToDelete);
            mediaList.removeAll(photosToDelete);
        }

        // Deleting videos
        int countOfVideos = videosToDelete.size();
        if (countOfVideos > 0) {
            int[] idsToDelete = new int[countOfVideos];

            for (int i = 0; i < countOfVideos; ++i) {
                idsToDelete[i] = videosToDelete.get(i).getId();
            }

            mediaGallery.deleteVideos(idsToDelete);
            mediaList.removeAll(videosToDelete);
        }

        selectedItems.clear();

        if (countOfPhotos > 0 || countOfVideos > 0) {
            switchEditBarToInitialState();
        }
    }


    protected void onPlayMediaItem(int position)
    {
        final Intent intent = new Intent(this, GalleryActivity.class);
        intent.putExtra(GalleryActivity.SELECTED_ELEMENT, position);
        intent.putExtra(GalleryActivity.MEDIA_FILTER, currentFilter.ordinal());

        startActivity(intent);
    }


    private void switchEditBarToInitialState()
    {
        btnSelectClear.setText(getString(R.string.select_all));
        switchAllItemState(false);
        final MediaAdapter adapter = (MediaAdapter) gridView.getAdapter();
        
        if (adapter != null) {
        	adapter.notifyDataSetChanged();
        }
    }


    private void initActionBar(final ActionBarState state)
    {
        final LinearLayout browseBar = (LinearLayout) findViewById(R.id.llayBrowseBar);
        final LinearLayout editBar = (LinearLayout) findViewById(R.id.llayEditBar);

        switch (state) {
        case BROWSE:
            browseBar.setVisibility(View.VISIBLE);
            editBar.setVisibility(View.GONE);
            break;
        case EDIT:
            browseBar.setVisibility(View.GONE);
            editBar.setVisibility(View.VISIBLE);
            break;

        }
    }


    private void switchAllItemState(final boolean isSelected)
    {
        if (isSelected) {
            selectedItems.addAll(mediaList);
        } else {
            selectedItems.clear();
        }

        final int size = mediaList.size();

        for (int i = 0; i < size; i++) {
            final MediaVO imageDetailVO = mediaList.get(i);

            imageDetailVO.setSelected(isSelected);
        }
    }


    public void onCheckedChanged(final RadioGroup group, final int checkedId)
    {
        switch (checkedId) {
        case R.id.rbtn_images:
            currentFilter = MediaFilter.IMAGES;
            break;

        case R.id.rbtn_videos:
            currentFilter = MediaFilter.VIDEOS;
            break;

        case R.id.rbtn_all:
        default:
            currentFilter = MediaFilter.ALL;
            break;
        }

        onApplyMediaFilter(currentFilter);
    }


    public void onClick(final View v)
    {
        final int id = v.getId();

        switch (id) {
        case R.id.btnEdit:
            onEditClicked();
            break;
        case R.id.btnCancel:
            onCancelEditClicked();
            break;
        case R.id.btnSelectClear:
            onSelectAllClicked();
            break;
        case R.id.btnDelete:
            onDeleteMediaClicked();
            break;
        default:
        }

        initActionBar(currentABState);
    }


    public void onItemClick(final AdapterView<?> adapterView, final View view, final int position, final long id)
    {
        switch (currentABState) {
        case BROWSE:
            onPlayMediaItem(position);
            break;

        case EDIT:
            final LinearLayout selectedHolder = (LinearLayout) view.findViewById(R.id.selected_holder);

            if (selectedHolder.isShown()) {
                selectedHolder.setVisibility(View.GONE);
                MediaVO media = mediaList.get(position);
                media.setSelected(false);

                selectedItems.remove(media);

            } else {
                selectedHolder.setVisibility(View.VISIBLE);
                MediaVO media = mediaList.get(position);
                media.setSelected(true);

                selectedItems.add(media);
                btnSelectClear.setText(getString(R.string.clear_all));
            }

            break;

        default:
        }
    }

    @Override
    public void onMediaReady(File mediaFile)
    {
        Log.d(TAG, "New file available " + mediaFile.getAbsolutePath());
        onApplyMediaFilter(currentFilter);
    }


    @Override
    public void onLowMemory()
    {
        super.onLowMemory();
        Log.w(TAG, "Low memory warning received. Trying to cleanum cacne");

        MediaAdapter adapter = (MediaAdapter) gridView.getAdapter();
        adapter.onLowMemory();
    }


    @Override
    public void onMediaStorageMounted()
    {
        // Nothing to do
    }


    @Override
    public void onMediaStorageUnmounted()
    {
        
    }


    @Override
    public void onMediaEject()
    {
        mediaGallery.onDestroy();
        finish();
    }
}
