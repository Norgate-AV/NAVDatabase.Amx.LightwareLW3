MODULE_NAME='mLightwareLW3'     (
                                    dev vdvObject,
                                    dev dvPort
                                )

(***********************************************************)
#DEFINE USING_NAV_MODULE_BASE_CALLBACKS
#DEFINE USING_NAV_MODULE_BASE_PROPERTY_EVENT_CALLBACK
#DEFINE USING_NAV_MODULE_BASE_PASSTHRU_EVENT_CALLBACK
#DEFINE USING_NAV_STRING_GATHER_CALLBACK
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.SocketUtils.axi'
#include 'NAVFoundation.ArrayUtils.axi'
#include 'NAVFoundation.StringUtils.axi'
#include 'LibLightwareLW3.axi'

/*
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

constant char DELIMITER[] = "{ {NAV_CR}, {NAV_LF} }"

constant integer IP_PORT = 6107

constant long TL_DRIVE    = 1
constant long TL_IP_CHECK = 2
constant long TL_HEARTBEAT = 3

constant integer MAX_LEVELS = 3
constant integer MAX_OUTPUTS = 4
constant integer MAX_INPUTS = 4


(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile long driveTick[] = { 200 }
volatile long ipCheck[] = { 3000 }
volatile long heartbeat[] = { 20000 }

volatile integer output[MAX_LEVELS][MAX_OUTPUTS]
volatile integer outputPending[MAX_LEVELS][MAX_OUTPUTS]

volatile integer outputActual[MAX_LEVELS][MAX_OUTPUTS]

volatile integer inputSignalDetected[MAX_INPUTS] = {
    false,
    false,
    false,
    false
}


(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)

define_function SendString(char payload[]) {
    payload = "payload, NAV_CR, NAV_LF"

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_TO,
                                            dvPort,
                                            payload))

    send_string dvPort, "payload"
    wait 1 module.CommandBusy = false
}


define_function Drive() {
    stack_var integer x
    stack_var integer z

    if (module.CommandBusy) {
        return
    }

    for (x = 1; x <= MAX_OUTPUTS; x++) {
        for (z = 1; z <= MAX_LEVELS; z++) {
            if (!outputPending[z][x] || module.CommandBusy) {
                continue
            }

            outputPending[z][x] = false
            module.CommandBusy = true

            switch (z) {
                case NAV_SWITCH_LEVEL_VID:
                    SendString(BuildVideoSwitchCommand(output[z][x], x))
                    break
                case NAV_SWITCH_LEVEL_AUD:
                    SendString(BuildAudioSwitchCommand(output[z][x], x))
                    break
                case NAV_SWITCH_LEVEL_ALL:
                    SendString(BuildVideoSwitchCommand(output[z][x], x))
                    SendString(BuildAudioSwitchCommand(output[z][x], x))
                    break
            }
        }
    }
}


define_function MaintainIpConnection() {
    if (module.Device.SocketConnection.IsConnected) {
        return
    }

    NAVClientSocketOpen(dvPort.PORT,
                        module.Device.SocketConnection.Address,
                        module.Device.SocketConnection.Port,
                        IP_TCP)
}


#IF_DEFINED USING_NAV_STRING_GATHER_CALLBACK
define_function NAVStringGatherCallback(_NAVStringGatherResult args) {
    stack_var char data[NAV_MAX_BUFFER]
    stack_var char delimiter[NAV_MAX_CHARS]

    stack_var char prefix[NAV_MAX_CHARS]
    stack_var char path[NAV_MAX_CHARS]
    stack_var char property[NAV_MAX_CHARS]

    stack_var char errorCode[NAV_MAX_CHARS]
    stack_var char errorMessage[NAV_MAX_CHARS]

    stack_var char value[NAV_MAX_CHARS]
    stack_var char node[20][NAV_MAX_CHARS]
    stack_var integer nodeCount

    data = args.Data
    delimiter = args.Delimiter

    NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_PARSING_STRING_FROM,
                                            dvPort,
                                            data))

    data = NAVStripRight(data, length_array(delimiter))

    prefix = NAVStripRight(remove_string(data, ' ', 1), 1)

    switch (prefix) {
        case PREFIX_NODE_ERROR:
        case PREFIX_PROPERTY_ERROR:
        case PREFIX_METHOD_ERROR:
        case PREFIX_METHOD_RESPONSE_FAILURE: {
            path = NAVStripRight(remove_string(data, ':', 1), 1)
            property = NAVStripRight(remove_string(data, ' ', 1), 1)
            errorCode = NAVStripRight(remove_string(data, ':', 1), 1)
            errorMessage = data

            NAVErrorLog(NAV_LOG_LEVEL_ERROR, "'mLightwareLW3: Error ', errorCode, ' ', errorMessage")
            return
        }

        case PREFIX_PROPERTY_READ_ONLY:
        case PREFIX_PROPERTY_READ_WRITE:
        case PREFIX_SUBSCRIPTION_CHANGE_EVENT_MESSAGE: {
            path = NAVStripRight(remove_string(data, '.', 1), 1)
            property = NAVStripRight(remove_string(data, '=', 1), 1)
            value = data
        }

        default: {
            // Ignore all other messages
            return
        }
    }

    nodeCount = NAVSplitString(path, '/', node)

    if (nodeCount <= 0) {
        NAVErrorLog(NAV_LOG_LEVEL_ERROR, 'mLightwareLW3: Error Splitting Path')
        return
    }

    switch (property) {
        case 'SignalPresent': {
            stack_var integer inputIndex

            inputIndex = atoi(NAVStripLeft(node[nodeCount], 1))

            inputSignalDetected[inputIndex] = NAVStringToBoolean(value)
            NAVErrorLog(NAV_LOG_LEVEL_DEBUG, "'mLightwareLW3: Video Input ', itoa(inputIndex), ' SignalPresent: ', value")

            send_string vdvObject, "'INPUT_SIGNAL_DETECTED-', itoa(inputIndex), ',', NAVBooleanToString(type_cast(inputSignalDetected[inputIndex]))"
        }
        case 'ConnectedSource': {
            stack_var integer outputIndex

            outputIndex = atoi(NAVStripLeft(node[nodeCount], 1))

            outputActual[NAV_SWITCH_LEVEL_VID][outputIndex] = atoi(NAVStripLeft(value, 1))
            NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                        "'mLightwareLW3: Video Output ', itoa(outputIndex), ' ConnectedSource: ', itoa(outputActual[NAV_SWITCH_LEVEL_VID][outputIndex])")
        }
        case 'SerialNumber': {
            if (module.Device.IsInitialized) {
                return
            }

            Init()
        }
    }
}
#END_IF


define_function Init() {
    SendString(BuildSubscriptionCommand(SUBSCRIPTION_PATH_VIDEO))
    SendString(BuildSubscriptionCommand(SUBSCRIPTION_PATH_VIDEO_CROSSPOINT))
    SendString(BuildSubscriptionCommand(''))

    SendString(BuildGetConnectedVideoSourceCommand(1))
    SendString(BuildGetConnectedVideoSourceCommand(2))
    SendString(BuildGetConnectedVideoSourceCommand(3))
    SendString(BuildGetConnectedVideoSourceCommand(4))

    SendString(BuildGetVideoSignalPresenseCommand(1))
    SendString(BuildGetVideoSignalPresenseCommand(2))
    SendString(BuildGetVideoSignalPresenseCommand(3))
    SendString(BuildGetVideoSignalPresenseCommand(4))

    module.Device.IsInitialized = true
}


define_function CommunicationTimeOut(integer timeout) {
    cancel_wait 'TimeOut'

    module.Device.IsCommunicating = true

    wait (timeout * 10) 'TimeOut' {
        module.Device.IsCommunicating = false
    }
}


define_function Reset() {
    module.Device.SocketConnection.IsConnected = false
    module.Device.IsCommunicating = false
    module.Device.IsInitialized = false

    NAVTimelineStop(TL_HEARTBEAT)
    NAVTimelineStop(TL_DRIVE)
}


define_function NAVModulePropertyEventCallback(_NAVModulePropertyEvent event) {
    switch (event.Name) {
        case NAV_MODULE_PROPERTY_EVENT_IP_ADDRESS: {
            module.Device.SocketConnection.Address = event.Args[1]
            module.Device.SocketConnection.Port = IP_PORT
            NAVTimelineStart(TL_IP_CHECK, ipCheck, TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
        }
    }
}


define_function NAVModulePassthruEventCallback(_NAVModulePassthruEvent event) {
    if (event.Device != vdvObject) {
        return
    }

    SendString(event.Payload)
}


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    create_buffer dvPort, module.RxBuffer.Data
}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[dvPort] {
    online: {
        if (data.device.number != 0) {
            NAVCommand(data.device, "'SET BAUD 38400,N,8,1 485 DISABLE'")
            NAVCommand(data.device, "'B9MOFF'")
            NAVCommand(data.device, "'CHARD-0'")
            NAVCommand(data.device, "'CHARDM-0'")
            NAVCommand(data.device, "'HSOFF'")
        }

        if (data.device.number == 0) {
            module.Device.SocketConnection.IsConnected = true
        }

        SendString(BuildProtocol(COMMAND_TYPE_GET, '/', 'SerialNumber', ''))

        NAVTimelineStart(TL_DRIVE, driveTick, TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
        NAVTimelineStart(TL_HEARTBEAT, heartbeat, TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
    }
    offline: {
        if (data.device.number == 0) {
            NAVClientSocketClose(data.device.port)
            Reset()
        }
    }
    onerror: {
        if (data.device.number == 0) {
            Reset()
        }
    }
    string: {
        CommunicationTimeOut(30)

        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM,
                                                data.device,
                                                data.text))

        select {
            active (1): {
                NAVStringGather(module.RxBuffer, "NAV_CR, NAV_LF")
            }
        }
    }
}


data_event[vdvObject] {
    online: {
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_DESCRIPTION,Matrix Switcher'")
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_URL,lightware.com'")
        NAVCommand(data.device, "'PROPERTY-RMS_MONITOR_ASSET_PROPERTY,MONITOR_ASSET_MANUFACTURER_NAME,Lightware'")
    }
    command: {
        stack_var _NAVSnapiMessage message

        NAVParseSnapiMessage(data.text, message)

        switch (message.Header) {
            case NAV_MODULE_EVENT_SWITCH: {
                stack_var integer level
                stack_var integer outputIndex

                level = NAVFindInArrayString(NAV_SWITCH_LEVELS, message.Parameter[3])

                if (!level) { level = 1 }

                outputIndex = atoi(message.Parameter[2])
                if (!outputIndex) { outputIndex = 1 }

                output[level][outputIndex] = atoi(message.Parameter[1])
                outputPending[level][outputIndex] = true
            }
            case NAV_MODULE_EVENT_VOLUME: {
                switch (message.Parameter[1]) {
                    case 'ABS': {
                        stack_var integer value

                        value = atoi(message.Parameter[2])
                        SendString(BuildVolumePercentCommand(value, 2))

                        send_level vdvObject, VOL_LVL, value * 255 / 100
                    }
                    default: {
                        stack_var integer value
                        stack_var integer percentage

                        value = atoi(message.Parameter[1])
                        send_level vdvObject, VOL_LVL, value

                        percentage = value * 100 / 255

                        SendString(BuildVolumePercentCommand(percentage, 2))
                    }
                }
            }
            case NAV_MODULE_EVENT_MUTE: {
                switch (message.Parameter[1]) {
                    case 'ON': { SendString(BuildVolumeMuteCommand(true, 2)) }
                    case 'OFF': { SendString(BuildVolumeMuteCommand(false, 2)) }
                }
            }
        }
    }
}


timeline_event[TL_DRIVE] { Drive() }


timeline_event[TL_IP_CHECK] { MaintainIpConnection() }


timeline_event[TL_HEARTBEAT] {
    SendString(BuildProtocol(COMMAND_TYPE_GET, '/', 'SerialNumber', ''))
}


timeline_event[TL_NAV_FEEDBACK] {
    [vdvObject, NAV_IP_CONNECTED]	= (module.Device.SocketConnection.IsConnected)
    [vdvObject, DEVICE_COMMUNICATING] = (module.Device.IsCommunicating)
    [vdvObject, DATA_INITIALIZED] = (module.Device.IsInitialized)

    {
        stack_var integer x

        for (x = 1; x <= MAX_INPUTS; x++) {
            [vdvObject, NAV_INPUT_SIGNAL[x]] = (inputSignalDetected[x])
        }
    }
}


(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
