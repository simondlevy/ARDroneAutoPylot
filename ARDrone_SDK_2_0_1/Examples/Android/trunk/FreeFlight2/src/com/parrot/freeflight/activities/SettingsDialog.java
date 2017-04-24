
package com.parrot.freeflight.activities;

import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.DialogInterface.OnClickListener;
import android.content.IntentFilter;
import android.net.wifi.WifiManager;
import android.os.AsyncTask;
import android.os.Build;
import android.os.Bundle;
import android.support.v4.app.DialogFragment;
import android.support.v4.content.LocalBroadcastManager;
import android.util.Log;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputMethodManager;
import android.widget.CompoundButton;
import android.widget.CompoundButton.OnCheckedChangeListener;
import android.widget.RadioGroup;
import android.widget.SeekBar;
import android.widget.TextView;
import android.widget.TextView.OnEditorActionListener;

import com.parrot.freeflight.FreeFlightApplication;
import com.parrot.freeflight.R;
import com.parrot.freeflight.drone.DroneConfig;
import com.parrot.freeflight.drone.DroneConfig.EDroneVersion;
import com.parrot.freeflight.receivers.DroneConfigChangedReceiver;
import com.parrot.freeflight.receivers.DroneConfigChangedReceiverDelegate;
import com.parrot.freeflight.service.DroneControlService;
import com.parrot.freeflight.settings.ApplicationSettings;
import com.parrot.freeflight.settings.ApplicationSettings.ControlMode;
import com.parrot.freeflight.settings.ApplicationSettings.EAppSettingProperty;
import com.parrot.freeflight.ui.SettingsDialogDelegate;
import com.parrot.freeflight.ui.SettingsViewController;
import com.parrot.freeflight.ui.listeners.OnSeekChangedListener;
import com.parrot.freeflight.utils.FontUtils;

