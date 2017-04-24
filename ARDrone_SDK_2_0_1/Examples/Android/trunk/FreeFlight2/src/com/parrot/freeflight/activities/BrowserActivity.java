package com.parrot.freeflight.activities;

import android.annotation.SuppressLint;
import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.view.View.OnClickListener;
import android.webkit.WebSettings;
import android.webkit.WebSettings.PluginState;
import android.webkit.WebSettings.ZoomDensity;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.LinearLayout;

import com.parrot.freeflight.R;
import com.parrot.freeflight.activities.base.ParrotActivity;

public class BrowserActivity extends ParrotActivity implements OnClickListener
{
	public static final String URL = "url";

	private WebView webView;

	private ImageView imgBack;
	private ImageView imgForward;
	
	private class BrowserClient extends WebViewClient
	{
		@Override
		public void onReceivedError(WebView view, int errorCode, String description, String failingUrl)
		{
			final String mimeType = "text/html";

			view.loadData("", mimeType, null);

			LinearLayout loadingIndicator = (LinearLayout) findViewById(R.id.loadingIndicator);
			loadingIndicator.setVisibility(View.INVISIBLE);
			
			LinearLayout errorIndicator = (LinearLayout) findViewById(R.id.errorIndicator);
			errorIndicator.setVisibility(View.VISIBLE);
		}
		

		@Override
		public void onPageFinished(WebView view, String url)
		{
			LinearLayout loadingIndicator = (LinearLayout) findViewById(R.id.loadingIndicator);
			loadingIndicator.setVisibility(View.INVISIBLE);

			checkButtonState();

			super.onPageFinished(view, url);
		}
	}

	@Override
	protected void onPause()
	{
		overridePendingTransition(R.anim.nothing, R.anim.slide_down_out);
		super.onPause();
	}

	private void checkButtonState()
	{
		if (webView.canGoBack())
		{
			imgBack.setEnabled(true);
		} else
		{
			imgBack.setEnabled(false);
		}

		if (webView.canGoForward())
		{
			imgForward.setEnabled(true);
		} else
		{
			imgForward.setEnabled(false);
		}
	}

	@Override
	protected void onCreate(Bundle savedInstanceState)
	{
		super.onCreate(savedInstanceState);

		overridePendingTransition(R.anim.slide_up_in, R.anim.nothing);

		setContentView(R.layout.browser_screen);
		initView();
	}

	@SuppressLint("SetJavaScriptEnabled")
    private void initView()
	{
		Intent intent = getIntent();

		String url = intent.getStringExtra(URL);

		webView = (WebView) findViewById(R.id.webView);
		webView.clearHistory();
		webView.loadUrl(url);
		webView.setWebViewClient(new BrowserClient());
		webView.setInitialScale(0);
		
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
		settings.setDomStorageEnabled(true);
		

		Button btnDone = (Button) findViewById(R.id.btnDone);
		btnDone.setOnClickListener(this);

		imgBack = (ImageView) findViewById(R.id.imgBack);
		imgForward = (ImageView) findViewById(R.id.imgForward);

		imgBack.setOnClickListener(this);
		imgForward.setOnClickListener(this);

		checkButtonState();
	}

	public void onClick(View v)
	{
		switch (v.getId())
		{
			case R.id.imgBack:
				historyBack();
				break;
			case R.id.imgForward:
				historyForward();
				break;
			case R.id.btnDone:
				done();
				break;
		}

	}

	
	private void done()
	{
		finish();
	}

	
	private void historyForward()
	{
		if (webView.canGoForward())
		{
			webView.goForward();
		}
	}

	
	private void historyBack()
	{
		if (webView.canGoBack())
		{
			webView.goBack();
		}
	}
}
