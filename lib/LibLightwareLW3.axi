PROGRAM_NAME='LibLightwareLW3'

(***********************************************************)
#include 'NAVFoundation.Core.axi'

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


#IF_NOT_DEFINED __LIB_LIGHTWARE_LW3__
#DEFINE __LIB_LIGHTWARE_LW3__ 'LibLightwareLW3'

DEFINE_CONSTANT

constant integer COMMAND_TYPE_GET = 1
constant integer COMMAND_TYPE_SET = 2
constant integer COMMAND_TYPE_CALL = 3
constant integer COMMAND_TYPE_MAN = 4
constant integer COMMAND_TYPE_SUBSCRIBE = 5
constant integer COMMAND_TYPE_UNSUBSCRIBE = 6

constant char COMMAND_TYPE[][NAV_MAX_CHARS]     =   {
                                                        'GET',
                                                        'SET',
                                                        'CALL',
                                                        'MAN',
                                                        'OPEN',
                                                        'CLOSE'
                                                    }

constant char SUBSCRIPTION_PATH_VIDEO[] = '/V1/MEDIA/VIDEO/*'
constant char SUBSCRIPTION_PATH_AUDIO[] = '/V1/MEDIA/AUDIO/*'
constant char SUBSCRIPTION_PATH_VIDEO_CROSSPOINT[] = '/V1/MEDIA/VIDEO/XP/*'
constant char SUBSCRIPTION_PATH_AUDIO_CROSSPOINT[] = '/V1/MEDIA/AUDIO/XP/*'

constant char PREFIX_NODE[] = 'n-'
constant char PREFIX_NODE_ERROR[] = 'nE'
constant char PREFIX_NODE_MANUAL[] = 'nm'
constant char PREFIX_PROPERTY_READ_ONLY[] = 'pr'
constant char PREFIX_PROPERTY_READ_WRITE[] = 'pw'
constant char PREFIX_PROPERTY_ERROR[] = 'pE'
constant char PREFIX_PROPERTY_MANUAL[] = 'pm'
constant char PREFIX_METHOD[] = 'm-'
constant char PREFIX_METHOD_RESPONSE_SUCCESS[] = 'mO'
constant char PREFIX_METHOD_RESPONSE_FAILURE[] = 'mF'
constant char PREFIX_METHOD_ERROR[] = 'mE'
constant char PREFIX_METHOD_MANUAL[] = 'mm'
constant char PREFIX_SUBSCRIPTION_OPEN_RESPONSE[] = 'o-'
constant char PREFIX_SUBSCRIPTION_CLOSE_RESPONSE[] = 'c-'
constant char PREFIX_SUBSCRIPTION_CHANGE_EVENT_MESSAGE[] = 'CHG'


define_function char[NAV_MAX_BUFFER] BuildProtocol(integer type, char path[], char method[], char args[]) {
    stack_var char payload[NAV_MAX_BUFFER]

    payload = "COMMAND_TYPE[type]"

    if (!length_array(path)) {
        return payload
    }

    payload = "payload, ' ', path"

    if (length_array(method)) {
        switch (type) {
            case COMMAND_TYPE_CALL:
                payload = "payload, ':', method"
                break
            default:
                payload = "payload, '.', method"
                break
        }
    }

    if (type == COMMAND_TYPE_GET || type == COMMAND_TYPE_MAN || type == COMMAND_TYPE_SUBSCRIBE || type == COMMAND_TYPE_UNSUBSCRIBE) {
        return payload
    }

    if (length_array(args)) {
        switch (type) {
            case COMMAND_TYPE_SET:
                payload = "payload, '=', args"
                break
            case COMMAND_TYPE_CALL:
                payload = "payload, '(', args, ')'"
                break
        }
    }

    return payload
}


define_function char[NAV_MAX_BUFFER] BuildVideoSwitchCommand(integer input, integer output) {
    return BuildProtocol(COMMAND_TYPE_CALL, '/V1/MEDIA/VIDEO/XP', 'switch', "'I', itoa(input), ':O', itoa(output)")
}


define_function char[NAV_MAX_BUFFER] BuildAudioSwitchCommand(integer input, integer output) {
    return BuildProtocol(COMMAND_TYPE_CALL, '/V1/MEDIA/AUDIO/XP', 'switch', "'I', itoa(input), ':O', itoa(output)")
}


define_function char[NAV_MAX_BUFFER] BuildVolumePercentCommand(integer value, integer output) {
    return BuildProtocol(COMMAND_TYPE_SET, "'/V1/MEDIA/AUDIO/O', itoa(output)", 'VolumePercent', itoa(value))
}


define_function char[NAV_MAX_BUFFER] BuildVolumeMuteCommand(integer state, integer output) {
    return BuildProtocol(COMMAND_TYPE_SET, "'/V1/MEDIA/AUDIO/O', itoa(output)", 'Mute', NAVBooleanToString(type_cast(state)))
}


define_function char[NAV_MAX_BUFFER] BuildGetConnectedVideoSourceCommand(integer output) {
    return BuildProtocol(COMMAND_TYPE_GET, "'/V1/MEDIA/VIDEO/XP/O', itoa(output)", 'ConnectedSource', '')
}


define_function char[NAV_MAX_BUFFER] BuildGetVideoSignalPresenseCommand(integer input) {
    return BuildProtocol(COMMAND_TYPE_GET, "'/V1/MEDIA/VIDEO/I', itoa(input)", 'SignalPresent', '')
}


define_function char[NAV_MAX_BUFFER] BuildSubscriptionCommand(char path[]) {
    return BuildProtocol(COMMAND_TYPE_SUBSCRIBE, path, '', '')
}


#END_IF // __LIB_LIGHTWARE_LW3__
