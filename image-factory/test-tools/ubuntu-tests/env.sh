IMAGE="$URCHIN_IMG_ID"
TESTENV="./.current-run.env.sh"
FLAVOR_STD="n1.cw.standard-1"
FLAVOR_ALT="n1.cw.standard-2"
NETWORK="b9580568-3f05-4a20-82ee-f5617c74962d"
FLOATING_IP_POOL="6ea98324-0f14-49f6-97c0-885d1b8dc517"
KEYPAIR="jenkins-ci"
PRIVATE_KEY="/var/lib/jenkins/.ssh/jenkins-ci.pem"
SSH_USER="cloud"
HOST="google.com"
LOG_FILE="/tmp/test-ubuntu.log"
USER_DATA_FILE="./userdata.yml"

if [ -f "$TESTENV" ]; then
    . $TESTENV
fi
