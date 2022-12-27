#!/bin/bash
computer_type=$(/usr/sbin/system_profiler SPHardwareDataType | grep "Model Identifier")
if echo $computer_type | grep -q "Book" ; then {
    echo "It's a MacBook Air"
}
elif echo $computer_type | grep -vq "Book" ; then {
    echo "It's an iMac"
}
else {
    echo "name is not resolved"
}
fi