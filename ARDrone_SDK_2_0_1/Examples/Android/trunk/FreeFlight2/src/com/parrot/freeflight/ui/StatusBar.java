package com.parrot.freeflight.ui;

import java.util.Date;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.res.Resources;
import android.os.BatteryManager;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;

import com.parrot.freeflight.R;

public final class StatusBar
{
	private BroadcastReceiver mBatInfoReceiver;
	private BroadcastReceiver mTimeInfoReceiver;

	private final Activity activity;

	private final View headerView;

	private final int batteryIndicatorIds[] = { R.drawable.ff2_battery_000, R.drawable.ff2_battery_020, R.drawable.ff2_battery_040,
			R.drawable.ff2_battery_060, R.drawable.ff2_battery_080, R.drawable.ff2_battery_100 };

	public StatusBar(Activity activity, View headerView)
	{
		this.activity = activity;
		this.headerView = headerView;

		initBroadcastReceivers();
		updateTime();

	}
	

	protected void onStartPreferences()
	{
		Toast.makeText(activity, "Not implemented yet", Toast.LENGTH_SHORT).show();
	}

	public void startUpdating()
	{
	    updateTime();
	    
		activity.registerReceiver(mBatInfoReceiver, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
		activity.registerReceiver(mTimeInfoReceiver, new IntentFilter(Intent.ACTION_TIME_TICK));
	}

	public void stopUpdating()
	{
		activity.unregisterReceiver(mBatInfoReceiver);
		activity.unregisterReceiver(mTimeInfoReceiver);
	}

	private void initBroadcastReceivers()
	{
		mBatInfoReceiver = new BroadcastReceiver()
		{
			@Override
			public void onReceive(Context context, Intent intent)
			{
				processBatteryEvent(intent);
			}
		};

		mTimeInfoReceiver = new BroadcastReceiver()
		{
			@Override
			public void onReceive(Context context, Intent intent)
			{
				String action = intent.getAction();

				if (action.equals(Intent.ACTION_TIME_TICK))
				{
					updateTime();
				}
			}
		};
	}

	private void updateTime()
	{
		TextView txtTime = (TextView) headerView.findViewById(R.id.txtTime);

		Date date = new Date(System.currentTimeMillis());

		String time = android.text.format.DateFormat.getTimeFormat(activity).format(date);
		txtTime.setText(time);
	}

	private void processBatteryEvent(Intent intent)
	{
		TextView txtBatteryState = (TextView) headerView.findViewById(R.id.txtBatteryStatus);
		ImageView imgBatteryIcon = (ImageView) headerView.findViewById(R.id.imgBattery);
		String action = intent.getAction();

		if (action.equals(Intent.ACTION_BATTERY_CHANGED))
		{
			int level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, 0);
			txtBatteryState.setText("" + level + "%");

			Resources res = activity.getResources();

			int levelIdx = 0;

			if (level <= 20)
			{
				levelIdx = 1;
			} else if (level <= 40)
			{
				levelIdx = 2;
			} else if (level <= 60)
			{
				levelIdx = 3;
			} else if (level <= 80)
			{
				levelIdx = 4;
			} else if (level <= 100)
			{
				levelIdx = 5;
			}

			imgBatteryIcon.setImageDrawable(res.getDrawable(batteryIndicatorIds[levelIdx]));
		}
	}
}
