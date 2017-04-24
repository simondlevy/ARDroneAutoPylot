package com.parrot.freeflight.ui;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.os.Build;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.animation.Animation;
import android.webkit.WebView;
import android.widget.Button;
import android.widget.ImageButton;
import android.widget.RelativeLayout;
import android.widget.TextView;

import com.parrot.freeflight.R;
import com.parrot.freeflight.activities.DashboardActivity;
import com.parrot.freeflight.utils.AnimationUtils;

public class ActionBar implements OnClickListener
{
	private final View view;
	private final Activity activity;
	private Animation animationCurrent;
	
	public enum Background
	{
		ACCENT, ACCENT_HALF_TRANSP;
	}
	private WebView webView;

	private final OnClickListener homeBtnCLickListener = new OnClickListener()
	{
		public void onClick(final View v)
		{
			startDashboardActivity();
		}
	};


	private final OnClickListener backBtnCLickListener = new OnClickListener()
	{
		public void onClick(final View v)
		{
			activity.finish();
		}
	};



	public ActionBar(final Activity activity, final View view)
	{
		this.view = view;
		this.activity = activity;
	}

	public void initBackButton()
	{
		final ImageButton btnBack = (ImageButton) view.findViewById(R.id.btn_back_home);
		btnBack.setOnClickListener(backBtnCLickListener);
		btnBack.setVisibility(View.VISIBLE);
		btnBack.setImageDrawable(activity.getResources().getDrawable(R.drawable.btn_back_arrow));
	}

	public void initHomeButton()
	{
		final ImageButton btnHome = (ImageButton) view.findViewById(R.id.btn_back_home);
		btnHome.setOnClickListener(homeBtnCLickListener);
		btnHome.setVisibility(View.VISIBLE);
		btnHome.setImageDrawable(activity.getResources().getDrawable(R.drawable.btn_home));
	}
	
	
	public void initShareButton(OnClickListener listener)
	{
		final Button btnShare = (Button) view.findViewById(R.id.btnShare);
		btnShare.setOnClickListener(listener);
		btnShare.setVisibility(View.VISIBLE);
	}
	
	
	public void changeBackground(Background bg)
	{
		RelativeLayout layout = (RelativeLayout) view;

		switch (bg)
		{
			case ACCENT:
				layout.setBackgroundResource(R.color.accent);
				break;
			case ACCENT_HALF_TRANSP:
				layout.setBackgroundResource(R.color.accent_half_transp);
				break;

		}
	}
	
	
	public void setWebView(WebView webView)
	{
		this.webView = webView;

		View webButtons = view.findViewById(R.id.webButtons);	
		webButtons.setVisibility(webView != null?View.VISIBLE:View.GONE);
		
		View btnForward = view.findViewById(R.id.btnGoForward);
		View btnBack = view.findViewById(R.id.btnGoBack);
		
		btnForward.setOnClickListener(this);
		btnBack.setOnClickListener(this);	
	
		if (webView != null) {
			btnBack.setEnabled(webView.canGoBack());
			btnForward.setEnabled(webView.canGoForward());
		}
	}
	
	
	public void refreshWebButtonState()
	{
		if (webView != null) {
			View btnForward = view.findViewById(R.id.btnGoForward);
			View btnBack = view.findViewById(R.id.btnGoBack);
			
			btnBack.setEnabled(webView.canGoBack());
			btnForward.setEnabled(webView.canGoForward());
		}
	}
	

	public void initTitle(final String title)
	{
		final TextView txtTitle = (TextView) view.findViewById(R.id.txt_title);
		txtTitle.setText(title);
		txtTitle.setVisibility(View.VISIBLE);
	}
	

	private void startDashboardActivity()
	{
		final Intent intent = new Intent(activity, DashboardActivity.class);
		activity.startActivity(intent);
		activity.finish();
	}

	
	public void onClick(View v) 
	{
		if (webView != null) {
			switch (v.getId()) {
			case R.id.btnGoBack:
				webView.goBack();
				v.setEnabled(webView.canGoBack());
				break;
			case R.id.btnGoForward:
				webView.goForward();
				v.setEnabled(webView.canGoForward());
				break;
			}
		}	
	}
	
	
	@SuppressLint("NewApi")
    public boolean isVisible()
	{
	    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB) {
	        return view.getVisibility() == View.VISIBLE && view.getAlpha() >= 0;
	    } else {
	        return view.getVisibility() == View.VISIBLE;
	    }
	}
	

	public void hide(boolean animated)
	{
	    if (animated) {
	        if (animationCurrent != null && !animationCurrent.hasEnded()) {
	            return;
	        }

	        animationCurrent = AnimationUtils.makeInvisibleAnimated(view);
	    } else {
	        view.setVisibility(View.INVISIBLE);
	    }
	}


	public void show(boolean animated)
    {
	    if (animated) {
            if (animationCurrent != null && !animationCurrent.hasEnded()) {
                return;
            }
    
            animationCurrent = AnimationUtils.makeVisibleAnimated(view);
	    } else {
	        view.setVisibility(View.VISIBLE);
	    }
    }
    
	
	public View getView()
	{
		return view;
	}
}
