package com.parrot.freeflight.updater.receivers;

import com.parrot.freeflight.updater.FirmwareUpdateService.ECommand;
import com.parrot.freeflight.updater.FirmwareUpdateService.ECommandResult;

public interface FirmwareUpdateServiceReceiverDelegate
{
    public void onCommandStateChanged(ECommand command, ECommandResult result, int progress, String message);
}
