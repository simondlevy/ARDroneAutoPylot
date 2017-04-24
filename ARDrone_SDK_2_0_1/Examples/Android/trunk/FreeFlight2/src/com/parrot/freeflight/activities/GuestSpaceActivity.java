package com.parrot.freeflight.activities;

import android.annotation.SuppressLint;
import android.annotation.TargetApi;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.support.v4.view.ViewPager;
import android.support.v4.view.ViewPager.OnPageChangeListener;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceResponse;
import android.webkit.WebSettings;
import android.webkit.WebSettings.PluginState;
import android.webkit.WebSettings.ZoomDensity;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.ProgressBar;
import android.widget.RadioGroup;
import android.widget.RadioGroup.OnCheckedChangeListener;
import android.widget.TextView;

import com.parrot.freeflight.R;
import com.parrot.freeflight.activities.base.ParrotActivity;
import com.parrot.freeflight.ui.ActionBar;
import com.parrot.freeflight.ui.StatusBar;
import com.parrot.freeflight.ui.adapters.InfosAdapter;
import com.parrot.freeflight.utils.NookUtils;

@SuppressLint("NewApi")
public class GuestSpaceActivity extends ParrotActivity 
implements OnPageChangeListener,
		   OnClickListener,
		   OnCheckedChangeListener
{
	private int[] infosPages = {R.layout.guest_space_informations_page_fly_record_share,
			 R.layout.guest_space_informations_page_camera,
			 R.layout.guest_space_informations_page_absolute_control,
			 R.layout.guest_space_informations_page_super_stable,
			 R.layout.guest_space_informations_page_share,
			 R.layout.guest_space_informations_page_video_games};
	
	private StatusBar header;
	private ActionBar actionBar;
	private ParrotWebViewClient webViewClient;
	private ParrotWebChromeClient webChromeClient;
	
	
	@Override
	protected void onCreate(Bundle savedInstanceState) 
	{	
		super.onCreate(savedInstanceState);		
		setContentView(R.layout.guest_space_screen);
		initStatusBar();
		initActionBar();
		initInformationsScreen();
		
		RadioGroup bottomButtons = (RadioGroup) findViewById(R.id.bottomBar);
		bottomButtons.setOnCheckedChangeListener(this);
	}
	
	
	@Override
    protected void onDestroy()
    {
        super.onDestroy();
    }


    private void initActionBar()
	{
		final View viewOrangeBar = findViewById(R.id.navigation_bar);

		actionBar = new ActionBar(this, viewOrangeBar);
		actionBar.initTitle(getString(R.string.ARDRONE_2_0));
		actionBar.initHomeButton();
	}
	
	
	private void initStatusBar()
	{
		final View viewHeader = findViewById(R.id.header_preferences);
		header = new StatusBar(this, viewHeader);
	}
	
	
	public void initInformationsScreen()
	{
		actionBar.setWebView(null);
		ViewPager pager = (ViewPager) findViewById(R.id.infoPager);
		
		if (pager != null) {
			InfosAdapter adapter = new InfosAdapter(infosPages);
			pager.setAdapter(adapter);
			pager.setOnPageChangeListener(this);
		}
		
		View btnPrev = findViewById(R.id.btnPrev);
		btnPrev.setOnClickListener(this);
		View btnNext = findViewById(R.id.btnNext);
		btnNext.setOnClickListener(this);
	}
	
	
	public void initUserVideosScreen()
	{
		WebView webView = (WebView) findViewById(R.id.webView);
		webView.clearHistory();
		webView.loadUrl(getString(R.string.url_user_videos));
	}
	
	
	private void initWhereToBuySceen() 
	{
		WebView webView = (WebView) findViewById(R.id.webView);
		webView.clearHistory();
		if (NookUtils.isNook())
		{
			webView.loadUrl(getString(R.string.url_where_to_buy_nook));
		}
		else
		{
			webView.loadUrl(getString(R.string.url_where_to_buy));
		}
	}
	
	private void initStayTunedScreen() 
	{
		actionBar.setWebView(null);
		
		ImageView imageWeb = (ImageView) findViewById(R.id.imageWeb);
		TextView textUrlWeb = (TextView) findViewById(R.id.textUrlWeb);
		TextView textWeb = (TextView) findViewById(R.id.textWeb);
		imageWeb.setOnClickListener(this);
		textUrlWeb.setOnClickListener(this);
		textWeb.setOnClickListener(this);
		
		ImageView imageNews = (ImageView) findViewById(R.id.imageNews);
		TextView textSignUp = (TextView) findViewById(R.id.textSignUp);
		TextView textNews = (TextView) findViewById(R.id.textNews);
		imageNews.setOnClickListener(this);
		textSignUp.setOnClickListener(this);
		textNews.setOnClickListener(this);
		
		ImageView imageFacebook = (ImageView) findViewById(R.id.imageFacebook);
		TextView textFacebook = (TextView) findViewById(R.id.textFacebook);
		TextView textLike = (TextView) findViewById(R.id.textLike);
		imageFacebook.setOnClickListener(this);
		textFacebook.setOnClickListener(this);
		textLike.setOnClickListener(this);
		
		ImageView imageTwitter = (ImageView) findViewById(R.id.imageTwitter);
		TextView textTwitter = (TextView) findViewById(R.id.textTwitter);
		TextView textFollowUp = (TextView) findViewById(R.id.textFollowUp);
		imageTwitter.setOnClickListener(this);
		textTwitter.setOnClickListener(this);
		textFollowUp.setOnClickListener(this);
		
	}

	
	private void openInformations() 
	{
		switchToLayout( R.layout.guest_space_informations);	
		initInformationsScreen();
	}
	
	
	private void openUserVideos()
	{
		showBrowserView();	
		initUserVideosScreen();
	}
	
	
	private void openStayTuned()
	{
		switchToLayout(R.layout.guest_space_stay_tuned);
		initStayTunedScreen();
	}


	@SuppressLint("SetJavaScriptEnabled")
    private void showBrowserView() 
	{
		switchToLayout(R.layout.browse_web_screen);
		
		WebView webView = (WebView) findViewById(R.id.webView);
//		webView.setWebViewClient(new BrowserClient());
		actionBar.setWebView(webView);
		
		if (webViewClient == null) {
			webViewClient = new ParrotWebViewClient();
		}
		
		if (webChromeClient == null) {
			webChromeClient = new ParrotWebChromeClient();
		}
		
		webView.setWebViewClient(webViewClient);
		webView.setWebChromeClient(webChromeClient);
		WebSettings settings = webView.getSettings();
		settings.setJavaScriptEnabled(true);
		settings.setJavaScriptCanOpenWindowsAutomatically(false);
		settings.setPluginState(PluginState.ON);
		settings.setLoadWithOverviewMode(true);
		settings.setSupportMultipleWindows(false);
		settings.setDefaultZoom(ZoomDensity.FAR);
		settings.setSupportZoom(true);
		settings.setBuiltInZoomControls(true);
		settings.setUseWideViewPort(true);

		webView.setInitialScale(0);
	}
	
	
	private void openWhereToBuy()
	{
		showBrowserView();
		initWhereToBuySceen();
	}
	

    private void switchToLayout(int layout) 
    {
        View iformations = inflateView(layout, null, false);
        
        ViewGroup view = (ViewGroup) findViewById(R.id.content);
        view.removeAllViewsInLayout();
        view.addView(iformations, new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
    }

    
	@Override
	protected void onPause() 
	{
		super.onPause();	
		header.stopUpdating();
	}

	
	@Override
	protected void onResume() 
	{
		super.onResume();	
		header.startUpdating();
	}
	
	
	@Override
	public void onBackPressed() 
	{
		if (webChromeClient != null &&
			webChromeClient.isShowingVideo()) 
		{
			webChromeClient.onHideCustomView();
		} 
		
		WebView web = (WebView) findViewById(R.id.webView);
		
		if (web != null) {
		//	web.setWebViewClient(new BrowserClient());
			
			if (web != null && web.canGoBack()) {
				web.goBack();
			} else {
				super.onBackPressed();
			}
		} else {
			super.onBackPressed();
		}
	}
	
	
	public void onPageScrollStateChanged(int arg0) 
	{
		// Left unimplemented
	}


	public void onPageScrolled(int arg0, float arg1, int arg2) 
	{
		// Left unimplemented
	}


	public void onPageSelected(int index) 
	{
		if (index == 0) {
			View btnPrev = findViewById(R.id.btnPrev);
			if (btnPrev != null) {
				btnPrev.setVisibility(View.INVISIBLE);
			}
		} else if (index == 1) {
			View btnPrev = findViewById(R.id.btnPrev);
			if (btnPrev != null) {
				btnPrev.setVisibility(View.VISIBLE);
			}
		}
		
		if (index == infosPages.length-1) {
			View btnNext = findViewById(R.id.btnNext);
			if (btnNext != null) {
				btnNext.setVisibility(View.INVISIBLE);
			}
		} else if (index == infosPages.length - 2) {
			View btnNext = findViewById(R.id.btnNext);
			if (btnNext != null) {
				btnNext.setVisibility(View.VISIBLE);
			}
		}
	}


	public void onClick(View v) 
	{
		switch (v.getId()) {
		case R.id.btnPrev:
			onPrevPageClicked();
			break;
		case R.id.btnNext:
			onNextPageClicked();
			break;
		case R.id.textWeb:
		case R.id.imageWeb:
		case R.id.textUrlWeb:
			openBrowserActivity(getString(R.string.url_ardrone_website));
			break;
		case R.id.textNews:
		case R.id.imageNews:
		case R.id.textSignUp:
			openBrowserActivity(getString(R.string.url_newsletter));
			break;
		case R.id.textFacebook:
		case R.id.imageFacebook:
		case R.id.textLike:
			openBrowserActivity(getString(R.string.url_facebook));
			break;
		case R.id.textTwitter:
		case R.id.imageTwitter:
		case R.id.textFollowUp:
			openBrowserActivity(getString(R.string.url_twitter));
			break;
		}
	}
	
	private void openBrowserActivity(String url)
	{
		Intent intent = new Intent(GuestSpaceActivity.this, BrowserActivity.class);
		intent.putExtra(BrowserActivity.URL, url);
		startActivity(intent);
	}


	protected void onNextPageClicked() 
	{
		ViewPager pager = (ViewPager) findViewById(R.id.infoPager);
		pager.setCurrentItem(pager.getCurrentItem() + 1, true);
	}


	protected void onPrevPageClicked() 
	{
		ViewPager pager = (ViewPager) findViewById(R.id.infoPager);
		pager.setCurrentItem(pager.getCurrentItem() - 1, true);
	}


	public void onCheckedChanged(RadioGroup group, int checkedId) {
		switch (checkedId) {
		case R.id.rbInformations:
			openInformations();
			break;
		case R.id.rbUserVideos:
			openUserVideos();
			break;
		case R.id.rbStayTuned:
			openStayTuned();
			break;
		case R.id.rbWheretoBuy:
			openWhereToBuy();
			break;
		}
	}
	
	
	public void showLoadingIndicator(boolean show)
	{
		View view = findViewById(R.id.loadingIndicator);
		if (view != null) {
			view.setVisibility(show?View.VISIBLE:View.GONE);
		}
	}
	
	public void showErrorMessage(boolean show)
	{
		View view = findViewById(R.id.errorIndicator);
		if (view != null) {
			view.setVisibility(show?View.VISIBLE:View.GONE);
		}
	}
	
	
	private class ParrotWebChromeClient extends WebChromeClient
	{
		private View customView;
		private CustomViewCallback callback;
		
		@Override
		public View getVideoLoadingProgressView() {
			return new ProgressBar(GuestSpaceActivity.this);
		}

		@Override
		public void onShowCustomView(View view, final CustomViewCallback callback) {
			Log.d("GuestSpace", "Show custom View ");
		
			String youtubeVideoId = webViewClient.getYoutubeVideoId();
			try {
				Intent i = new Intent(Intent.ACTION_VIEW);
				i.setData(Uri.parse("vnd.youtube:" + youtubeVideoId));
			    startActivity(i);
			    
			    webViewClient.youtubeVideoId = null;
			} catch (ActivityNotFoundException e){
				 if (view instanceof FrameLayout) {
					 customView = view;
					 ViewGroup webRootView = (ViewGroup) findViewById(R.id.guestSpaceRoot);
					 view.setBackgroundColor(getResources().getColor(R.color.video_window_background));
				        webRootView.addView(view, new FrameLayout.LayoutParams(
				                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT,
				                Gravity.CENTER));
				        
				        this.callback = callback;
				    }

				return;
			}
		}
		

		@Override
		public void onHideCustomView() 
		{
			 ViewGroup webRootView = (ViewGroup) findViewById(R.id.guestSpaceRoot);
			 	
			 if (customView != null) {
				 webRootView.removeView(customView);
				 customView = null;
				 if (callback != null) {
					 callback.onCustomViewHidden();
				 }
				 callback = null;
			 }
			 
			super.onHideCustomView();
		}
		
		
		public boolean isShowingVideo()
		{
			return customView != null;
		}
	}
	
	private class ParrotWebViewClient extends WebViewClient
	{
		private String youtubeVideoId;
		
		@TargetApi(11)
        @Override
		public WebResourceResponse shouldInterceptRequest(final WebView view,
				String url) {
			parseVideoId(url);	
			return super.shouldInterceptRequest(view, url);
		}

		private void parseVideoId(String url) {
			int idxStart = -1;
			int idxEnd = -1;
			boolean videoUrl = false;
			
			if (url.startsWith("http://s.youtube.com/s") && url.indexOf("playback=1") != -1) {	
				 idxStart = url.indexOf("&docid=") + "&docid=".length();
				 idxEnd = url.indexOf('&', idxStart+1);
				 videoUrl = true;
			} else if (url.startsWith("http://m.youtube.com/watch")) {
				idxStart = url.indexOf("&v=") + "&v=".length();
				idxEnd = url.indexOf('&', idxStart+1);
				videoUrl = true;
			}
			
			if (videoUrl) {
				if (idxStart > -1 && idxEnd == -1) {
					idxEnd = url.length();
				}
				
				youtubeVideoId = url.substring(idxStart, idxEnd);
			}
		}

		@Override
		public boolean shouldOverrideUrlLoading(WebView view, String url) {
			if (url.startsWith("vnd.youtube")) {
	             startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));         
	             return true;
             }
	       
			view.loadUrl(url);
			return true;
		}
		
		
		public String getYoutubeVideoId()
		{
			return youtubeVideoId;
		}

		
		@Override
		public void onReceivedError(WebView view, int errorCode,
				String description, String failingUrl) 
		{
			final String mimeType = "text/html";
			view.loadData("", mimeType, null);
			
			showLoadingIndicator(false);
			showErrorMessage(true);
		}


		@Override
		public void onPageFinished(WebView view, String url) {
			showLoadingIndicator(false);
			parseVideoId(url);
			super.onPageFinished(view, url);
		}

		@Override
		public void doUpdateVisitedHistory(WebView view, String url,
				boolean isReload) 
		{
			super.doUpdateVisitedHistory(view, url, isReload);		
			actionBar.refreshWebButtonState();
		}
	}
}
