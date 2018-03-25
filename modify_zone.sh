#!/bin/bash

fail() {
    echo "[FAIL] $*"
    echo "roll back file..."
    cp -p ${OLD_FILE} ${FILE} && rm $OLD_FILE && echo "OK" || echo "NG"
    exit 1
}

yes_no() {
    read -p "$* (y/n): " yesno
    case $yesno in
        "y") return 0 ;;
        "n") return 1 ;;
        *) fail "please input y or n" ;;
    esac
}

if [ $UID -ne 0 ]; then
    fail "requires root privileges"
fi

CONF=$( basename $0 .sh ).conf
if [ ! -f $CONF ]; then
    fail "no such file $CONF"
fi
. $CONF

grep -E -o -m 1 '(^| |")(([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])' $IP_FILE \
    > /dev/null 2>&1 || fail "$IP_FILE is invalid"
IP=$(grep -E -o -m 1 '(([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])' $IP_FILE)
echo "new ip is [$IP]"

echo "copy zone file..."
cp -ip ${FILE} ${OLD_FILE} && echo "OK" || fail

echo "increment serial number..."
serial=$(fgrep '; serial' $FILE | awk '{print $1}')
sed -i -e '3d' $FILE || fail
if [ $DATE -eq $(echo $serial | cut -c 1-8) ]; then
    sed -i -e "2a \\\t`expr $serial + 1`\t; serial" $FILE && echo "OK" || fail
else
    sed -i -e "2a \\\t${DATE}01\t; serial" $FILE && echo "OK" || fail
fi

echo "update ip..."
sed -i -e '$d' $FILE || fail
sed -i -e "\$a $A_RECORD\tIN\tA\t$IP" $FILE && echo "OK" || fail

echo "named-checkzone..."
/usr/sbin/named-checkzone $ZONE $FILE || fail

echo "diff result..."
echo "--------------------------------------------------------------------"
diff -up $OLD_FILE $FILE
echo "--------------------------------------------------------------------"

yes_no "reload OK?" \
    && /usr/sbin/rndc reload $ZONE \
    || fail "user cancel"