public class SettingsDialog extends DialogFragment
        implements
        OnCheckedChangeListener,
        OnSeekChangedListener,
        OnEditorActionListener,
        android.widget.RadioGroup.OnCheckedChangeListener,
        android.view.View.OnClickListener,
        DroneConfigChangedReceiverDelegate
{
    public static final int RESULT_OK = 0;
    public static final int RESULT_CLOSE_APP = 1;

    private static final String TAG = SettingsDialog.class.getSimpleName();
    private static final String NULL_MAC = "00:00:00:00:00:00";

    private DroneConfigChangedReceiver configChangedReceiver;

    private String ownerMac;
    private SettingsViewController view;
    private ApplicationSettings appSettings;
    private DroneConfig droneSettings;
    private DroneControlService mService;
    private Context context;
    private AsyncTask<ApplicationSettings, Integer, Boolean> loadSettingsTask;
    private SettingsDialogDelegate delegate;

    private boolean magnetoAvailable;
    private boolean acceleroAvailable;


    public SettingsDialog(Context context, SettingsDialogDelegate delegate, DroneControlService service,
            boolean magnetoAvailable)
    {
        super();
        this.delegate = delegate;

        this.magnetoAvailable = magnetoAvailable;
        this.mService = service;
        this.context = context;
    }


    public void onCreate(Bundle savedInstanceState)
    {
        super.onCreate(savedInstanceState);
        configChangedReceiver = new DroneConfigChangedReceiver(this);

        setStyle(DialogFragment.STYLE_NO_TITLE, R.style.FreeFlightTheme_SettingsScreen);
    }


    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState)
    {
        ViewGroup v = (ViewGroup) inflater.inflate(R.layout.ff2_settings_screen, container, false);
        FontUtils.applyFont(getActivity(), v);

        view = new SettingsViewController(getActivity(), inflater, v, mService.getDroneVersion(), magnetoAvailable);

        if (delegate != null) {
            this.delegate.prepareDialog(this);
        }

        return v;
    }


    @Override
    public void onStart()
    {
        super.onStart();

        droneSettings = mService.getDroneConfig();

        LocalBroadcastManager.getInstance(mService.getApplicationContext()).registerReceiver(configChangedReceiver,
                new IntentFilter(DroneControlService.DRONE_CONFIG_STATE_CHANGED_ACTION));

        loadSettings();

        Context context = mService;
        WifiManager wifiMgr = (WifiManager) context.getSystemService(Context.WIFI_SERVICE);
        ownerMac = wifiMgr.getConnectionInfo().getMacAddress();
    }


    @Override
    public void onStop()
    {
        LocalBroadcastManager.getInstance(mService.getApplicationContext()).unregisterReceiver(configChangedReceiver);

        if (loadSettingsTask != null) {
            loadSettingsTask.cancel(true);
        }

        super.onStop();
    }


    public void onOkClicked(View v)
    {
        dismiss();
    }


    @Override
    public void onDismiss(DialogInterface dialog)
    {
        super.onDismiss(dialog);

        if (delegate != null) {
            delegate.onDismissed(this);
        }
    }


    private void initListeners()
    {
        view.setToggleButtonsCheckedListener(this);
        view.setSeekBarsOnChangeListener(this);
        view.setNetworkNameOnEditorActionListener(this);
        view.setRadioButtonsCheckedListener(this);
        view.setButtonsOnClickListener(this);
    }


    private void loadSettings()
    {
        appSettings = ((FreeFlightApplication) mService.getApplicationContext()).getAppSettings();

        fillUiControls();

        view.enableAvailableSettings();

        initListeners();
    }


    protected void fillUiControls()
    {
        view.setLeftHandedChecked(appSettings.isLeftHanded());

        if (appSettings.isCombinedControlForced()) {
            view.setAceMode(true);
            view.setAceModeEnabled(false);
        }

        ControlMode mode = appSettings.getControlMode();

        view.setAceMode(mode == ControlMode.ACE_MODE);
        view.setAcceleroDisabledChecked(mode != ControlMode.ACCELERO_MODE && mode != ControlMode.ACE_MODE);
        view.setAcceleroDisabledEnabled(mode != ControlMode.ACE_MODE);

        view.setAbsoluteControlChecked(appSettings.isAbsoluteControlEnabled());
        view.setLoopingEnabled(appSettings.isFlipEnabled());
        view.setInterfaceOpacity(appSettings.getInterfaceOpacity());

        view.setYawSpeedMax(DroneConfig.YAW_MIN);
        view.setVerticalSpeedMax(DroneConfig.VERT_SPEED_MIN);
        view.setTilt(DroneConfig.TILT_MIN);

        if (mService != null) {
            droneSettings = mService.getDroneConfig();

            if (droneSettings != null) {
                view.setDroneVersion(droneSettings.getHardwareVersion(), droneSettings.getSoftwareVersion());

                view.setRecordOnUsb(droneSettings.isRecordOnUsb());

                view.setInertialVersion(droneSettings.getInertialHardwareVersion(),
                        droneSettings.getInertialSoftwareVersion());

                view.setMotorVersion(0, droneSettings.getMotor1Vendor(), droneSettings.getMotor1HardVersion(),
                        droneSettings.getMotor1SoftVersion());
                view.setMotorVersion(1, droneSettings.getMotor2Vendor(), droneSettings.getMotor2HardVersion(),
                        droneSettings.getMotor2SoftVersion());
                view.setMotorVersion(2, droneSettings.getMotor3Vendor(), droneSettings.getMotor3HardVersion(),
                        droneSettings.getMotor3SoftVersion());
                view.setMotorVersion(3, droneSettings.getMotor4Vendor(), droneSettings.getMotor4HardVersion(),
                        droneSettings.getMotor4SoftVersion());

                Log.d(TAG, "config.ownerMac = " + droneSettings.getOwnerMac());

                if (droneSettings.getOwnerMac() != null && !droneSettings.getOwnerMac().equalsIgnoreCase(NULL_MAC)) {
                    view.setPairing(true);
                } else {
                    view.setPairing(false);
                }

                view.setNetworkName(droneSettings.getNetworkName());
                view.setAltitudeLimit(droneSettings.getAltitudeLimit());
                view.setAdaptiveVideo(droneSettings.isAdaptiveVideo());
                view.setOutdoorHull(droneSettings.isOutdoorHull());

                if (droneSettings.getDroneVersion() == EDroneVersion.DRONE_1) {
                    if (droneSettings.getVideoCodec() == DroneConfig.P264_CODEC) {
                        view.setVideoP264Checked(true);
                    } else if (droneSettings.getVideoCodec() == DroneConfig.UVLC_CODEC) {
                        view.setVideoVLIBChecked(true);
                    } else {
                        Log.w(TAG, "Unknown video codec " + droneSettings.getVideoCodec());
                    }
                }

                view.setOutdoorFlight(droneSettings.isOutdoorFlight());
                view.setYawSpeedMax(droneSettings.getYawSpeedMax());
                view.setVerticalSpeedMax(droneSettings.getVertSpeedMax());
                view.setTilt(droneSettings.getTilt());
                view.setTiltMax(droneSettings.getDeviceTiltMax());
            } else {
                Log.w(TAG, "Can't get drone's configuration.");
            }
        }
    }


    public void onDefaultSettingsClicked(View v)
    {
        view.disableControlsThatRequireDroneConnection();

        AsyncTask<Integer, Integer, Boolean> resetSettingsTask = new AsyncTask<Integer, Integer, Boolean>()
        {
            protected Boolean doInBackground(Integer... params)
            {

                appSettings.setInterfaceOpacity(ApplicationSettings.DEFAULT_INTERFACE_OPACITY);

                if (appSettings.isCombinedControlForced()) {
                    appSettings.setControlMode(ControlMode.ACE_MODE);
                } else if (acceleroAvailable) {
                    appSettings.setControlMode(ControlMode.ACCELERO_MODE);
                } else {
                    appSettings.setControlMode(ControlMode.NORMAL_MODE);
                }

                appSettings.setFlipEnabled(false);
                appSettings.setAbsoluteControlEnabled(false);
                appSettings.setLeftHanded(false);
                mService.resetConfigToDefaults();

                return Boolean.TRUE;
            }


            @Override
            protected void onPostExecute(Boolean result)
            {
                fillUiControls();
                mService.requestConfigUpdate();
            }
        };

        resetSettingsTask.execute();
    }


    public void onFlatTrimClicked(View v)
    {
        mService.flatTrim();
    }


    public void onCheckedChanged(CompoundButton buttonView, boolean isChecked)
    {
        switch (buttonView.getId())
        {
        case R.id.toggleAcceleroDisabled: {
            ControlMode controlMode = (isChecked ? ControlMode.NORMAL_MODE : ControlMode.ACCELERO_MODE);
            appSettings.setControlMode(controlMode);
            delegate.onOptionChangedApp(this, EAppSettingProperty.CONTROL_MODE_PROP, controlMode);
            break;
        }
        case R.id.toggleAbsoluteControl:
            appSettings.setAbsoluteControlEnabled(isChecked);
            delegate.onOptionChangedApp(this, EAppSettingProperty.MAGNETO_ENABLED_PROP, isChecked);
            break;
        case R.id.toggleLeftHanded:
            appSettings.setLeftHanded(isChecked);
            delegate.onOptionChangedApp(this, EAppSettingProperty.LEFT_HANDED_PROP, isChecked);
            break;
        case R.id.toggleUsbRecord:
            droneSettings.setRecordOnUsb(isChecked);
            break;
        case R.id.toggleLoopingEnabled:
            appSettings.setFlipEnabled(isChecked);
            break;
        case R.id.toggleOutdoorHull:
            droneSettings.setOutdoorHull(isChecked);
            break;
        case R.id.toggleAdaptiveVideo:
            droneSettings.setAdaptiveVideo(isChecked);
            break;
        case R.id.togglePairing:
            droneSettings.setOwnerMac(isChecked ? ownerMac : NULL_MAC);
            break;
        case R.id.toggleOutdoorFlight:
            view.setOutdoorFlightControlsEnabled(false);
            droneSettings.setOutdoorFlight(isChecked);
            mService.triggerConfigUpdate();
            break;
        default:
            Log.d(TAG, "Unknown button");
        }
    }


    public void onChanged(SeekBar seek, int value)
    {
        switch (seek.getId()) {
        case R.id.seekAltitudeLimit:
            droneSettings.setAltitudeLimit(view.getAltitudeLimit());
            break;
        case R.id.seekDeviceTiltMax:
            droneSettings.setDeviceTiltMax(view.getTiltMax());
            break;
        case R.id.seekInterfaceOpacity:
            appSettings.setInterfaceOpacity(view.getInterfaceOpacity());
            delegate.onOptionChangedApp(this, EAppSettingProperty.INTERFACE_OPACITY_PROP, value);
            break;
        case R.id.seekYawSpeedMax:
            droneSettings.setYawSpeedMax(view.getYawSpeedMax());
            break;
        case R.id.seekVerticalSpeedMax:
            droneSettings.setVertSpeedMax(view.getVerticalSpeedMax());
            break;
        case R.id.seekTiltMax:
            droneSettings.setTilt(view.getTilt());
            break;
        }
    }


    public boolean onEditorAction(TextView v, int actionId, KeyEvent event)
    {
        if (v.getId() == R.id.editNetworkName) {
            if (actionId == EditorInfo.IME_ACTION_SEARCH ||
                    actionId == EditorInfo.IME_ACTION_DONE ||
                    actionId == EditorInfo.IME_ACTION_GO ||
                    actionId == EditorInfo.IME_ACTION_UNSPECIFIED ||
                    (event != null &&
                            event.getAction() == KeyEvent.ACTION_DOWN &&
                    event.getKeyCode() == KeyEvent.KEYCODE_ENTER)) {

                // If ssid has not been changed - skipping
                String newSsid = v.getText().toString();
                if (newSsid.equals(droneSettings.getNetworkName())) { return false; }

                if (newSsid == null || newSsid.trim().length() == 0) {
                    // If ssid is not valid restoring previous one
                    v.setText(droneSettings.getNetworkName());

                    // Show error message
                    AlertDialog.Builder builder = new AlertDialog.Builder(context);
                    builder.setMessage(
                            R.string.the_network_name_can_only_contain_alphanumeric_characters_and_underscores_and_must_not_be_longer_than_32_characters_)
                            .setTitle(R.string.Bad_network_name)
                            .setCancelable(true)
                            .setIcon(android.R.drawable.ic_dialog_info)
                            .setNegativeButton(android.R.string.ok, new OnClickListener() {
                                @Override
                                public void onClick(DialogInterface dialog, int which)
                                {
                                    dialog.dismiss();
                                }
                            });

                    AlertDialog dialog = builder.create();
                    dialog.show();
                } else {
                    // If ssid is valid saving applying it
                    droneSettings.setNetworkName(v.getText().toString());

                    // Displaying instructions to reconnect to the drone
                    String message = context.getString(R.string.quit_app_reboot_drone_connect_to_network);
                    message = message.replace("{device}", Build.MANUFACTURER.toUpperCase());
                    message = message.replace("{network}", v.getText());

                    AlertDialog.Builder builder = new AlertDialog.Builder(context);
                    builder.setMessage(message)
                            .setTitle(context.getString(R.string.your_changes_will_be_applied_after_rebooting_drone))
                            .setCancelable(false)
                            .setIcon(android.R.drawable.ic_dialog_info)
                            .setPositiveButton(android.R.string.ok, new OnClickListener() {

                                public void onClick(DialogInterface dialog, int which)
                                {
                                    dialog.dismiss();
                                }

                            });

                    AlertDialog dialog = builder.create();
                    dialog.show();
                }
            }

            return true;
        }

        return false;
    }


    public void onCheckedChanged(RadioGroup group, int checkedId)
    {
        switch (checkedId) {
        case R.id.rbVideoP264:
            droneSettings.setVideoCodec(DroneConfig.P264_CODEC);
            break;
        case R.id.rbVideoVLIB:
            droneSettings.setVideoCodec(DroneConfig.UVLC_CODEC);
            break;
        }
    }


    public void onClick(View v)
    {
        switch (v.getId()) {
        case R.id.btnDefaultSettings:
            onDefaultSettingsClicked(v);
            break;
        case R.id.btnFlatTrim:
            onFlatTrimClicked(v);
            break;
        case R.id.btnBack:
            dismiss();
            break;
        case R.id.btnCalibration:
            onCalibrate();
        }
    }


    private void onCalibrate()
    {
        mService.calibrateMagneto();
    }


    public void setConnected(boolean connected)
    {
        view.setConnected(connected);
    }


    public void setMagnetoAvailable(boolean available)
    {
        view.setMagnetoAvailable(available);
    }


    public void setAcceleroAvailable(boolean available)
    {
        acceleroAvailable = available;
        view.setAcceleroAvailable(available);
    }


    public void setFlying(boolean flying)
    {
        view.setFlying(flying);
    }


    public void enableAvailableSettings()
    {
        view.enableAvailableSettings();
    }


    public void onDroneConfigChanged()
    {
        fillUiControls();
        view.enableAvailableSettings();
    }
}
